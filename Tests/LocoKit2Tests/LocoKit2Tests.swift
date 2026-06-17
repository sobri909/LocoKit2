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
