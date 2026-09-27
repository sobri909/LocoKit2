//
//  ActivityTypesModel.swift
//  LocoKit2
//
//  Created on 2025-02-27.
//

import Foundation
import CoreML
import CoreLocation
import GRDB

public struct ActivityTypesModel: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    // MARK: - Configuration Constants

    // [Depth: Samples]
    static let modelMaxTrainingSamples: [Int: Int] = [
        2: 200_000,
        1: 200_000,
        0: 250_000
    ]

    // for completenessScore
    // [Depth: Samples]
    static let modelMinTrainingSamples: [Int: Int] = [
        2: 50_000,
        1: 150_000,
        0: 200_000
    ]

    static let numberOfLatBucketsDepth0 = 18
    static let numberOfLongBucketsDepth0 = 36
    static let numberOfLatBucketsDepth1 = 100
    static let numberOfLongBucketsDepth1 = 100
    static let numberOfLatBucketsDepth2 = 200
    static let numberOfLongBucketsDepth2 = 200

    // MARK: - Properties
    
    public let geoKey: String
    public let filename: String
    
    public let depth: Int
    public let latitudeMin: Double
    public let latitudeMax: Double
    public let longitudeMin: Double
    public let longitudeMax: Double
    
    public var lastUpdated: Date?
    public var accuracyScore: Double?
    public var totalSamples: Int = 0
    public var needsUpdate = false

    // MARK: - Computed Properties
    
    public var id: String { geoKey }
    
    public var latitudeRange: ClosedRange<Double> { latitudeMin...latitudeMax }
    public var longitudeRange: ClosedRange<Double> { longitudeMin...longitudeMax }
    
    public var latitudeWidth: Double { return latitudeMax - latitudeMin }
    public var longitudeWidth: Double { return longitudeMax - longitudeMin }

    public var centerCoordinate: CLLocationCoordinate2D {
        return Self.centerFrom(latMin: latitudeMin, latMax: latitudeMax, lonMin: longitudeMin, lonMax: longitudeMax)
    }
    
    public var completenessScore: Double {
        return min(1.0, Double(totalSamples) / Double(Self.modelMinTrainingSamples[depth]!))
    }

    // MARK: - Initializers
    
    public init(
        geoKey: String, 
        depth: Int, 
        latitudeRange: ClosedRange<Double>, 
        longitudeRange: ClosedRange<Double>, 
        filename: String? = nil, 
        needsUpdate: Bool = true,
        lastUpdated: Date? = nil,
        accuracyScore: Double? = nil,
        totalSamples: Int = 0
    ) {
        self.geoKey = geoKey
        self.depth = depth
        self.latitudeMin = latitudeRange.lowerBound
        self.latitudeMax = latitudeRange.upperBound
        self.longitudeMin = longitudeRange.lowerBound
        self.longitudeMax = longitudeRange.upperBound
        self.needsUpdate = needsUpdate
        self.lastUpdated = lastUpdated
        self.accuracyScore = accuracyScore
        self.totalSamples = totalSamples
        
        if let filename {
            self.filename = filename
        } else {
            let center = Self.centerFrom(latMin: latitudeMin, latMax: latitudeMax, lonMin: longitudeMin, lonMax: longitudeMax)
            self.filename = Self.inferredFilename(for: geoKey, depth: depth, coordinate: center)
        }
    }
    
    public init(coordinate: CLLocationCoordinate2D, depth: Int) {
        let latitudeRange = Self.latitudeRangeFor(depth: depth, coordinate: coordinate)
        let longitudeRange = Self.longitudeRangeFor(depth: depth, coordinate: coordinate)
        let geoKey = Self.inferredGeoKey(depth: depth, coordinate: coordinate)
        
        self.init(
            geoKey: geoKey,
            depth: depth,
            latitudeRange: latitudeRange,
            longitudeRange: longitudeRange
        )
    }
    
    public init(bundledURL: URL) {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.init(
            geoKey: "BD0 0.00,0.00",
            depth: 0,
            latitudeRange: Self.latitudeRangeFor(depth: 0, coordinate: coordinate),
            longitudeRange: Self.longitudeRangeFor(depth: 0, coordinate: coordinate),
            filename: bundledURL.lastPathComponent,
            needsUpdate: false
        )
    }

    // MARK: - Model Fetching
    
    @ActivityTypesActor
    public static func fetchModelFor(coordinate: CLLocationCoordinate2D, depth: Int) -> ActivityTypesModel {
        var request = ActivityTypesModel
            .filter { $0.depth == depth }
        if depth > 0 {
            request = request
                .filter { $0.latitudeMin <= coordinate.latitude && $0.latitudeMax >= coordinate.latitude }
                .filter { $0.longitudeMin <= coordinate.longitude && $0.longitudeMax >= coordinate.longitude }
        }

        // try to fetch existing model
        if let model = try? Database.pool.read({ try request.fetchOne($0) }) {
            // check if model needs immediate update
            if model.needsUpdate {
                ActivityTypesManager.processModelUpdate(model: model)
            }
            return model
        }

        // create if missing
        let model = ActivityTypesModel(coordinate: coordinate, depth: depth)
        Log.info("NEW MODEL: [\(model.geoKey)]", subsystem: .activitytypes)
        
        // save the new model
        do {
            try Database.pool.write { db in
                try model.insert(db)
            }
        } catch {
            Log.error(error, subsystem: .database)
        }

        // process update for new model (which by definition has no file yet)
        ActivityTypesManager.processModelUpdate(model: model, fileMissing: true)

        return model
    }
    
    @ActivityTypesActor
    public func reloadModel() throws {
        try MLModelCache.reloadModelFor(filename: filename)
    }

    private func markNeedsUpdate(fileMissing: Bool = false) async {
        // BIG-794 review: a missing file always records the need (the in-memory copy's
        // `needsUpdate` can be stale against the database after a skipped or failed build,
        // and the immediate gate may be closed) and always asks for the immediate path
        if needsUpdate, !fileMissing { return }

        do {
            // BIG-794: `self` is a value copy; the flagged copy has to be the one handed on,
            // or processModelUpdate's `guard model.needsUpdate` sees the stale false and the
            // repair this exists to trigger never fires
            var flagged = self
            try await Database.pool.write { [flagged] db in
                var mutableSelf = flagged
                try mutableSelf.updateChanges(db) {
                    $0.needsUpdate = true
                }
            }
            flagged.needsUpdate = true

            await ActivityTypesManager.processModelUpdate(model: flagged, fileMissing: fileMissing)

        } catch {
            Log.error(error, subsystem: .database)
        }
    }

    // MARK: - Utility Functions

    public func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
        guard coordinate.latitude != 0 || coordinate.longitude != 0 else { return false }

        if !latitudeRange.contains(coordinate.latitude) { return false }
        if !longitudeRange.contains(coordinate.longitude) { return false }

        return true
    }
    
    // MARK: - Classification
    
    /// nil means "no answer": the model file is missing, the predictor failed to load, the
    /// prediction failed or timed out, or the task was cancelled. BIG-791: it used to return an
    /// EMPTY result for all of those, which the classifier then cached per sample, so a
    /// cancelled pass (every swipe away from a day mid-classify) left its samples
    /// unclassifiable for the rest of the process — and merge scoring read the same cache.
    /// An unusable model is marked in `MLModelCache` and skipped until the mark expires or a
    /// rebuild clears it, so nothing here runs once per sample per pass.
    @ActivityTypesActor
    public func classify(_ sample: LocomotionSample) async -> ClassifierResults? {
        if MLModelCache.isMarkedUnavailable(filename: filename) { return nil }

        let predictor: ModelPredictor
        do {
            guard let p = try MLModelCache.predictorFor(filename: filename) else {
                MLModelCache.markUnavailable(filename: filename)
                // a model that has never been built has no file yet, which is expected; a
                // file that WAS built (accuracyScore is set only by a successful build, and
                // cleared by a skipped one) and is gone is the error — a storage-full
                // episode, say
                if accuracyScore != nil {
                    Log.error("ActivityTypesModel.classify: model file missing: \(filename)", subsystem: .activitytypes)
                } else {
                    Log.info("ActivityTypesModel.classify: model not yet built: \(filename)", subsystem: .activitytypes)
                }
                requestRebuildIfOwned()
                return nil
            }
            predictor = p
        } catch {
            // an unreadable or corrupt file: same treatment as missing, so it is rebuilt
            // rather than retried on every sample (BIG-791 review)
            MLModelCache.markUnavailable(filename: filename)
            Log.error(error, subsystem: .activitytypes)
            requestRebuildIfOwned()
            return nil
        }

        let input = sample.coreMLFeatureProvider
        let modelFilename = filename

        // race prediction against timeout — prediction runs on ModelPredictor's actor
        // (serial per model, off @ActivityTypesActor). Which child wins matters: only a real
        // timeout evicts and marks the model; a failed prediction is just no answer, and a
        // cancelled parent is neither (BIG-791 review).
        enum Outcome { case answered(ClassifierResults), failed, timedOut }
        return await withTaskGroup(of: Outcome.self) { group in
            group.addTask {
                do {
                    let scores = try await predictor.predict(from: input)
                    return .answered(self.results(from: scores))
                } catch {
                    Log.error(error, subsystem: .activitytypes)
                    return .failed
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(30))
                return .timedOut
            }

            let outcome = await group.next()
            group.cancelAll()

            switch outcome {
            case .answered(let results):
                return results
            case .timedOut where !Task.isCancelled:
                // the mark keeps a slow model from being retried on every sample of every
                // pass now that nothing caches its non-answer; a rebuild clears it
                Log.info("CoreML prediction timed out (\(modelFilename)), evicting model", subsystem: .activitytypes)
                MLModelCache.invalidateModelFor(filename: modelFilename)
                MLModelCache.markUnavailable(filename: modelFilename)
                return nil
            default:
                return nil // failed, or the parent was cancelled — never an empty stand-in
            }
        }
    }

    /// The bundled base model ("B…") has no database row to flag, so only the built,
    /// per-region models ask for a rebuild (BIG-791 review).
    private func requestRebuildIfOwned() {
        guard !geoKey.hasPrefix("B") else { return }
        Task { await markNeedsUpdate(fileMissing: true) }
    }
    
    private func results(from scores: [Int: Double]) -> ClassifierResults {
        var items: [ClassifierResultItem] = []
        for (name, score) in scores {
            items.append(ClassifierResultItem(name: ActivityType(rawValue: name)!, score: score))
        }
        return ClassifierResults(resultItems: items)
    }
    
    // MARK: - Geographic Calculations
    
    private static func centerFrom(latMin: Double, latMax: Double, lonMin: Double, lonMax: Double) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: latMin + (latMax - latMin) * 0.5,
            longitude: lonMin + (lonMax - lonMin) * 0.5
        )
    }
    
    private static func modelCenterCoordinates(for depth: Int, coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // get coordinate ranges for this model depth
        let latRange = latitudeRangeFor(depth: depth, coordinate: coordinate)
        let lonRange = longitudeRangeFor(depth: depth, coordinate: coordinate)
        
        // calculate the center coordinates
        let centerLat = latRange.lowerBound + (latRange.upperBound - latRange.lowerBound) / 2
        let centerLon = lonRange.lowerBound + (lonRange.upperBound - lonRange.lowerBound) / 2
        
        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }
    
    private static func inferredGeoKey(depth: Int, coordinate: CLLocationCoordinate2D) -> String {
        let center = modelCenterCoordinates(for: depth, coordinate: coordinate)
        return String(format: "CD\(depth) %.2f,%.2f", center.latitude, center.longitude)
    }
    
    private static func inferredFilename(for geoKey: String, depth: Int, coordinate: CLLocationCoordinate2D) -> String {
        let center = modelCenterCoordinates(for: depth, coordinate: coordinate)
        return String(format: "CD\(depth)_%.2f_%.2f", center.latitude, center.longitude) + ".mlmodelc"
    }
    
    public static func latitudeRangeFor(depth: Int, coordinate: CLLocationCoordinate2D) -> ClosedRange<Double> {
        switch depth {
        case 2:
            let bucketSize = latitudeBinSizeFor(depth: 1)
            let parentRange = latitudeRangeFor(depth: 1, coordinate: coordinate)
            let bucket = Int((coordinate.latitude - parentRange.lowerBound) / bucketSize)
            let min = parentRange.lowerBound + (bucketSize * Double(bucket))
            let max = parentRange.lowerBound + (bucketSize * Double(bucket + 1))
            return min...max

        case 1:
            let bucketSize = latitudeBinSizeFor(depth: 0)
            let parentRange = latitudeRangeFor(depth: 0, coordinate: coordinate)
            let bucket = Int((coordinate.latitude - parentRange.lowerBound) / bucketSize)
            let min = parentRange.lowerBound + (bucketSize * Double(bucket))
            let max = parentRange.lowerBound + (bucketSize * Double(bucket + 1))
            return min...max

        default:
            return -90.0...90.0
        }
    }

    public static func longitudeRangeFor(depth: Int, coordinate: CLLocationCoordinate2D) -> ClosedRange<Double> {
        switch depth {
        case 2:
            let bucketSize = Self.longitudeBinSizeFor(depth: 1)
            let parentRange = Self.longitudeRangeFor(depth: 1, coordinate: coordinate)
            let bucket = Int((coordinate.longitude - parentRange.lowerBound) / bucketSize)
            let min = parentRange.lowerBound + (bucketSize * Double(bucket))
            let max = parentRange.lowerBound + (bucketSize * Double(bucket + 1))
            return min...max

        case 1:
            let bucketSize = Self.longitudeBinSizeFor(depth: 0)
            let parentRange = Self.longitudeRangeFor(depth: 0, coordinate: coordinate)
            let bucket = Int((coordinate.longitude - parentRange.lowerBound) / bucketSize)
            let min = parentRange.lowerBound + (bucketSize * Double(bucket))
            let max = parentRange.lowerBound + (bucketSize * Double(bucket + 1))
            return min...max

        default:
            return -180.0...180.0
        }
    }

    public static func latitudeBinSizeFor(depth: Int) -> Double {
        let depth0 = 180.0 / Double(Self.numberOfLatBucketsDepth0)
        let depth1 = depth0 / Double(Self.numberOfLatBucketsDepth1)
        let depth2 = depth1 / Double(Self.numberOfLatBucketsDepth2)

        switch depth {
        case 2: return depth2
        case 1: return depth1
        default: return depth0
        }
    }

    public static func longitudeBinSizeFor(depth: Int) -> Double {
        let depth0 = 360.0 / Double(Self.numberOfLongBucketsDepth0)
        let depth1 = depth0 / Double(Self.numberOfLongBucketsDepth1)
        let depth2 = depth1 / Double(Self.numberOfLongBucketsDepth2)

        switch depth {
        case 2: return depth2
        case 1: return depth1
        default: return depth0
        }
    }

    // MARK: - Columns

    public enum Columns {
        public static let geoKey = Column("geoKey")
        public static let filename = Column("filename")
        public static let depth = Column("depth")
        public static let latitudeMin = Column("latitudeMin")
        public static let latitudeMax = Column("latitudeMax")
        public static let longitudeMin = Column("longitudeMin")
        public static let longitudeMax = Column("longitudeMax")
        public static let lastUpdated = Column("lastUpdated")
        public static let accuracyScore = Column("accuracyScore")
        public static let totalSamples = Column("totalSamples")
        public static let needsUpdate = Column("needsUpdate")
    }

}
