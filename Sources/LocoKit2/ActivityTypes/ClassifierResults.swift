//
//  ClassifierResults.swift
//
//  Created by Matt Greenfield on 29/08/17.
//

import Surge

public struct ClassifierResults: Sequence, IteratorProtocol, Sendable {
    
    internal let results: [ClassifierResultItem]

    public init(results: [ClassifierResultItem], moreComing: Bool) {
        self.results = results.sorted { $0.score > $1.score }
        self.moreComing = moreComing
    }

    public init(confirmedType: ActivityType) {
        var resultItems = [ClassifierResultItem(name: confirmedType, score: 1)]
        for activityType in ActivityType.allCases where activityType != confirmedType {
            resultItems.append(ClassifierResultItem(name: activityType, score: 0))
        }
        self.results = resultItems
        self.moreComing = false
    }

    public init(merging resultsArray: [ClassifierResults]) {
        var allScores: [ActivityType: [Double]] = [:]
        for typeName in ActivityType.allCases {
            allScores[typeName] = []
        }

        for result in resultsArray {
            for typeName in ActivityType.allCases {
                if let resultRow = result[typeName] {
                    allScores[resultRow.activityType]!.append(resultRow.score)
                } else {
                    allScores[typeName]!.append(0)
                }
            }
        }

        var mergedResults: [ClassifierResultItem] = []
        for typeName in ActivityType.allCases {
            var finalScore = 0.0
            if let scores = allScores[typeName], !scores.isEmpty {
                finalScore = mean(scores)
            }
            mergedResults.append(ClassifierResultItem(name: typeName, score: finalScore))
        }

        self.init(results: mergedResults, moreComing: false)
    }

    func merging(_ otherResults: ClassifierResults, withWeight otherWeight: Double) -> ClassifierResults {
        let selfWeight = 1.0 - otherWeight

        var combinedDict: [ActivityType: ClassifierResultItem] = [:]
        let combinedTypes = Set(self.results.map { $0.activityType } + otherResults.map { $0.activityType })

        for typeName in combinedTypes {
            let selfScore = self[typeName]?.score ?? 0.0
            let otherScore = otherResults[typeName]?.score ?? 0.0
            let mergedScore = (selfScore * selfWeight) + (otherScore * otherWeight)
            let mergedItem = ClassifierResultItem(name: typeName, score: mergedScore)
            combinedDict[typeName] = mergedItem
        }

        return ClassifierResults(results: Array(combinedDict.values),
                                 moreComing: self.moreComing || otherResults.moreComing)
    }

    // MARK: -
    
    private lazy var arrayIterator: IndexingIterator<Array<ClassifierResultItem>> = {
        return self.results.makeIterator()
    }()

    /**
     Indicates that the classifier does not yet have all relevant model data, so a subsequent attempt to classify the
     same sample again may produce new results with higher accuracy.
     */
    public var moreComing: Bool

    /**
     Returns the result rows as a plain array.
     */
    public var array: [ClassifierResultItem] {
        return results
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public var count: Int {
        return results.count
    }

    public var best: ClassifierResultItem {
        if let first = first, first.score > 0 { return first }
        return ClassifierResultItem(name: .unknown, score: 0)
    }
    
    public var first: ClassifierResultItem? {
        return self.results.first
    }

    public var scoresTotal: Double {
        return results.map { $0.score }.sum()
    }

    // MARK: -

    public subscript(index: Int) -> ClassifierResultItem {
        return results[index]
    }

    // eg `let walkingResult = results[.walking]`
    public subscript(activityType: ActivityType) -> ClassifierResultItem? {
        return results.first { $0.activityType == activityType }
    }
    
    public mutating func next() -> ClassifierResultItem? {
        return arrayIterator.next()
    }
}

public func + (left: ClassifierResults, right: ClassifierResults) -> ClassifierResults {
    return ClassifierResults(results: left.array + right.array, moreComing: left.moreComing || right.moreComing)
}

public func - (left: ClassifierResults, right: ActivityType) -> ClassifierResults {
    return ClassifierResults(results: left.array.filter { $0.activityType != right }, moreComing: left.moreComing)
}
