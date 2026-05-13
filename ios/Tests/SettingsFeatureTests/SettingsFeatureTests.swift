// SettingsFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA TestStore tests for SettingsFeature: preferences CRUD,
// clamping, toggles, theme gating, health/calendar auth flows.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("SettingsFeature")
@MainActor
struct SettingsFeatureTests {

    // MARK: - Helpers

    private nonisolated func defaultPrefs() -> UserPreferencesDTO {
        UserPreferencesDTO(
            soundEnabled: true,
            hapticEnabled: true,
            defaultMode: "pomodoro",
            themeName: "default"
        )
    }

    private nonisolated func customPrefs() -> UserPreferencesDTO {
        var prefs = UserPreferencesDTO()
        prefs.pomodoroDuration = 50 * 60         // 50 min
        prefs.shortBreakDuration = 10 * 60        // 10 min
        prefs.longBreakDuration = 30 * 60         // 30 min
        prefs.pomodorosPerCycle = 6
        prefs.autoStartBreaks = false
        prefs.autoStartWork = true
        prefs.defaultBlockDuration = 90 * 60      // 90 min
        prefs.blockMidpointCheckIn = true
        prefs.flowtimeMinSessionMinutes = 10
        prefs.soundEnabled = false
        prefs.hapticEnabled = false
        prefs.keepScreenOn = true
        prefs.defaultMode = "flowtime"
        prefs.themeName = "ocean"
        prefs.dailyReminderEnabled = true
        prefs.dailyReminderHour = 8
        prefs.dailyReminderMinute = 30
        prefs.healthLoggingEnabled = true
        prefs.adhdFriendlyEnabled = true
        prefs.calendarIntegrationEnabled = true
        prefs.isProUser = true
        prefs.currentStreakDays = 14
        return prefs
    }

    private func makeStore(
        state: SettingsFeature.State = .init(),
        prefs: UserPreferencesDTO? = nil,
        healthAuthorized: Bool = false
    ) -> TestStore<SettingsFeature.State, SettingsFeature.Action> {
        let fetchPrefs = prefs ?? defaultPrefs()
        return TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { fetchPrefs }
            $0.persistenceClient.savePreferences = { _ in }
            $0.healthClient.isAuthorized = { healthAuthorized }
            $0.healthClient.requestAuthorization = { healthAuthorized }
            $0.calendarClient.requestAccess = { false }
        }
    }

    // MARK: - Default State Values

    @Test("Default state has expected initial values")
    func testDefaultState() {
        let state = SettingsFeature.State()
        #expect(state.pomodoroDurationMinutes == 25)
        #expect(state.shortBreakMinutes == 5)
        #expect(state.longBreakMinutes == 15)
        #expect(state.pomodorosPerCycle == 4)
        #expect(state.autoStartBreaks == true)
        #expect(state.autoStartWork == false)
        #expect(state.blockDurationMinutes == 60)
        #expect(state.blockMidpointCheckIn == false)
        #expect(state.flowtimeMinMinutes == 5)
        #expect(state.soundEnabled == true)
        #expect(state.hapticEnabled == true)
        #expect(state.keepScreenOn == false)
        #expect(state.defaultMode == .pomodoro)
        #expect(state.themeName == "default")
        #expect(state.dailyReminderEnabled == false)
        #expect(state.dailyReminderHour == 9)
        #expect(state.dailyReminderMinute == 0)
        #expect(state.healthLoggingEnabled == false)
        #expect(state.healthAuthorized == false)
        #expect(state.adhdFriendlyEnabled == false)
        #expect(state.calendarIntegrationEnabled == false)
        #expect(state.isProUser == false)
        #expect(state.currentStreakDays == 0)
        #expect(state.isLoading == false)
        #expect(state.about == nil)
    }

    // MARK: - onAppear / Loading Preferences

    @Test("onAppear loads preferences and populates state")
    func testOnAppearLoadsPreferences() async {
        let prefs = customPrefs()
        let store = makeStore(prefs: prefs)
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.preferencesLoaded) {
            $0.isLoading = false
            $0.pomodoroDurationMinutes = 50
            $0.shortBreakMinutes = 10
            $0.longBreakMinutes = 30
            $0.pomodorosPerCycle = 6
            $0.autoStartBreaks = false
            $0.autoStartWork = true
            $0.blockDurationMinutes = 90
            $0.blockMidpointCheckIn = true
            $0.flowtimeMinMinutes = 10
            $0.soundEnabled = false
            $0.hapticEnabled = false
            $0.keepScreenOn = true
            $0.defaultMode = .flowtime
            $0.themeName = "ocean"
            $0.dailyReminderEnabled = true
            $0.dailyReminderHour = 8
            $0.dailyReminderMinute = 30
            $0.healthLoggingEnabled = true
            $0.adhdFriendlyEnabled = true
            $0.calendarIntegrationEnabled = true
            $0.isProUser = true
            $0.currentStreakDays = 14
        }
    }

    @Test("onAppear does nothing when already loading")
    func testOnAppearGuardsAgainstDoubleLoad() async {
        var state = SettingsFeature.State()
        state.isLoading = true

        let store = makeStore(state: state)
        await store.send(.onAppear)
        // No state mutation expected — guard blocks second load
    }

    // MARK: - Pomodoro Duration Changes

    @Test("Pomodoro duration change updates state and triggers save")
    func testPomodoroDurationChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.pomodoroDurationChanged(30)) {
            $0.pomodoroDurationMinutes = 30
        }
    }

    @Test("Pomodoro duration is clamped to minimum of 1")
    func testPomodoroDurationClampedMin() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.pomodoroDurationChanged(0)) {
            $0.pomodoroDurationMinutes = 1
        }
    }

    @Test("Pomodoro duration is clamped to maximum of 120")
    func testPomodoroDurationClampedMax() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.pomodoroDurationChanged(200)) {
            $0.pomodoroDurationMinutes = 120
        }
    }

    // MARK: - Short Break Changes

    @Test("Short break change updates state")
    func testShortBreakChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.shortBreakChanged(10)) {
            $0.shortBreakMinutes = 10
        }
    }

    @Test("Short break is clamped between 1 and 60")
    func testShortBreakClamped() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.shortBreakChanged(0)) {
            $0.shortBreakMinutes = 1
        }

        await store.send(.shortBreakChanged(100)) {
            $0.shortBreakMinutes = 60
        }
    }

    // MARK: - Long Break Changes

    @Test("Long break change updates state")
    func testLongBreakChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.longBreakChanged(20)) {
            $0.longBreakMinutes = 20
        }
    }

    @Test("Long break is clamped between 5 and 120")
    func testLongBreakClamped() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.longBreakChanged(2)) {
            $0.longBreakMinutes = 5
        }

        await store.send(.longBreakChanged(200)) {
            $0.longBreakMinutes = 120
        }
    }

    // MARK: - Pomodoros Per Cycle

    @Test("Pomodoros per cycle change updates state")
    func testPomodorosPerCycleChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.pomodorosPerCycleChanged(6)) {
            $0.pomodorosPerCycle = 6
        }
    }

    @Test("Pomodoros per cycle is clamped between 1 and 12")
    func testPomodorosPerCycleClamped() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.pomodorosPerCycleChanged(0)) {
            $0.pomodorosPerCycle = 1
        }

        await store.send(.pomodorosPerCycleChanged(20)) {
            $0.pomodorosPerCycle = 12
        }
    }

    // MARK: - Toggle Actions

    @Test("Auto-start breaks toggle flips state")
    func testAutoStartBreaksToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        // Default is true, toggle to false
        await store.send(.autoStartBreaksToggled) {
            $0.autoStartBreaks = false
        }
    }

    @Test("Auto-start work toggle flips state")
    func testAutoStartWorkToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        // Default is false, toggle to true
        await store.send(.autoStartWorkToggled) {
            $0.autoStartWork = true
        }
    }

    @Test("Sound toggle flips state")
    func testSoundToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.soundToggled) {
            $0.soundEnabled = false
        }
    }

    @Test("Haptic toggle flips state")
    func testHapticToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.hapticToggled) {
            $0.hapticEnabled = false
        }
    }

    @Test("Keep screen on toggle flips state")
    func testKeepScreenOnToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.keepScreenOnToggled) {
            $0.keepScreenOn = true
        }
    }

    @Test("Block midpoint toggle flips state")
    func testBlockMidpointToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.blockMidpointToggled) {
            $0.blockMidpointCheckIn = true
        }
    }

    @Test("ADHD-friendly toggle flips state")
    func testAdhdFriendlyToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.adhdFriendlyToggled) {
            $0.adhdFriendlyEnabled = true
        }
    }

    // MARK: - Block Duration

    @Test("Block duration change updates state")
    func testBlockDurationChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.blockDurationChanged(90)) {
            $0.blockDurationMinutes = 90
        }
    }

    @Test("Block duration is clamped between 5 and 480")
    func testBlockDurationClamped() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.blockDurationChanged(2)) {
            $0.blockDurationMinutes = 5
        }

        await store.send(.blockDurationChanged(600)) {
            $0.blockDurationMinutes = 480
        }
    }

    // MARK: - Flowtime Min Minutes

    @Test("Flowtime min minutes change updates state")
    func testFlowtimeMinMinutesChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.flowtimeMinMinutesChanged(15)) {
            $0.flowtimeMinMinutes = 15
        }
    }

    @Test("Flowtime min minutes is clamped between 1 and 60")
    func testFlowtimeMinMinutesClamped() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.flowtimeMinMinutesChanged(0)) {
            $0.flowtimeMinMinutes = 1
        }

        await store.send(.flowtimeMinMinutesChanged(100)) {
            $0.flowtimeMinMinutes = 60
        }
    }

    // MARK: - Default Mode

    @Test("Default mode change updates state")
    func testDefaultModeChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.defaultModeChanged(.flowtime)) {
            $0.defaultMode = .flowtime
        }

        await store.send(.defaultModeChanged(.timeBlock)) {
            $0.defaultMode = .timeBlock
        }

        await store.send(.defaultModeChanged(.stopwatch)) {
            $0.defaultMode = .stopwatch
        }
    }

    // MARK: - Theme Changes

    @Test("Pro user can change theme")
    func testProUserCanChangeTheme() async {
        var state = SettingsFeature.State()
        state.isProUser = true

        let store = makeStore(state: state)
        store.exhaustivity = .off

        await store.send(.themeChanged("ocean")) {
            $0.themeName = "ocean"
        }
    }

    @Test("Free user cannot change theme away from default")
    func testFreeUserCannotChangeTheme() async {
        var state = SettingsFeature.State()
        state.isProUser = false

        let store = makeStore(state: state)
        store.exhaustivity = .off

        await store.send(.themeChanged("ocean"))
        await store.receive(.upgradeTapped)
        #expect(store.state.themeName == "default")
    }

    @Test("Free user selecting forest theme triggers upgrade action")
    func testFreeUserForestThemeTriggersUpgrade() async {
        var state = SettingsFeature.State()
        state.isProUser = false

        let store = makeStore(state: state)
        store.exhaustivity = .off

        await store.send(.themeChanged("forest"))
        await store.receive(.upgradeTapped)
        #expect(store.state.themeName == "default")
    }

    @Test("Free user can select default theme")
    func testFreeUserCanSelectDefaultTheme() async {
        var state = SettingsFeature.State()
        state.isProUser = false
        state.themeName = "default"

        let store = makeStore(state: state)
        store.exhaustivity = .off

        await store.send(.themeChanged("default"))
        // "default" is allowed even for free users; triggers save
    }

    // MARK: - Daily Reminder

    @Test("Daily reminder toggle flips state")
    func testDailyReminderToggle() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.dailyReminderToggled) {
            $0.dailyReminderEnabled = true
        }

        await store.send(.dailyReminderToggled) {
            $0.dailyReminderEnabled = false
        }
    }

    @Test("Daily reminder time change updates hour and minute")
    func testDailyReminderTimeChanged() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.dailyReminderTimeChanged(hour: 7, minute: 45)) {
            $0.dailyReminderHour = 7
            $0.dailyReminderMinute = 45
        }
    }

    // MARK: - Health Logging

    @Test("Health logging toggle off does not require auth")
    func testHealthLoggingToggleOff() async {
        var state = SettingsFeature.State()
        state.healthLoggingEnabled = true

        let store = makeStore(state: state)
        store.exhaustivity = .off

        await store.send(.healthLoggingToggled) {
            $0.healthLoggingEnabled = false
        }
    }

    @Test("Health logging toggle on triggers authorization request")
    func testHealthLoggingToggleOnRequestsAuth() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { self.defaultPrefs() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.healthClient.requestAuthorization = { true }
            $0.healthClient.isAuthorized = { false }
            $0.calendarClient.requestAccess = { false }
        }
        store.exhaustivity = .off

        await store.send(.healthLoggingToggled)
        // Should trigger authorization request effect

        await store.receive(.healthAuthorizationResult(true)) {
            $0.healthAuthorized = true
            $0.healthLoggingEnabled = true
        }
    }

    @Test("Health authorization denied shows alert")
    func testHealthAuthorizationDenied() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.healthAuthorizationResult(false)) {
            $0.healthAuthorized = false
            $0.showHealthDeniedAlert = true
        }
    }

    @Test("Health denied alert dismissal clears flag")
    func testHealthDeniedAlertDismissed() async {
        var state = SettingsFeature.State()
        state.showHealthDeniedAlert = true

        let store = makeStore(state: state)

        await store.send(.healthDeniedAlertDismissed) {
            $0.showHealthDeniedAlert = false
        }
    }

    // MARK: - Calendar Integration

    @Test("Calendar integration toggle off disables without auth")
    func testCalendarToggleOff() async {
        var state = SettingsFeature.State()
        state.calendarIntegrationEnabled = true

        let store = makeStore(state: state)
        store.exhaustivity = .off

        await store.send(.calendarIntegrationToggled) {
            $0.calendarIntegrationEnabled = false
        }
    }

    @Test("Calendar integration toggle on triggers authorization")
    func testCalendarToggleOnRequestsAuth() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { self.defaultPrefs() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.healthClient.isAuthorized = { false }
            $0.healthClient.requestAuthorization = { false }
            $0.calendarClient.requestAccess = { true }
        }
        store.exhaustivity = .off

        await store.send(.calendarIntegrationToggled)

        await store.receive(.calendarAuthorizationResult(true)) {
            $0.calendarIntegrationEnabled = true
        }
    }

    @Test("Calendar authorization denied does not enable integration")
    func testCalendarAuthorizationDenied() async {
        let store = makeStore()

        await store.send(.calendarAuthorizationResult(false))
        // No state change — calendarIntegrationEnabled stays false
    }

    // MARK: - isProUser

    @Test("isProUser reflects loaded preference")
    func testIsProUserReflectsPreference() async {
        var prefs = defaultPrefs()
        prefs.isProUser = true

        let store = makeStore(prefs: prefs)
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.preferencesLoaded) {
            $0.isLoading = false
            $0.isProUser = true
        }
    }

    // MARK: - Save Settings Flow

    @Test("Setting change triggers saveSettings then settingsSaved")
    func testSaveSettingsFlow() async {
        nonisolated(unsafe) var savedPrefs: UserPreferencesDTO?

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { self.defaultPrefs() }
            $0.persistenceClient.savePreferences = { prefs in savedPrefs = prefs }
            $0.healthClient.isAuthorized = { false }
            $0.healthClient.requestAuthorization = { false }
            $0.calendarClient.requestAccess = { false }
        }
        store.exhaustivity = .off

        await store.send(.pomodoroDurationChanged(45)) {
            $0.pomodoroDurationMinutes = 45
        }

        await store.receive(.saveSettings)
        await store.receive(.settingsSaved)

        #expect(savedPrefs != nil)
        #expect(savedPrefs?.pomodoroDuration == TimeInterval(45 * 60))
    }

    // MARK: - About

    @Test("About tapped presents AboutFeature with isProUser")
    func testAboutTapped() async {
        var state = SettingsFeature.State()
        state.isProUser = true

        let store = makeStore(state: state)

        await store.send(.aboutTapped) {
            $0.about = AboutFeature.State(isProUser: true)
        }
    }

    // MARK: - Upgrade / Paywall (pass-through)

    @Test("Upgrade tapped does not mutate state")
    func testUpgradeTapped() async {
        let store = makeStore()
        await store.send(.upgradeTapped)
    }

    @Test("Paywall dismissed does not mutate state")
    func testPaywallDismissed() async {
        let store = makeStore()
        await store.send(.paywallDismissed)
    }
}
