//
//  JSONEncoderDecoder+LocoKit.swift
//  LocoKit2
//
//  Created by Claude on 2025-12-02
//

import Foundation

extension JSONDecoder {

    /// decoder that handles both ISO8601 strings and legacy numeric dates
    public static func flexibleDateDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            // try ISO8601 string first (new format)
            if let string = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                if let date = formatter.date(from: string) {
                    return date
                }

                // try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: string) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date string: \(string)"
                )
            }

            // fall back to numeric (legacy format)
            let seconds = try container.decode(Double.self)

            // Apple reference date values are smaller than Unix timestamps
            // Reference date 2001 = ~0, Unix 2001 = ~978307200
            if seconds < 978307200 {
                return Date(timeIntervalSinceReferenceDate: seconds)
            } else {
                return Date(timeIntervalSince1970: seconds)
            }
        }
        return decoder
    }

}

extension JSONEncoder {

    /// encoder that uses ISO8601 date strings with fractional seconds
    public static func iso8601Encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }

}
