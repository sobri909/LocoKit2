//
//  ActivityTypesModel.swift
//  
//
//  Created by Matt Greenfield on 26/10/22.
//

import Foundation
import CoreML
import CoreLocation
import BackgroundTasks
import Surge
import GRDB

public final class ActivityTypesModel: Record, Hashable, Identifiable {

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

    static let modelsDir: URL = {
        return try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("MLModels", isDirectory: true)
    }()

    // MARK: -

    public var id: String { geoKey }
    public internal(set) var geoKey: String = ""
    public internal(set) var filename: String = ""
    public internal(set) var depth: Int
    public internal(set) var latitudeRange: ClosedRange<Double>
    public internal(set) var longitudeRange: ClosedRange<Double>
    public internal(set) var lastUpdated: Date?
    public internal(set) var accuracyScore: Double?
    public internal(set) var totalSamples: Int = 0

    public var needsUpdate = false

    // MARK: - Fetching

    public static func fetchModelFor(coordinate: CLLocationCoordinate2D, depth: Int) -> ActivityTypesModel {
        var request = ActivityTypesModel
            .filter(Column("depth") == depth)
        if depth > 0 {
            request = request
                .filter(Column("latitudeMin") <= coordinate.latitude && Column("latitudeMax") >= coordinate.latitude)
                .filter(Column("longitudeMin") <= coordinate.longitude && Column("longitudeMax") >= coordinate.longitude)
        }

        if let model = try? Database.pool.read({ try request.fetchOne($0) }) {
            return model
        }

        // create if missing
        let model = ActivityTypesModel(coordinate: coordinate, depth: depth)
        logger.info("NEW CORE ML MODEL: [\(model.geoKey)]")
        model.needsUpdate = true
        model.save()

        // fire it off for update
        let geoKey = model.geoKey
        Task { await CoreMLModelUpdater.highlander.updateModel(geoKey: geoKey) }

        return model
    }

    // MARK: - Init

    internal convenience init(bundledURL: URL) {
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

    internal convenience init(coordinate: CLLocationCoordinate2D, depth: Int) {
        self.init(
            depth: depth,
            latitudeRange: Self.latitudeRangeFor(depth: 0, coordinate: coordinate),
            longitudeRange: Self.longitudeRangeFor(depth: 0, coordinate: coordinate)
        )
    }

    internal init(geoKey: String? = nil, depth: Int, latitudeRange: ClosedRange<Double>, longitudeRange: ClosedRange<Double>, filename: String? = nil, needsUpdate: Bool = true) {
        self.depth = depth
        self.latitudeRange = latitudeRange
        self.longitudeRange = longitudeRange
        self.needsUpdate = needsUpdate

        super.init()

        self.geoKey = geoKey ?? inferredGeoKey
        self.filename = filename ?? inferredFilename
    }

    // MARK: - FetchableRecord

    public required init(row: Row) throws {
        geoKey = row["geoKey"]
        depth = row["depth"]
        latitudeRange = (row["latitudeMin"] as! Double)...(row["latitudeMax"] as! Double)
        longitudeRange = (row["longitudeMin"] as! Double)...(row["longitudeMax"] as! Double)

        lastUpdated = row["lastUpdated"]
        needsUpdate = row["needsUpdate"]

        accuracyScore = row["accuracyScore"]
        totalSamples = row["totalSamples"]
        filename = row["filename"]

        try super.init(row: row)
    }

    // MARK: -

    private var inferredGeoKey: String {
        return String(format: "CD\(depth) %.2f,%.2f", centerCoordinate.latitude, centerCoordinate.longitude)
    }

    private var inferredFilename: String {
        return String(format: "CD\(depth)_%.2f_%.2f", centerCoordinate.latitude, centerCoordinate.longitude) + ".mlmodelc"
    }

    var latitudeWidth: Double { return latitudeRange.upperBound - latitudeRange.lowerBound }
    var longitudeWidth: Double { return longitudeRange.upperBound - longitudeRange.lowerBound }

    var centerCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: latitudeRange.lowerBound + latitudeWidth * 0.5,
            longitude: longitudeRange.lowerBound + longitudeWidth * 0.5
        )
    }

    // MARK: - MLModel loading

    @ActivityTypesActor
    private lazy var model: MLModel? = {
        do {
            return try MLModel(contentsOf: modelURL)
        } catch {
            if !needsUpdate {
                needsUpdate = true
                save()
                logger.info("[\(self.geoKey)] Queued update, because missing model file")
            }
            return nil
        }
    }()

    public var modelURL: URL {
        if filename.hasPrefix("B") {
            return Bundle.main.url(forResource: filename, withExtension: nil)!
        }
        return Self.modelsDir.appendingPathComponent(filename)
    }

    @ActivityTypesActor
    public func reloadModel() throws {
        self.model = try MLModel(contentsOf: modelURL)
    }

    static func latitudeRangeFor(depth: Int, coordinate: CLLocationCoordinate2D) -> ClosedRange<Double> {
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

    static func longitudeRangeFor(depth: Int, coordinate: CLLocationCoordinate2D) -> ClosedRange<Double> {
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

    static func latitudeBinSizeFor(depth: Int) -> Double {
        let depth0 = 180.0 / Double(Self.numberOfLatBucketsDepth0)
        let depth1 = depth0 / Double(Self.numberOfLatBucketsDepth1)
        let depth2 = depth1 / Double(Self.numberOfLatBucketsDepth2)

        switch depth {
        case 2: return depth2
        case 1: return depth1
        default: return depth0
        }
    }

    static func longitudeBinSizeFor(depth: Int) -> Double {
        let depth0 = 360.0 / Double(Self.numberOfLongBucketsDepth0)
        let depth1 = depth0 / Double(Self.numberOfLongBucketsDepth1)
        let depth2 = depth1 / Double(Self.numberOfLongBucketsDepth2)

        switch depth {
        case 2: return depth2
        case 1: return depth1
        default: return depth0
        }
    }

    // MARK: - DiscreteClassifier

    @ActivityTypesActor
    public func classify(_ sample: LocomotionSample) -> ClassifierResults {
        guard let model else {
            totalSamples = 0 // if file used to exist, sample count will be wrong and will cause incorrect weighting
//            print("[\(geoKey)] classify(classifiable:) NO MODEL!")
            return ClassifierResults(resultItems: [])
        }
        let input = sample.coreMLFeatureProvider

        do {
            let output = try model.prediction(from: input, options: MLPredictionOptions())
            return results(for: output)

        } catch {
            logger.error(error, subsystem: .activitytypes)
            return ClassifierResults(resultItems: [])
        }
    }

    public func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
        guard coordinate.latitude != 0 || coordinate.longitude != 0 else { return false }

        if !latitudeRange.contains(coordinate.latitude) { return false }
        if !longitudeRange.contains(coordinate.longitude) { return false }

        return true
    }

    public var completenessScore: Double {
        return min(1.0, Double(totalSamples) / Double(Self.modelMinTrainingSamples[depth]!))
    }

    // MARK: - Core ML classifying

    private func results(for classifierOutput: MLFeatureProvider) -> ClassifierResults {
        let scores = classifierOutput.featureValue(for: "confirmedActivityTypeProbability")!.dictionaryValue as! [Int: Double]
        var items: [ClassifierResultItem] = []
        for (name, score) in scores {
            items.append(ClassifierResultItem(name: ActivityType(rawValue: name)!, score: score))
        }
        return ClassifierResults(resultItems: items)
    }

    // MARK: - Saving

    public func save() {
        if geoKey.hasPrefix("B") { return }
        do {
            try Database.pool.write { try self.save($0) }
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - PersistableRecord

    public static override var databaseTableName: String { return "ActivityTypesModel" }

    public override func encode(to container: inout PersistenceContainer) {
        container["geoKey"] = geoKey
        container["depth"] = depth
        container["lastUpdated"] = lastUpdated
        container["needsUpdate"] = needsUpdate
        container["totalSamples"] = totalSamples
        container["accuracyScore"] = accuracyScore
        container["filename"] = filename

        container["latitudeMin"] = latitudeRange.lowerBound
        container["latitudeMax"] = latitudeRange.upperBound
        container["longitudeMin"] = longitudeRange.lowerBound
        container["longitudeMax"] = longitudeRange.upperBound
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(geoKey)
    }

    public static func ==(lhs: ActivityTypesModel, rhs: ActivityTypesModel) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

}
