//
//  ActivityTypesManager.swift
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
public enum ActivityTypesManager {
    
    // MARK: - Task Configuration

    nonisolated
    public static let taskIdentifier = "com.bigpaua.Arc.activityTypeModelUpdates"

    // MARK: - Queueing Model Updates

    public static func queueUpdatesForModelsContaining(_ samples: [LocomotionSample]) {
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

        do {
            try Database.pool.write { db in
                for var model in models {
                    try model.updateChanges(db) {
                        $0.needsUpdate = true
                    }
                }
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Background Task Management

    @MainActor
    public static func registerModelUpdatesTask() {
        let taskDefinition = TaskDefinition(
            identifier: taskIdentifier,
            minimumDelay: .hours(1),
            requiresNetwork: false,
            requiresPower: true,
            workHandler: processModelsForBackground
        )
        
        TasksManager.add(task: taskDefinition)
    }
    
    private static func processModelsForBackground() async throws {
        while true {
            if Task.isCancelled { throw CancellationError() }
            
            // get prioritised model to update (one at a time)
            let model = await fetchNextModelToUpdate()
            
            // no more models to update? we're done
            guard let model else { return }
            
            updateModel(geoKey: model.geoKey)
        }
    }
    
    private static func fetchNextModelToUpdate() async -> ActivityTypesModel? {

        // CD0 update interval for already "complete" models
        let cd0UpdateInterval: TimeInterval = .days(7)

        // CD0 update interval for "incomplete" moels
        let cd0FrequentUpdateInterval: TimeInterval = .days(1)

        do {
            return try await Database.pool.read { db in
                try ActivityTypesModel
                    .filter(
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
                        """,
                        arguments: [ActivityTypesModel.modelMinTrainingSamples[0]!, ActivityTypesModel.modelMinTrainingSamples[0]!]
                    )
                    .order(Column("depth").desc, Column("totalSamples").asc)
                    .fetchOne(db)
            }
            
        } catch {
            logger.error(error, subsystem: .database)
            return nil
        }
    }
    
    public static func fetchPendingModelGeoKeys() async throws -> [String] {
        return try await Database.pool.read { db in
            let request = ActivityTypesModel
                .select(Column("geoKey"))
                .filter(Column("needsUpdate") == true)
                .order(Column("depth").desc, Column("totalSamples").asc)
            return try String.fetchAll(db, request)
        }
    }

    public static func updateModel(geoKey: String) {
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
    
    public static func processModelUpdate(model: ActivityTypesModel, fileMissing: Bool = false) {
        guard model.needsUpdate else { return }

        let shouldUpdateImmediately = fileMissing || model.depth < 2 || (model.depth == 2 && model.completenessScore < 1.0)
        
        if shouldUpdateImmediately {
            let geoKey = model.geoKey
            Task { updateModel(geoKey: geoKey) }
        }
    }

    // MARK: - Model building

#if targetEnvironment(simulator)
    static func update(model: ActivityTypesModel) {
        print("SIMULATOR DOESN'T SUPPORT MODEL UPDATES")
    }
#else
    static func update(model: ActivityTypesModel) {
        if model.geoKey.hasPrefix("B") { return }
        
        if Task.isCancelled { return }

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
                var fakeSample = LocomotionSample(
                    date: .now,
                    movingState: .stationary,
                    recordingState: .recording,
                    location: model.centerCoordinate.location
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
                try? Database.pool.write { db in
                    var mutableModel = model
                    try mutableModel.updateChanges(db) {
                        $0.totalSamples = samplesCount
                        $0.accuracyScore = nil
                        $0.lastUpdated = .now
                        $0.needsUpdate = false
                    }
                }
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
                try FileManager.default.createDirectory(at: MLModelCache.modelsDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.error("Couldn't create MLModels directory", subsystem: .activitytypes)
            }

            // write model to temp file
            try classifier.write(to: tempModelFile)

            // compile the model
            let compiledModelFile = try MLModel.compileModel(at: tempModelFile)

            // save model to final dest
            _ = try manager.replaceItemAt(MLModelCache.getModelURLFor(filename: model.filename), withItemAt: compiledModelFile)

            // update metadata
            try? Database.pool.write { db in
                var mutableModel = model
                try mutableModel.updateChanges(db) {
                    $0.totalSamples = samplesCount
                    $0.accuracyScore = (1.0 - classifier.validationMetrics.classificationError)
                    $0.lastUpdated = .now
                    $0.needsUpdate = false
                }
            }

            logger.info("UPDATED: \(model.geoKey) (samples: \(model.totalSamples), accuracy: \(String(format: "%.2f", model.accuracyScore ?? 0)), completeness: \(String(format: "%.2f", model.completenessScore)), includedTypes: \(includedTypes.count))", subsystem: .activitytypes)

            try model.reloadModel()

            ActivityClassifier.invalidateModel(geoKey: model.geoKey)

        } catch {
            logger.error(error, subsystem: .activitytypes)
        }
    }
#endif

    private static func fetchTrainingSamples(for model: ActivityTypesModel) throws -> [LocomotionSample] {
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

    private static func exportCSV(samples: [LocomotionSample], appendingTo: URL? = nil) throws -> (URL, Int, Set<ActivityType>) {
        let modelFeatures = [
            "confirmedActivityType", "stepHz", "xyAcceleration", "zAcceleration", "movingState",
            "verticalAccuracy", "horizontalAccuracy", "speed", "course",
            "latitude", "longitude", "altitude", "heartRate",
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
            line += "\(location.coordinate.latitude),\(location.coordinate.longitude),\(location.altitude),\(sample.heartRate ?? -1),"
            line += "\(sample.timeOfDay),\(sample.sinceVisitStart)"

            try line.appendLineTo(csvFile)
            samplesAdded += 1
        }

        print("exportCSV() WROTE SAMPLES: \(samplesAdded)")

        return (csvFile, samplesAdded, includedTypes)
    }

}
