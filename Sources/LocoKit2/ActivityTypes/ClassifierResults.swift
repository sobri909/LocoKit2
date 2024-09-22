//
//  ClassifierResults.swift
//
//  Created by Matt Greenfield on 29/08/17.
//

import Surge

public final class ClassifierResults:  Sendable {

    public let resultItems: [ClassifierResultItem]

    public init(resultItems: [ClassifierResultItem]) {
        self.resultItems = resultItems.sorted { $0.score > $1.score }
    }

    func merging(_ otherResults: ClassifierResults, withWeight otherWeight: Double) -> ClassifierResults {
        let selfWeight = 1.0 - otherWeight

        var combinedDict: [ActivityType: ClassifierResultItem] = [:]
        let combinedTypes = Set(self.resultItems.map { $0.activityType } + otherResults.resultItems.map { $0.activityType })

        for typeName in combinedTypes {
            let selfScore = self[typeName]?.score ?? 0.0
            let otherScore = otherResults[typeName]?.score ?? 0.0
            let mergedScore = (selfScore * selfWeight) + (otherScore * otherWeight)
            let mergedItem = ClassifierResultItem(name: typeName, score: mergedScore)
            combinedDict[typeName] = mergedItem
        }

        return ClassifierResults(resultItems: Array(combinedDict.values))
    }

    // MARK: -

    public var bestMatch: ClassifierResultItem {
        if let first = resultItems.first, first.score > 0 { return first }
        return ClassifierResultItem(name: .unknown, score: 0)
    }
    
    public var scoresTotal: Double {
        return resultItems.map { $0.score }.sum()
    }

    // MARK: -

    // eg `let walkingResult = results[.walking]`
    public subscript(activityType: ActivityType) -> ClassifierResultItem? {
        return resultItems.first { $0.activityType == activityType }
    }

}
