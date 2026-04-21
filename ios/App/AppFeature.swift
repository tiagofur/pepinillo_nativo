// AppFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// Root TCA feature that composes all child features.
// Manages tab selection, subscription state, celebrations, Watch bridge,
// drawer navigation, and Sign in with Apple state.

import Foundation
import ComposableArchitecture
import WidgetKit

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

        // Drawer
        var isDrawerOpen: Bool = false
        var isSettingsPresented: Bool = false
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
    }

    enum Tab: String, Equatable, CaseIterable {
        case focus
        case tasks
        case analytics

        var title: String {
            switch self {
            case .focus:     return String(localized: "Focus")
            case .tasks:     return String(localized: "Tasks")
            case .analytics: return String(localized: "Analytics")
            }
        }

        var systemImage: String {
            switch self {
            case .focus:     return "brain.head.profile"
            case .tasks:     return "checklist"
            case .analytics: return "chart.bar"
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

        // Drawer
        case drawerOpened
        case drawerClosed
        case settingsDrawerTapped
        case settingsSheetDismissed
        case weeklyReviewDrawerTapped
        case upgradeDrawerTapped
        case calendarDrawerTapped
        case calendarSheetDismissed
        case calendar(PresentationAction<CalendarFeature.Action>)

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
        case appleCredentialStateChecked(String, Bool)

        // Day change
        case dayChanged

        // Handoff
        case handoffFocusReceived(modeID: String, isRunning: Bool, taskTitle: String?)
        case handoffAnalyticsReceived
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.subscriptionClient) var subscriptionClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.watchConnectivityClient) var watchClient
    @Dependency(\.signInWithAppleClient) var appleClient
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.syncClient) var syncClient
    @Dependency(\.webSocketClient) var webSocketClient

    private enum CancelID {
        case transactionListener
        case watchCommandListener
        case notificationActionListener
        case externalCommandObserver
        case webSocket
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
            switch action {

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .onboardingCompleted:
                state.hasCompletedOnboarding = true
                return .run { send in
                    var prefs = try await persistence.fetchPreferences()
                    prefs.hasCompletedOnboarding = true
                    try await persistence.savePreferences(prefs)
                }

            case .onboardingCompletedWithMode(let mode):
                state.hasCompletedOnboarding = true
                state.settings.defaultMode = mode
                state.focus.selectedMode = mode
                return .run { [mode] send in
                    var prefs = try await persistence.fetchPreferences()
                    prefs.hasCompletedOnboarding = true
                    prefs.defaultMode = mode.rawValue
                    try await persistence.savePreferences(prefs)
                }

            case .appLaunched:
                return .merge(
                    // Configure RevenueCat early
                    .run { send in
                        let prefs = try await persistence.fetchPreferences()
                        // Use Apple User ID if available, otherwise nil for anonymous
                        let userID = prefs.appleUserID
                        await subscriptionClient.configure("appl_xnChlVXXtUFhusIfJyNrNDcMGLj", userID)
                    },
                    // Onboarding check + Apple credential state check
                    .run { [appleClient] send in
                        let prefs = try await persistence.fetchPreferences()
                        if prefs.hasCompletedOnboarding {
                            await send(.onboardingCompleted)
                        }
                        if let userID = prefs.appleUserID {
                            let authorized = await appleClient.checkCredentialState(userID)
                            await send(.appleCredentialStateChecked(userID, authorized))
                        }
                    },
                    // Subscription entitlement
                    .run { send in
                        let sub = await subscriptionClient.checkEntitlement()
                        await send(.subscriptionStateLoaded(sub))
                    },
                    // RevenueCat customer info stream
                    .run { send in
                        let stream = subscriptionClient.listenForTransactionUpdates()
                        for await sub in stream {
                            await send(.subscriptionUpdated(sub))
                        }
                    }
                    .cancellable(id: CancelID.transactionListener),
                    // Notification permission
                    .send(.requestNotificationPermission),
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
                    // If tokens exist, try to refresh user profile from network and sync tasks
                    .run { [keychain, apiClient, persistence, syncClient] send in
                        guard await keychain.hasTokens() else { return }
                        do {
                            let apiUser = try await apiClient.getMe()
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
                            // Network error — use cached data silently
                        }
                        // Sync tasks after profile refresh if Pro
                        if state.subscriptionState.isPro {
                            try? await syncClient.syncAll()
                        }
                    },
                    // Connect WebSocket if authenticated
                    .run { [keychain, webSocketClient] _ in
                        guard await keychain.hasTokens() else { return }
                        await webSocketClient.connect()
                    }
                    .cancellable(id: CancelID.webSocket),
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
                    .cancellable(id: CancelID.watchCommandListener)
                )

            case .requestNotificationPermission:
                return .run { _ in
                    _ = await notificationClient.requestAuthorization()
                }

            case .appBecameActive:
                // Check for external commands from Siri, widgets, or Control Center
                if AppGroupDefaults.externalStartRequested && !state.focus.isRunning {
                    if let modeID = AppGroupDefaults.requestedMode,
                       let mode = FocusMode(rawValue: modeID) {
                        AppGroupDefaults.clearExternalCommands()
                        return .merge(
                            .send(.focus(.modeSelected(mode))),
                            .send(.focus(.startTapped))
                        )
                    }
                    AppGroupDefaults.clearExternalCommands()
                    return .send(.focus(.startTapped))
                }
                if AppGroupDefaults.externalStopRequested && state.focus.isRunning {
                    AppGroupDefaults.clearExternalCommands()
                    return .send(.focus(.stopTapped))
                }
                if AppGroupDefaults.externalResumeRequested && state.focus.isRunning && state.focus.isPaused {
                    AppGroupDefaults.clearExternalCommands()
                    return .send(.focus(.resumeTapped))
                }
                if AppGroupDefaults.externalPauseRequested && state.focus.isRunning {
                    AppGroupDefaults.clearExternalCommands()
                    if state.focus.isPaused {
                        return .send(.focus(.resumeTapped))
                    } else {
                        return .send(.focus(.pauseTapped))
                    }
                }
                AppGroupDefaults.clearExternalCommands()
                // Reconnect WebSocket if authenticated
                return .run { [keychain, webSocketClient] _ in
                    guard await keychain.hasTokens() else { return }
                    await webSocketClient.connect()
                }
                .cancellable(id: CancelID.webSocket)

            case .appWentToBackground:
                webSocketClient.disconnect()
                return .none

            case .subscriptionStateLoaded(let sub):
                state.subscriptionState = sub
                state.focus.isProUser = sub.isPro
                state.settings.isProUser = sub.isPro
                state.analytics.isProUser = sub.isPro
                state.tasks.isProUser = sub.isPro
                AppGroupDefaults.isProUser = sub.isPro
                return .run { _ in
                    WidgetCenter.shared.reloadAllTimelines()
                }

            case .subscriptionUpdated(let sub):
                state.subscriptionState = sub
                state.focus.isProUser = sub.isPro
                state.settings.isProUser = sub.isPro
                state.analytics.isProUser = sub.isPro
                state.tasks.isProUser = sub.isPro
                AppGroupDefaults.isProUser = sub.isPro
                if sub.isPro { state.focus.showPaywall = false }
                return .run { _ in
                    WidgetCenter.shared.reloadAllTimelines()
                }

            case .celebrationTriggered(let milestone):
                state.pendingCelebration = milestone
                return .none

            case .celebrationDismissed:
                state.pendingCelebration = nil
                return .none

            // MARK: - Drawer

            case .drawerOpened:
                state.isDrawerOpen = true
                return .none

            case .drawerClosed:
                state.isDrawerOpen = false
                return .none

            case .settingsDrawerTapped:
                state.isDrawerOpen = false
                state.isSettingsPresented = true
                return .none

            case .settingsSheetDismissed:
                state.isSettingsPresented = false
                return .none

            case .weeklyReviewDrawerTapped:
                state.isDrawerOpen = false
                if state.subscriptionState.isPro {
                    state.analytics.weeklyReview = WeeklyReviewFeature.State()
                } else {
                    state.focus.showPaywall = true
                }
                return .none

            case .upgradeDrawerTapped:
                state.isDrawerOpen = false
                state.focus.showPaywall = true
                return .none

            case .calendarDrawerTapped:
                state.isDrawerOpen = false
                state.calendar = CalendarFeature.State()
                return .none

            case .calendarSheetDismissed:
                state.calendar = nil
                return .none

            case .calendar:
                return .none

            // MARK: - Auth & Profile

            case .showAuth:
                state.auth = AuthFeature.State()
                state.isDrawerOpen = false
                return .none

            case .showProfile:
                state.profile = ProfileFeature.State()
                state.isDrawerOpen = false
                return .none

            case .cachedUserLoaded(let user):
                state.cachedUser = user
                if let user {
                    state.displayName = user.name
                    state.userEmail = user.email
                }
                return .none

            case .auth(.presented(.delegate(.authenticated(let user)))):
                state.cachedUser = user
                state.displayName = user.name
                state.userEmail = user.email
                state.auth = nil  // dismiss auth sheet
                // Sync tasks and connect WebSocket after successful email login if Pro
                return .run { [syncClient, webSocketClient, isPro = state.subscriptionState.isPro] _ in
                    if isPro {
                        try? await syncClient.syncAll()
                    }
                    await webSocketClient.connect()
                }

            case .auth(.presented(.delegate(.emailVerificationRequired(let email)))):
                state.auth = nil  // dismiss auth sheet
                state.emailVerification = EmailVerificationFeature.State(email: email)
                return .none

            case .emailVerification(.presented(.delegate(.verificationSucceeded(let user)))):
                state.cachedUser = user
                state.displayName = user.name
                state.userEmail = user.email
                state.emailVerification = nil  // dismiss verification sheet
                return .run { [syncClient, webSocketClient, isPro = state.subscriptionState.isPro] _ in
                    if isPro {
                        try? await syncClient.syncAll()
                    }
                    await webSocketClient.connect()
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
                state.isDrawerOpen = false
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
                return .merge(
                    .run { [info, resolvedName] send in
                        var prefs = try await persistence.fetchPreferences()
                        prefs.appleUserID = info.userID
                        if let name = info.displayName { prefs.displayName = name }
                        if let email = info.email { prefs.userEmail = email }
                        try await persistence.savePreferences(prefs)
                        // Identify user in RevenueCat
                        await subscriptionClient.logIn(info.userID)
                        // Always synthesize and persist a CachedUserDTO from Apple identity
                        // so ProfileFeature and drawer can display user info without a backend call.
                        // The backend call below will overwrite this with full server data if successful.
                        if try await (persistence.fetchCachedUser()) == nil {
                            let now = ISO8601DateFormatter().string(from: .now)
                            let dto = CachedUserDTO(
                                id: info.userID,
                                email: info.email ?? "",
                                name: resolvedName ?? "Apple User",
                                imageUrl: nil,
                                birthDate: nil,
                                subscriptionTier: "free",
                                subscriptionExpiresAt: nil,
                                emailVerified: false,
                                appleId: info.userID,
                                createdAt: now,
                                updatedAt: now
                            )
                            try? await persistence.saveCachedUser(dto)
                            await send(.cachedUserLoaded(dto))
                        }
                    },
                    // Try to authenticate with backend if identity token available
                    {
                        if let idToken = info.identityToken {
                            return .run { [apiClient, keychain, persistence, syncClient, webSocketClient] send in
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
                                    // Sync tasks and connect WebSocket after successful Apple Sign-In if Pro
                                    if state.subscriptionState.isPro {
                                        try? await syncClient.syncAll()
                                    }
                                    await webSocketClient.connect()
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
                state.isDrawerOpen = false
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

            // MARK: - Notification Action Bridge

            case .notificationActionReceived(let notifAction):
                switch notifAction {
                case .startBreak:
                    let breakMinutes = max(1, Int(state.focus.config.shortBreakDuration / 60))
                    return .run { [notificationClient] _ in
                        await notificationClient.scheduleBreakEnd(breakMinutes)
                    }
                case .startSession:
                    return .send(.focus(.startTapped))
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
                    return .merge(
                        .send(.focus(.modeSelected(mode))),
                        .send(.focus(.startTapped))
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
                    let title = state.tasks.tasks.first(where: { $0.id == id })?.title
                    return .send(.focus(.linkTask(id, title)))
                case .unlinkTask:
                    return .send(.focus(.linkTask(nil, nil)))
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

            case .focus(.pauseTapped), .focus(.resumeTapped):
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
                            return .merge(
                                .send(.tasks(.onAppear)),
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

            // MARK: - Cross-feature: Tasks → Focus

            case .tasks(.tasksLoaded):
                state.focus.availableTasks = state.tasks.tasks
                return .none

            case .tasks(.startFocusOnTask(let taskID)):
                if let task = state.tasks.tasks[id: taskID] {
                    state.selectedTab = .focus
                    return .send(.focus(.linkTask(taskID, task.title)))
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
                return .send(.focus(.dayChanged))

            // MARK: - Handoff

            case .handoffFocusReceived(let modeID, let isRunning, _):
                if let mode = FocusMode(rawValue: modeID) {
                    state.selectedTab = .focus
                    var effects: [Effect<Action>] = [.send(.focus(.modeSelected(mode)))]
                    if isRunning && !state.focus.isRunning {
                        effects.append(.send(.focus(.startTapped)))
                    }
                    return .merge(effects)
                }
                state.selectedTab = .focus
                return .none

            case .handoffAnalyticsReceived:
                state.selectedTab = .analytics
                return .none

            case .tasks(.addTaskTapped),
                 .tasks(.taskCompleted),
                 .tasks(.taskDeleted),
                 .tasks(.undoDeleteTask),
                 .tasks(.remindersImported),
                 .tasks(.detail(.presented(.delegate(.taskDeleted)))):
                // Keep focus task list in sync after mutations
                state.focus.availableTasks = state.tasks.tasks
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
