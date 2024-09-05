//
//  ActivityClassifier.swift
//  
//
//  Created by Matt Greenfield on 2/9/22.
//

import Foundation
import CoreLocation
import TabularData
import CoreML
import Surge
import GRDB

@ActivityTypesActor
public final class ActivityClassifier {

    public private(set) var discreteClassifiers: [Int: ActivityTypesModel] = [:] // index = priority

    // MARK: - MLCompositeClassifier

    public func canClassify(_ coordinate: CLLocationCoordinate2D? = nil) -> Bool {
        if let coordinate {
            updateDiscreteClassifiers(for: coordinate)
        }
        return !discreteClassifiers.isEmpty
    }

    public func classify(_ sample: LocomotionSample) -> ClassifierResults? {

        // make sure have suitable classifiers
        if let coordinate = sample.location?.coordinate {
            updateDiscreteClassifiers(for: coordinate)
        }

        // highest priorty first (ie CD2 first)
        let classifiers = discreteClassifiers.sorted { $0.key > $1.key }.map { $0.value } 

        var combinedResults: ClassifierResults?
        var remainingWeight = 1.0
        var moreComing = true

        for classifier in classifiers {
            let results = classifier.classify(sample)

            // at least one classifier in the tree is complete?
            if classifier.completenessScore >= 1 { moreComing = false }

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

        combinedResults?.moreComing = moreComing

        return combinedResults
    }

    // TODO: is this date ordering still a thing? double check
    // NOTE: samples should be provided in date ascending order
    public func classify(_ samples: [LocomotionSample], timeout: TimeInterval? = nil) -> ClassifierResults? {
        if samples.isEmpty { return nil }

        let start = Date()

        var allScores: [ActivityType: [Double]] = [:]
        for typeName in ActivityType.allCases {
            allScores[typeName] = []
        }

        var moreComing = false

        for sample in samples {
            if let timeout = timeout, start.age >= timeout {
                logger.info("Classifer reached timeout limit.")
                moreComing = true
                break
            }

            guard let results = classify(sample) else {
                continue
            }

            if results.moreComing {
                moreComing = true
            }

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

        return ClassifierResults(results: finalResults, moreComing: moreComing)
    }

    public func classify(_ timelineItem: TimelineItem, timeout: TimeInterval?) -> ClassifierResults? {
        guard let samples = timelineItem.samples else { return nil }
        return classify(samples, timeout: timeout)
    }

//    public func classify(_ segment: ItemSegment, timeout: TimeInterval?) -> ClassifierResults? {
//        return classify(segment.samples, timeout: timeout)
//    }

    // MARK: -

    private func updateDiscreteClassifiers(for coordinate: CLLocationCoordinate2D) {
        var updated = discreteClassifiers.filter { (key, classifier) in
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

        discreteClassifiers = updated
    }

    // MARK: -
  

}
