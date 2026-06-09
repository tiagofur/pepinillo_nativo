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
        var hasCompletedOnboarding: Bool = false

        // Subscription
        var subscriptionState: SubscriptionState = .free

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
        var pendingExternalStartModeID: String?
        var pendingExternalStartTaskID: String?
        var pendingExternalStartTimerStart: Date?
        var pendingExternalStartTimerEnd: Date?
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
                emailVerified: cachedUser?.emailVerified ?? (restoredEmail != nil),
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
            case .dashboard: return "chart.bar"
            case .account:   return "ellipsis"
            }
        }
    }

    enum Action: Equatable {
        case tabSelected(Tab)
        case focus(FocusFeature.Action)
        case tasks(TaskListFeature.Action)
        case analytics(AnalyticsFeature.Action)
        case settings(SettingsFeature.Action)
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

        // Sign in with Apple
        case signInWithAppleSucceeded(AppleUserInfo)
        case signInWithAppleFailed
        case signOutTapped
        case deleteAccountTapped
        case appleCredentialStateChecked(String, Bool)

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

    private enum CancelID {
        case transactionListener
        case watchCommandListener
        case notificationActionListener
        case externalCommandObserver
        case webSocket
        case softSync
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
                        return .send(.focus(.modeSelected(mode)))
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
                        guard !revenueCatKey.isEmpty, !revenueCatKey.contains("$(REVENUECAT_API_KEY)") else {
                            appLaunchLogger.warning("RevenueCat API key not configured — skipping configure()")
                            return
                        }
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
                    // Notification permission
                    .run { send in
                        try? await Task.sleep(for: .seconds(2))
                        await send(.requestNotificationPermission)
                    },
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
                    .send(.consumeExternalCommands)
                )

            case .requestNotificationPermission:
                return .run { _ in
                    _ = await notificationClient.requestAuthorization()
                }

            case .appBecameActive:
                return .send(.consumeExternalCommands)

            case .appURLReceived(let url):
                guard url.scheme == "pepinillo" else { return .none }
                switch url.host?.lowercased() {
                case "plan", "tasks":
                    state.selectedTab = .plan
                case "focus":
                    state.selectedTab = .focus
                case "dashboard", "analytics":
                    state.selectedTab = .dashboard
                default:
                    break
                }
                return .none

            case .consumeExternalCommands:
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
                    return state.focus.isRunning ? .send(.focus(.stopTapped)) : .none
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
                #if DEBUG
                let effectiveSub = DemoDataSeeder.shouldSimulatePro ? .pepinilloPlus : sub
                #else
                let effectiveSub = sub
                #endif
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
                return .run { [syncModeClient, keychain, syncClient, webSocketClient, capabilities = effectiveSub.capabilities] send in
                    try? await Task.sleep(for: .seconds(3))
                    let start = Date.now
                    await syncModeClient.reconcile(capabilities)
                    if capabilities.backendSync, await keychain.hasTokens() {
                        try? await syncClient.syncAll()
                        await webSocketClient.connect()
                    } else {
                        webSocketClient.disconnect()
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                    appLaunchLogger.info("Soft sync finished in \(Date.now.timeIntervalSince(start), privacy: .public)s")
                    // Reconcile may swap the active store (local → CloudKit); refresh the task
                    // list so in-memory state reflects the now-active container.
                    await send(.tasks(.refresh))
                }
                .cancellable(id: CancelID.softSync, cancelInFlight: true)

            case .subscriptionUpdated(let sub):
                #if DEBUG
                let effectiveSub = DemoDataSeeder.shouldSimulatePro ? .pepinilloPlus : sub
                #else
                let effectiveSub = sub
                #endif
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
                return .run { [syncModeClient, keychain, syncClient, webSocketClient, capabilities = effectiveSub.capabilities] send in
                    try? await Task.sleep(for: .seconds(3))
                    let start = Date.now
                    await syncModeClient.reconcile(capabilities)
                    if capabilities.backendSync, await keychain.hasTokens() {
                        try? await syncClient.syncAll()
                        await webSocketClient.connect()
                    } else {
                        webSocketClient.disconnect()
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                    appLaunchLogger.info("Soft sync update finished in \(Date.now.timeIntervalSince(start), privacy: .public)s")
                    // Reconcile may swap the active store (local → CloudKit); refresh the task
                    // list so in-memory state reflects the now-active container.
                    await send(.tasks(.refresh))
                }
                .cancellable(id: CancelID.softSync, cancelInFlight: true)

            case .celebrationTriggered(let milestone):
                state.pendingCelebration = milestone
                return .none

            case .celebrationDismissed:
                state.pendingCelebration = nil
                return .none

            // MARK: - Upgrade (from Account tab)

            case .upgradeTapped:
                state.focus.showPaywall = true
                return .none

            // MARK: - Calendar & Weekly Review

            case .calendarTapped:
                state.calendar = CalendarFeature.State()
                return .none

            case .weeklyReviewTapped:
                if state.subscriptionState.isPro {
                    state.analytics.weeklyReview = WeeklyReviewFeature.State()
                } else {
                    state.focus.showPaywall = true
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
                return .run { [syncClient, webSocketClient, canBackendSync = state.subscriptionState.capabilities.backendSync] _ in
                    if canBackendSync {
                        try? await syncClient.syncAll()
                        await webSocketClient.connect()
                    }
                }

            case .emailVerification:
                return .none

            case .auth(.presented(.delegate(.guestModeSelected))):
                state.auth = nil  // dismiss auth sheet
                return .none

            case .auth:
                return .none

            case .profile(.presented(.delegate(.signedOut))):
                state.cachedUser = nil
                state.appleUserID = nil
                state.displayName = nil
                state.userEmail = nil
                state.profile = nil  // dismiss profile sheet
                webSocketClient.disconnect()
                return .run { send in
                    var prefs = try await persistence.fetchPreferences()
                    prefs.appleUserID = nil
                    prefs.displayName = nil
                    prefs.userEmail = nil
                    try await persistence.savePreferences(prefs)
                }

            case .profile:
                return .none

            case .tokenRefreshFailed:
                state.cachedUser = nil
                state.appleUserID = nil
                state.displayName = nil
                state.userEmail = nil
                webSocketClient.disconnect()
                return .none

            // MARK: - Sign in with Apple

            case .appleCredentialStateChecked(let userID, let authorized):
                if authorized {
                    // Restore state from preferences (already loaded on launch)
                    return .run { send in
                        let prefs = try await persistence.fetchPreferences()
                        if prefs.appleUserID == userID {
                            await send(.signInWithAppleSucceeded(AppleUserInfo(
                                userID: userID,
                                displayName: prefs.displayName,
                                email: prefs.userEmail
                            )))
                        }
                    }
                } else {
                    // Credential revoked — clear local state
                    state.appleUserID = nil
                    state.displayName = nil
                    state.userEmail = nil
                    return .run { send in
                        var prefs = try await persistence.fetchPreferences()
                        prefs.appleUserID = nil
                        prefs.displayName = nil
                        prefs.userEmail = nil
                        try await persistence.savePreferences(prefs)
                    }
                }

            case .signInWithAppleSucceeded(let info):
                state.auth = nil  // dismiss auth sheet if open
                state.appleUserID = info.userID
                // Apple only provides displayName on the very first sign-in ever.
                // Fall back to cached user name, then existing displayName, then email prefix.
                let resolvedName = info.displayName
                    ?? state.cachedUser?.name
                    ?? state.displayName
                    ?? info.email?.components(separatedBy: "@").first
                state.displayName = resolvedName
                state.userEmail = info.email ?? state.userEmail
                let fallbackUser = state.profileSummaryUser
                return .merge(
                    .run { [info, fallbackUser] send in
                        var prefs = try await persistence.fetchPreferences()
                        prefs.appleUserID = info.userID
                        if let name = info.displayName { prefs.displayName = name }
                        if let email = info.email { prefs.userEmail = email }
                        try await persistence.savePreferences(prefs)
                        // Identify user in RevenueCat
                        await subscriptionClient.logIn(info.userID)
                        if let fallbackUser {
                            try? await persistence.saveCachedUser(fallbackUser)
                            await send(.cachedUserLoaded(fallbackUser))
                        }
                    },
                    // Try to authenticate with backend if identity token available
                    {
                        if let idToken = info.identityToken {
                            return .run { [apiClient, keychain, persistence, syncClient, webSocketClient, canBackendSync = state.subscriptionState.capabilities.backendSync] send in
                                do {
                                    guard let nonce = info.nonce, !nonce.isEmpty else {
                                        return
                                    }
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
                                    // VPS sync is Everywhere/AI+ only.
                                    if canBackendSync {
                                        try? await syncClient.syncAll()
                                        await webSocketClient.connect()
                                    }
                                } catch {
                                    // Backend auth failed — synthetic CachedUserDTO already saved above
                                }
                            }
                        }
                        return .none
                    }()
                )

            case .signInWithAppleFailed:
                return .none

            case .signOutTapped:
                state.appleUserID = nil
                state.displayName = nil
                state.userEmail = nil
                state.cachedUser = nil
                webSocketClient.disconnect()
                return .run { [keychain, apiClient, persistence] send in
                    if let refreshToken = await keychain.loadRefreshToken() {
                        try? await apiClient.logout(LogoutRequest(refreshToken: refreshToken))
                    }
                    try? await keychain.deleteTokens()
                    try? await persistence.deleteCachedUser()
                    var prefs = try await persistence.fetchPreferences()
                    prefs.appleUserID = nil
                    prefs.displayName = nil
                    prefs.userEmail = nil
                    try await persistence.savePreferences(prefs)
                    // Reset to anonymous in RevenueCat
                    await subscriptionClient.logOut()
                }

            case .deleteAccountTapped:
                state.appleUserID = nil
                state.displayName = nil
                state.userEmail = nil
                state.cachedUser = nil
                webSocketClient.disconnect()
                return .run { [keychain, apiClient, persistence] send in
                    // Call backend to delete data
                    try? await apiClient.deleteAccount()
                    
                    // Cleanup local state
                    try? await keychain.deleteTokens()
                    try? await persistence.deleteCachedUser()
                    var prefs = try await persistence.fetchPreferences()
                    prefs.appleUserID = nil
                    prefs.displayName = nil
                    prefs.userEmail = nil
                    try await persistence.savePreferences(prefs)
                    
                    // Reset to anonymous in RevenueCat
                    await subscriptionClient.logOut()
                }

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
                    let mode = FocusMode(rawValue: modeID) ?? state.focus.selectedMode
                    return .concatenate(
                        .send(.focus(.modeSelected(mode))),
                        .send(.focus(.startTapped()))
                    )
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
                case .toggleTaskCompleted(let idStr):
                    guard let id = UUID(uuidString: idStr) else { return .none }
                    return .send(.tasks(.taskCompleted(id)))
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
                case .requestDashboard:
                    return .run { [watchClient, persistence] _ in
                        let stats = try? await persistence.fetchDailyStats(Date.now)
                        let prefs = try? await persistence.fetchPreferences()
                        let tasks = try? await persistence.fetchTasks()
                        let todayTasks = tasks?.filter { $0.scheduledForToday } ?? []

                        // Longest session today
                        let startOfDay = Calendar.current.startOfDay(for: Date.now)
                        let sessions = try? await persistence.fetchSessions(startOfDay, Date.now)
                        let longestMinutes = (sessions ?? [])
                            .map { Int($0.actualDuration) / 60 }
                            .max() ?? 0

                        let dashStats = WatchDashboardStats(
                            todayMinutes: stats?.totalFocusMinutes ?? 0,
                            sessionsCompleted: stats?.sessionsCompleted ?? 0,
                            tasksCompleted: todayTasks.filter(\.isCompleted).count,
                            tasksTotal: todayTasks.count,
                            streakDays: prefs?.currentStreakDays ?? 0,
                            pomodoroMinutes: stats?.pomodoroMinutes ?? 0,
                            flowtimeMinutes: stats?.flowtimeMinutes ?? 0,
                            timeBlockMinutes: stats?.timeBlockMinutes ?? 0,
                            stopwatchMinutes: stats?.stopwatchMinutes ?? 0,
                            longestSessionMinutes: longestMinutes
                        )
                        await watchClient.sendDashboardStats(dashStats)
                    }
                }

            // MARK: - Watch State Bridge (iOS → Watch)

            case .focus(.timerTicked):
                let watchState = WatchSessionState(from: state.focus)
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState)
                }

            case .focus(.phaseCompleted):
                var watchState = WatchSessionState(from: state.focus)
                watchState.isPhaseTransition = true
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState)
                }

            case .focus(.pauseTapped), .focus(.resumeTapped),
                 .focus(.externalPauseApplied), .focus(.externalResumeApplied):
                let watchState = WatchSessionState(from: state.focus)
                return .run { [watchClient, watchState] _ in
                    await watchClient.sendSessionState(watchState)
                }

            case .focus(.stopTapped), .focus(.sessionCompleted):
                let watchState = WatchSessionState(from: state.focus)
                return .merge(
                    .run { [watchClient, watchState] _ in
                        await watchClient.sendSessionState(watchState)
                    },
                    .run { [watchClient] _ in
                        if let stats = try? await persistence.fetchDailyStats(Date.now),
                           let prefs = try? await persistence.fetchPreferences() {
                            await watchClient.sendStats(
                                stats.totalFocusMinutes,
                                stats.sessionsCompleted,
                                prefs.currentStreakDays
                            )
                        }
                    },
                    {
                        if case .focus(.sessionCompleted) = action {
                            // Task refresh after session completion is handled by the
                            // .focus(.delegate(.sessionPersisted)) path below — which fires
                            // reliably once the session is actually saved and has the
                            // correct pomodoro counts. Do not send .tasks(.onAppear) here:
                            // that path is guarded by hasLoadedData and would no-op anyway.
                            return .merge(
                                .send(.analytics(.onAppear)),
                                Effect<Action>.run { send in
                                    if let prefs = try? await persistence.fetchPreferences(),
                                       let milestone = CelebrationMilestone.checkStreak(prefs.currentStreakDays) {
                                        await send(.celebrationTriggered(milestone))
                                    }
                                }
                            )
                        }
                        return .none
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
                return .none

            case .settings(.paywallDismissed):
                state.focus.showPaywall = false
                return .none

            case .analytics(.paywallRequested):
                state.focus.showPaywall = true
                return .none

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
                return .run { [notificationClient] _ in
                    if enabled {
                        await notificationClient.scheduleDailyReminder(hour, minute)
                    } else {
                        await notificationClient.cancelAll()
                    }
                }

            // MARK: - Day Change

            case .dayChanged:
                // Forward to focus for its own day-change logic and also refresh the
                // task list so recurring tasks are regenerated for the new day.
                return .merge(
                    .send(.focus(.dayChanged)),
                    .send(.tasks(.refresh))
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
                return .run { [persistence] send in
                    let items = try await persistence.fetchTasks()
                    await send(.tasks(.tasksLoaded(items.map { TaskListFeature.TaskItemState.from($0) })))
                }
                .cancellable(id: CancelID.sessionTaskRefresh, cancelInFlight: true)

            case .tasks(.delegate(.showPaywall)):
                state.focus.showPaywall = true
                return .none

            case .focus, .tasks, .analytics, .settings:
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
}

// MARK: - WatchSessionState factory from FocusFeature.State

extension WatchSessionState {
    init(from focusState: FocusFeature.State, isPhaseTransition: Bool = false) {
        let activeMode = focusState.activeMode ?? focusState.selectedMode
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
            isPhaseTransition: isPhaseTransition
        )
    }
}

// MARK: - Milestone Detection

extension CelebrationMilestone {
    static func checkStreak(_ streak: Int) -> CelebrationMilestone? {
        guard [3, 7, 14, 30, 60, 100].contains(streak) else { return nil }
        return .streakDay(streak)
    }
}
