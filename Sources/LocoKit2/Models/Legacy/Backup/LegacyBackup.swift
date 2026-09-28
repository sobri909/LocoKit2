//
//  LegacyBackup.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

/// The old app's (Arc Timeline 3) iCloud backup set format, as written by its `Backups.swift`
/// from October 2020 onward. A set is a folder holding `TimelineItem/`, `Place/`, `Note/`,
/// `TimelineRangeSummary/` (one pretty-printed JSON file per record, bucketed by id prefix) and
/// `LocomotionSample/` (one gzipped JSON array per ISO week). Dates are ISO 8601 strings at
/// whole-second precision; conditional keys are absent rather than null, except a sample's
/// `lastSaved` and `location`, which can be explicit null.
///
/// These are decode-only DTOs (BIG-399). They deliberately keep the file's own shapes — nested
/// `center` / `radius` / `location`, string `movingState` / `recordingState` — and hand off to
/// the existing `LegacyItem` / `LegacySample` / `LegacyPlace` structs through the adapters in
/// `LegacyItem+Backup.swift` and siblings, so the proven AT3 → LocoKit2 converters do the rest.
/// Unknown keys are ignored on purpose: `samples` / `place` / `notes` embedded in a few item
/// files, `rtreeId`, `coreMotionActivityType`, `workoutRouteId`, `facebookPlaceId`, `isHome`.
///
/// Nothing here imports GRDB, so the whole namespace compiles in a bare `swiftc` harness.
public enum LegacyBackup {

    /// `{ "latitude": …, "longitude": … }` — the old `CLLocationCoordinate2D` encoding.
    public struct Coordinate: Codable, Hashable, Sendable {
        public let latitude: Double
        public let longitude: Double
    }

    /// `{ "mean": …, "sd": … }` — the old `Radius` encoding.
    public struct Radius: Codable, Hashable, Sendable {
        public let mean: Double
        public let sd: Double
    }

    /// Per-element decode for a JSON array: a malformed element becomes a counted failure
    /// instead of failing the whole array (the old app decoded whole weeks atomically, so one
    /// bad sample lost ~20k). `error` is the description, not the `Error`, to stay Sendable.
    public struct Lenient<T: Decodable & Sendable>: Decodable, Sendable {
        public let value: T?
        public let error: String?

        public init(from decoder: Decoder) throws {
            do {
                value = try T(from: decoder)
                error = nil
            } catch let decodeError {
                value = nil
                error = String(describing: decodeError)
            }
        }
    }

    /// The decoder every backup file goes through: ISO 8601 with or without fractional seconds
    /// (the old app wrote none; AT4-written dates carry them), numeric fallback for good measure.
    public static func decoder() -> JSONDecoder {
        return JSONDecoder.flexibleDateDecoder()
    }
}
