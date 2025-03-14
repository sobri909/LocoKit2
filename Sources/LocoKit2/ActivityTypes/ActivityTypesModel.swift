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
            .filter(Column("depth") == depth)
        if depth > 0 {
            request = request
                .filter(Column("latitudeMin") <= coordinate.latitude && Column("latitudeMax") >= coordinate.latitude)
                .filter(Column("longitudeMin") <= coordinate.longitude && Column("longitudeMax") >= coordinate.longitude)
        }

        // try to fetch existing model
        if let model = try? Database.pool.read({ try request.fetchOne($0) }) {
            // if model needs update, decide whether to update immediately or defer to background task
            if model.needsUpdate {
                let geoKey = model.geoKey
                
                // update incomplete D2 models immediately
                let shouldUpdateImmediately = model.depth == 2 && model.completenessScore < 1.0
                
                if shouldUpdateImmediately {
                    Task { ActivityTypesManager.updateModel(geoKey: geoKey) }
                }
            }
            return model
        }

        // create if missing
        let model = ActivityTypesModel(coordinate: coordinate, depth: depth)
        logger.info("New Core ML model: [\(model.geoKey)]", subsystem: .activitytypes)
        
        // save the new model
        do {
            try Database.pool.write { db in
                try model.insert(db)
            }
        } catch {
            logger.error(error, subsystem: .database)
        }

        // always update new models immediately to ensure model files exist
        let geoKey = model.geoKey
        Task { ActivityTypesManager.updateModel(geoKey: geoKey) }

        return model
    }
    
    // MARK: - Utility Functions
    
    @ActivityTypesActor
    public func reloadModel() throws {
        try MLModelCache.reloadModelFor(filename: filename)
    }
    
    public func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
        guard coordinate.latitude != 0 || coordinate.longitude != 0 else { return false }

        if !latitudeRange.contains(coordinate.latitude) { return false }
        if !longitudeRange.contains(coordinate.longitude) { return false }

        return true
    }
    
    // MARK: - Classification
    
    @ActivityTypesActor
    public func classify(_ sample: LocomotionSample) -> ClassifierResults {
        do {
            let model = try MLModelCache.modelFor(filename: filename)
            let input = sample.coreMLFeatureProvider
            
            let output = try model.prediction(from: input, options: MLPredictionOptions())
            return results(for: output)
            
        } catch {
            logger.error(error, subsystem: .activitytypes)
            return ClassifierResults(resultItems: [])
        }
    }
    
    private func results(for classifierOutput: MLFeatureProvider) -> ClassifierResults {
        let scores = classifierOutput.featureValue(for: "confirmedActivityTypeProbability")!.dictionaryValue as! [Int: Double]
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
    
    private static func inferredGeoKey(depth: Int, coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "CD\(depth) %.2f,%.2f", coordinate.latitude, coordinate.longitude)
    }

    private static func inferredFilename(for geoKey: String, depth: Int, centerLat: Double, centerLon: Double) -> String {
        return String(format: "CD\(depth)_%.2f_%.2f", centerLat, centerLon) + ".mlmodelc"
    }
    
    private static func inferredFilename(for geoKey: String, depth: Int, coordinate: CLLocationCoordinate2D) -> String {
        return inferredFilename(for: geoKey, depth: depth, centerLat: coordinate.latitude, centerLon: coordinate.longitude)
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

}
