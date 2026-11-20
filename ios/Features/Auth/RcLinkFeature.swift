// RcLinkFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer for the #953 license bridge: the user enters the single-use
// 6-digit code shown on the web account page (app.pepinillo.app/account);
// the backend verifies the RevenueCat entitlement server-side and binds the
// purchase to that web account. Identity is then linked through the SAME
// path as every auth flow (AppFeature.linkSubscriptionIdentity →
// Purchases.logIn → SUBSCRIBER_ALIAS transfers the purchase).

import Foundation
import ComposableArchitecture

// MARK: - RcLinkFeature

@Reducer
struct RcLinkFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var code = ""
        var isLoading = false
        var errorMessage: String? = nil
    }

    // MARK: - Action

    enum Action: Equatable {
        case codeChanged(String)
        case claimTapped

        case claimResponse(Result<RcLinkResponse, APIClientError>)

        case delegate(Delegate)
        enum Delegate: Equatable {
            case claimSucceeded(userID: String)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.subscriptionClient) var subscriptionClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .codeChanged(let code):
                state.code = String(code.filter(\.isNumber).prefix(6))
                state.errorMessage = nil
                return .none

            case .claimTapped:
                guard state.code.count == 6 else {
                    state.errorMessage = String(localized: "account.rclink.invalid", defaultValue: "That code is invalid or expired. Generate a new one on the web.")
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let reqCode = state.code
                return .run { send in
                    let appUserID = await subscriptionClient.currentAppUserID()
                    let req = RcLinkRequest(code: reqCode, appUserId: appUserID, platform: "ios")
                    do {
                        let response = try await apiClient.rcLink(req)
                        await send(.claimResponse(.success(response)))
                    } catch let error as APIClientError {
                        await send(.claimResponse(.failure(error)))
                    } catch {
                        await send(.claimResponse(.failure(.networkError)))
                    }
                }

            case .claimResponse(.success(let response)):
                state.isLoading = false
                // Identity linking runs in AppFeature (same path as auth
                // flows): Purchases.logIn fires SUBSCRIBER_ALIAS in RC and
                // soft-sync refreshes capabilities with the granted tier.
                return .send(.delegate(.claimSucceeded(userID: response.userId)))

            case .claimResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
