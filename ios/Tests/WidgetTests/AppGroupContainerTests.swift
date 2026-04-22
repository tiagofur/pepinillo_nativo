// AppGroupContainerTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for AppGroupDefaults capability read/write.
// Verifies that userCapabilities can be stored and retrieved from shared UserDefaults.

import Testing
import Foundation
@testable import Pepinillo

@Suite("AppGroupContainerTests")
struct AppGroupContainerTests {

    @Test("userCapabilities round-trips through AppGroupDefaults")
    func userCapabilitiesRoundTrip() {
        let original = UserCapabilities.everywherePlus
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = original
        let read = AppGroupDefaults.userCapabilities
        #expect(read == original)
    }

    @Test("userCapabilities defaults to nil when unset")
    func userCapabilitiesDefaultsNilWhenUnset() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = nil
        #expect(AppGroupDefaults.userCapabilities == nil)
    }

    @Test("userCapabilities stores pepinilloPlus preset")
    func userCapabilitiesStoresPepinilloPlus() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .pepinilloPlus
        let read = AppGroupDefaults.userCapabilities
        #expect(read?.backendSync == false)
        #expect(read?.localPremium == true)
    }

    @Test("userCapabilities stores free preset")
    func userCapabilitiesStoresFreePreset() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .free
        let read = AppGroupDefaults.userCapabilities
        #expect(read?.backendSync == false)
        #expect(read?.localPremium == false)
        #expect(read?.hasAnyPremium == false)
    }

    @Test("userCapabilities stores everywherePlus backendSync=true")
    func userCapabilitiesStoresEverywhereSync() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .everywherePlus
        let read = AppGroupDefaults.userCapabilities
        #expect(read?.backendSync == true)
        #expect(read?.hasAnyPremium == true)
    }
}
