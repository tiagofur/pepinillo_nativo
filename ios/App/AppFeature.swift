// AppFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// Root TCA feature that composes all child features.
// Manages tab selection, subscription state, celebrations, Watch bridge,
// and Sign in with Apple state.
//
// Navigation: 4 tabs (Focus, Plan, Dashboard, Account/"...") with no lateral drawer.
// Account tab centralizes Profile, Settings, Subscription, Export, Help.

import Foundation
import ComposableArchitecture
import OSLog
import UserNotifications
import WidgetKit

private enum AppLaunchDefaults {
    static let hasCompletedOnboardingKey = "pepinillo.hasCompletedOnboarding"
}

private let appLaunchLogger = Logger(subsystem: "com.pepinillo.app", category: "app-launch")

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .focus
        var focus = FocusFeature.State()
        var tasks = TaskListFeature.State()
        var analytics = AnalyticsFeature.State()
        var settings = SettingsFeature.State()
        var paywall = PaywallFeature.State()
        var hasCompletedOnboarding: Bool = false

        // Subscription
        var subscriptionState: SubscriptionState = .free
        /// Last capabilities the soft-sync was run for (issue #78). Avoids
        /// running the full reconcile/sync pipeline twice when
        /// `subscriptionStateLoaded` and `subscriptionUpdated` arrive in quick
        /// succession with identical capabilities.
        var lastSyncedCapabilities: UserCapabilities? = nil

        /// Connectivity state from NetworkClient (issue #89). `true` = offline.
        /// Drives the offline banner in AppView.
        var isOffline: Bool = false

        // Celebration overlay
        var pendingCelebration: CelebrationMilestone? = nil

        @Presents var calendar: CalendarFeature.State?

        // Auth & Profile sheets
        @Presents var auth: AuthFeature.State?
        @Presents var profile: ProfileFeature.State?
        @Presents var emailVerification: EmailVerificationFeature.State?

        // Sign in with Apple
        var appleUserID: String? = nil
        var displayName: String? = nil
        var userEmail: String? = nil
        var cachedUser: CachedUserDTO? = nil
        var isSignedIn: Bool { cachedUser != nil || appleUserID != nil }
        /// Error surfaced when account deletion fails (#193). Non-nil presents an alert.
        var deleteAccountError: String? = nil
        /// True while the backend account-deletion request is in flight (#193).
        var isDeletingAccount: Bool = false
        /// Non-nil when Sign in with Apple fails for a real error (not user cancel) (#200).
        var signInWithAppleError: String? = nil
        var pendingExternalStartModeID: String?
        var pendingExternalStartTaskID: String?
        var pendingExternalStartTimerStart: Date?
        var pendingExternalStartTimerEnd: Date?
        /// Task ID from Spotlight / universal link, opened after tasks load.
        var pendingDeepLinkTaskID: UUID?

        // Watch bridge throttle — last elapsed value sent to Watch (1Hz gate)
        var lastWatchSentElapsed: TimeInterval = -1
        var profileSummaryUser: CachedUserDTO? {
            func normalized(_ value: String?) -> String? {
                guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                    return nil
                }
                return value
            }

            let cachedName = normalized(cachedUser?.name)
            let cachedEmail = normalized(cachedUser?.email)
            let restoredName = normalized(displayName)
            let restoredEmail = normalized(userEmail)
            let resolvedUserID = normalized(cachedUser?.id) ?? appleUserID
            let resolvedAppleID = normalized(cachedUser?.appleId) ?? appleUserID

            guard let resolvedUserID else {
                return nil
            }

            let resolvedEmail = cachedEmail ?? restoredEmail ?? ""

            let resolvedName: String
            if let cachedName {
                resolvedName = cachedName
            } else if let restoredName {
                resolvedName = restoredName
            } else if let emailPrefix = (cachedEmail ?? restoredEmail)?.split(separator: "@").first, !emailPrefix.isEmpty {
                resolvedName = String(emailPrefix)
            } else {
                resolvedName = "Apple User"
            }

            return CachedUserDTO(
                id: resolvedUserID,
                email: resolvedEmail,
                name: resolvedName,
                imageUrl: cachedUser?.imageUrl,
                birthDate: cachedUser?.birthDate,
                subscriptionTier: normalized(cachedUser?.subscriptionTier) ?? subscriptionState.capabilities.tierIdentifier,
                subscriptionExpiresAt: cachedUser?.subscriptionExpiresAt,
                // Never infer verification from a restored email string (#199).
                emailVerified: cachedUser?.emailVerified ?? false,
                appleId: resolvedAppleID,
                createdAt: cachedUser?.createdAt ?? "",
                updatedAt: cachedUser?.updatedAt ?? ""
            )
        }
    }

    enum Tab: String, Equatable, CaseIterable {
        case focus
        case plan
        case dashboard
        case account

        var title: String {
            switch self {
            case .focus:     return String(localized: "Focus")
            case .plan:      return String(localized: "Plan")
            case .dashboard: return String(localized: "Dashboard")
            case .account:   return String(localized: "More")
            }
        }

        var systemImage: String {
            switch self {
            case .focus:     return "brain.head.profile"
            case .plan:      return "checklist"
            case .dashboard: return "chart.bar.fill"
            case .account:   return "ellipsis.circle"
            }
        }
    }

    enum Action: Equatable {
        case tabSelected(Tab)
        case focus(FocusFeature.Action)
        case tasks(TaskListFeature.Action)
        case analytics(AnalyticsFeature.Action)
        case settings(SettingsFeature.Action)
        case paywall(PaywallFeature.Action)
        case onboardingCompleted
        case onboardingCompletedWithMode(FocusMode)
        case appLaunched
        case appBecameActive
        case appWentToBackground
        case consumeExternalCommands
        case appURLReceived(URL)

        // Subscription
        case subscriptionStateLoaded(SubscriptionState)
        case subscriptionUpdated(SubscriptionState)

        // Celebrations
        case celebrationTriggered(CelebrationMilestone)
        case celebrationDismissed

        // Notification permission
        case requestNotificationPermission

        // Notification actions
        case notificationActionReceived(NotificationAction)

        // Watch bridge
        case watchCommandReceived(WatchCommand)

        // Calendar
        case calendarTapped
        case calendarSheetDismissed
        case calendar(PresentationAction<CalendarFeature.Action>)

        // Weekly Review
        case weeklyReviewTapped

        // Upgrade (from Account tab subscription row)
        case upgradeTapped

        // Auth & Profile
        case showAuth
        case showProfile
        case auth(PresentationAction<AuthFeature.Action>)
        case profile(PresentationAction<ProfileFeature.Action>)
        case emailVerification(PresentationAction<EmailVerificationFeature.Action>)
        case cachedUserLoaded(CachedUserDTO?)
        case tokenRefreshFailed

        // Connectivity (issue #89)
        case connectivityChanged(Bool)  // true = connected

        // Sign in with Apple
        case signInWithAppleSucceeded(AppleUserInfo)
        /// Cold-start restore of a still-authorized Apple credential — no fresh SIWA (#199).
        case appleIdentityRestored(AppleUserInfo)
        case signInWithAppleFailed(wasUserCancelled: Bool = false)
        case signOutTapped
        case deleteAccountTapped
        case deleteAccountSucceeded
        case deleteAccountFailed(String)
        case dismissDeleteAccountError
        case dismissSignInWithAppleError
        case appleCredentialStateChecked(String, Bool)
        case appleCredentialRevoked

        // Day change
        case dayChanged

        // Handoff
        case handoffFocusReceived(modeID: String, isRunning: Bool, taskTitle: String?)
        case handoffAnalyticsReceived
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.focusClient) var focusClient
    @Dependency(\.subscriptionClient) var subscriptionClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.watchConnectivityClient) var watchClient
    @Dependency(\.signInWithAppleClient) var appleClient
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.syncClient) var syncClient
    @Dependency(\.webSocketClient) var webSocketClient
    @Dependency(\.syncModeClient) var syncModeClient
    @Dependency(\.networkClient) var networkClient
    @Dependency(\.liveActivityClient) var liveActivityClient

    private enum CancelID {
        case transactionListener
        case watchCommandListener
        case notificationActionListener
        case externalCommandObserver
        case webSocket
        case softSync
        case networkConnectivity
        case appleCredentialRevocation
        /// Deduplicates rapid-fire taskProgressChanged + sessionPersisted refreshes.
        case sessionTaskRefresh
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.focus, action: \.focus) {
            FocusFeature()
        }
        Scope(state: \.tasks, action: \.tasks) {
            TaskListFeature()
        }
        Scope(state: \.analytics, action: \.analytics) {
            AnalyticsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Scope(state: \.paywall, action: \.paywall) {
            PaywallFeature()
        }
        Reduce { state, action in
            let pushTasksToWatch: (State) -> Effect<Action> = { [watchClient] state in
                let watchTasks = state.tasks.tasks
                    .filter { $0.scheduledForToday }
                    .map { task in
                        WatchTaskItem(
                            id: task.id,
                            title: task.title,
                            isCompleted: task.isCompleted,
                            priority: task.priority.rawValue,
                            estimatedPomodoros: task.estimatedPomodoros,
                            completedPomodoros: task.completedPomodoros
                        )
                    }
                return .run { _ in
                    await watchClient.sendTasks(watchTasks)
                }
            }
            
            let startFromExternalRequest: (inout State, String?, String?, Date?, Date?, Bool) -> Effect<Action> = { state, requestedModeID, requestedTaskID, timerStart, timerEnd, canDeferForTaskLoad in
                state.selectedTab = .focus

                var effects: [Effect<Action>] = []
                var shouldClearLinkedTask = requestedTaskID != nil

                if let taskIDString = requestedTaskID,
                   let taskID = UUID(uuidString: taskIDString) {
                    if let task = state.tasks.tasks[id: taskID] {
                        shouldClearLinkedTask = false
                        effects.append(.send(.focus(.linkTask(task.id, task.title, task.energyLevel.emoji))))
                    } else if canDeferForTaskLoad && state.tasks.tasks.isEmpty {
                        state.pendingExternalStartModeID = requestedModeID
                        state.pendingExternalStartTaskID = requestedTaskID
                        state.pendingExternalStartTimerStart = timerStart
                        state.pendingExternalStartTimerEnd = timerEnd
                        return .send(.tasks(.onAppear))
                    }
                }

                if shouldClearLinkedTask {
                    effects.append(.send(.focus(.linkTask(nil, nil, nil))))
                }

                if let modeID = requestedModeID,
                   let mode = FocusMode(rawValue: modeID) {
                    guard mode.isFreeTier || state.focus.isProUser else {
                        state.focus.showPaywall = true
                        return .concatenate(
                            .send(.focus(.modeSelected(mode))),
                            .send(.paywall(.appeared))
                        )
                    }
                    effects.append(.send(.focus(.modeSelected(mode))))
                }

                effects.append(.send(.focus(.startTapped(timerStart: timerStart, timerEnd: timerEnd))))
                return .concatenate(effects)
            }

            switch action {

            case .tabSelected(let tab):
                state.selectedTab = tab
                if tab == .dashboard {
                    return .send(.analytics(.onAppear))
                }
                return .none

            case .onboardingCompleted:
                state.hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: AppLaunchDefaults.hasCompletedOnboardingKey)
                return .run { send in
                    var prefs = try await persistence.fetchPreferences()
                    prefs.hasCompletedOnboarding = true
                    try await persistence.savePreferences(prefs)
                }

            case .onboardingCompletedWithMode(let mode):
                state.hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: AppLaunchDefaults.hasCompletedOnboardingKey)
                state.settings.defaultMode = mode
                state.focus.selectedMode = mode
                return .run { [mode] send in
                    var prefs = try await persistence.fetchPreferences()
                    prefs.hasCompletedOnboarding = true
                    prefs.defaultMode = mode.rawValue
                    try await persistence.savePreferences(prefs)
                }

            case .appLaunched:
                // Launch contract:
                // 1. Load local data immediately so the app is useful after splash.
                // 2. Start RevenueCat early because Pro flags gate product behavior.
                // 3. Defer cloud/backend sync and heavyweight analytics until after
                //    the UI has had time to become interactive.
                return .merge(
                    // RevenueCat: configure in parallel. Entitlement checks wait
                    // internally for configure(), but none of this blocks UI taps.
                    .run { send in
                        let start = Date.now
                        let prefs = try await persistence.fetchPreferences()
                        let userID = prefs.appleUserID
                        let revenueCatKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
                        await subscriptionClient.configure(revenueCatKey, userID)
                        appLaunchLogger.info("RevenueCat configure finished in \(Date.now.timeIntervalSince(start), privacy: .public)s")
                    },
                    // Onboarding check + Apple credential state check
                    .run { [appleClient] send in
                        let start = Date.now
                        let prefs = try await persistence.fetchPreferences()
                        if prefs.hasCompletedOnboarding {
                            await send(.onboardingCompleted)
                        }
                        if let userID = prefs.appleUserID {
                            let authorized = await appleClient.checkCredentialState(userID)
                            await send(.appleCredentialStateChecked(userID, authorized))
                        }
                        appLaunchLogger.info("Local preferences launch read finished in \(Date.now.timeIntervalSince(start), privacy: .public)s")
                    },
                    // Subscription entitlement (waits for configure internally)
                    .run { send in
                        let start = Date.now
                        let sub = await subscriptionClient.checkEntitlement()
                        appLaunchLogger.info("RevenueCat entitlement finished in \(Date.now.timeIntervalSince(start), privacy: .public)s")
                        await send(.subscriptionStateLoaded(sub))
                    },
                    // RevenueCat customer info stream (waits for configure internally)
                    .run { send in
                        let stream = subscriptionClient.listenForTransactionUpdates()
                        for await sub in stream {
                            await send(.subscriptionUpdated(sub))
                        }
                    }
                    .cancellable(id: CancelID.transactionListener),
                    // Notification action taps
                    .run { [notificationClient] send in
                        let stream = notificationClient.observeActions()
                        for await action in stream {
                            await send(.notificationActionReceived(action))
                        }
                    }
                    .cancellable(id: CancelID.notificationActionListener),
                    // Load cached user from persistence
                    .run { send in
                        let user = try? await persistence.fetchCachedUser()
                        await send(.cachedUserLoaded(user))
                    },
                    // Refresh user profile from network (with 10s timeout, non-blocking)
                    .run { [keychain, apiClient, persistence] send in
                        try? await Task.sleep(for: .seconds(2))
                        guard await keychain.hasTokens() else { return }
                        do {
                            let apiUser = try await withThrowingTaskGroup(of: APIUser.self) { group in
                                group.addTask {
                                    try await apiClient.getMe()
                                }
                                group.addTask {
                                    try await Task.sleep(for: .seconds(10))
                                    throw CancellationError()
                                }
                                guard let result = try await group.next() else {
                                    throw CancellationError()
                                }
                                group.cancelAll()
                                return result
                            }
                            let dto = CachedUserDTO(
                                id: apiUser.id, email: apiUser.email, name: apiUser.name,
                                imageUrl: apiUser.imageUrl, birthDate: apiUser.birthDate,
                                subscriptionTier: apiUser.subscriptionTier,
                                subscriptionExpiresAt: apiUser.subscriptionExpiresAt,
                                emailVerified: apiUser.emailVerified, appleId: apiUser.appleId,
                                createdAt: apiUser.createdAt, updatedAt: apiUser.updatedAt
                            )
                            try? await persistence.saveCachedUser(dto)
                            await send(.cachedUserLoaded(dto))
                        } catch let error as APIClientError {
                            // Definitive session expiry (refresh rejected 401/403) — the
                            // APIClient already cleared keychain tokens as a silent side
                            // effect, so we MUST propagate this to the state layer,
                            // otherwise cachedUser/prefs/RevenueCat linger and the user
                            // stays "signed in" with dead credentials (#194).
                            if case .sessionExpired = error {
                                await send(.tokenRefreshFailed)
                            }
                            // Other errors (network, timeout, 5xx) — use cached data silently.
                        } catch {
                            // Network error or timeout — use cached data silently
                        }
                    },
                    // Watch: listen for commands from the Watch
                    .run { [watchClient] send in
                        guard watchClient.isSupported() else { return }
                        let stream = await watchClient.receiveMessages()
                        for await message in stream {
                            if case .command(let cmd) = message {
                                await send(.watchCommandReceived(cmd))
                            }
                        }
                    }
                    .cancellable(id: CancelID.watchCommandListener),
                    // Load tasks early so they are available for focus linking
                    .send(.tasks(.onAppear)),
                    // Reconcile widget/intent commands even if they arrived before bootstrap finished.
                    .send(.consumeExternalCommands),
                    pushWatchSessionSnapshot(from: state, publishContext: true),
                    // Observe network connectivity for the offline banner (issue #89)
                    .run { [networkClient] send in
                        for await isConnected in networkClient.observeConnectivity() {
                            await send(.connectivityChanged(isConnected))
                        }
                    }
                    .cancellable(id: CancelID.networkConnectivity),
                    // Observe Apple credential revocation mid-session (#195). Without this
                    // a revoke only surfaces on the next cold start's checkCredentialState,
                    // leaving the session alive for the rest of the foreground run.
                    .run { [appleClient] send in
                        let stream = await appleClient.observeCredentialRevocation()
                        for await _ in stream {
                            await send(.appleCredentialRevoked)
                        }
                    }
                    .cancellable(id: CancelID.appleCredentialRevocation),
                    .run { _ in
                        ExportService.cleanLegacyExportDirectories()
                    }
                )

            case .requestNotificationPermission:
                return .run { _ in
                    _ = await notificationClient.requestAuthorization()
                }

            case .appBecameActive:
                return .merge(
                    .send(.consumeExternalCommands),
                    syncWatchStats(isPro: state.subscriptionState.isPro),
                    pushWatchSessionSnapshot(from: state, publishContext: true)
                )

            case .appURLReceived(let url):
                guard url.scheme == "pepinillo" else { return .none }
                switch url.host?.lowercased() {
                case "plan", "tasks":
                    state.selectedTab = .plan
                    return .none
                case "task":
                    guard let taskID = Self.taskID(from: url) else { return .none }
                    state.selectedTab = .plan
                    state.pendingDeepLinkTaskID = taskID
                    return .send(.tasks(.onAppear))
                case "focus":
                    state.selectedTab = .focus
                    return .none
                case "dashboard", "analytics":
                    state.selectedTab = .dashboard
                    return .none
                default:
                    break
                }
                return .none

            case .consumeExternalCommands:
                AppGroupDefaults.discardStaleExternalCommandsIfNeeded()

                let ghostSessionClearedEffects: () -> Effect<Action> = { [liveActivityClient, notificationClient] in
                    .merge(
                        .run { _ in
                            WidgetSurfaceReload.reloadFocusTasksAndControlCenter()
                        },
                        .run { _ in
                            await liveActivityClient.end(false)
                            await notificationClient.clearActiveSession()
                        }
                    )
                }

                // Check for external commands from Siri, widgets, or Control Center
                if AppGroupDefaults.externalStartRequested {
                    let requestedModeID = AppGroupDefaults.requestedMode ?? AppGroupDefaults.activeModeName
                    let requestedTaskID = AppGroupDefaults.requestedTaskID
                    let timerStart = AppGroupDefaults.activeSessionTimerStart
                    let timerEnd = AppGroupDefaults.activeSessionTimerEnd
                    
                    AppGroupDefaults.clearExternalCommands()
                    state.pendingExternalStartModeID = nil
                    state.pendingExternalStartTaskID = nil
                    
                    if state.focus.isRunning {
                        // Stop current session before starting a new one from an external request
                        return .concatenate(
                            .send(.focus(.stopTapped)),
                            startFromExternalRequest(&state, requestedModeID, requestedTaskID, timerStart, timerEnd, true)
                        )
                    } else {
                        return startFromExternalRequest(&state, requestedModeID, requestedTaskID, timerStart, timerEnd, true)
                    }
                }
                
                if AppGroupDefaults.externalStopRequested {
                    AppGroupDefaults.clearExternalCommands()
                    if state.focus.isRunning {
                        return .send(.focus(.stopTapped))
                    }
                    if AppGroupDefaults.SessionReconcilePolicy.clearGhostSessionIfNeeded(
                        engineIsRunning: state.focus.isRunning
                    ) {
                        return ghostSessionClearedEffects()
                    }
                    return .none
                }
                
                if AppGroupDefaults.externalResumeRequested {
                    let liveElapsed = AppGroupDefaults.activeSessionLiveElapsed()
                    let liveRemaining = AppGroupDefaults.activeSessionLiveRemaining()
                    AppGroupDefaults.clearExternalCommands()
                    guard state.focus.isRunning else { return .none }
                    return .send(.focus(.externalResumeApplied(
                        elapsed: liveElapsed,
                        remaining: liveRemaining
                    )))
                }
                
                if AppGroupDefaults.externalPauseRequested {
                    let frozenElapsed = AppGroupDefaults.activeSessionLiveElapsed()
                    let frozenRemaining = AppGroupDefaults.activeSessionLiveRemaining()
                    let pausedAt = AppGroupDefaults.activeSessionPausedAt ?? Date.now
                    AppGroupDefaults.clearExternalCommands()
                    guard state.focus.isRunning else { return .none }

                    return .send(.focus(.externalPauseApplied(
                        elapsed: frozenElapsed,
                        remaining: frozenRemaining,
                        pausedAt: pausedAt
                    )))
                }
                
                AppGroupDefaults.clearExternalCommands()

                // Killed mid-session: App Group still says active but FocusEngine is idle.
                if AppGroupDefaults.SessionReconcilePolicy.clearGhostSessionIfNeeded(
                    engineIsRunning: state.focus.isRunning
                ) {
                    return ghostSessionClearedEffects()
                }
                
                // Sync idle mode selection from widget to app if no session is running
                if !state.focus.isRunning, let widgetModeID = AppGroupDefaults.widgetSelectedMode,
                   let widgetMode = FocusMode(rawValue: widgetModeID),
                   widgetMode != state.focus.selectedMode {
                    return .send(.focus(.modeSelected(widgetMode)))
                }

                // Reconnect WebSocket if authenticated
                let timerSync: Effect<Action> = {
                    guard state.focus.isRunning, AppGroupDefaults.isSessionActive else { return .none }
                    let liveElapsed = AppGroupDefaults.activeSessionLiveElapsed()
                    let liveRemaining = AppGroupDefaults.activeSessionLiveRemaining()
                    return .run { [focusClient] _ in
                        await focusClient.syncExternalState(liveElapsed, liveRemaining)
                    }
                }()
                return .merge(
                    timerSync,
                    .run { [keychain, webSocketClient, canBackendSync = state.subscriptionState.capabilities.backendSync] _ in
                        guard canBackendSync else { return }
                        guard await keychain.hasTokens() else { return }
                        await withTaskCancellationHandler {
                            await webSocketClient.connect()
                        } onCancel: {
                            webSocketClient.disconnect()
                        }
                    }
                    .cancellable(id: CancelID.webSocket, cancelInFlight: true)
                )

            case .appWentToBackground:
                webSocketClient.disconnect()
                return .none

            case .subscriptionStateLoaded(let sub):
                return applySubscriptionUpdate(sub, state: &state)

            case .subscriptionUpdated(let sub):
                return applySubscriptionUpdate(sub, state: &state)

            case .celebrationTriggered(let milestone):
                state.pendingCelebration = milestone
                return .none

            case .celebrationDismissed:
                state.pendingCelebration = nil
                return .none

            // MARK: - Upgrade (from Account tab)

            case .upgradeTapped:
                state.focus.showPaywall = true
                return .send(.paywall(.appeared))

            case .paywall(.delegate(.proUnlocked(let sub))):
                return applySubscriptionUpdate(sub, state: &state)

            // MARK: - Calendar & Weekly Review

            case .calendarTapped:
                state.calendar = CalendarFeature.State()
                return .none

            case .weeklyReviewTapped:
                if state.subscriptionState.isPro {
                    state.analytics.weeklyReview = WeeklyReviewFeature.State()
                } else {
                    state.focus.showPaywall = true
                    return .send(.paywall(.appeared))
                }
                return .none

            case .calendarSheetDismissed:
                state.calendar = nil
                return .none

            case .calendar:
                return .none

            // MARK: - Auth & Profile

            case .showAuth:
                state.auth = AuthFeature.State()
                return .none

            case .showProfile:
                state.profile = ProfileFeature.State(user: state.profileSummaryUser)
                return .none

            case .cachedUserLoaded(let user):
                state.cachedUser = user
                if let user {
                    let normalizedName = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalizedEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !normalizedName.isEmpty {
                        state.displayName = normalizedName
                    }
                    if !normalizedEmail.isEmpty {
                        state.userEmail = normalizedEmail
                    }
                    // Email verification gate on cold-start restore (#192).
                    // AuthFeature persists tokens + CachedUser BEFORE the verification
                    // sheet, so a force-quit during verification left an unverified
                    // session that bypassed the gate on relaunch. Re-present the
                    // verification sheet for unverified users — UNLESS they are signed
                    // in with Apple, whose credential state implies a verified account.
                    if !user.emailVerified && state.appleUserID == nil && state.emailVerification == nil {
                        state.emailVerification = EmailVerificationFeature.State(email: user.email)
                    }
                    // Re-link RevenueCat on cold-start session restore (#197).
                    return linkSubscriptionIdentity(user.id)
                }
                return .none

            case .auth(.presented(.delegate(.authenticated(let user)))):
                state.cachedUser = user
                state.displayName = user.name
                state.userEmail = user.email
                state.auth = nil  // dismiss auth sheet
                // Reload the task list: the account-only auth path runs
                // syncClient.wipeAndSync() (deleteAllTasks) before delegating here,
                // which leaves the in-memory list stale. `.refresh` bypasses the
                // hasLoadedData guard and refetches from the now-current store.
                return .merge(
                    .send(.tasks(.refresh)),
                    linkSubscriptionIdentity(user.id),
                    .run { [syncClient, webSocketClient, canBackendSync = state.subscriptionState.capabilities.backendSync] _ in
                        if canBackendSync {
                            try? await syncClient.syncAll()
                            await webSocketClient.connect()
                        }
                    }
                )

            case .auth(.presented(.delegate(.emailVerificationRequired(let email)))):
                state.auth = nil  // dismiss auth sheet
                state.emailVerification = EmailVerificationFeature.State(email: email)
                return .none

            case .emailVerification(.presented(.delegate(.verificationSucceeded(let user)))):
                state.cachedUser = user
                state.displayName = user.name
                state.userEmail = user.email
                state.emailVerification = nil  // dismiss verification sheet
                return .merge(
                    linkSubscriptionIdentity(user.id),
                    .run { [syncClient, webSocketClient, canBackendSync = state.subscriptionState.capabilities.backendSync] _ in
                        if canBackendSync {
                            try? await syncClient.syncAll()
                            await webSocketClient.connect()
                        }
                    }
                )

            case .emailVerification(.presented(.delegate(.signOutRequested))):
                // User tapped the escape hatch on the verification sheet. Clear the
                // unverified persisted session so the next launch presents AuthView
                // instead of bypassing the gate (#192).
                state.emailVerification = nil
                return performSignOutCleanup(&state)

            case .emailVerification:
                return .none

            case .auth(.presented(.delegate(.guestModeSelected))):
                state.auth = nil  // dismiss auth sheet
                return .none

            case .auth:
                return .none

            case .profile(.presented(.delegate(.signedOut))):
                return performSignOutCleanup(&state, dismissProfile: true)

            case .profile:
                return .none

            case .tokenRefreshFailed:
                // Session expired (refresh rejected 401/403). Run the full sign-out
                // cleanup so the app returns to the signed-out state — previously this
                // handler only cleared in-memory fields while tokens/cachedUser/prefs/RC
                // lingered, and it was never even dispatched (#194).
                return performSignOutCleanup(&state)

            // MARK: - Connectivity (issue #89)

            case .connectivityChanged(let isConnected):
                state.isOffline = !isConnected
                return .none

            // MARK: - Sign in with Apple

            case .appleCredentialRevoked:
                // Mid-session Apple credential revocation notification (#195). Perform
                // a full sign-out without waiting for the next cold-start credential
                // check — otherwise the session lingers until the app is force-quit.
                return performSignOutCleanup(&state)

            case .appleCredentialStateChecked(let userID, let authorized):
                if authorized {
                    // Restore local Apple identity only — do not replay fresh SIWA (#199).
                    return .run { send in
                        let prefs = try await persistence.fetchPreferences()
                        if prefs.appleUserID == userID {
                            await send(.appleIdentityRestored(AppleUserInfo(
                                userID: userID,
                                displayName: prefs.displayName,
                                email: prefs.userEmail
                            )))
                        }
                    }
                } else {
                    // Credential revoked by user (Settings → Apple ID → Sign in with Apple → Stop)
                    // or system. This must be a full sign-out — previously only appleUserID and
                    // prefs were cleared, leaving cachedUser/tokens/RevenueCat alive so the user
                    // remained "signed in" (#195).
                    return performSignOutCleanup(&state)
                }

            case .appleIdentityRestored(let info):
                state.appleUserID = info.userID
                if let name = info.displayName { state.displayName = name }
                if let email = info.email { state.userEmail = email }
                // Dismiss a premature email-verification gate for Apple users (#192).
                state.emailVerification = nil
                return .none

            case .signInWithAppleSucceeded(let info):
                state.auth = nil  // dismiss auth sheet if open
                state.appleUserID = info.userID
                state.emailVerification = nil
                state.signInWithAppleError = nil
                // Apple only provides displayName on the very first sign-in ever.
                let resolvedName = info.displayName
                    ?? state.cachedUser?.name
                    ?? state.displayName
                    ?? info.email?.components(separatedBy: "@").first
                state.displayName = resolvedName
                state.userEmail = info.email ?? state.userEmail
                return .merge(
                    .run { [info] _ in
                        var prefs = try await persistence.fetchPreferences()
                        prefs.appleUserID = info.userID
                        if let name = info.displayName { prefs.displayName = name }
                        if let email = info.email { prefs.userEmail = email }
                        if let code = info.authorizationCode { prefs.appleAuthorizationCode = code }
                        try await persistence.savePreferences(prefs)
                    },
                    {
                        guard let idToken = info.identityToken,
                              let nonce = info.nonce,
                              !nonce.isEmpty else {
                            return .none
                        }
                        return .run { [apiClient, keychain, persistence, syncClient, webSocketClient, canBackendSync = state.subscriptionState.capabilities.backendSync] send in
                            do {
                                let response = try await apiClient.loginWithApple(AppleLoginRequest(idToken: idToken, nonce: nonce))
                                try await keychain.saveTokens(response.tokens.accessToken, response.tokens.refreshToken)
                                let dto = CachedUserDTO(
                                    id: response.user.id, email: response.user.email, name: response.user.name,
                                    imageUrl: response.user.imageUrl, birthDate: response.user.birthDate,
                                    subscriptionTier: response.user.subscriptionTier,
                                    subscriptionExpiresAt: response.user.subscriptionExpiresAt,
                                    emailVerified: response.user.emailVerified, appleId: response.user.appleId,
                                    createdAt: response.user.createdAt, updatedAt: response.user.updatedAt
                                )
                                try? await persistence.saveCachedUser(dto)
                                await send(.cachedUserLoaded(dto))
                                await subscriptionClient.logIn(response.user.id)
                                if canBackendSync {
                                    try? await syncClient.syncAll()
                                    await webSocketClient.connect()
                                }
                            } catch {
                                // Backend auth failed — keep local Apple identity; getMe may recover later.
                            }
                        }
                    }()
                )

            case .signInWithAppleFailed(let wasUserCancelled):
                guard !wasUserCancelled else { return .none }
                state.signInWithAppleError = String(
                    localized: "Could not sign in with Apple. Please try again."
                )
                return .none

            case .signOutTapped:
                return performSignOutCleanup(&state, notifyBackendLogout: true)

            case .deleteAccountTapped:
                // Account deletion is a destructive, server-authoritative operation.
                // Previously the network call was wrapped in `try?`, so a backend failure
                // was silently swallowed and local state was cleared anyway — leaving the
                // user "signed out" with a live server account (#193, App Store 5.1.1(v)).
                // We now: (1) call the backend WITHOUT try? and surface hard errors,
                // (2) only clear local state on confirmed success, (3) wipe local user PII.
                state.isDeletingAccount = true
                state.deleteAccountError = nil
                return .run { [keychain, apiClient, persistence] send in
                    let refreshToken = await keychain.loadRefreshToken()
                    let prefs = try await persistence.fetchPreferences()
                    let appleAuthCode = prefs.appleAuthorizationCode
                    do {
                        try await apiClient.deleteAccount(
                            DeleteAccountRequest(
                                refreshToken: refreshToken,
                                appleAuthorizationCode: appleAuthCode
                            )
                        )
                        await send(.deleteAccountSucceeded)
                    } catch let error as APIClientError {
                        await send(.deleteAccountFailed(error.userMessage))
                    } catch {
                        await send(.deleteAccountFailed(String(localized: "Could not delete account. Check your connection and try again.")))
                    }
                }

            case .deleteAccountSucceeded:
                // Server confirmed deletion — now it is safe to wipe everything local.
                state.isDeletingAccount = false
                state.deleteAccountError = nil
                return performSignOutCleanup(&state, wipeLocalUserData: true)

            case .deleteAccountFailed(let message):
                // Backend rejected the delete — keep the session intact so the user can retry.
                state.isDeletingAccount = false
                state.deleteAccountError = message
                return .none

            case .dismissDeleteAccountError:
                state.deleteAccountError = nil
                return .none

            case .dismissSignInWithAppleError:
                state.signInWithAppleError = nil
                return .none

            // MARK: - Notification Action Bridge

            case .notificationActionReceived(let notifAction):
                switch notifAction {
                case .startBreak:
                    let breakMinutes = max(1, Int(state.focus.config.shortBreakDuration / 60))
                    return .run { [notificationClient] _ in
                        await notificationClient.scheduleBreakEnd(breakMinutes)
                    }
                case .startSession:
                    return .send(.focus(.startTapped()))
                case .pauseSession:
                    if state.focus.isPaused {
                        return .send(.focus(.resumeTapped))
                    } else {
                        return .send(.focus(.pauseTapped))
                    }
                case .stopSession:
                    return .send(.focus(.stopTapped))
                case .dismissed:
                    return .none
                }

            // MARK: - Watch Command Bridge (Watch → iOS)

            case .watchCommandReceived(let command):
                switch command {
                case .startSession(let modeID):
                    return startFromExternalRequest(&state, modeID, nil, nil, nil, false)
                case .pauseSession:
                    return .send(.focus(.pauseTapped))
                case .resumeSession:
                    return .send(.focus(.resumeTapped))
                case .stopSession:
                    return .send(.focus(.stopTapped))
                case .skipPhase:
                    return .send(.focus(.skipPhaseTapped))
                case .linkTask(let idStr):
                    guard let id = UUID(uuidString: idStr) else { return .none }
                    let task = state.tasks.tasks.first(where: { $0.id == id })
                    return .send(.focus(.linkTask(id, task?.title, task?.energyLevel.emoji)))
                case .unlinkTask:
                    return .send(.focus(.linkTask(nil, nil, nil)))
                case .setTaskCompleted(let idStr, let isCompleted):
                    guard let id = UUID(uuidString: idStr) else { return .none }
                    return .send(.tasks(.setTaskCompleted(id, isCompleted)))
                case .requestTasks:
                    let tasks = state.tasks.tasks.filter { $0.scheduledForToday }
                    let watchTasks = tasks.map { task in
                        WatchTaskItem(
                            id: task.id,
                            title: task.title,
                            isCompleted: task.isCompleted,
                            priority: task.priority.rawValue,
                            estimatedPomodoros: task.estimatedPomodoros,
                            completedPomodoros: task.completedPomodoros
                        )
                    }
                    return .run { [watchClient, watchTasks] _ in
                        await watchClient.sendTasks(watchTasks)
                    }
                case .startNextPhase:
                    return .send(.focus(.startNextPhaseTapped))

                case .requestDashboard:
                    return syncWatchStats(isPro: state.subscriptionState.isPro)

                case .requestSession:
                    return pushWatchSessionSnapshot(from: state, publishContext: true)
                }

            // MARK: - Watch State Bridge (iOS → Watch)

            case .focus(.timerTicked):
                // Throttle to 1Hz: only send when a full second of elapsed time has passed.
                // State transitions (pause/resume/stop/phaseCompleted) bypass this guard
                // and send immediately via their own dedicated cases below.
                let currentElapsed = state.focus.elapsedSeconds
                let lastSent = state.lastWatchSentElapsed
                guard currentElapsed - lastSent >= 1.0 else { return .none }
                state.lastWatchSentElapsed = currentElapsed
                let watchState = WatchSessionState(from: state.focus)
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState, false)
                }

            case .focus(.phaseCompleted):
                var watchState = WatchSessionState(from: state.focus)
                watchState.isPhaseTransition = true
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState, true)
                }

            case .focus(.pauseTapped), .focus(.resumeTapped),
                 .focus(.externalPauseApplied), .focus(.externalResumeApplied):
                let watchState = WatchSessionState(from: state.focus)
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState, true)
                }

            case .focus(.waitingForNextPhase):
                // The tick loop is suspended during the hold, so this is the only trigger
                // that will push a watch state update when autoStart is OFF. Without this,
                // the watch never learns the engine entered the waiting state.
                let watchState = WatchSessionState(from: state.focus)
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState, true)
                }

            case .focus(.startNextPhaseTapped):
                // The phone is leaving the waiting hold — push fresh state so the watch
                // transitions away from the waiting view immediately.
                let watchState = WatchSessionState(from: state.focus)
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState, true)
                }

            case .focus(.stopTapped), .focus(.sessionCompleted):
                let watchState = WatchSessionState(from: state.focus)
                return .merge(
                    .run { [watchClient, watchState] _ in
                        await watchClient.sendSessionState(watchState, true)
                    },
                    {
                        if case .focus(.sessionCompleted) = action {
                            // Task refresh after session completion is handled by the
                            // .focus(.delegate(.sessionPersisted)) path below — which fires
                            // reliably once the session is actually saved and has the
                            // correct pomodoro counts. Do not send .tasks(.onAppear) here:
                            // that path is guarded by hasLoadedData and would no-op anyway.
                            //
                            // Analytics refresh and Watch stats are sent from
                            // .focus(.delegate(.sessionPersisted)) so they read committed data.
                            let isPro = state.subscriptionState.isPro
                            let dailyReminderEnabled = state.settings.dailyReminderEnabled
                            let reminderHour = state.settings.dailyReminderHour
                            let reminderMinute = state.settings.dailyReminderMinute
                            return Effect<Action>.merge(
                                .run { [isPro] send in
                                    let allStats = (try? await persistence.fetchDailyStatsRange(Date.distantPast, Date.now)) ?? []
                                    let streakResult = StreakProtectionService.computeProtectedStreak(
                                        history: allStats,
                                        isPro: isPro
                                    )
                                    if let milestone = CelebrationMilestone.checkStreak(streakResult.days) {
                                        await send(.celebrationTriggered(milestone))
                                    }
                                },
                                .run { [notificationClient] _ in
                                    if dailyReminderEnabled {
                                        await notificationClient.rescheduleDailyReminderAfterFocus(
                                            reminderHour,
                                            reminderMinute
                                        )
                                    }
                                }
                            )
                        }
                        // stopTapped: refresh analytics so the dashboard reflects the abandoned session
                        return .send(.analytics(.refresh))
                    }()
                )

            // MARK: - Watch Tasks Bridge (iOS → Watch)

            case .tasks(.undoTimerExpired),
                 .tasks(.taskScheduledForToday),
                 .tasks(.taskMoved):
                return pushTasksToWatch(state)

            // MARK: - Cross-feature: Tasks → Focus

            case .tasks(.tasksLoaded):
                state.focus.availableTasks = state.tasks.tasks
                if let pendingTaskID = state.pendingDeepLinkTaskID {
                    state.pendingDeepLinkTaskID = nil
                    if state.tasks.tasks[id: pendingTaskID] != nil {
                        return .merge(
                            pushTasksToWatch(state),
                            .send(.tasks(.taskTapped(pendingTaskID)))
                        )
                    }
                }
                if state.pendingExternalStartModeID != nil || state.pendingExternalStartTaskID != nil {
                    let requestedModeID = state.pendingExternalStartModeID
                    let requestedTaskID = state.pendingExternalStartTaskID
                    let timerStart = state.pendingExternalStartTimerStart
                    let timerEnd = state.pendingExternalStartTimerEnd
                    
                    state.pendingExternalStartModeID = nil
                    state.pendingExternalStartTaskID = nil
                    state.pendingExternalStartTimerStart = nil
                    state.pendingExternalStartTimerEnd = nil
                    
                    return .merge(
                        pushTasksToWatch(state),
                        startFromExternalRequest(&state, requestedModeID, requestedTaskID, timerStart, timerEnd, false)
                    )
                }
                return pushTasksToWatch(state)

            case .tasks(.startFocusOnTask(let taskID)):
                if let task = state.tasks.tasks[id: taskID] {
                    state.selectedTab = .focus
                    return .merge(
                        .send(.focus(.linkTask(taskID, task.title, task.energyLevel.emoji))),
                        .send(.focus(.startTapped()))
                    )
                }
                return .none

            // MARK: - Settings: paywall

            case .settings(.upgradeTapped):
                state.focus.showPaywall = true
                return .send(.paywall(.appeared))

            case .settings(.paywallDismissed):
                state.focus.showPaywall = false
                return .none

            case .analytics(.paywallRequested):
                state.focus.showPaywall = true
                return .send(.paywall(.appeared))

            // MARK: - Settings: propagate config changes to active focus session

            case .settings(.settingsSaved):
                // Build a FocusConfig from current settings state and push it to the
                // FocusFeature so any active Pomodoro/TimeBlock timer updates in real-time.
                let s = state.settings
                let updatedConfig = FocusConfig(
                    pomodoroDuration: TimeInterval(s.pomodoroDurationMinutes * 60),
                    shortBreakDuration: TimeInterval(s.shortBreakMinutes * 60),
                    longBreakDuration: TimeInterval(s.longBreakMinutes * 60),
                    pomodorosPerCycle: s.pomodorosPerCycle,
                    autoStartBreaks: s.autoStartBreaks,
                    autoStartWork: s.autoStartWork,
                    defaultBlockDuration: TimeInterval(s.blockDurationMinutes * 60),
                    blockMidpointCheckIn: s.blockMidpointCheckIn,
                    flowtimeMinSessionMinutes: s.flowtimeMinMinutes,
                    flowtimeShowBreakSuggestion: true,
                    soundEnabled: s.soundEnabled,
                    hapticEnabled: s.hapticEnabled,
                    keepScreenOn: s.keepScreenOn
                )
                return .send(.focus(.configUpdated(updatedConfig)))

            // MARK: - Settings: daily reminder sync

            case .settings(.dailyReminderToggled), .settings(.dailyReminderTimeChanged):
                let enabled = state.settings.dailyReminderEnabled
                let hour    = state.settings.dailyReminderHour
                let minute  = state.settings.dailyReminderMinute
                return .run { [notificationClient] send in
                    if enabled {
                        let status = await notificationClient.authorizationStatus()
                        switch status {
                        case .notDetermined:
                            _ = await notificationClient.requestAuthorization()
                            UserDefaults.standard.set(true, forKey: "pepinillo.hasRequestedNotificationPermission")
                            let updated = await notificationClient.authorizationStatus()
                            guard updated == .authorized || updated == .provisional || updated == .ephemeral else {
                                await send(.settings(.notificationAuthorizationDenied))
                                return
                            }
                        case .authorized, .provisional, .ephemeral:
                            break
                        default:
                            await send(.settings(.notificationAuthorizationDenied))
                            return
                        }
                        await notificationClient.scheduleDailyReminder(hour, minute)
                    } else {
                        await notificationClient.cancelDailyReminder()
                    }
                }

            // MARK: - Day Change

            case .dayChanged:
                // Forward to focus for its own day-change logic and also refresh the
                // task list so recurring tasks are regenerated for the new day.
                return .merge(
                    .send(.focus(.dayChanged)),
                    .send(.tasks(.refresh)),
                    syncWatchStats(isPro: state.subscriptionState.isPro)
                )

            // MARK: - Handoff

            case .handoffFocusReceived(let modeID, let isRunning, _):
                if let mode = FocusMode(rawValue: modeID) {
                    state.selectedTab = .focus
                    var effects: [Effect<Action>] = [.send(.focus(.modeSelected(mode)))]
                    if isRunning && !state.focus.isRunning {
                        effects.append(.send(.focus(.startTapped())))
                    }
                    return .concatenate(effects)
                }
                state.selectedTab = .focus
                return .none

            case .handoffAnalyticsReceived:
                state.selectedTab = .dashboard
                return .none

            case .tasks(.addTaskTapped),
                 .tasks(.taskCompleted),
                 .tasks(.setTaskCompleted),
                 .tasks(.taskDeleted),
                 .tasks(.undoDeleteTask),
                 .tasks(.remindersImported),
                 .tasks(.detail(.presented(.delegate(.taskDeleted)))):
                // Keep focus task list in sync after mutations
                state.focus.availableTasks = state.tasks.tasks
                return pushTasksToWatch(state)

            case .focus(.delegate(.sessionPersisted)),
                 .focus(.delegate(.taskProgressChanged)):
                // Single explicit refresh path for session events. cancelInFlight ensures
                // that when taskProgressChanged fires just before sessionPersisted (final
                // pomodoro), only one fetch runs — the second cancels the first.
                //
                // Also refresh analytics dashboard and push full Watch stats here so both
                // reads happen after saveSession has committed (FIX 1 + FIX 3).
                return .merge(
                    .run { [persistence] send in
                        let items = try await persistence.fetchTasks()
                        await send(.tasks(.tasksLoaded(items.map { TaskListFeature.TaskItemState.from($0) })))
                    }
                    .cancellable(id: CancelID.sessionTaskRefresh, cancelInFlight: true),
                    .send(.analytics(.refresh)),
                    syncWatchStats(isPro: state.subscriptionState.isPro)
                )

            case .tasks(.delegate(.showPaywall)):
                state.focus.showPaywall = true
                return .send(.paywall(.appeared))

            case .focus(.paywallTapped):
                state.focus.showPaywall = true
                return .send(.paywall(.appeared))

            case .focus, .tasks, .analytics, .settings, .paywall:
                return .none
            }
        }
        .ifLet(\.$calendar, action: \.calendar) {
            CalendarFeature()
        }
        .ifLet(\.$auth, action: \.auth) {
            AuthFeature()
        }
        .ifLet(\.$profile, action: \.profile) {
            ProfileFeature()
        }
        .ifLet(\.$emailVerification, action: \.emailVerification) {
            EmailVerificationFeature()
        }
    }

    // MARK: - Watch stats

    /// Push timer/complication stats (`sendStats`) and dashboard payload (#236).
    private func syncWatchStats(isPro: Bool) -> Effect<Action> {
        .run { [watchClient, persistence] _ in
            guard let stats = try? await persistence.fetchDailyStats(Date.now) else { return }
            let tasks = (try? await persistence.fetchTasks()) ?? []
            let todayTasks = tasks.filter { $0.scheduledForToday }
            let startOfDay = Calendar.current.startOfDay(for: Date.now)
            let sessions = (try? await persistence.fetchSessions(startOfDay, Date.now)) ?? []
            let longestMinutes = sessions.map { Int($0.actualDuration) / 60 }.max() ?? 0
            let allStats = (try? await persistence.fetchDailyStatsRange(Date.distantPast, Date.now)) ?? []
            let streakResult = StreakProtectionService.computeProtectedStreak(
                history: allStats,
                isPro: isPro
            )
            await watchClient.sendStats(
                stats.totalFocusMinutes,
                stats.sessionsCompleted,
                streakResult.days
            )
            let dashStats = WatchDashboardStats(
                todayMinutes: stats.totalFocusMinutes,
                sessionsCompleted: stats.sessionsCompleted,
                tasksCompleted: todayTasks.filter(\.isCompleted).count,
                tasksTotal: todayTasks.count,
                streakDays: streakResult.days,
                pomodoroMinutes: stats.pomodoroMinutes,
                flowtimeMinutes: stats.flowtimeMinutes,
                timeBlockMinutes: stats.timeBlockMinutes,
                stopwatchMinutes: stats.stopwatchMinutes,
                longestSessionMinutes: longestMinutes
            )
            await watchClient.sendDashboardStats(dashStats)
        }
    }

    // MARK: - Subscription helpers

    /// Shared handler for `subscriptionStateLoaded` and `subscriptionUpdated`
    /// (issue #78). Both actions previously carried the same propagate+sync
    /// logic copy-pasted; when they arrived in quick succession (the common
    /// case at launch), the full reconcile/sync pipeline ran twice on the
    /// foreground critical path.
    ///
    /// Propagation of Pro flags always runs. The soft sync only runs when the
    /// capabilities actually changed since the last sync (`lastSyncedCapabilities`).
    private func applySubscriptionUpdate(_ sub: SubscriptionState, state: inout State) -> Effect<Action> {
        #if DEBUG
        let effectiveSub = DemoDataSeeder.shouldSimulatePro ? .pepinilloPlus : sub
        #else
        let effectiveSub = sub
        #endif
        let wasPro = state.subscriptionState.isPro
        state.subscriptionState = effectiveSub
        let isPro = effectiveSub.isPro
        let canSync = effectiveSub.isEverywhere
        state.focus.isProUser = isPro
        state.settings.isProUser = isPro
        state.analytics.isProUser = isPro
        state.tasks.isProUser = isPro
        AppGroupDefaults.userCapabilities = effectiveSub.capabilities
        AppGroupDefaults.isProUser = isPro
        AppGroupDefaults.canBackendSync = canSync
        AppGroupDefaults.canAppleCloudSync = effectiveSub.capabilities.appleCloudSync && !effectiveSub.capabilities.backendSync
        if isPro { state.focus.showPaywall = false }

        if wasPro && !isPro && !state.focus.selectedMode.isFreeTier {
            state.focus.selectedMode = .pomodoro
            state.focus.modeIcon = FocusMode.pomodoro.icon
            AppGroupDefaults.widgetSelectedMode = FocusMode.pomodoro.rawValue
        }

        let persistProFlag = Effect<Action>.run { [persistence] _ in
            var prefs = try await persistence.fetchPreferences()
            prefs.isProUser = isPro
            try await persistence.savePreferences(prefs)
        }

        // Dedupe: skip the expensive soft sync when capabilities are unchanged
        // since the last run. Both subscription actions commonly arrive together
        // at launch with the same capabilities.
        let capabilities = effectiveSub.capabilities
        guard state.lastSyncedCapabilities != capabilities else {
            appLaunchLogger.info("Soft sync skipped — capabilities unchanged (issue #78 dedupe)")
            return persistProFlag
        }
        state.lastSyncedCapabilities = capabilities

        return .merge(
            persistProFlag,
            .run { send in
                try? await Task.sleep(for: .seconds(3))
                let start = Date.now
                await syncModeClient.reconcile(capabilities)
                if capabilities.backendSync, await keychain.hasTokens() {
                    try? await syncClient.syncAll()
                    await webSocketClient.connect()
                } else {
                    webSocketClient.disconnect()
                }
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                appLaunchLogger.info("Soft sync finished in \(Date.now.timeIntervalSince(start), privacy: .public)s")
                // Reconcile may swap the active store (local → CloudKit); refresh the task
                // list so in-memory state reflects the now-active container.
                await send(.tasks(.refresh))
            }
            .cancellable(id: CancelID.softSync, cancelInFlight: true)
        )
    }

    // MARK: - RevenueCat identity (#197)

    /// Links RevenueCat to the backend user id after any successful auth path.
    private func linkSubscriptionIdentity(_ userID: String) -> Effect<Action> {
        .run { [subscriptionClient] _ in
            await subscriptionClient.logIn(userID)
        }
    }

    // MARK: - Session cleanup (shared sign-out path)

    /// Single source of truth for tearing down a signed-in session.
    ///
    /// Previously this cleanup logic was copy-pasted across five entry points
    /// (`signOutTapped`, `deleteAccountTapped`, `tokenRefreshFailed`,
    /// `appleCredentialStateChecked` unauthorized, and `profile(.signedOut)`)
    /// with materially different behavior — several paths leaked tokens, cached
    /// user, RevenueCat identity, or AI report cache, and `tokenRefreshFailed`
    /// was dead code that was never even dispatched (#194, #195).
    ///
    /// - Parameters:
    ///   - wipeLocalUserData: When `true` (account deletion), also deletes all
    ///     local tasks/sessions/stats so the next user starts clean (#193).
    ///   - notifyBackendLogout: When `true` (explicit sign-out), revokes the
    ///     refresh token on the backend. Skipped for expiry/revoke paths where
    ///     the backend session is already invalid.
    ///   - dismissProfile: When `true`, dismisses the profile sheet if present.
    private func performSignOutCleanup(
        _ state: inout State,
        wipeLocalUserData: Bool = false,
        notifyBackendLogout: Bool = false,
        dismissProfile: Bool = false
    ) -> Effect<Action> {
        // Clear in-memory auth state synchronously so the UI flips immediately.
        state.cachedUser = nil
        state.appleUserID = nil
        state.displayName = nil
        state.userEmail = nil
        if dismissProfile { state.profile = nil }
        webSocketClient.disconnect()
        return .run { [keychain, apiClient, persistence, subscriptionClient] _ in
            if notifyBackendLogout, let refreshToken = await keychain.loadRefreshToken() {
                try? await apiClient.logout(LogoutRequest(refreshToken: refreshToken))
            }
            try? await keychain.deleteTokens()
            try? await persistence.deleteCachedUser()
            var prefs = try await persistence.fetchPreferences()
            prefs.appleUserID = nil
            prefs.displayName = nil
            prefs.userEmail = nil
            prefs.appleAuthorizationCode = nil
            try await persistence.savePreferences(prefs)
            if wipeLocalUserData {
                // Full PII wipe for account deletion — orphaned local data must not
                // survive the user who created it (App Store 5.1.1(v)).
                try? await persistence.deleteAllTasks()
                try? await persistence.deleteAllSessions()
                try? await persistence.deleteAllStats()
            }
            AIReportFeature.clearAllCachedReports()
            await subscriptionClient.logOut()
        }
    }
}

// MARK: - WatchSessionState factory from FocusFeature.State

extension WatchSessionState {
    init(from focusState: FocusFeature.State, isPhaseTransition: Bool = false) {
        let activeMode = focusState.activeMode ?? focusState.selectedMode

        // During a waiting hold, derive the break/long-break flags from the PENDING
        // next phase so the watch CTA label ("Start break" / "Start long break" /
        // "Start focus") reflects what's about to start, not the phase just completed.
        let phaseForFlags: FocusPhase = focusState.isWaitingForNextPhase
            ? (focusState.pendingNextPhase ?? focusState.phase)
            : focusState.phase
        let isBreak: Bool
        let isLongBreak: Bool
        switch phaseForFlags {
        case .shortBreak, .flowBreak:            isBreak = true;  isLongBreak = false
        case .longBreak:                         isBreak = true;  isLongBreak = true
        case .work, .flow, .block, .freeform,
             .idle, .paused:                     isBreak = false; isLongBreak = false
        }
        self.init(
            isActive:         focusState.isRunning,
            isPaused:         focusState.isPaused,
            modeID:           activeMode.rawValue,
            displayTime:      focusState.displayTime,
            phaseLabel:       focusState.phaseLabel,
            progress:         focusState.progress,
            pomodoroNumber:   focusState.pomodoroNumber,
            linkedTaskTitle:  focusState.linkedTaskTitle,
            linkedTaskID:     focusState.linkedTaskID?.uuidString,
            isPhaseTransition: isPhaseTransition,
            isBreakPhase:     isBreak,
            isLongBreakPhase: isLongBreak,
            isWaiting:        focusState.isWaitingForNextPhase,
            phaseStartDate:   AppGroupDefaults.activeSessionTimerStart,
            phaseEndDate:     AppGroupDefaults.activeSessionTimerEnd,
            countsDown:       activeMode.direction == .countDown
        )
    }
}

// MARK: - Deep links

extension AppFeature {
    fileprivate static func taskID(from url: URL) -> UUID? {
        let candidate = url.lastPathComponent
        guard !candidate.isEmpty, candidate != "/" else { return nil }
        return UUID(uuidString: candidate)
    }
}

// MARK: - Watch session snapshot push

extension AppFeature {
    /// Push the current focus snapshot to the watch. Use `publishContext: true` on
    /// transitions, launch, and connect so cold-start hydration stays accurate (#239).
    fileprivate func pushWatchSessionSnapshot(
        from state: State,
        publishContext: Bool
    ) -> Effect<Action> {
        .run { [watchClient] _ in
            guard watchClient.isSupported() else { return }
            let watchState = WatchSessionState(from: state.focus)
            await watchClient.sendSessionState(watchState, publishContext)
        }
    }
}

// MARK: - Milestone Detection

extension CelebrationMilestone {
    static func checkStreak(_ streak: Int) -> CelebrationMilestone? {
        guard [3, 7, 14, 30, 60, 100].contains(streak) else { return nil }
        return .streakDay(streak)
    }
}
