import XCTest
import CoreLocation
@testable import LocoKit2

final class LocoKit2Tests: XCTestCase {

    // MARK: - v3 import: visit coordinate normalisation (BIG-611)
    //
    // Regression guard: old LocoKit data contains null-island (0,0) and other invalid
    // visit coordinates. TimelineItemVisit's coordinate CHECK rejects them at insert, so
    // the importer must null unusable coordinates (both together) rather than carry them
    // through — otherwise a single bad visit aborts the whole migration. (BIG-290 reverted
    // this and reintroduced the throw; these tests stop that recurring.)

    /// A null-island (0,0) coordinate must be nulled, not carried.
    func testImportNullsNullIslandVisitCoordinates() throws {
        let item = try TimelineItem(from: makeLegacyVisit(latitude: 0, longitude: 0))
        XCTAssertNil(item.visit?.latitude)
        XCTAssertNil(item.visit?.longitude)
    }

    /// Out-of-range coordinates must be nulled (also CHECK-violating).
    func testImportNullsOutOfRangeVisitCoordinates() throws {
        let item = try TimelineItem(from: makeLegacyVisit(latitude: 91, longitude: 200))
        XCTAssertNil(item.visit?.latitude)
        XCTAssertNil(item.visit?.longitude)
    }

    /// A single missing coordinate must null both (the CHECK requires both-null or both-valid).
    func testImportNullsPartialVisitCoordinates() throws {
        let item = try TimelineItem(from: makeLegacyVisit(latitude: -8.65, longitude: nil))
        XCTAssertNil(item.visit?.latitude)
        XCTAssertNil(item.visit?.longitude)
    }

    /// Valid coordinates must be carried across unchanged (BIG-290's intent preserved).
    func testImportCarriesValidVisitCoordinates() throws {
        let item = try TimelineItem(from: makeLegacyVisit(latitude: -8.65, longitude: 115.13))
        let lat = try XCTUnwrap(item.visit?.latitude)
        let lon = try XCTUnwrap(item.visit?.longitude)
        XCTAssertEqual(lat, -8.65, accuracy: 1e-9)
        XCTAssertEqual(lon, 115.13, accuracy: 1e-9)
    }

    // MARK: - v3 import: place / title / activity-type normalisation (BIG-608 GAPs 3-5)

    /// A confirmed trip whose old activity-type string doesn't map must stay uncertain,
    /// not claim a confirmed-but-nil type (uncertainActivityType CHECK).
    func testImportUnmappedConfirmedActivityTypeStaysUncertain() throws {
        let item = try TimelineItem(from: makeLegacyTrip(activityType: "totallyBogusType", manual: true))
        XCTAssertNil(item.trip?.confirmedActivityType)
        XCTAssertEqual(item.trip?.uncertainActivityType, true)
    }

    /// A confirmed trip with a recognised type stays certain (no regression).
    func testImportMappedConfirmedActivityTypeIsCertain() throws {
        let item = try TimelineItem(from: makeLegacyTrip(activityType: "walking", manual: true))
        XCTAssertNotNil(item.trip?.confirmedActivityType)
        XCTAssertEqual(item.trip?.uncertainActivityType, false)
    }

    /// An empty Place name must become the fallback, not violate the length CHECK.
    func testImportEmptyPlaceNameBecomesFallback() throws {
        let place = Place(from: try makeLegacyPlace(name: ""))
        XCTAssertEqual(place.name, "Unnamed Place")
    }

    /// An empty customTitle must normalise to nil, not violate the length CHECK.
    func testImportEmptyCustomTitleBecomesNil() throws {
        let item = try TimelineItem(from: makeLegacyVisit(latitude: -8.65, longitude: 115.13, customTitle: ""))
        XCTAssertNil(item.visit?.customTitle)
    }

    // MARK: - non-finite / invalid location accuracy clamping (Daily JSON Export crash)
    //
    // Regression guard for:
    //   [ERROR] [TASKS] EncodingError.invalidValue: inf (Double).
    //   Path: samples[681].verticalAccuracy. Unable to encode Double.inf directly in JSON.
    //
    // A GPS sample taken with no altitude fix can carry a non-finite verticalAccuracy (.infinity).
    // JSONEncoder.iso8601Encoder() uses the default .throw strategy, so one such sample aborts the
    // whole day's export. LocomotionSample now clamps non-finite / invalid CoreLocation values to nil
    // at both construction boundaries (CLLocation ingest and decode / GRDB row reads).
    //
    // The committed fixture Fixtures/non-finite-accuracy-samples.json mirrors the real export-array
    // shape (anonymised), including the on-disk "no vertical fix" pattern (verticalAccuracy: -1,
    // altitude: 0). Non-finite values can't be represented in standard JSON (overflow literals throw
    // on decode), so the .infinity condition the recorder produces is injected here via a CLLocation.

    private func nonFiniteFixtureSamples() throws -> [LocomotionSample] {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "non-finite-accuracy-samples", withExtension: "json", subdirectory: "Fixtures"
        ))
        let data = try Data(contentsOf: url)
        return try JSONDecoder.flexibleDateDecoder().decode([LocomotionSample].self, from: data)
    }

    /// Real-shape sample data round-trips through the export encoder cleanly (no regression, no inf).
    /// This is the same call ExportManager makes: encoder.encode(weekSamples).
    func testFixtureSamplesRoundTripThroughExportEncoder() throws {
        let samples = try nonFiniteFixtureSamples()
        XCTAssertEqual(samples.count, 3)
        let data = try JSONEncoder.iso8601Encoder().encode(samples)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("inf"))
    }

    /// The decode boundary clamps invalid values: the fixture's "no vertical fix" sample stores
    /// verticalAccuracy: -1, which must decode to nil. An inf read from a GRDB row is the same
    /// isFinite failure and is cleaned identically, so data already persisted as inf is exportable.
    func testDecodeClampsInvalidAccuracyToNil() throws {
        let samples = try nonFiniteFixtureSamples()
        let noFix = try XCTUnwrap(samples.first { $0.altitude == 0 })
        XCTAssertNil(noFix.verticalAccuracy)
    }

    /// The actual failure: a sample re-ingested through a CLLocation whose altitude/verticalAccuracy
    /// are non-finite (what the recorder produced on the failing day) is clamped to nil, so the export
    /// encoder no longer throws EncodingError.invalidValue and the value round-trips to nil.
    func testInfiniteAccuracyFromRecorderIsClampedAndExportable() throws {
        let samples = try nonFiniteFixtureSamples()
        let base = try XCTUnwrap(samples.first { $0.coordinate != nil })
        let coordinate = try XCTUnwrap(base.coordinate)

        let recorderLocation = CLLocation(
            coordinate: coordinate,
            altitude: .infinity,              // no altitude fix
            horizontalAccuracy: base.horizontalAccuracy ?? 10,
            verticalAccuracy: .infinity,      // samples[681].verticalAccuracy == inf
            course: base.course ?? -1,
            speed: base.speed ?? -1,
            timestamp: base.date
        )
        let sample = LocomotionSample(
            date: base.date, movingState: base.movingState,
            recordingState: base.recordingState, location: recorderLocation
        )
        XCTAssertNil(sample.verticalAccuracy)
        XCTAssertNil(sample.altitude)

        let data = try JSONEncoder.iso8601Encoder().encode([sample])   // must not throw
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("inf"))

        let decoded = try JSONDecoder.flexibleDateDecoder().decode([LocomotionSample].self, from: data)
        XCTAssertNil(decoded.first?.verticalAccuracy)
    }

    /// A negative (CoreLocation "invalid") accuracy is treated as unknown, not stored verbatim;
    /// a finite (even below-sea-level) altitude is preserved.
    func testNegativeAccuracyFromRecorderIsClampedButAltitudePreserved() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            altitude: -8, horizontalAccuracy: -1, verticalAccuracy: -1,
            course: -1, speed: -1, timestamp: Date()
        )
        let sample = LocomotionSample(date: location.timestamp, movingState: .uncertain, recordingState: .recording, location: location)
        XCTAssertNil(sample.horizontalAccuracy)
        XCTAssertNil(sample.verticalAccuracy)
        XCTAssertEqual(sample.altitude, -8)
    }

    /// Control: the export encoder really rejects non-finite values (.throw strategy) — without the
    /// source-level clamp the day's export would fail here. Pins down why the fix is needed.
    func testExportEncoderRejectsRawNonFiniteDouble() {
        XCTAssertThrowsError(try JSONEncoder.iso8601Encoder().encode([Double.infinity]))
    }

    // MARK: - Helpers

    /// Build a visit-shaped LegacyItem (its memberwise init is suppressed by a custom init,
    /// so we go through the Codable conformance).
    private func makeLegacyVisit(latitude: Double?, longitude: Double?, customTitle: String? = nil) throws -> LegacyItem {
        var dict: [String: Any] = [
            "itemId": UUID().uuidString,
            "isVisit": true,
            "source": "LocoKit",
            "deleted": false,
            "disabled": false
        ]
        if let latitude { dict["latitude"] = latitude }
        if let longitude { dict["longitude"] = longitude }
        if let customTitle { dict["customTitle"] = customTitle }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LegacyItem.self, from: data)
    }

    /// Build a trip-shaped LegacyItem.
    private func makeLegacyTrip(activityType: String?, manual: Bool) throws -> LegacyItem {
        var dict: [String: Any] = [
            "itemId": UUID().uuidString,
            "isVisit": false,
            "source": "LocoKit",
            "deleted": false,
            "disabled": false,
            "manualActivityType": manual
        ]
        if let activityType { dict["activityType"] = activityType }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LegacyItem.self, from: data)
    }

    /// Build a LegacyPlace (no custom init, so go through Codable).
    private func makeLegacyPlace(name: String?) throws -> LegacyPlace {
        var dict: [String: Any] = [
            "placeId": UUID().uuidString,
            "latitude": -8.65,
            "longitude": 115.13,
            "radiusMean": 50.0,
            "radiusSD": 10.0
        ]
        if let name { dict["name"] = name }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LegacyPlace.self, from: data)
    }
}
