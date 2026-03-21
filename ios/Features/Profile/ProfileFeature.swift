// ProfileFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the user profile screen.
// Loads cached user, local stats, refreshes from network, and handles sign-out.

import Foundation
import ComposableArchitecture

// MARK: - ProfileFeature

@Reducer
struct ProfileFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var user: CachedUserDTO? = nil
        var isLoading = false
        var errorMessage: String? = nil

        // Local stats
        var totalFocusMinutes: Int = 0
        var totalSessions: Int = 0
        var bestStreak: Int = 0
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case cachedUserLoaded(CachedUserDTO?)
        case statsLoaded(totalMinutes: Int, totalSessions: Int, bestStreak: Int)
        case profileRefreshed(Result<APIUser, APIClientError>)
        case signOutTapped
        case signOutCompleted

        case delegate(Delegate)
        enum Delegate: Equatable {
            case signedOut
        }
    }

    // MARK: - Dependencies

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.persistenceClient) var persistence

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                return .merge(
                    // Load cached user (instant)
                    .run { send in
                        let user = try? await persistence.fetchCachedUser()
                        await send(.cachedUserLoaded(user))
                    },
                    // Load local stats from preferences (streak) and daily stats (focus/sessions)
                    .run { send in
                        let prefs = try? await persistence.fetchPreferences()
                        let bestStreak = prefs?.longestStreakDays ?? 0

                        // Aggregate daily stats for the last 365 days
                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: .now)
                        var totalMinutes = 0
                        var totalSessions = 0

                        for dayOffset in 0..<365 {
                            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                            if let stats = try? await persistence.fetchDailyStats(date) {
                                totalMinutes += stats.totalFocusMinutes
                                totalSessions += stats.sessionsCompleted
                            }
                        }

                        await send(.statsLoaded(
                            totalMinutes: totalMinutes,
                            totalSessions: totalSessions,
                            bestStreak: bestStreak
                        ))
                    },
                    // Best-effort refresh from network
                    .run { send in
                        do {
                            let user = try await apiClient.getMe()
                            await send(.profileRefreshed(.success(user)))
                        } catch let error as APIClientError {
                            await send(.profileRefreshed(.failure(error)))
                        } catch {
                            // Network error — silently use cached data
                        }
                    }
                )

            case .cachedUserLoaded(let user):
                state.user = user
                return .none

            case .statsLoaded(let totalMinutes, let totalSessions, let bestStreak):
                state.totalFocusMinutes = totalMinutes
                state.totalSessions = totalSessions
                state.bestStreak = bestStreak
                return .none

            case .profileRefreshed(.success(let apiUser)):
                let dto = CachedUserDTO(
                    id: apiUser.id,
                    email: apiUser.email,
                    name: apiUser.name,
                    imageUrl: apiUser.imageUrl,
                    birthDate: apiUser.birthDate,
                    subscriptionTier: apiUser.subscriptionTier,
                    subscriptionExpiresAt: apiUser.subscriptionExpiresAt,
                    emailVerified: apiUser.emailVerified,
                    appleId: apiUser.appleId,
                    createdAt: apiUser.createdAt,
                    updatedAt: apiUser.updatedAt
                )
                state.user = dto
                return .run { _ in
                    try? await persistence.saveCachedUser(dto)
                }

            case .profileRefreshed(.failure(let error)):
                if error == .sessionExpired {
                    return .send(.signOutTapped)
                }
                // Other errors: silently use cached data
                return .none

            case .signOutTapped:
                state.isLoading = true
                return .run { send in
                    if let refreshToken = await keychain.loadRefreshToken() {
                        try? await apiClient.logout(LogoutRequest(refreshToken: refreshToken))
                    }
                    try? await keychain.deleteTokens()
                    try? await persistence.deleteCachedUser()
                    await send(.signOutCompleted)
                }

            case .signOutCompleted:
                state.isLoading = false
                state.user = nil
                return .send(.delegate(.signedOut))

            case .delegate:
                return .none
            }
        }
    }
}
