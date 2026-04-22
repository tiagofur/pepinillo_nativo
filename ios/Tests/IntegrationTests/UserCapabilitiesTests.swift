// UserCapabilitiesTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Unit tests for UserCapabilities Codable conformance.
// Verifies JSON round-trip for all three preset capability sets.

import Testing
import Foundation
@testable import Pepinillo

@Suite("UserCapabilities")
struct UserCapabilitiesTests {

    @Test("Free preset survives JSON round-trip")
    func freeRoundTrip() throws {
        let original = UserCapabilities.free
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserCapabilities.self, from: data)
        #expect(decoded == original)
    }

    @Test("PepinilloPlus preset survives JSON round-trip")
    func pepinilloPlusRoundTrip() throws {
        let original = UserCapabilities.pepinilloPlus
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserCapabilities.self, from: data)
        #expect(decoded == original)
    }

    @Test("EverywhereePlus preset survives JSON round-trip")
    func everywherePlusRoundTrip() throws {
        let original = UserCapabilities.everywherePlus
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserCapabilities.self, from: data)
        #expect(decoded == original)
    }

    @Test("Decoding preserves all bool fields correctly")
    func decodingPreservesFields() throws {
        let original = UserCapabilities.everywherePlus
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserCapabilities.self, from: data)
        #expect(decoded.localPremium == true)
        #expect(decoded.appleCloudSync == true)
        #expect(decoded.localAI == true)
        #expect(decoded.exportAccess == true)
        #expect(decoded.backendSync == true)
        #expect(decoded.aiCreditsMonthly == 100)
        #expect(decoded.crossDeviceRestore == true)
    }

    @Test("Free capabilities have all booleans false and zero credits")
    func freeCapabilitiesAllFalse() throws {
        let data = try JSONEncoder().encode(UserCapabilities.free)
        let decoded = try JSONDecoder().decode(UserCapabilities.self, from: data)
        #expect(decoded.localPremium == false)
        #expect(decoded.appleCloudSync == false)
        #expect(decoded.localAI == false)
        #expect(decoded.exportAccess == false)
        #expect(decoded.backendSync == false)
        #expect(decoded.aiCreditsMonthly == 0)
        #expect(decoded.crossDeviceRestore == false)
    }
}
