//
//  ActivityClassifier.swift
//  
//
//  Created by Matt Greenfield on 2/9/22.
//

import Foundation
import CoreLocation
import CoreML
import Surge
import GRDB

@ActivityTypesActor
public final class ActivityClassifier {

    public static let highlander = ActivityClassifier()

    // MARK: - Classifying

    public func canClassify(_ coordinate: CLLocationCoordinate2D? = nil) -> Bool {
        if let coordinate {
            refreshModels(for: coordinate)
        }
        return !models.isEmpty
    }

    public func results(for sample: LocomotionSample) -> ClassifierResults? {
        if let cached = cache.object(forKey: sample.id as NSString) {
            return cached
        }

        // make sure have suitable classifiers
        if let coordinate = sample.location?.coordinate {
            refreshModels(for: coordinate)
        }

        // highest priorty first (ie CD2 first)
        let classifiers = models.sorted { $0.key > $1.key }.map { $0.value } 

        var combinedResults: ClassifierResults?
        var remainingWeight = 1.0

        for classifier in classifiers {
            let results = classifier.classify(sample)

            if combinedResults == nil {
                combinedResults = results
                remainingWeight -= classifier.completenessScore
                if remainingWeight <= 0 { break } else { continue }
            }

            var completeness = classifier.completenessScore
            if classifier.id == classifiers.last?.id {
                // if last is a BD0, give it half as much weight
                if classifier.geoKey.hasPrefix("B") {
                    completeness = 0.5
                } else { // otherwise let the last one take up all remaining weight
                    completeness = 1.0
                }
            }

            // merge in the results
            let weight = remainingWeight * completeness
            combinedResults = combinedResults?.merging(results, withWeight: weight)

            remainingWeight -= weight

            if remainingWeight <= 0 { break }
        }

        if let combinedResults {
            cache.setObject(combinedResults, forKey: sample.id as NSString)
        }

        return combinedResults
    }

    public func results(for samples: [LocomotionSample], timeout: TimeInterval? = nil) -> (combinedResults: ClassifierResults?, perSampleResults: [String: ClassifierResults])? {
        if samples.isEmpty { return nil }

        let start = Date()

        var allScores: [ActivityType: [Double]] = [:]
        for typeName in ActivityType.allCases {
            allScores[typeName] = []
        }

        var perSampleResults: [String: ClassifierResults] = [:]

        for sample in samples {
            if let timeout, start.age >= timeout {
                logger.info("ActivityClassifier reached timeout limit (\(timeout) seconds)", subsystem: .activitytypes)
                break
            }

            guard let results = results(for: sample) else {
                continue
            }

            perSampleResults[sample.id] = results

            for typeName in ActivityType.allCases {
                if let resultRow = results[typeName] {
                    allScores[resultRow.activityType]!.append(resultRow.score)
                } else {
                    allScores[typeName]!.append(0)
                }
            }
        }

        var finalResults: [ClassifierResultItem] = []

        for typeName in ActivityType.allCases {
            var finalScore = 0.0
            if let scores = allScores[typeName], !scores.isEmpty {
                finalScore = mean(scores)
            }

            finalResults.append(ClassifierResultItem(name: typeName, score: finalScore))
        }

        return (ClassifierResults(resultItems: finalResults), perSampleResults)
    }

    // MARK: - Results caching

    private let cache = NSCache<NSString, ClassifierResults>()

    private func set(results: ClassifierResults, sampleId: String) {
        cache.setObject(results, forKey: sampleId as NSString)
    }

    // MARK: - Fetching models

    public private(set) var models: [Int: ActivityTypesModel] = [:] // index = priority

    private func refreshModels(for coordinate: CLLocationCoordinate2D) {
        var updated = models.filter { (key, classifier) in
            return classifier.contains(coordinate: coordinate)
        }

        let bundledModelURL = Bundle.main.url(forResource: "BD0", withExtension: "mlmodelc")
        let targetModelsCount = bundledModelURL != nil ? 4 : 3

        // all existing classifiers are good?
        if updated.count == targetModelsCount { return }

        // get a CD2
        if updated.first(where: { $0.value.geoKey.hasPrefix("CD2") == true }) == nil {
            updated[2] = ActivityTypesModel.fetchModelFor(coordinate: coordinate, depth: 2) // priority 2 (top)
        }

        // get a CD1
        if updated.first(where: { $0.value.geoKey.hasPrefix("CD1") == true }) == nil {
            updated[1] = ActivityTypesModel.fetchModelFor(coordinate: coordinate, depth: 1)
        }
        
        // get a CD0
        if updated.first(where: { $0.value.geoKey.hasPrefix("CD0") == true }) == nil {
            updated[0] = ActivityTypesModel.fetchModelFor(coordinate: coordinate, depth: 0)
        }

        // get bundled CD0 (BD0)
        if let bundledModelURL, updated.first(where: { $0.value.geoKey.hasPrefix("BD0") == true }) == nil {
            updated[-1] = ActivityTypesModel(bundledURL: bundledModelURL)
        }

        models = updated
    }

    public func invalidateModel(geoKey: String) {
        models = models.filter { $0.value.geoKey != geoKey }
    }

}
