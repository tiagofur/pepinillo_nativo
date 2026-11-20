// RcLinkFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for the #953 RC license bridge:
// - Valid code claims through POST /rc/link and delegates to identity linking.
// - 404 rc_link_not_claimable surfaces the invalid/expired message.
// - 409 rc_link_already_bound surfaces the bound message.
// - A short code blocks the claim before any API call.
// - AppFeature.showRcLinkTapped presents the sheet; the delegate routes to
//   linkSubscriptionIdentity (Purchases.logIn → SUBSCRIBER_ALIAS).

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("RC License Bridge", .serialized, .appGroupDefaultsSerialized)
@MainActor
struct RcLinkFeatureTests {

    // MARK: - Successful claim delegates to identity linking

    @Test("valid code claims and delegates claimSucceeded with the backend userId")
    func validCodeClaimsAndDelegates() async {
        let store = TestStore(initialState: RcLinkFeature.State()) {
            RcLinkFeature()
        } withDependencies: {
            $0.apiClient.rcLink = { req in
                #expect(req.code == "123456")
                #expect(req.appUserId == "$RCAnonymousID:abc")
                return RcLinkResponse(
                    userId: "11111111-1111-1111-1111-111111111111",
                    tier: "pepinillo_plus",
                    email: "t***@gmail.com",
                    expiresAt: nil
                )
            }
            $0.subscriptionClient.currentAppUserID = { "$RCAnonymousID:abc" }
        }

        await store.send(.codeChanged("12a3 456")) {
            $0.code = "123456"  // non-digits and spaces are stripped
        }
        await store.send(.claimTapped) {
            $0.isLoading = true
        }
        await store.receive(.claimResponse(.success(RcLinkResponse(
            userId: "11111111-1111-1111-1111-111111111111",
            tier: "pepinillo_plus",
            email: "t***@gmail.com",
            expiresAt: nil
        )))) {
            $0.isLoading = false
            $0.successEmail = "t***@gmail.com"
            $0.successUserID = "11111111-1111-1111-1111-111111111111"
        }
        await store.send(.continueTapped) {
            $0.successEmail = nil
            $0.successUserID = nil
        }
        await store.receive(.delegate(.claimSucceeded(userID: "11111111-1111-1111-1111-111111111111")))
    }

    // MARK: - Paste truncation (judge A round 1)

    @Test("paste longer than 6 digits truncates to the first six")
    func pasteTruncatesToSix() async {
        let store = TestStore(initialState: RcLinkFeature.State()) {
            RcLinkFeature()
        }

        await store.send(.codeChanged("1234567890")) {
            $0.code = "123456"
        }
    }

    // MARK: - 404: invalid or expired code

    @Test("rc_link_not_claimable surfaces the invalid/expired message")
    func notClaimableSurfacesInvalidMessage() async {
        let store = TestStore(initialState: RcLinkFeature.State()) {
            RcLinkFeature()
        } withDependencies: {
            $0.apiClient.rcLink = { _ in
                throw APIClientError.rcLinkNotClaimable
            }
            $0.subscriptionClient.currentAppUserID = { "$RCAnonymousID:abc" }
        }

        await store.send(.codeChanged("999999")) {
            $0.code = "999999"
        }
        await store.send(.claimTapped) {
            $0.isLoading = true
        }
        await store.receive(.claimResponse(.failure(.rcLinkNotClaimable))) {
            $0.isLoading = false
            $0.errorMessage = String(localized: "account.rclink.invalid", defaultValue: "That code is invalid or expired. Generate a new one on the web.")
        }
    }

    // MARK: - 409: purchase already bound to another account

    @Test("rc_link_already_bound surfaces the bound message")
    func alreadyBoundSurfacesBoundMessage() async {
        let store = TestStore(initialState: RcLinkFeature.State()) {
            RcLinkFeature()
        } withDependencies: {
            $0.apiClient.rcLink = { _ in
                throw APIClientError.rcLinkAlreadyBound
            }
            $0.subscriptionClient.currentAppUserID = { "$RCAnonymousID:abc" }
        }

        await store.send(.codeChanged("123456")) {
            $0.code = "123456"
        }
        await store.send(.claimTapped) {
            $0.isLoading = true
        }
        await store.receive(.claimResponse(.failure(.rcLinkAlreadyBound))) {
            $0.isLoading = false
            $0.errorMessage = String(localized: "account.rclink.bound", defaultValue: "This purchase is already linked to another account.")
        }
    }

    // MARK: - Short code blocks before any API call

    @Test("short code blocks the claim with the inline error")
    func shortCodeBlocksClaim() async {
        let store = TestStore(initialState: RcLinkFeature.State()) {
            RcLinkFeature()
        } withDependencies: {
            $0.apiClient.rcLink = { _ in
                Issue.record("API must not be called with a short code")
                return RcLinkResponse(userId: "x", tier: "free", email: "", expiresAt: nil)
            }
            $0.subscriptionClient.currentAppUserID = { "" }
        }

        await store.send(.codeChanged("123")) {
            $0.code = "123"
        }
        await store.send(.claimTapped) {
            $0.errorMessage = String(localized: "account.rclink.shortCode", defaultValue: "Enter the 6-digit code shown on the web account page.")
        }
    }

    // MARK: - AppFeature wiring: sheet + identity link

    @Test("showRcLinkTapped presents the sheet and the delegate links identity")
    func appFeatureWiringLinksIdentityOnClaim() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.apiClient.rcLink = { req in
                #expect(req.appUserId == "$RCAnonymousID:abc")
                return RcLinkResponse(
                    userId: "22222222-2222-2222-2222-222222222222",
                    tier: "everywhere_annual",
                    email: "t***@gmail.com",
                    expiresAt: "2027-01-01T00:00:00Z"
                )
            }
            $0.subscriptionClient.currentAppUserID = { "$RCAnonymousID:abc" }
            $0.subscriptionClient.logIn = { userID in
                #expect(userID == "22222222-2222-2222-2222-222222222222")
                return .everywherePlus
            }
        }
        store.exhaustivity = .off

        await store.send(.showRcLinkTapped) {
            $0.rcLink = RcLinkFeature.State()
        }

        await store.send(.rcLink(.presented(.codeChanged("123456")))) {
            $0.rcLink?.code = "123456"
        }
        await store.send(.rcLink(.presented(.claimTapped))) {
            $0.rcLink?.isLoading = true
        }
        await store.receive(.rcLink(.presented(.claimResponse(.success(RcLinkResponse(
            userId: "22222222-2222-2222-2222-222222222222",
            tier: "everywhere_annual",
            email: "t***@gmail.com",
            expiresAt: "2027-01-01T00:00:00Z"
        )))))) {
            $0.rcLink?.isLoading = false
            $0.rcLink?.successEmail = "t***@gmail.com"
            $0.rcLink?.successUserID = "22222222-2222-2222-2222-222222222222"
        }
        // Continue hands the sheet over: dismiss + existing identity path
        // (Purchases.logIn → subscriptionStateLoaded → soft-sync).
        await store.send(.rcLink(.presented(.continueTapped))) {
            $0.rcLink?.successEmail = nil
            $0.rcLink?.successUserID = nil
        }
        await store.receive(.rcLink(.presented(.delegate(.claimSucceeded(userID: "22222222-2222-2222-2222-222222222222"))))) {
            $0.rcLink = nil
        }
        await store.receive(.subscriptionStateLoaded(.everywherePlus))
    }
}
