//
//  Created by Matt Greenfield on 10/3/24.
//

import Foundation

extension Date {
    var age: TimeInterval { -timeIntervalSinceNow }
}

extension String {
    func appendLineTo(_ url: URL) throws {
        try (self + "\n").appendTo(url)
    }

    func appendTo(_ url: URL) throws {
        let data = data(using: .utf8)!
        try data.appendTo(url)
    }
}

extension Data {
    func appendTo(_ url: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: url) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url, options: .atomic)
        }
    }
}

extension TimeInterval {
    static func minutes(_ minutes: Int) -> TimeInterval {
        return 60.0 * Double(minutes)
    }

    static func hours(_ hours: Int) -> TimeInterval {
        return .minutes(60) * Double(hours)
    }

    static func days(_ days: Int) -> TimeInterval {
        return .hours(24) * Double(days)
    }

    var unit: Measurement<UnitDuration> {
        return Measurement(value: self, unit: UnitDuration.seconds)
    }
}

func withContinousObservation<T>(of value: @escaping @autoclosure () -> T, execute: @escaping (T) -> Void) {
    withObservationTracking {
        execute(value())
    } onChange: {
        Task { @MainActor in
            withContinousObservation(of: value(), execute: execute)
        }
    }
}
