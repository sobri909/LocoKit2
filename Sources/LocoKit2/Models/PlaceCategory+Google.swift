//
//  PlaceCategory+Google.swift
//  LocoKit2
//
//  Created by Claude on 2026-08-10
//
//  Hand-written (not generated). Google primaryType resolution with legacy
//  alias handling: places migrated from AT3 can carry deprecated old
//  Places-API type strings that the modern primaryType vocabulary dropped
//  (found in real data at BIG-513 build time). Aliases get added here as
//  they surface — the generated taxonomy stays pure current-vocabulary.
//

extension PlaceCategory {

    init?(googlePrimaryType: String) {
        if let direct = PlaceCategory(rawValue: googlePrimaryType) {
            self = direct
            return
        }
        if let aliased = Self.legacyGoogleAliases[googlePrimaryType],
           let resolved = PlaceCategory(rawValue: aliased) {
            self = resolved
            return
        }
        return nil
    }

    // old Places-API type -> modern primaryType
    static let legacyGoogleAliases: [String: String] = [
        "grocery_or_supermarket": "supermarket",
    ]
}
