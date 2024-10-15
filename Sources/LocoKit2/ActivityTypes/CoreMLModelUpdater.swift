//
//  CoreMLModelUpdater.swift
//  
//
//  Created by Matt Greenfield on 5/11/22.
//

import Foundation
import BackgroundTasks
import CoreLocation
import TabularData
import CoreML
import GRDB
#if !targetEnvironment(simulator)
import CreateML
#endif

@ActivityTypesActor
public final class CoreMLModelUpdater {

    public static var highlander = CoreMLModelUpdater()

    var backgroundTaskExpired = false

    public func queueUpdatesForModelsContaining(_ samples: [LocomotionSample]) {
        var lastD2Model: ActivityTypesModel?
        var models: Set<ActivityTypesModel> = []

        for sample in samples where sample.confirmedActivityType != nil {
            guard sample.hasUsableCoordinate, let coordinate = sample.location?.coordinate else { continue }

            if let lastD2Model, lastD2Model.contains(coordinate: coordinate) {
                continue
            }

            let d2model = ActivityTypesModel.fetchModelFor(coordinate: coordinate, depth: 2)
            models.insert(d2model)
            lastD2Model = d2model

            models.insert(ActivityTypesModel.fetchModelFor(coordinate: coordinate, depth: 1))
            models.insert(ActivityTypesModel.fetchModelFor(coordinate: coordinate, depth: 0))
        }

        for model in models {
            model.needsUpdate = true
            model.save()
        }
    }

    private var onUpdatesComplete: ((Bool) -> Void)?

    public func updateQueuedModels(task: BGProcessingTask, currentClassifier classifier: ActivityClassifier?, onComplete: ((Bool) -> Void)? = nil) {
        if let onComplete {
            onUpdatesComplete = onComplete
        }

        // not allowed to continue?
        if backgroundTaskExpired {
            backgroundTaskExpired = false
            onUpdatesComplete?(true)
            return
        }

        // catch background expiration
        if task.expirationHandler == nil {
            backgroundTaskExpired = false
            task.expirationHandler = {
                self.backgroundTaskExpired = true
                task.setTaskCompleted(success: false)
            }
        }

        // do the current CD2 first, if it needs it
        let currentModel = classifier?.models.first { $0.value.geoKey.hasPrefix("CD2") }?.value
        if let currentModel, currentModel.needsUpdate {
            update(model: currentModel, in: task, currentClassifier: classifier)
            return
        }

        // CD0 update intervals
        let cd0UpdateInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        let cd0FrequentUpdateInterval: TimeInterval = 24 * 60 * 60 // 1 day

        // check for any queued model, prioritising by depth and completeness
        do {
            let model = try Database.pool.read { db in
                try ActivityTypesModel
                    .fetchOne(
                        db,
                        sql: """
                        needsUpdate = 1 AND 
                        (depth > 0 OR 
                         (depth = 0 AND 
                          (lastUpdated IS NULL OR 
                           (totalSamples < ? AND lastUpdated < datetime('now', '-\(Int(cd0FrequentUpdateInterval)) seconds')) OR
                           (totalSamples >= ? AND lastUpdated < datetime('now', '-\(Int(cd0UpdateInterval)) seconds'))
                          )
                         )
                        )
                        ORDER BY depth DESC, totalSamples ASC
                        """,
                        arguments: [ActivityTypesModel.modelMinTrainingSamples[0]!, ActivityTypesModel.modelMinTrainingSamples[0]!]
                    )
            }

            if let model {
                // backfill r-tree for old dbs or restores from backup
                // Task.detached {
                //     await store.backfillSampleRTree(batchSize: CoreMLModelWrapper.modelMaxTrainingSamples[0]!)
                // }

                update(model: model, in: task, currentClassifier: classifier)
                return
            }
        } catch {
            logger.error(error, subsystem: .database)
        }

        // job's finished
        onUpdatesComplete?(false)
        task.setTaskCompleted(success: true)
    }

    public func updateModel(geoKey: String) {
        do {
            let model = try Database.pool.read {
                try ActivityTypesModel.fetchOne($0, key: geoKey)
            }
            if let model {
                update(model: model)
            }
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Model building

#if targetEnvironment(simulator)
    public func update(model: ActivityTypesModel, in task: BGProcessingTask? = nil, currentClassifier classifier: ActivityClassifier? = nil) {
        print("SIMULATOR DOESN'T SUPPORT MODEL UPDATES")
    }
#else
    public func update(model: ActivityTypesModel, in task: BGProcessingTask? = nil, currentClassifier classifier: ActivityClassifier? = nil) {
        if model.geoKey.hasPrefix("B") { return }

        defer {
            if let task {
                updateQueuedModels(task: task, currentClassifier: classifier)
            }
        }

        print("UPDATING: \(model.geoKey)")

        let manager = FileManager.default
        let tempModelFile = manager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mlmodel")

        do {
            var csvFile: URL?
            var samplesCount = 0
            var includedTypes: Set<ActivityType> = []

            let start = Date()
            let samples = try fetchTrainingSamples(for: model)
            print("UPDATING: \(model.geoKey), SAMPLES BATCH: \(samples.count), duration: \(start.age)")

            let (url, samplesAdded, typesAdded) = try exportCSV(samples: samples, appendingTo: csvFile)
            csvFile = url
            samplesCount += samplesAdded
            includedTypes.formUnion(typesAdded)

            // if includedTypes only has one type and it's not stationary, throw in a fake stationary sample
            if samplesCount > 0 && includedTypes.count == 1 && !includedTypes.contains(.stationary) {
                print("UPDATING: \(model.geoKey), ADDING FAKE STATIONARY SAMPLE")

                // create a fake stationary sample
                let coord = model.centerCoordinate
                let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                var fakeSample = LocomotionSample(
                    date: .now,
                    movingState: .stationary,
                    recordingState: .recording,
                    location: location
                )
                fakeSample.confirmedActivityType = .stationary
                fakeSample.xyAcceleration = 0
                fakeSample.zAcceleration = 0
                fakeSample.stepHz = 0

                // add the fake sample to the CSV
                let (url, samplesAdded, typesAdded) = try exportCSV(samples: [fakeSample], appendingTo: csvFile)
                csvFile = url
                samplesCount += samplesAdded
                includedTypes.formUnion(typesAdded)
            }

            guard samplesCount > 0, includedTypes.count > 1 else {
                print("SKIPPED: \(model.geoKey) (samples: \(samplesCount), includedTypes: \(includedTypes.count))")
                model.totalSamples = samplesCount
                model.accuracyScore = nil
                model.lastUpdated = Date()
                model.needsUpdate = false
                model.save()
                return
            }

            print("UPDATING: \(model.geoKey), FINISHED WRITING CSV FILE")

            guard let csvFile else {
                logger.error("Missing CSV file for model build", subsystem: .activitytypes)
                return
            }

            // load the csv file
            let dataFrame = try DataFrame(contentsOfCSVFile: csvFile)

            // train the model
            let classifier = try MLBoostedTreeClassifier(trainingData: dataFrame, targetColumn: "confirmedActivityType")

            do {
                try FileManager.default.createDirectory(at: ActivityTypesModel.modelsDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.error("Couldn't create MLModels directory", subsystem: .activitytypes)
            }

            // write model to temp file
            try classifier.write(to: tempModelFile)

            // compile the model
            let compiledModelFile = try MLModel.compileModel(at: tempModelFile)

            // save model to final dest
            _ = try manager.replaceItemAt(model.modelURL, withItemAt: compiledModelFile)

            // update metadata
            model.totalSamples = samplesCount
            model.accuracyScore = (1.0 - classifier.validationMetrics.classificationError)
            model.lastUpdated = .now
            model.needsUpdate = false
            model.save()

            logger.info("UPDATED: \(model.geoKey) (samples: \(model.totalSamples), accuracy: \(String(format: "%.2f", model.accuracyScore!)), includedTypes: \(includedTypes.count))", subsystem: .activitytypes)

            try model.reloadModel()

        } catch {
            logger.error(error, subsystem: .activitytypes)
        }
    }
#endif

    private func fetchTrainingSamples(for model: ActivityTypesModel) throws -> [LocomotionSample] {
        return try Database.pool.read { db in
            var query = LocomotionSample
                .filter(sql: """
                    confirmedActivityType IS NOT NULL
                    AND likely(xyAcceleration IS NOT NULL)
                    AND likely(zAcceleration IS NOT NULL)
                    AND likely(stepHz IS NOT NULL)
                    """)

            if model.depth != 0 {
                query = query
                    .joining(required: LocomotionSample.rtree.aliased(TableAlias(name: "r")))
                    .filter(
                        sql: """
                            r.latMin >= :latMin AND r.latMax <= :latMax AND 
                            r.lonMin >= :lonMin AND r.lonMax <= :lonMax
                            """,
                        arguments: [
                            "latMin": model.latitudeRange.lowerBound, "latMax": model.latitudeRange.upperBound,
                            "lonMin": model.longitudeRange.lowerBound, "lonMax": model.longitudeRange.upperBound
                        ]
                    )
            }

            return try query
                .order(Column("date").desc)
                .limit(ActivityTypesModel.modelMaxTrainingSamples[model.depth]!)
                .fetchAll(db)
        }
    }

    private func exportCSV(samples: [LocomotionSample], appendingTo: URL? = nil) throws -> (URL, Int, Set<ActivityType>) {
        let modelFeatures = [
            "confirmedActivityType", "stepHz", "xyAcceleration", "zAcceleration", "movingState",
            "verticalAccuracy", "horizontalAccuracy", "speed", "course",
            "latitude", "longitude", "altitude",
            "timeOfDay", "sinceVisitStart"
        ]

        let csvFile = appendingTo ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        // header the csv file
        if appendingTo == nil {
            try modelFeatures.joined(separator: ",").appendLineTo(csvFile)
        }

        var samplesAdded = 0
        var includedTypes: Set<ActivityType> = []

        print("exportCSV() CONSIDERING SAMPLES: \(samples.count)")

        // write the samples to file
        for sample in samples {
            guard sample.source == "LocoKit" else { continue }
            guard let confirmedActivityType = sample.confirmedActivityType else { continue }
            guard let location = sample.location, location.hasUsableCoordinate else { continue }
            guard location.speed >= 0, location.course >= 0 else { continue }
            guard let stepHz = sample.stepHz else { continue }
            guard let xyAcceleration = sample.xyAcceleration else { continue }
            guard let zAcceleration = sample.zAcceleration else { continue }
            guard location.speed >= 0 else { continue }
            guard location.course >= 0 else { continue }
            guard location.horizontalAccuracy > 0 else { continue }
            guard location.verticalAccuracy > 0 else { continue }

            includedTypes.insert(sample.confirmedActivityType!)

            var line = ""
            line += "\(confirmedActivityType.rawValue),\(stepHz),\(xyAcceleration),\(zAcceleration),\(sample.movingState.rawValue),"
            line += "\(location.verticalAccuracy),\(location.horizontalAccuracy),\(location.speed),\(location.course),"
            line += "\(location.coordinate.latitude),\(location.coordinate.longitude),\(location.altitude),"
            line += "\(sample.timeOfDay),\(sample.sinceVisitStart)"

            try line.appendLineTo(csvFile)
            samplesAdded += 1
        }

        print("exportCSV() WROTE SAMPLES: \(samplesAdded)")

        return (csvFile, samplesAdded, includedTypes)
    }


}
