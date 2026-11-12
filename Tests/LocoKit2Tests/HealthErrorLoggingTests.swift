//
//  HealthErrorLoggingTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-12
//
//  BIG-980: HealthKit's "Protected health data is inaccessible" (code 6) is answered to any query the
//  phone locks on, and `HealthManager.log` writes that one at debug instead of ERROR. These pin the
//  discriminator on both shapes the error arrives in (the bridged NSError and the native HKError) and
//  on the two neighbours it must not match (another HealthKit code; code 6 from another domain).

import XCTest
import HealthKit
@testable import LocoKit2

final class HealthErrorLoggingTests: XCTestCase {

    func testCodeSixIsHealthKitDatabaseInaccessible() {
        XCTAssertEqual(HKError.errorDatabaseInaccessible.rawValue, 6)
    }

    func testBridgedNSErrorCodeSixIsDataInaccessible() {
        let error: Error = NSError(
            domain: HKErrorDomain,
            code: HKError.errorDatabaseInaccessible.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Protected health data is inaccessible"]
        )
        XCTAssertTrue(HealthManager.isDataInaccessible(error))
    }

    func testNativeHKErrorCodeSixIsDataInaccessible() {
        let error: Error = HKError(.errorDatabaseInaccessible)
        XCTAssertTrue(HealthManager.isDataInaccessible(error))
    }

    func testOtherHealthKitCodeIsNotDataInaccessible() {
        let error: Error = NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue)
        XCTAssertFalse(HealthManager.isDataInaccessible(error))
    }

    func testCodeSixFromAnotherDomainIsNotDataInaccessible() {
        let error: Error = NSError(domain: NSCocoaErrorDomain, code: 6)
        XCTAssertFalse(HealthManager.isDataInaccessible(error))
    }

    func testTimeoutIsNotDataInaccessible() {
        XCTAssertFalse(HealthManager.isDataInaccessible(HealthManager.HealthQueryTimeout()))
    }
}
