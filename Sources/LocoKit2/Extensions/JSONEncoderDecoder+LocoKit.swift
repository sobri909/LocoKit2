//
//  JSONEncoderDecoder+LocoKit.swift
//  LocoKit2
//
//  Created by Claude on 2025-12-02
//

import Foundation

extension JSONDecoder {

    // Parsed once, shared: the strategy closure below runs per date, and an import decodes
    // millions of them. Building an ISO8601DateFormatter per call constructs an ICU Locale and
    // DateFormatSymbols each time, which made a 200 MB sample corpus take over ten minutes to
    // decode (BIG-399 harness, sampled). The format styles are value types and Sendable.
    private static let iso8601Fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let iso8601Whole = Date.ISO8601FormatStyle()

    /// decoder that handles both ISO8601 strings and legacy numeric dates
    public static func flexibleDateDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            // try ISO8601 string first (new format)
            if let string = try? container.decode(String.self) {
                if let date = try? iso8601Fractional.parse(string) {
                    return date
                }

                // try without fractional seconds
                if let date = try? iso8601Whole.parse(string) {
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
