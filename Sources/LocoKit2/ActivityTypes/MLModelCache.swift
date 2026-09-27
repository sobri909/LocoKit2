//
//  MLModelCache.swift
//  LocoKit2
//
//  Created on 2025-02-27.
//

import Foundation
import CoreML

@ActivityTypesActor
public enum MLModelCache {
    private static var loadedModels: [String: ModelPredictor] = [:]

    // MARK: - Unavailable-model marks (BIG-791/794)

    /// Filenames whose model could not be used — file missing, load threw, or a prediction
    /// timed out — with when. `ActivityTypesModel` is a struct copied into
    /// `ActivityClassifier.models`, so a flag on the model never reaches the next call; this
    /// table is what makes "already tried" stick. A marked model is skipped without a file
    /// probe until the interval passes, so a device with an unusable model pays one probe, one
    /// log line and one `needsUpdate` write per model per interval instead of one per sample
    /// per pass. A rebuild clears the mark (`reloadModelFor`), so a freshly trained model is
    /// used at once; the interval only governs files that stay unusable.
    private static var unavailableMarks: [String: Date] = [:]
    static let unavailableRetryInterval: TimeInterval = .hours(1)

    static func isMarkedUnavailable(filename: String) -> Bool {
        guard let marked = unavailableMarks[filename] else { return false }
        return marked.age < unavailableRetryInterval
    }

    static func markUnavailable(filename: String) {
        unavailableMarks[filename] = .now
    }

    nonisolated
    public static let modelsDir: URL = {
        return try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("MLModels", isDirectory: true)
    }()

    @discardableResult
    public static func predictorFor(filename: String) throws -> ModelPredictor? {
        if let cached = loadedModels[filename] {
            return cached
        }

        do {
            let modelURL = getModelURLFor(filename: filename)
            let newModel = try MLModel(contentsOf: modelURL)
            let predictor = ModelPredictor(newModel)
            loadedModels[filename] = predictor
            unavailableMarks.removeValue(forKey: filename)
            return predictor

        } catch let error as MLModelError {
            let isMissingModelFile = (error as NSError).localizedDescription.contains(".mlmodelc") &&
                (error.code == .io || error.code == .generic)

            // "file not found" errors are just noise
            if isMissingModelFile {
                return nil
            }
            
            throw error
        }
    }
    
    nonisolated
    public static func getModelURLFor(filename: String) -> URL {
        if filename.hasPrefix("B") {
            return Bundle.main.url(forResource: filename, withExtension: nil)!
        }
        return modelsDir.appendingPathComponent(filename)
    }
    
    public static func invalidateModelFor(filename: String) {
        loadedModels.removeValue(forKey: filename)
    }
    
    public static func reloadModelFor(filename: String) throws {
        invalidateModelFor(filename: filename)
        try predictorFor(filename: filename) // a successful load clears the mark; a failed one keeps it
    }
}
