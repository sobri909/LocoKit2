//
//  ModelPredictor.swift
//  LocoKit2
//
//  Created by Claude on 2026-03-09
//

import CoreML

/// Wraps an MLModel in its own actor to provide serial access to prediction()
/// while keeping @ActivityTypesActor free during potentially slow CoreML calls.
///
/// Apple's guidance: "Use an MLModel instance on one thread or one dispatch queue
/// at a time." This actor satisfies that requirement — each MLModel gets its own
/// serial executor, preventing concurrent prediction() calls on the same instance.
public actor ModelPredictor {

    private let model: MLModel

    init(_ model: MLModel) {
        self.model = model
    }

    public func predict(from input: MLFeatureProvider) throws -> [Int: Double] {
        let output = try model.prediction(from: input, options: MLPredictionOptions())
        return output.featureValue(for: "confirmedActivityTypeProbability")!.dictionaryValue as! [Int: Double]
    }

}
