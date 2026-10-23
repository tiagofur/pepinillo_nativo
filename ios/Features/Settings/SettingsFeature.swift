// SettingsFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Settings screen.
// Loads UserPreferences from SwiftData, exposes them as editable state,
// and auto-saves on any change.

import Foundation
import ComposableArchitecture

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        // Pomodoro
        var pomodoroDurationMinutes: Int = 25
        var shortBreakMinutes: Int = 5
        var longBreakMinutes: Int = 15
        var pomodorosPerCycle: Int = 4
        var autoStartBreaks: Bool = true
        var autoStartWork: Bool = false

        // Time Block
        var blockDurationMinutes: Int = 60
        var blockMidpointCheckIn: Bool = false

        // Flowtime
        var flowtimeMinMinutes: Int = 5

        // General
        var soundEnabled: Bool = true
        var hapticEnabled: Bool = true
        var keepScreenOn: Bool = false
        var showJournalAfterSession: Bool = true
        var defaultMode: FocusMode = .pomodoro

        // Theme
        var themeName: String = "default"
        var appearanceMode: String = "system"

        // Notifications
        var dailyReminderEnabled: Bool = false
        var dailyReminderHour: Int = 9
        var dailyReminderMinute: Int = 0
        var showNotificationDeniedAlert: Bool = false

        // Apple Health
        var healthLoggingEnabled: Bool = false
        var healthAuthorized: Bool = false
        var showHealthDeniedAlert: Bool = false

        // ADHD-Friendly Mode
        var adhdFriendlyEnabled: Bool = false

        // Calendar Integration
        var calendarIntegrationEnabled: Bool = false

        // Subscription (read-only)
        var isProUser: Bool = false
        var currentStreakDays: Int = 0

        // iCloud sync status (read from AppGroupDefaults — issue #161)
        var syncStatus: AppGroupDefaults.SyncStatus = .idle
        var lastAppleCloudActivationError: String?
        var canAppleCloudSync: Bool = false
        var isRetryingAppleCloudSync: Bool = false

        var isLoading: Bool = false

        // Child features
        @Presents var about: AboutFeature.State?

        var selectedTheme: AppTheme { AppTheme.named(themeName) }
    }

    enum Action: Equatable {
        case onAppear
        case preferencesLoaded(SettingsSnapshot)

        // Pomodoro
        case pomodoroDurationChanged(Int)
        case shortBreakChanged(Int)
        case longBreakChanged(Int)
        case pomodorosPerCycleChanged(Int)
        case autoStartBreaksToggled
        case autoStartWorkToggled

        // Time Block
        case blockDurationChanged(Int)
        case blockMidpointToggled

        // Flowtime
        case flowtimeMinMinutesChanged(Int)

        // General
        case soundToggled
        case hapticToggled
        case keepScreenOnToggled
        case showJournalAfterSessionToggled
        case defaultModeChanged(FocusMode)

        // Theme
        case themeChanged(String)
        case appearanceModeChanged(String)

        // Notifications
        case dailyReminderToggled
        case dailyReminderTimeChanged(hour: Int, minute: Int)
        case notificationAuthorizationDenied
        case notificationDeniedAlertDismissed

        // Apple Health
        case healthLoggingToggled
        case healthAuthorizationResult(Bool)
        case healthDeniedAlertDismissed

        // ADHD-Friendly Mode
        case adhdFriendlyToggled

        // Calendar Integration
        case calendarIntegrationToggled
        case calendarAuthorizationResult(Bool)

        // About
        case aboutTapped
        case about(PresentationAction<AboutFeature.Action>)

        // Subscription / Paywall
        case upgradeTapped
        case paywallDismissed

        // iCloud sync (#161)
        case syncStatusRefreshed(
            status: AppGroupDefaults.SyncStatus,
            error: String?,
            canAppleCloudSync: Bool
        )
        case retryAppleCloudSyncTapped
        case appleCloudSyncRetryFinished(
            status: AppGroupDefaults.SyncStatus,
            error: String?
        )

        // Internal
        case saveSettings
        case settingsSaved
    }

    /// Value-type snapshot for passing preferences across concurrency boundaries.
    struct SettingsSnapshot: Equatable {
        var pomodoroDurationMinutes: Int
        var shortBreakMinutes: Int
        var longBreakMinutes: Int
        var pomodorosPerCycle: Int
        var autoStartBreaks: Bool
        var autoStartWork: Bool
        var blockDurationMinutes: Int
        var blockMidpointCheckIn: Bool
        var flowtimeMinMinutes: Int
        var soundEnabled: Bool
        var hapticEnabled: Bool
        var keepScreenOn: Bool
        var showJournalAfterSession: Bool
        var defaultMode: FocusMode
        var themeName: String
        var appearanceMode: String
        var dailyReminderEnabled: Bool
        var dailyReminderHour: Int
        var dailyReminderMinute: Int
        var healthLoggingEnabled: Bool
        var adhdFriendlyEnabled: Bool
        var calendarIntegrationEnabled: Bool
        var isProUser: Bool
        var currentStreakDays: Int

        init(from prefs: UserPreferencesDTO) {
            pomodoroDurationMinutes = max(5, Int(prefs.pomodoroDuration / 60))
            shortBreakMinutes = Int(prefs.shortBreakDuration / 60)
            longBreakMinutes = Int(prefs.longBreakDuration / 60)
            pomodorosPerCycle = prefs.pomodorosPerCycle
            autoStartBreaks = prefs.autoStartBreaks
            autoStartWork = prefs.autoStartWork
            blockDurationMinutes = Int(prefs.defaultBlockDuration / 60)
            blockMidpointCheckIn = prefs.blockMidpointCheckIn
            flowtimeMinMinutes = prefs.flowtimeMinSessionMinutes
            soundEnabled = prefs.soundEnabled
            hapticEnabled = prefs.hapticEnabled
            keepScreenOn = prefs.keepScreenOn
            showJournalAfterSession = prefs.showJournalAfterSession
            defaultMode = FocusMode(rawValue: prefs.defaultMode) ?? .pomodoro
            themeName = prefs.themeName
            appearanceMode = prefs.appearanceMode
            dailyReminderEnabled = prefs.dailyReminderEnabled
            dailyReminderHour = prefs.dailyReminderHour
            dailyReminderMinute = prefs.dailyReminderMinute
            healthLoggingEnabled = prefs.healthLoggingEnabled
            adhdFriendlyEnabled = prefs.adhdFriendlyEnabled
            calendarIntegrationEnabled = prefs.calendarIntegrationEnabled
            // Honor the DEBUG Pro simulation so it isn't clobbered by the persisted
            // value (always false under simulation). Issue #95.
            isProUser = DemoDataSeeder.effectiveIsPro(persisted: prefs.isProUser)
            currentStreakDays = prefs.currentStreakDays
        }
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.healthClient) var healthClient
    @Dependency(\.calendarClient) var calendarClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                state.syncStatus = AppGroupDefaults.syncStatus
                state.lastAppleCloudActivationError = AppGroupDefaults.lastAppleCloudActivationError
                state.canAppleCloudSync = AppGroupDefaults.canAppleCloudSync
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return .run { send in
                    let prefs = try await persistence.fetchPreferences()
                    let snapshot = SettingsSnapshot(from: prefs)
                    await send(.preferencesLoaded(snapshot))
                    await send(.syncStatusRefreshed(
                        status: AppGroupDefaults.syncStatus,
                        error: AppGroupDefaults.lastAppleCloudActivationError,
                        canAppleCloudSync: AppGroupDefaults.canAppleCloudSync
                    ))
                }

            case .preferencesLoaded(let snap):
                state.isLoading = false
                state.pomodoroDurationMinutes = snap.pomodoroDurationMinutes
                state.shortBreakMinutes = snap.shortBreakMinutes
                state.longBreakMinutes = snap.longBreakMinutes
                state.pomodorosPerCycle = snap.pomodorosPerCycle
                state.autoStartBreaks = snap.autoStartBreaks
                state.autoStartWork = snap.autoStartWork
                state.blockDurationMinutes = snap.blockDurationMinutes
                state.blockMidpointCheckIn = snap.blockMidpointCheckIn
                state.flowtimeMinMinutes = snap.flowtimeMinMinutes
                state.soundEnabled = snap.soundEnabled
                state.hapticEnabled = snap.hapticEnabled
                state.keepScreenOn = snap.keepScreenOn
                state.showJournalAfterSession = snap.showJournalAfterSession
                state.defaultMode = snap.defaultMode
                state.themeName = snap.themeName
                state.appearanceMode = snap.appearanceMode
                state.dailyReminderEnabled = snap.dailyReminderEnabled
                state.dailyReminderHour = snap.dailyReminderHour
                state.dailyReminderMinute = snap.dailyReminderMinute
                state.healthLoggingEnabled = snap.healthLoggingEnabled
                state.healthAuthorized = healthClient.isAuthorized()
                state.adhdFriendlyEnabled = snap.adhdFriendlyEnabled
                state.calendarIntegrationEnabled = snap.calendarIntegrationEnabled
                // isProUser is owned by AppFeature.applySubscriptionUpdate — never reload
                // from stale SwiftData prefs (#207).
                state.currentStreakDays = snap.currentStreakDays
                return .none

            // MARK: - Mutations (each triggers autosave)

            case .pomodoroDurationChanged(let v):
                state.pomodoroDurationMinutes = max(5, min(120, v))
                PreferenceDirtyTracker.markDirty("pomodoroMinutes")
                return .send(.saveSettings)

            case .shortBreakChanged(let v):
                state.shortBreakMinutes = max(1, min(60, v))
                PreferenceDirtyTracker.markDirty("shortBreakMinutes")
                return .send(.saveSettings)

            case .longBreakChanged(let v):
                state.longBreakMinutes = max(5, min(120, v))
                PreferenceDirtyTracker.markDirty("longBreakMinutes")
                return .send(.saveSettings)

            case .pomodorosPerCycleChanged(let v):
                state.pomodorosPerCycle = max(1, min(12, v))
                PreferenceDirtyTracker.markDirty("sessionsBeforeLongBreak")
                return .send(.saveSettings)

            case .autoStartBreaksToggled:
                state.autoStartBreaks.toggle()
                PreferenceDirtyTracker.markDirty("autoStartBreaks")
                return .send(.saveSettings)

            case .autoStartWorkToggled:
                state.autoStartWork.toggle()
                PreferenceDirtyTracker.markDirty("autoStartNextPomodoro")
                return .send(.saveSettings)

            case .blockDurationChanged(let v):
                state.blockDurationMinutes = max(5, min(480, v))
                PreferenceDirtyTracker.markDirty("timeBlockMinutes")
                return .send(.saveSettings)

            case .blockMidpointToggled:
                state.blockMidpointCheckIn.toggle()
                PreferenceDirtyTracker.markDirty("midpointCheckIn")
                return .send(.saveSettings)

            case .flowtimeMinMinutesChanged(let v):
                state.flowtimeMinMinutes = max(1, min(60, v))
                PreferenceDirtyTracker.markDirty("flowtimeMinMinutes")
                return .send(.saveSettings)

            case .soundToggled:
                state.soundEnabled.toggle()
                PreferenceDirtyTracker.markDirty("soundEnabled")
                return .send(.saveSettings)

            case .hapticToggled:
                state.hapticEnabled.toggle()
                PreferenceDirtyTracker.markDirty("hapticEnabled")
                return .send(.saveSettings)

            case .keepScreenOnToggled:
                state.keepScreenOn.toggle()
                PreferenceDirtyTracker.markDirty("keepScreenOn")
                return .send(.saveSettings)

            case .showJournalAfterSessionToggled:
                state.showJournalAfterSession.toggle()
                PreferenceDirtyTracker.markDirty("showJournalAfterSession")
                return .send(.saveSettings)

            case .defaultModeChanged(let mode):
                // Pro gating — mirrors themeChanged. Free tier can pick Pomodoro /
                // Stopwatch (FocusMode.isFreeTier); Flowtime / TimeBlock require Pro.
                guard state.isProUser || mode.isFreeTier else {
                    return .send(.upgradeTapped)
                }
                state.defaultMode = mode
                PreferenceDirtyTracker.markDirty("defaultMode")
                return .send(.saveSettings)

            case .themeChanged(let name):
                if !state.isProUser && name != "default" {
                    return .send(.upgradeTapped)
                }
                state.themeName = name
                PreferenceDirtyTracker.markDirty("themeName")
                return .send(.saveSettings)

            case .appearanceModeChanged(let mode):
                state.appearanceMode = mode
                PreferenceDirtyTracker.markDirty("appearanceMode")
                return .send(.saveSettings)

            case .dailyReminderToggled:
                state.dailyReminderEnabled.toggle()
                return .send(.saveSettings)

            case .notificationAuthorizationDenied:
                state.dailyReminderEnabled = false
                state.showNotificationDeniedAlert = true
                return .send(.saveSettings)

            case .notificationDeniedAlertDismissed:
                state.showNotificationDeniedAlert = false
                return .none

            case .dailyReminderTimeChanged(let hour, let minute):
                state.dailyReminderHour = hour
                state.dailyReminderMinute = minute
                return .send(.saveSettings)

            case .healthLoggingToggled:
                if state.healthLoggingEnabled {
                    // Turning off — no auth needed
                    state.healthLoggingEnabled = false
                    return .send(.saveSettings)
                } else {
                    // Health integration is Premium-only (#216)
                    guard state.isProUser else {
                        return .send(.upgradeTapped)
                    }
                    // Turning on — request authorization first
                    return .run { [healthClient] send in
                        let authorized = try await healthClient.requestAuthorization()
                        await send(.healthAuthorizationResult(authorized))
                    }
                }

            case .healthAuthorizationResult(let authorized):
                state.healthAuthorized = authorized
                if authorized {
                    state.healthLoggingEnabled = true
                    return .send(.saveSettings)
                }
                state.showHealthDeniedAlert = true
                return .none

            case .healthDeniedAlertDismissed:
                state.showHealthDeniedAlert = false
                return .none

            case .adhdFriendlyToggled:
                state.adhdFriendlyEnabled.toggle()
                return .send(.saveSettings)

            case .calendarIntegrationToggled:
                if state.calendarIntegrationEnabled {
                    state.calendarIntegrationEnabled = false
                    return .send(.saveSettings)
                } else {
                    // Calendar integration is Premium-only (#216)
                    guard state.isProUser else {
                        return .send(.upgradeTapped)
                    }
                    return .run { [calendarClient] send in
                        let authorized = try await calendarClient.requestAccess()
                        await send(.calendarAuthorizationResult(authorized))
                    }
                }

            case .calendarAuthorizationResult(let authorized):
                if authorized {
                    state.calendarIntegrationEnabled = true
                    return .send(.saveSettings)
                }
                return .none

            case .saveSettings:
                let snapshot = SettingsSnapshot(
                    pomodoroDurationMinutes: state.pomodoroDurationMinutes,
                    shortBreakMinutes: state.shortBreakMinutes,
                    longBreakMinutes: state.longBreakMinutes,
                    pomodorosPerCycle: state.pomodorosPerCycle,
                    autoStartBreaks: state.autoStartBreaks,
                    autoStartWork: state.autoStartWork,
                    blockDurationMinutes: state.blockDurationMinutes,
                    blockMidpointCheckIn: state.blockMidpointCheckIn,
                    flowtimeMinMinutes: state.flowtimeMinMinutes,
                    soundEnabled: state.soundEnabled,
                    hapticEnabled: state.hapticEnabled,
                    keepScreenOn: state.keepScreenOn,
                    showJournalAfterSession: state.showJournalAfterSession,
                    defaultMode: state.defaultMode,
                    themeName: state.themeName,
                    appearanceMode: state.appearanceMode,
                    dailyReminderEnabled: state.dailyReminderEnabled,
                    dailyReminderHour: state.dailyReminderHour,
                    dailyReminderMinute: state.dailyReminderMinute,
                    healthLoggingEnabled: state.healthLoggingEnabled,
                    adhdFriendlyEnabled: state.adhdFriendlyEnabled,
                    calendarIntegrationEnabled: state.calendarIntegrationEnabled,
                    isProUser: state.isProUser,
                    currentStreakDays: state.currentStreakDays
                )
                return .run { [snapshot] send in
                    var prefs = try await persistence.fetchPreferences()
                    prefs.pomodoroDuration = TimeInterval(snapshot.pomodoroDurationMinutes * 60)
                    prefs.shortBreakDuration = TimeInterval(snapshot.shortBreakMinutes * 60)
                    prefs.longBreakDuration = TimeInterval(snapshot.longBreakMinutes * 60)
                    prefs.pomodorosPerCycle = snapshot.pomodorosPerCycle
                    prefs.autoStartBreaks = snapshot.autoStartBreaks
                    prefs.autoStartWork = snapshot.autoStartWork
                    prefs.defaultBlockDuration = TimeInterval(snapshot.blockDurationMinutes * 60)
                    prefs.blockMidpointCheckIn = snapshot.blockMidpointCheckIn
                    prefs.flowtimeMinSessionMinutes = snapshot.flowtimeMinMinutes
                    prefs.soundEnabled = snapshot.soundEnabled
                    prefs.hapticEnabled = snapshot.hapticEnabled
                    prefs.keepScreenOn = snapshot.keepScreenOn
                    prefs.showJournalAfterSession = snapshot.showJournalAfterSession
                    prefs.defaultMode = snapshot.defaultMode.rawValue
                    prefs.themeName = snapshot.themeName
                    prefs.appearanceMode = snapshot.appearanceMode
                    prefs.dailyReminderEnabled = snapshot.dailyReminderEnabled
                    prefs.dailyReminderHour = snapshot.dailyReminderHour
                    prefs.dailyReminderMinute = snapshot.dailyReminderMinute
                    prefs.healthLoggingEnabled = snapshot.healthLoggingEnabled
                    prefs.adhdFriendlyEnabled = snapshot.adhdFriendlyEnabled
                    prefs.calendarIntegrationEnabled = snapshot.calendarIntegrationEnabled
                    try await persistence.savePreferences(prefs)
                    await send(.settingsSaved)
                }

            case .settingsSaved:
                return .none

            case .aboutTapped:
                state.about = AboutFeature.State(isProUser: state.isProUser)
                return .none

            case .about:
                return .none

            case .upgradeTapped:
                // Handled by AppFeature — triggers the root paywall sheet.
                return .none

            case .paywallDismissed:
                // Handled by AppFeature.
                return .none

            case .syncStatusRefreshed(let status, let error, let canAppleCloudSync):
                state.syncStatus = status
                state.lastAppleCloudActivationError = error
                state.canAppleCloudSync = canAppleCloudSync
                return .none

            case .retryAppleCloudSyncTapped:
                // Handled by AppFeature — triggers a forced reconcile.
                return .none

            case .appleCloudSyncRetryFinished(let status, let error):
                state.isRetryingAppleCloudSync = false
                state.syncStatus = status
                state.lastAppleCloudActivationError = error
                return .none
            }
        }
        .ifLet(\.$about, action: \.about) {
            AboutFeature()
        }
    }
}

// MARK: - Convenience init for SettingsSnapshot

extension SettingsFeature.SettingsSnapshot {
    /// The focus-engine configuration equivalent of this snapshot. Shared by
    /// the launch hydration (`AppFeature` on `.preferencesLoaded`) so the Focus
    /// stage and the Settings UI always derive timers from the same values.
    var focusConfig: FocusConfig {
        FocusConfig(
            pomodoroDuration: TimeInterval(pomodoroDurationMinutes * 60),
            shortBreakDuration: TimeInterval(shortBreakMinutes * 60),
            longBreakDuration: TimeInterval(longBreakMinutes * 60),
            pomodorosPerCycle: pomodorosPerCycle,
            autoStartBreaks: autoStartBreaks,
            autoStartWork: autoStartWork,
            defaultBlockDuration: TimeInterval(blockDurationMinutes * 60),
            blockMidpointCheckIn: blockMidpointCheckIn,
            flowtimeMinSessionMinutes: flowtimeMinMinutes,
            flowtimeShowBreakSuggestion: true,
            soundEnabled: soundEnabled,
            hapticEnabled: hapticEnabled,
            keepScreenOn: keepScreenOn
        )
    }

    init(
        pomodoroDurationMinutes: Int,
        shortBreakMinutes: Int,
        longBreakMinutes: Int,
        pomodorosPerCycle: Int,
        autoStartBreaks: Bool,
        autoStartWork: Bool,
        blockDurationMinutes: Int,
        blockMidpointCheckIn: Bool,
        flowtimeMinMinutes: Int,
        soundEnabled: Bool,
        hapticEnabled: Bool,
        keepScreenOn: Bool,
        showJournalAfterSession: Bool = true,
        defaultMode: FocusMode,
        themeName: String,
        appearanceMode: String = "system",
        dailyReminderEnabled: Bool,
        dailyReminderHour: Int,
        dailyReminderMinute: Int,
        healthLoggingEnabled: Bool,
        adhdFriendlyEnabled: Bool = false,
        calendarIntegrationEnabled: Bool = false,
        isProUser: Bool,
        currentStreakDays: Int
    ) {
        self.pomodoroDurationMinutes = pomodoroDurationMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.pomodorosPerCycle = pomodorosPerCycle
        self.autoStartBreaks = autoStartBreaks
        self.autoStartWork = autoStartWork
        self.blockDurationMinutes = blockDurationMinutes
        self.blockMidpointCheckIn = blockMidpointCheckIn
        self.flowtimeMinMinutes = flowtimeMinMinutes
        self.soundEnabled = soundEnabled
        self.hapticEnabled = hapticEnabled
        self.keepScreenOn = keepScreenOn
        self.showJournalAfterSession = showJournalAfterSession
        self.defaultMode = defaultMode
        self.themeName = themeName
        self.appearanceMode = appearanceMode
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
        self.healthLoggingEnabled = healthLoggingEnabled
        self.adhdFriendlyEnabled = adhdFriendlyEnabled
        self.calendarIntegrationEnabled = calendarIntegrationEnabled
        self.isProUser = isProUser
        self.currentStreakDays = currentStreakDays
    }
}
