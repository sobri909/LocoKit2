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
            Log.error(error, subsystem: .database)
        }
    }

    // MARK: - Background Task Management

    @MainActor
    public static func registerModelUpdatesTask() {
        let taskDefinition = BackgroundTaskDefinition(
            identifier: taskIdentifier,
            displayName: "Updating activity models",
            minimumDelay: .hours(1),
            requiresNetwork: false,
            requiresPower: true,
            foregroundThreshold: .hours(23),
            workHandler: processModelsForBackground
        )
        
        BackgroundTasksManager.add(task: taskDefinition)
    }
    
    private static func processModelsForBackground() async throws {
        while true {
            if Task.isCancelled { throw CancellationError() }
            
            // get prioritised model to update (one at a time)
            let model = await fetchNextModelToUpdate()
            
            // no more models to update? we're done
            guard let model else { return }
            
            await updateModel(geoKey: model.geoKey)
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
                    .order { [$0.depth.desc, $0.totalSamples.asc] }
                    .fetchOne(db)
            }
            
        } catch {
            Log.error(error, subsystem: .database)
            return nil
        }
    }
    
    public static func fetchPendingModelGeoKeys() async throws -> [String] {
        return try await Database.pool.read { db in
            let request = ActivityTypesModel
                .select(\.geoKey)
                .filter { $0.needsUpdate == true }
                .order { [$0.depth.desc, $0.totalSamples.asc] }
            return try String.fetchAll(db, request)
        }
    }
    
    public static func deleteAllModels() async throws {
        // first clear from memory cache
        ActivityClassifier.clearModels()
        
        // then remove from database
        try await Database.pool.write { db in
            _ = try ActivityTypesModel.deleteAll(db)
        }
        
        // then delete model files
        let manager = FileManager.default
        if let files = try? manager.contentsOfDirectory(at: MLModelCache.modelsDir, includingPropertiesForKeys: nil) {
            for file in files {
                if file.lastPathComponent.hasPrefix("CD") {
                    try? manager.removeItem(at: file)
                }
            }
        }
        
        Log.info("Deleted all ActivityTypesModels", subsystem: .activitytypes)
    }

    public static func updateModel(geoKey: String) async {
        do {
            let model = try await Database.pool.read {
                try ActivityTypesModel.fetchOne($0, key: geoKey)
            }
            if let model {
                guard let handle = await OperationRegistry.startOperation(
                    .activityTypes, 
                    operation: "ActivityTypesManager.updateModel(geoKey:)", 
                    objectKey: model.geoKey,
                    rejectDuplicates: true
                ) else {
                    Log.info("Skipping duplicate ActivityTypesManager.updateModel(geoKey:) for \(model.geoKey)", subsystem: .activitytypes)
                    return
                }
                defer { Task { await OperationRegistry.endOperation(handle) } }
                
                await update(model: model)
            }
            
        } catch {
            Log.error(error, subsystem: .database)
        }
    }
    
    public static func processModelUpdate(model: ActivityTypesModel, fileMissing: Bool = false) {
        guard model.needsUpdate else { return }

        let shouldUpdateImmediately = fileMissing || (model.depth == 2 && model.completenessScore < 0.1)
        
        if shouldUpdateImmediately {
            let geoKey = model.geoKey
            Task(priority: .background) { await updateModel(geoKey: geoKey) }
        }
    }

    // MARK: - Model building

#if targetEnvironment(simulator)
    static func update(model: ActivityTypesModel) async {
        print("SIMULATOR DOESN'T SUPPORT MODEL UPDATES")
    }
#else
    static func update(model: ActivityTypesModel) async {
        if model.geoKey.hasPrefix("B") { return }
        if Task.isCancelled { return }

        // run heavy training work off-actor to avoid blocking classification
        let trained = await Task.detached(priority: .background) { [model] () -> Bool in
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

                    let fakeLocation = CLLocation(
                        coordinate: model.centerCoordinate,
                        altitude: 0,
                        horizontalAccuracy: 10,
                        verticalAccuracy: 10,
                        course: 0,
                        speed: 0,
                        timestamp: .now
                    )

                    var fakeSample = LocomotionSample(
                        date: .now,
                        movingState: .stationary,
                        recordingState: .recording,
                        location: fakeLocation
                    )
                    fakeSample.confirmedActivityType = .stationary
                    fakeSample.xyAcceleration = 0
                    fakeSample.zAcceleration = 0
                    fakeSample.stepHz = 0

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
                    return false
                }

                guard let csvFile else {
                    Log.error("Missing CSV file for model build", subsystem: .activitytypes)
                    return false
                }

                let dataFrame = try DataFrame(contentsOfCSVFile: csvFile)
                let classifier = try MLBoostedTreeClassifier(trainingData: dataFrame, targetColumn: "confirmedActivityType")

                do {
                    try FileManager.default.createDirectory(at: MLModelCache.modelsDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    Log.error("Couldn't create MLModels directory", subsystem: .activitytypes)
                }

                try classifier.write(to: tempModelFile)
                let compiledModelFile = try MLModel.compileModel(at: tempModelFile)
                _ = try manager.replaceItemAt(MLModelCache.getModelURLFor(filename: model.filename), withItemAt: compiledModelFile)

                let accuracy = 1.0 - classifier.validationMetrics.classificationError
                try? Database.pool.write { db in
                    var mutableModel = model
                    try mutableModel.updateChanges(db) {
                        $0.totalSamples = samplesCount
                        $0.accuracyScore = accuracy
                        $0.lastUpdated = .now
                        $0.needsUpdate = false
                    }
                }

                let completeness = min(1.0, Double(samplesCount) / Double(ActivityTypesModel.modelMinTrainingSamples[model.depth]!))
                Log.info("UPDATED: \(model.geoKey) (samples: \(samplesCount), accuracy: \(String(format: "%.2f", accuracy)), completeness: \(String(format: "%.2f", completeness)), includedTypes: \(includedTypes.count))", subsystem: .activitytypes)

                return true

            } catch {
                Log.error(error, subsystem: .activitytypes)
                return false
            }
        }.value

        if Task.isCancelled { return }

        // only cache reload and classifier invalidation need the actor
        if trained {
            try? model.reloadModel()
            ActivityClassifier.invalidateModel(geoKey: model.geoKey)
        }
    }
#endif

    nonisolated
    private static func fetchTrainingSamples(for model: ActivityTypesModel) throws -> [LocomotionSample] {
        return try Database.pool.read { db in
            if model.depth != 0 {
                // Use spatial query with rtree subquery and forced index usage
                // This ensures the rtreeId index is used instead of the date index
                let sql = """
                    SELECT s.* FROM LocomotionSample s INDEXED BY LocomotionSample_on_rtreeId
                    WHERE s.rtreeId IN (
                        SELECT rowid FROM SampleRTree 
                        WHERE latMin >= ? AND latMax <= ? 
                        AND lonMin >= ? AND lonMax <= ?
                    )
                    AND s.confirmedActivityType IS NOT NULL
                    AND likely(s.xyAcceleration IS NOT NULL)
                    AND likely(s.zAcceleration IS NOT NULL)
                    AND likely(s.stepHz IS NOT NULL)
                    ORDER BY s.date DESC
                    LIMIT ?
                    """
                
                return try LocomotionSample.fetchAll(db, sql: sql, arguments: [
                    model.latitudeRange.lowerBound, model.latitudeRange.upperBound,
                    model.longitudeRange.lowerBound, model.longitudeRange.upperBound,
                    ActivityTypesModel.modelMaxTrainingSamples[model.depth]!
                ])

            } else {
                // For depth 0 (global), use the original approach
                let query = LocomotionSample
                    .filter(sql: """
                        confirmedActivityType IS NOT NULL
                        AND likely(xyAcceleration IS NOT NULL)
                        AND likely(zAcceleration IS NOT NULL)
                        AND likely(stepHz IS NOT NULL)
                        """)
                    .order(\.date.desc)
                    .limit(ActivityTypesModel.modelMaxTrainingSamples[model.depth]!)
                
                return try query.fetchAll(db)
            }
        }
    }

    nonisolated
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

        // write the samples to file
        for sample in samples {
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

        return (csvFile, samplesAdded, includedTypes)
    }

}
