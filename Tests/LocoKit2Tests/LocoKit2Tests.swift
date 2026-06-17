import XCTest
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

    // MARK: - Helpers

    /// Build a visit-shaped LegacyItem (its memberwise init is suppressed by a custom init,
    /// so we go through the Codable conformance).
    private func makeLegacyVisit(latitude: Double?, longitude: Double?) throws -> LegacyItem {
        var dict: [String: Any] = [
            "itemId": UUID().uuidString,
            "isVisit": true,
            "source": "LocoKit",
            "deleted": false,
            "disabled": false
        ]
        if let latitude { dict["latitude"] = latitude }
        if let longitude { dict["longitude"] = longitude }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LegacyItem.self, from: data)
    }
}
