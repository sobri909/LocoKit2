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
    private static var loadedModels: [String: MLModel] = [:]
    
    public static let modelsDir: URL = {
        return try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("MLModels", isDirectory: true)
    }()
    
    public static func modelFor(filename: String) throws -> MLModel {
        if let cachedModel = loadedModels[filename] {
            return cachedModel
        }
        
        let modelURL = getModelURLFor(filename: filename)
        let newModel = try MLModel(contentsOf: modelURL)
        loadedModels[filename] = newModel
        return newModel
    }
    
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
        let modelURL = getModelURLFor(filename: filename)
        loadedModels[filename] = try MLModel(contentsOf: modelURL)
    }
}
