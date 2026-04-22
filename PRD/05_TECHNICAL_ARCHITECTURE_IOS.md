# Technical Architecture: Pepinillo iOS / watchOS

**Date:** 2026-03-24  
**Platforms:** iOS 17+ / iPadOS 17+ / macOS 14+ (Catalyst) / watchOS 10+  
**Language:** Swift 6 (strict concurrency)  
**UI Framework:** SwiftUI  
**Architecture:** The Composable Architecture (TCA) by Point-Free  
**Status:** Active

---

## 1. Technology Stack

| Layer            | Technology                               | Minimum Version     |
| ---------------- | ---------------------------------------- | ------------------- |
| Language         | Swift 6 (strict concurrency)             | Xcode 16+           |
| UI               | SwiftUI                                  | iOS 17 / watchOS 10 |
| Architecture     | TCA (swift-composable-architecture)      | 1.17+               |
| Persistence      | SwiftData + CloudKit                     | iOS 17              |
| Synchronization  | NSPersistentCloudKitContainer            | iOS 17              |
| Widgets          | WidgetKit                                | iOS 17              |
| Dynamic Island   | ActivityKit                              | iOS 16.1+           |
| Siri / Shortcuts | App Intents                              | iOS 17              |
| Watch            | WatchConnectivity (WCSession)            | watchOS 10          |
| Control Center   | ControlWidget                            | iOS 18              |
| On-Device AI     | Apple Foundation Models                  | iOS 26              |
| Health           | HealthKit (Mindful Minutes)              | iOS 17              |
| Analytics        | TelemetryDeck                            | --                  |
| Audio            | AVAudioEngine                            | iOS 17              |
| Authentication   | Sign in with Apple                       | iOS 17              |
| Subscriptions    | RevenueCat SDK v5+ (wrapping StoreKit 2) | iOS 17              |

### Key Decisions

- **RevenueCat SDK v5+:** Wraps native StoreKit 2 for centralized subscription, entitlement, and webhook handling. Supports 3 products (monthly, annual, lifetime) with unified `pro` entitlement.
- **No Firebase:** Private CloudKit for data, TelemetryDeck for anonymous analytics, Sign in with Apple for authentication.
- **Swift 6 strict concurrency:** All code compiles under strict concurrency mode. Actors (`FocusEngine`, `SoundscapeManager`, `SubscriptionManager`) guarantee thread safety without manual locks.

---

## 2. Architecture — TCA (The Composable Architecture)

### Why TCA

TCA was chosen over MVVM, VIPER, and Clean Architecture for the following reasons:

1. **Unidirectional data flow** -- Predictable state, ideal for a timer app with complex states (running, paused, break, interruption, phase transition).
2. **Integrated side-effect management** -- perfect for timer ticks, notifications, CloudKit sync, Watch connectivity, and Live Activities.
3. **Testability** -- every reducer is a pure function; every effect is injectable and testable with `TestStore`.
4. **Composability** -- features compose into parent features, mirroring Pepinillo's modular structure.
5. **Active maintenance** -- Point-Free actively maintains it, extensive documentation, compatible with Swift 6.

### Fundamental Pattern

```
View (SwiftUI) --[sends Action]--> Reducer --[produces State + Effect]--> View (re-render)
                                       |
                                       v
                                   Effect --[async operation]--> Reducer (receives response Action)
```

Each feature follows this pattern:

```swift
@Reducer
struct MyFeature {
    @ObservableState
    struct State: Equatable { /* Observable state */ }

    enum Action: Equatable { /* user actions + system responses */ }

    @Dependency(\.myClient) var myClient  // injectable dependencies

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .buttonTapped:
                state.isLoading = true
                return .run { send in
                    let result = await myClient.operation()
                    await send(.resultReceived(result))
                }
            case .resultReceived(let data):
                state.isLoading = false
                state.data = data
                return .none
            }
        }
    }
}
```

Views use `@Bindable var store: StoreOf<MyFeature>` and send actions to the store. They never mutate state directly.

---

## 3. Project Structure

```
ios/
├── App/
│   ├── PepinilloApp.swift              # @main, root Store creation, ModelContainer
│   ├── AppFeature.swift                # Root reducer: coordinates shell tabs, auth/profile sheets, Watch listener, WebSocket lifecycle
│   ├── AppView.swift                   # Root view with TabView / NavigationSplitView; iPhone runtime shell is Focus / Plan / Dashboard / More
│   ├── DrawerView.swift                # Side drawer (iPad/Mac)
│   ├── iPadSplitView.swift             # Adaptive iPad Split View + Stage Manager layout
│   ├── MacCommands.swift               # Menu commands for Mac (Catalyst)
│   └── DemoDataSeeder.swift            # Demo data for previews and testing
│
├── Domain/
│   ├── Models/                         # SwiftData @Model classes
│   │   ├── TaskItem.swift              # User task (see section 4)
│   │   ├── FocusSessionRecord.swift    # Completed/abandoned session record
│   │   ├── DailyStats.swift            # Aggregated daily statistics
│   │   ├── ProductivityReport.swift    # Cached AI report (weekly/monthly)
│   │   ├── UserPreferences.swift       # User preferences
│   │   ├── Achievement.swift           # Achievements / badges with progress
│   │   ├── SubTask.swift               # Subtasks of a TaskItem
│   │   └── APIDTOs.swift               # 9 API DTOs for sync (NEW)
│   │
│   ├── Clients/                        # TCA @DependencyClient (see section 6)
│   │   ├── PersistenceClient.swift     # SwiftData CRUD with Sendable DTOs
│   │   ├── FocusClient.swift           # TCA <-> FocusEngine actor bridge
│   │   ├── WatchConnectivityClient.swift  # Bidirectional WCSession
│   │   ├── AIReportClient.swift        # AI report generation
│   │   ├── NotificationClient.swift    # UNUserNotificationCenter
│   │   ├── SubscriptionClient.swift    # RevenueCat SDK v5+ (wrapping StoreKit 2)
│   │   ├── SoundscapeClient.swift      # Ambient sound playback
│   │   ├── CalendarClient.swift        # EventKit (calendar reading)
│   │   ├── HealthClient.swift          # HealthKit Mindful Minutes
│   │   ├── SignInWithAppleClient.swift  # Apple authentication
│   │   ├── SpotlightClient.swift       # CoreSpotlight indexing
│   │   ├── LiveActivityClient.swift    # ActivityKit (Dynamic Island)
│   │   ├── APIClient.swift             # URLSession REST client with JWT auth (NEW)
│   │   ├── SyncClient.swift            # Sync orchestration: syncSettings, syncSessions, initialUpload, performInitialSync, wipeAndSync (NEW)
│   │   ├── IdentityClient.swift        # Identity state machine: ANONYMOUS/REGISTERED/VERIFIED (NEW)
│   │   ├── WebSocketClient.swift       # URLSessionWebSocketTask with exponential backoff (NEW)
│   │   └── KeychainClient.swift        # Keychain access + getOrCreateDeviceId (ENHANCED)
│   │
│   └── Services/                       # Pure business logic (see section 7)
│       ├── ModeIntelligenceService.swift     # History-based mode suggestion
│       ├── InsightsService.swift             # Insights and trend calculation
│       ├── OnDeviceReportGenerator.swift     # Apple Foundation Models (iOS 26+)
│       ├── TemplateReportGenerator.swift     # Template-based fallback
│       ├── ReportDataBuilder.swift           # Report payload construction
│       ├── WeeklyReportService.swift         # Weekly report orchestration
│       └── RemindersImportService.swift      # Apple Reminders import
│
├── Features/
│   ├── Focus/
│   │   ├── FocusFeature.swift          # Reducer: orchestrates all 4 modes
│   │   ├── FocusView.swift             # Main view with mode selector
│   │   ├── FocusEngine.swift           # Actor: unified timer (see section 5)
│   │   ├── FocusModels.swift           # FocusMode, FocusPhase, FocusConfig, etc.
│   │   ├── FocusModeProtocol.swift     # Strategy protocol
│   │   ├── TaskPickerView.swift        # Task picker to link to session
│   │   ├── SessionJournalFeature.swift # Post-session journal (note + satisfaction)
│   │   ├── SessionJournalView.swift    # Journal view
│   │   ├── ModeIntelligenceBanner.swift # Mode suggestion banner
│   │   ├── SoundscapePickerView.swift  # Ambient sound selector
│   │   ├── ADHDBreakView.swift         # ADHD-friendly break view
│   │   └── Modes/
│   │       ├── PomodoroStrategy.swift  # 25/5/15 with configurable cycles
│   │       ├── FlowtimeStrategy.swift  # Open-ended + dynamic break calculation
│   │       ├── TimeBlockStrategy.swift # Fixed block with optional check-in
│   │       └── StopwatchStrategy.swift # Ascending count with no target
│   │
│   ├── Tasks/
│   │   ├── TaskListFeature.swift       # Reducer: CRUD, filters, ordering, recurrence
│   │   ├── TaskListView.swift          # Task list with energy filters
│   │   ├── TaskDetailFeature.swift     # Reducer: individual task editing
│   │   └── TaskDetailView.swift        # Detail/edit view
│   │
│   ├── Analytics/
│   │   ├── AnalyticsFeature.swift      # Reducer: productivity dashboard
│   │   ├── AnalyticsView.swift         # Charts by mode, trends
│   │   ├── WeeklyReviewFeature.swift   # Reducer: weekly review comparison
│   │   ├── WeeklyReviewView.swift      # Week-over-week comparison
│   │   ├── MonthlyReviewFeature.swift  # Reducer: monthly review
│   │   ├── MonthlyReviewView.swift     # Monthly review view
│   │   ├── AIReportFeature.swift       # Reducer: AI report generation
│   │   ├── AIReportView.swift          # AI report view
│   │   ├── TaskAnalyticsFeature.swift  # Reducer: per-task analytics
│   │   ├── TaskAnalyticsView.swift     # Focus time per task
│   │   └── AchievementsView.swift      # Achievements/badges view
│   │
│   ├── Calendar/
│   │   ├── CalendarFeature.swift       # Reducer: calendar integration
│   │   └── CalendarView.swift          # Calendar view with sessions
│   │
│   ├── Auth/
│   │   ├── AuthFeature.swift           # Reducer: auth flow, initial upload, merge dialog, initial sync (NEW)
│   │   ├── AuthView.swift              # Auth view with merge dialog sheet (NEW)
│   │   └── DataMergeView.swift         # SwiftUI merge dialog: upload local vs download cloud (NEW)
│   │
│   ├── Account/
│   │   ├── AccountView.swift           # `More` tab hub for auth, billing, settings, export and support
│   │   ├── ExportView.swift            # Export surface launched from More
│   │   └── HelpSupportView.swift       # Help and support surface launched from More
│   │
│   ├── Profile/
│   │   ├── ProfileFeature.swift        # Reducer: full profile screen launched from More
│   │   ├── ProfileView.swift           # Profile screen with auth/account context
│   │   ├── EditProfileFeature.swift    # Local-first profile editing orchestration
│   │   └── EditProfileView.swift       # Manual edit flow for name, email, birth date and photo
│   │
│   ├── Settings/
│   │   ├── SettingsFeature.swift       # Reducer: global configuration + dirty tracking per preference key (ENHANCED)
│   │   ├── SettingsView.swift          # Settings view
│   │   ├── AboutFeature.swift          # Reducer: about / legal
│   │   └── AboutView.swift             # About view
│   │
│   ├── Paywall/
│   │   ├── PaywallFeature.swift        # Reducer: subscription with RevenueCat
│   │   └── PaywallView.swift           # Paywall view
│   │
│   └── Onboarding/
│       └── OnboardingView.swift        # Onboarding flow
│
├── Shared/
│   ├── Design/
│   │   ├── AppTheme.swift              # 4 themes: Classic, Forest, Ocean, Sunset
│   │   ├── ModeColors.swift            # Accent colors per focus mode
│   │   ├── GlassModifier.swift         # Glassmorphism effects
│   │   ├── HapticManager.swift         # Haptic feedback
│   │   ├── CelebrationView.swift       # Celebration animations
│   │   └── iPadSheetModifier.swift     # iPad sheet modifier
│   │
│   ├── Extensions/
│   │   ├── Date+Extensions.swift       # Date extensions
│   │   ├── Duration+Formatting.swift   # Duration formatting (mm:ss, hh:mm)
│   │   ├── ConditionalAnimation.swift  # Conditional animations (Reduce Motion)
│   │   └── PressableButtonStyle.swift  # Button style with tactile feedback
│   │
│   ├── Persistence/
│   │   └── SwiftDataPersistenceService.swift  # Preference key-value mapper, batch deletes (ENHANCED)
│   │
│   ├── Sounds/
│   │   └── SoundscapeManager.swift     # Actor: AVAudioEngine for ambient sounds
│   │
│   ├── HandoffActivity.swift           # Device handoff support
│   └── NotificationDelegate.swift      # UNUserNotificationCenterDelegate
│
├── PepinilloWatch/                     # watchOS companion app
│   ├── PepinilloWatchApp.swift         # @main entry point watchOS
│   ├── Features/
│   │   └── WatchDashboardFeature.swift # TCA: timer + tasks + dashboard
│   └── Views/
│       └── WatchDashboardView.swift    # Watch main view
│
├── PepinilloWidget/                    # WidgetKit (home + lock screen)
│   ├── FocusWidget.swift               # Active focus session widget
│   ├── FocusWidgetProvider.swift       # Focus TimelineProvider
│   ├── FocusWidgetViews.swift          # Small/medium/large views
│   ├── FocusWidgetModels.swift         # Widget models
│   ├── TasksWidget.swift              # Task list widget
│   ├── TasksWidgetProvider.swift       # Tasks TimelineProvider
│   ├── TasksWidgetViews.swift          # Task views
│   ├── DashboardWidget.swift          # Daily dashboard widget
│   ├── DashboardWidgetProvider.swift   # Dashboard TimelineProvider
│   ├── DashboardWidgetViews.swift      # Dashboard views
│   └── WidgetIntents.swift             # Interactive widget configuration
│
├── PepinilloLiveActivity/             # Dynamic Island + Live Activity
│   ├── FocusLiveActivityWidget.swift   # Live Activity widget
│   ├── FocusLiveActivityView.swift     # Dynamic Island views
│   ├── FocusActivityAttributes.swift   # Activity attributes
│   └── LiveActivityManager.swift       # Lifecycle management
│
├── PepinilloIntents/                   # App Intents (Siri)
│   ├── StartFocusIntent.swift          # "Start deep work in Pepinillo"
│   ├── PauseFocusIntent.swift          # "Pause my focus session"
│   ├── CheckStatsIntent.swift          # "How much did I focus today?"
│   ├── GetInsightsIntent.swift         # "Show my productivity insights"
│   ├── GetModeSuggestionIntent.swift   # "Which mode should I use?"
│   ├── GetWeeklyReportIntent.swift     # "Show my weekly report"
│   └── FocusFilterIntent.swift         # System Focus Modes integration
│
├── ControlCenterExtension/            # iOS 18+ Control Center widget
│   └── PepinilloControlCenter.swift    # ControlWidgetToggle: start/stop session
│
├── Tests/
│   ├── FocusFeatureTests/
│   │   ├── FocusFeatureReducerTests.swift    # Focus reducer tests
│   │   ├── FocusModeStrategyTests.swift      # 4 strategy tests
│   │   └── SessionJournalFeatureTests.swift  # Post-session journal tests
│   ├── TaskFeatureTests/
│   │   └── TaskListFeatureTests.swift        # Task CRUD tests
│   ├── AnalyticsFeatureTests/
│   │   ├── AnalyticsFeatureTests.swift       # Analytics tests
│   │   └── InsightsServiceTests.swift        # Insights service tests
│   ├── PaywallFeatureTests/
│   │   └── PaywallFeatureTests.swift         # Paywall tests
│   ├── ModeIntelligenceTests/
│   │   └── ModeIntelligenceTests.swift       # Mode suggestion tests
│   ├── SiriIntentsTests/
│   │   └── SiriIntentsTests.swift            # Intents tests
│   ├── WidgetTests/
│   │   └── FocusWidgetProviderTests.swift    # Timeline provider tests
│   ├── WatchFeatureTests/
│   │   └── WatchTimerFeatureTests.swift      # Watch tests
│   └── IntegrationTests/
│       └── AppFeatureIntegrationTests.swift  # Integration tests
│
└── Package.swift                       # SPM dependencies
```

### Current iPhone Shell and Account Ownership

| Surface | Runtime ownership |
| ------- | ----------------- |
| `Focus` | Hero execution surface |
| `Plan` | Task planning, detail and daily shaping |
| `Dashboard` | Analytics, reviews, calendar entry, AI report entry |
| `More` | Auth, profile, subscription, settings, export, help/support and about |

- `More` is the current phone label for the Account / Admin surface.
- `Calendar`, `Weekly Review`, `Monthly Review`, and `AI Report` are contextual flows reached from `Dashboard` or root sheet routing, not primary tabs.
- Regular-width layouts still switch to split navigation; the 4-tab shell is the current iPhone runtime baseline.

---

## 4. Data Models (SwiftData)

All models use the `@Model` macro from SwiftData and sync automatically via CloudKit (private database). The shared container via App Group (`group.com.pepinillo.app`) allows access from widgets, intents, and the Watch app.

### 4.1 TaskItem

User task. Supports recurrence, energy levels, linking with focus sessions, and subtasks.

```swift
@Model
public final class TaskItem {
    // Identification
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date

    // Content
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var completedAt: Date?

    // Organization
    public var priority: TaskPriority        // .none(0), .low(1), .medium(2), .high(3)
    public var sortOrder: Int
    public var energyLevel: EnergyLevel      // .deep, .shallow, .admin
    public var dueDate: Date?
    public var scheduledForToday: Bool

    // Focus integration
    public var estimatedPomodoros: Int
    public var completedPomodoros: Int
    public var preferredMode: String?        // FocusMode.rawValue suggested by ModeIntelligence

    // Recurrence (iCalendar RRULE)
    public var recurrenceRule: String?        // e.g.: "FREQ=DAILY", "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    public var nextOccurrence: Date?
    public var isRecurringTemplate: Bool
    public var recurringTemplateID: UUID?     // for generated instances

    // Relationships
    @Relationship(deleteRule: .cascade) var subtasks: [SubTask]
    @Relationship(inverse: \FocusSessionRecord.task) var sessions: [FocusSessionRecord]

    // Computed
    var totalFocusTime: TimeInterval         // sum of completed sessions
    var completionPercentage: Double          // completedPomodoros / estimatedPomodoros
    var subtaskProgress: (completed: Int, total: Int)
}
```

**Supporting enums:**

- `TaskPriority`: `.none(0)`, `.low(1)`, `.medium(2)`, `.high(3)` -- `Codable, Comparable`
- `EnergyLevel`: `.deep`, `.shallow`, `.admin` -- deep work classification (Cal Newport)
- `RecurrencePreset`: `.daily`, `.weekdays`, `.weekly`, `.biweekly`, `.monthly` -- recurrence presets with next date calculation

### 4.2 FocusSessionRecord

Persisted record of a completed or abandoned focus session. One record per session.

```swift
@Model
public final class FocusSessionRecord {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?

    // Mode and phase
    public var mode: String                  // "pomodoro", "flowtime", "timeBlock", "stopwatch"
    public var phase: String                 // "work", "shortBreak", "longBreak", "flow", "block", "freeform"

    // Duration
    public var targetDuration: TimeInterval? // nil for Flowtime/Stopwatch
    public var actualDuration: TimeInterval  // actual focus time

    // Completion
    public var wasCompleted: Bool            // completed naturally vs abandoned
    public var interruptions: Int

    // Pauses
    public var pauseCount: Int
    public var totalPauseDuration: TimeInterval

    // Pomodoro-specific
    public var pomodoroNumber: Int?          // e.g.: 3 (of 4)

    // Post-session journal
    public var journalNote: String?
    public var satisfactionRating: Int?      // 1-5 (emoji-based)

    // Relationship
    public var task: TaskItem?
}
```

### 4.3 DailyStats

Aggregated daily statistics. One record per day. Includes per-mode breakdown for unique analytics.

```swift
@Model
public final class DailyStats {
    public var id: UUID
    public var date: Date                    // normalizado a medianoche

    // Totals
    public var totalFocusSeconds: Int
    public var sessionsCompleted: Int
    public var tasksCompleted: Int
    public var longestStreak: Int            // Sessions consecutivas sin interrupcion

    // Per-mode breakdown (seconds + count)
    public var pomodoroSeconds: Int
    public var flowtimeSeconds: Int
    public var timeBlockSeconds: Int
    public var stopwatchSeconds: Int
    public var pomodoroCount: Int
    public var flowtimeCount: Int
    public var timeBlockCount: Int
    public var stopwatchCount: Int

    // Streak
    public var hadFocusSession: Bool         // focused at least once today

    // Computed
    var totalFocusMinutes: Int
    var totalFocusHours: Double
    var dominantMode: FocusMode?             // mode with most seconds
    var modeDistribution: [FocusMode: Double] // percentages
}
```

### 4.4 ProductivityReport

AI-generated productivity report (or template fallback), cached in SwiftData.

```swift
@Model
public final class ProductivityReport {
    public var id: UUID
    public var period: String                // "week" o "month"
    public var periodStart: Date
    public var periodEnd: Date
    public var generatedAt: Date
    public var title: String
    public var highlightsJSON: String         // JSON [String]
    public var insightsJSON: String           // JSON [ReportInsight]
    public var recommendationsJSON: String    // JSON [String]
    public var rawPayload: String            // JSON del payload enviado a IA (debug)
}
```

**Supporting types:**

- `ReportInsight`: `{ category: "pattern"|"improvement"|"achievement", text: String }`
- `AIReportResponse`: DTO for the report generator response
- `ProductivityReportDTO`: `Sendable` struct for crossing concurrency boundaries

### 4.5 UserPreferences

User preferences synced via CloudKit. A single record per user.

```swift
@Model
public final class UserPreferences {
    public var id: UUID

    // Pomodoro configuration
    public var pomodoroDuration: TimeInterval       // default: 25 min
    public var shortBreakDuration: TimeInterval      // default: 5 min
    public var longBreakDuration: TimeInterval       // default: 15 min
    public var pomodorosPerCycle: Int                 // default: 4
    public var autoStartBreaks: Bool                  // default: true
    public var autoStartWork: Bool                    // default: false

    // Time Block configuration
    public var defaultBlockDuration: TimeInterval    // default: 60 min
    public var blockMidpointCheckIn: Bool             // default: false

    // Flowtime configuration
    public var flowtimeMinSessionMinutes: Int         // default: 5
    public var flowtimeShowBreakSuggestion: Bool      // default: true

    // General
    public var soundEnabled: Bool
    public var hapticEnabled: Bool
    public var keepScreenOn: Bool
    public var defaultMode: String                   // FocusMode.rawValue

    // Theme
    public var themeName: String                     // "default", "forest", "ocean", "sunset"
    public var followSystemAppearance: Bool

    // Notifications
    public var dailyReminderEnabled: Bool
    public var dailyReminderHour: Int                // 0-23
    public var dailyReminderMinute: Int              // 0-59

    // Onboarding
    public var hasCompletedOnboarding: Bool

    // Streak
    public var currentStreakDays: Int
    public var longestStreakDays: Int
    public var lastFocusDate: Date?

    // Apple Health
    public var healthLoggingEnabled: Bool

    // Subscription (local cache -- source of truth is StoreKit)
    public var isProUser: Bool
    public var subscriptionExpiresAt: Date?

    // ADHD-friendly mode
    public var adhdFriendlyEnabled: Bool

    // Calendar
    public var calendarIntegrationEnabled: Bool

    // Sign in with Apple
    public var appleUserID: String?
    public var displayName: String?
    public var userEmail: String?

    // Computed
    var focusConfig: FocusConfig                     // converts to value type for FocusEngine
}
```

### 4.6 Achievement

Predefined achievements with progress tracking. Enum without SwiftData persistence -- progress is calculated in real time from `FocusSessionRecord` and `DailyStats`.

```swift
enum Achievement: String, CaseIterable {
    case firstSession      // "First Focus" -- 1 completed session
    case weekStreak        // "Week Warrior" -- 7-day streak
    case pomodoroMaster    // "Pomodoro Master" -- 100 pomodoros
    case deepDiver         // "Deep Diver" -- 10 deep work sessions
    case centuryClub       // "Century Club" -- 100 total sessions
    case earlyBird         // "Early Bird" -- 10 sessions before 8am
}
```

### 4.7 SubTask

Subtask within a TaskItem.

```swift
@Model
public final class SubTask {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var parent: TaskItem?
}
```

---

## 5. Focus Engine (FocusEngine)

The FocusEngine is the most critical component of the application. It is a **Swift Actor** that safely (thread-safe) manages the unified timer for all 4 focus modes.

### Architecture

```
┌───────────────────────────────────────────────────────┐
│                    FocusFeature (TCA)                  │
│     Consumes AsyncStream<FocusEngineEvent>              │
│     Translates events to State + dispatches Effects     │
└─────────────────────┬─────────────────────────────────┘
                      │ start / pause / resume / stop
                      v
┌───────────────────────────────────────────────────────┐
│                 FocusEngine (actor)                    │
│                                                       │
│  ┌──────────────┐    ┌─────────────────────────┐      │
│  │ Strategy     │    │ Timing Loop (10 Hz)     │      │
│  │ (protocol)   │    │ Date.now - phaseStart   │      │
│  │              │    │ - totalPausedDuration    │      │
│  │ Pomodoro     │    │                         │      │
│  │ Flowtime     │    │ Emits: tick, phase,     │      │
│  │ TimeBlock    │    │ completed, interrupted  │      │
│  │ Stopwatch    │    └─────────────────────────┘      │
│  └──────────────┘                                     │
└───────────────────────────────────────────────────────┘
```

### Strategy Pattern (FocusModeStrategy)

Protocol that all 4 modes implement. The engine delegates all mode-specific logic to the active strategy.

```swift
protocol FocusModeStrategy: Sendable {
    var mode: FocusMode { get }
    var direction: TimerDirection { get }     // .countDown o .countUp
    var hasTarget: Bool { get }              // true: Pomodoro/TimeBlock, false: Flowtime/Stopwatch
    var supportsAutoAdvance: Bool { get }    // avance automatico entre fases

    func targetDuration(config: FocusConfig, phase: FocusPhase) -> TimeInterval?
    func initialPhase(config: FocusConfig) -> FocusPhase
    func nextPhase(after phase: FocusPhase, elapsed: TimeInterval, config: FocusConfig) -> FocusPhase?
    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval
}
```

### The 4 Strategies

| Strategy              | Direction | Target            | Auto-advance | Phases                                                   |
| --------------------- | --------- | ----------------- | ------------ | -------------------------------------------------------- |
| **PomodoroStrategy**  | countDown | Yes (25 min)      | Yes          | work(n/total) -> shortBreak -> work -> ... -> longBreak  |
| **FlowtimeStrategy**  | countUp   | No                | No           | flow (open-ended, with dynamic break suggestion)         |
| **TimeBlockStrategy** | countDown | Yes (configurable)| No           | block (continuous block, optional mid-point check-in)    |
| **StopwatchStrategy** | countUp   | No                | No           | freeform (just counts)                                   |

**Flowtime break formula:**

- < 25 min focus -> 5 min break
- < 50 min -> 8 min
- < 90 min -> 10 min
- >= 90 min -> 15 min

### Date-Based Timing (drift-free)

The engine uses **date arithmetic** (`Date.now - phaseStartDate - totalPausedDuration`) instead of `Timer.scheduledTimer`. This eliminates the cumulative drift that occurs with interval-based timers, especially when the app goes to and returns from background.

### Engine Events

```swift
public enum FocusEngineEvent: Sendable {
    case tick(FocusSessionState)              // every 100ms: updated state
    case phaseCompleted(FocusPhase)           // phase completed (e.g.: work -> break)
    case sessionCompleted(FocusSessionResult) // session finished
    case breakSuggested(duration: TimeInterval) // Flowtime: break suggestion
    case midpointReached                      // TimeBlock: block midpoint
    case interrupted                          // interruption recorded
}
```

The `FocusFeature` reducer consumes these events via `AsyncStream` and reactively updates UI state, notifications, Live Activity, and Watch.

### Pause Management

The engine tracks pauses by preserving the exact phase that was active before pausing (`phaseBeforePause`). On resume, it restores the correct phase and adjusts `totalPausedDuration` so the elapsed time calculation remains accurate.

### Background Strategy

1. App enters background -> schedules `UNNotificationRequest` for the end time (countdown modes) or as a periodic reminder (count-up modes).
2. Live Activity continues showing countdown/count-up (managed by the system).
3. App returns to foreground -> recalculates elapsed time from `phaseStartDate`.
4. watchOS -> `ExtendedRuntimeSession` to keep the timer active.

### Extensibility

Adding a 5th mode (e.g.: 52/17 technique) requires only a new struct conforming to `FocusModeStrategy`. Zero changes to the engine, Live Activity, Widget, or Watch.

---

## 6. TCA Clients (@DependencyClient)

All clients follow the TCA `@DependencyClient` pattern. They are `Sendable` structs with closures that abstract the real implementation, allowing mock injection in tests.

### SwiftData <-> TCA Bridge

SwiftData `@Model` classes are not `Sendable` and are bound to `@MainActor`. The `PersistenceClient` resolves this with DTOs (Data Transfer Objects):

```
@Model (SwiftData, @MainActor) --> MainActor.run { } --> DTO (Sendable, value type) --> TCA Effect
```

### Client List

| #   | Client                      | Responsibility                                                                                                                                                                                |
| --- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **PersistenceClient**       | SwiftData CRUD: Tasks, Sessions, stats, preferences. All operations via `MainActor.run {}` returning `Sendable` DTOs. Enhanced with settings sync, deleteAll, and counts.                    |
| 2   | **FocusClient**             | Bridge between TCA and the `FocusEngine` actor. Starts/pauses/resumes/stops sessions. Exposes `AsyncStream<FocusEngineEvent>` for the reducer.                                               |
| 3   | **WatchConnectivityClient** | Bidirectional `WCSession` communication. iOS sends: `WatchSessionState` (each tick), stats, tasks. Watch sends: `WatchCommand`.                                                              |
| 4   | **AIReportClient**          | Generates productivity reports. Tries first with `OnDeviceReportGenerator` (Foundation Models, iOS 26+), fallback to `TemplateReportGenerator`.                                               |
| 5   | **NotificationClient**      | `UNUserNotificationCenter` wrapper. Schedules session-end notifications, daily reminders, break suggestions.                                                                                  |
| 6   | **SubscriptionClient**      | RevenueCat SDK v5+. Queries offerings/packages, makes purchases via StoreKit 2, restores transactions, verifies entitlements. Supports configure/logIn/logOut flow for user identification.   |
| 7   | **SoundscapeClient**        | Ambient sound playback during focus sessions. `SoundscapeManager` actor with `AVAudioEngine`. 8 soundscapes included.                                                                        |
| 8   | **CalendarClient**          | EventKit event reading. Shows calendar events alongside scheduled focus sessions.                                                                                                             |
| 9   | **HealthClient**            | Writes `HKCategorySample` of type `.mindfulSession` to Apple Health on session completion. Requests authorization explicitly.                                                                  |
| 10  | **SignInWithAppleClient**   | Authentication flow with `ASAuthorizationAppleIDProvider`. Stores `appleUserID`, name, and email in `UserPreferences`.                                                                        |
| 11  | **SpotlightClient**         | Indexes tasks in CoreSpotlight for system search. Updates the index on task create/edit/delete.                                                                                               |
| 12  | **LiveActivityClient**      | Manages Live Activities via `ActivityKit`. Starts, updates, and ends activities. Adapts Dynamic Island presentation per focus mode.                                                            |
| 13  | **APIClient** (NEW)         | URLSession-based REST client with JWT authentication, 5 new endpoints (preferences, sync/sessions, sync/initial-upload, sync/full). Auto-refresh on 401.                                      |
| 14  | **SyncClient** (NEW)        | Sync orchestration: syncSettings(), batch syncSessions(), initialUpload(), performInitialSync() (cursor pagination), wipeAndSync(), hasLocalData().                                           |
| 15  | **IdentityClient** (NEW)    | Identity state machine managing ANONYMOUS/REGISTERED/VERIFIED transitions. Coordinates auth flow with sync operations.                                                                         |
| 16  | **WebSocketClient** (NEW)   | URLSessionWebSocketTask with exponential backoff (1s, 2s, 4s, 8s, max 30s). Receives notification-only messages that trigger HTTP sync. Connect/disconnect on foreground/background.          |
| 17  | **KeychainClient** (ENHANCED) | Keychain access with getOrCreateDeviceId for X-Device-ID header on all sync requests.                                                                                                       |

---

## 7. Services

Services contain pure business logic, with no dependency on TCA or UI frameworks.

| Service                     | Responsibility                                                                                                                                                                                                                |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ModeIntelligenceService** | Analyzes historical `FocusSessionRecord` per task. Calculates `completionRateByMode` and `averageDurationByMode`. Returns `SuggestedMode` with confidence level (>70% to show suggestion).                                    |
| **InsightsService**         | Calculates trends, patterns, peak productivity hours, best day of the week, and week-over-week comparisons from `DailyStats`.                                                                                                 |
| **OnDeviceReportGenerator** | Generates productivity reports using Apple Foundation Models (`FoundationModels` framework, iOS 26+). Sends a prompt with aggregated data and parses the JSON response. Fails gracefully if the model is unavailable.          |
| **TemplateReportGenerator** | Fallback when Foundation Models is unavailable. Generates template-based reports with conditional logic (e.g.: "Your completion rate went up 15%").                                                                            |
| **ReportDataBuilder**       | Builds the `ReportPayload` by aggregating data from `DailyStats`, `FocusSessionRecord`, and `TaskItem` for the requested period (weekly/monthly).                                                                             |
| **WeeklyReportService**     | Orchestrates weekly report generation: builds payload via `ReportDataBuilder`, tries `OnDeviceReportGenerator`, fallback to `TemplateReportGenerator`, persists in `ProductivityReport`.                                       |
| **RemindersImportService**  | Imports tasks from Apple Reminders via `EventKit.EKEventStore`. One-way import (no continuous sync). Requests access explicitly.                                                                                               |

---

## 8. watchOS

### Communication Architecture

The Watch app communicates with iOS via `WCSession` (WatchConnectivity framework). The same file `WatchConnectivityClient.swift` compiles in both targets (iOS and watchOS), using `#if os(iOS)` for methods required only on one side.

### Data Flow iOS -> Watch

```
iOS (FocusFeature)
  |-- each tick: sendSessionState(WatchSessionState)
  |     isActive, isPaused, modeID, displayTime, phaseLabel,
  |     progress, pomodoroNumber, linkedTaskTitle, isPhaseTransition
  |
  |-- on session completion: sendStats(todayMinutes, sessions, streak)
  |
  |-- on app launch / task change: sendTasks([WatchTaskItem])
  |     id, title, isCompleted, priority, estimatedPomodoros, completedPomodoros
  |
  |-- on demand: sendDashboardStats(WatchDashboardStats)
        todayMinutes, sessionsCompleted, tasksCompleted, tasksTotal,
        streakDays, pomodoroMinutes, flowtimeMinutes, timeBlockMinutes,
        stopwatchMinutes, longestSessionMinutes
```

### Data Flow Watch -> iOS

```
Watch (WatchDashboardFeature)
  |-- WatchCommand:
  |     .startSession(mode: String)
  |     .pauseSession
  |     .resumeSession
  |     .stopSession
  |     .skipPhase
  |     .linkTask(id: String)
  |     .unlinkTask
  |     .toggleTaskCompleted(id: String)
  |     .requestTasks
  |     .requestDashboard
```

### Transport Protocol

- **`sendMessage`** for real-time communication (both devices active, Watch reachable).
- **`updateApplicationContext`** for background sync (persistent state).
- **`transferCurrentComplicationUserInfo`** for complication updates.
- All messages use `[String: Any]` with a `"type"` field as discriminator.

### Source of Truth

When both devices are active, **iOS is the source of truth**. The Watch displays the received state and sends commands; it does not maintain its own independent timer while iOS is connected.

### Independent Watch Features

- **Remote timer:** shows countdown/count-up received from iOS.
- **Dashboard:** daily statistics, per-mode breakdown, streak.
- **Task list:** active tasks with completion toggle.
- **Mode selector:** start a session in any of the 4 modes.

### Complications

| Type        | Content                                            |
| ----------- | -------------------------------------------------- |
| Circular    | Active session countdown or daily focus time        |
| Rectangular | Timer + linked task name                           |
| Corner      | Session count: "3/4"                               |

---

## 9. Ecosystem Extensions

### 9.1 WidgetKit (Home Screen + Lock Screen)

Three widget families:

| Widget              | Sizes                | Content                                                 |
| ------------------- | -------------------- | ------------------------------------------------------- |
| **FocusWidget**     | small, medium, large | Active session (mode, time, progress) or "Start Focus"  |
| **TasksWidget**     | small, medium        | Today's pending tasks with priority                     |
| **DashboardWidget** | small, medium, large | Daily statistics: time, sessions, streak                |

- Lock screen widgets: compact circular and inline versions.
- Interactive configuration via `WidgetIntents.swift`.
- Shared data via App Group container.

### 9.2 ActivityKit (Dynamic Island + Live Activity)

```swift
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var remainingSeconds: Int?        // nil para count-up
        var focusMode: String
        var phase: String
        var taskName: String?
        var progress: Double?             // 0.0-1.0 para countdown
        var pomodoroNumber: Int?
        var totalPomodoros: Int?
    }
    var startedAt: Date
    var targetDuration: TimeInterval?
    var focusMode: String
}
```

**Per-mode adaptation in Dynamic Island:**

| Mode       | Icon      | Display                                    |
| ---------- | --------- | ------------------------------------------ |
| Pomodoro   | Timer     | Countdown + "3 of 4" + progress ring       |
| Flowtime   | Wind      | Count-up + "Take a break" suggestion       |
| Time Block | Rectangle | Countdown + linear progress bar            |
| Stopwatch  | Stopwatch | Count-up + minimal chrome                  |

All modes: tap to open the app, long-press for pause/stop.

### 9.3 App Intents (Siri Shortcuts)

7 intents available in 3 languages (EN, ES, PT):

| Intent                    | Example Phrases                                    |
| ------------------------- | -------------------------------------------------- |
| `StartFocusIntent`        | "Start deep work in Pepinillo", "Start a Pomodoro" |
| `PauseFocusIntent`        | "Pause my focus session"                           |
| `CheckStatsIntent`        | "How much did I focus today?"                      |
| `GetInsightsIntent`       | "Show my productivity insights"                    |
| `GetModeSuggestionIntent` | "Which focus mode should I use?"                   |
| `GetWeeklyReportIntent`   | "Show my weekly report"                            |
| `FocusFilterIntent`       | System Focus Modes integration (iOS)               |

The `FocusFilterIntent` allows system Focus Modes (e.g.: "Do Not Disturb", "Work") to automatically activate/deactivate sessions in Pepinillo.

Task entities (`TaskEntityQuery`) query the App Group ModelContainer to suggest real user tasks.

### 9.4 Control Center (iOS 18+)

`ControlWidgetToggle` that allows starting/stopping the active focus session directly from the Control Center without opening the app.

### 9.5 Handoff

Support for continuing sessions on another Apple device via `NSUserActivity`. If the user is focused on iPhone, they can continue on iPad or Mac.

### 9.6 Spotlight

CoreSpotlight indexes all tasks for system search. The index is updated on task create, edit, or delete.

---

## 10. Synchronization

### Sync Architecture (Implemented 2026-03-24)

The iOS sync system is built with TCA dependency clients and follows an **offline-first** design where SwiftData is always the source of truth. The Go backend provides cross-platform sync while CloudKit is retained as a secondary layer for Apple-to-Apple device sync.

#### Core Design Principles

- **Source of Truth**: SwiftData (local)
- **Sync Pattern**: TCA-based clients with PreferenceDirtyTracker (UserDefaults-based)
- **Conflict Resolution**: Record-level Last-Write-Wins (LWW) with detection
- **Transport**: HTTPS (URLSession) + WebSocket (URLSessionWebSocketTask) notifications
- **Protocol Order**: Settings -> Tasks -> Sessions (batch) -> Stats (pull)

#### New TCA Sync Clients

| Client              | File                         | Responsibility                                                                           |
| ------------------- | ---------------------------- | ---------------------------------------------------------------------------------------- |
| **SyncClient**      | `SyncClient.swift`           | Orchestrates all sync: syncSettings(), syncSessions() (batch), initialUpload(), performInitialSync() (cursor pagination), wipeAndSync(), hasLocalData() |
| **IdentityClient**  | `IdentityClient.swift`       | State machine managing ANONYMOUS/REGISTERED/VERIFIED transitions                          |
| **WebSocketClient** | `WebSocketClient.swift`      | URLSessionWebSocketTask with exponential backoff (1s, 2s, 4s, 8s, max 30s)               |
| **APIClient**       | `APIClient.swift`            | URLSession REST client with JWT auth; 5 new endpoints for sync                            |
| **KeychainClient**  | `KeychainClient.swift`       | Enhanced with getOrCreateDeviceId for X-Device-ID header                                  |

#### Settings Sync with PreferenceDirtyTracker

- **SettingsFeature** enhanced with dirty tracking per preference key
- **PreferenceDirtyTracker**: UserDefaults-based tracker that marks individual preference keys as dirty when changed
- **17 syncable keys**: pomodoro duration, break durations, auto-advance, theme, language, sound settings, etc.
- **5 device-specific keys excluded**: notification permissions, calendar sync toggle, DND toggle, onboarding completed, device-specific UI preferences
- **Per-key LWW**: each preference key has its own `updatedAt` timestamp; conflicts resolved at key level, not bulk

#### Batch Session Sync

Sessions use batch upload instead of individual POSTs for efficiency:

- `POST /sync/sessions` accepts an array of dirty sessions
- Backend recomputes `focus_stats` after batch insert
- Client UUIDs are preserved (server no longer overwrites session IDs)
- FocusSessionRecord includes full fields: `interruptions`, `pomodoroNumber`, `satisfactionRating`, `journalNote`

#### Anonymous User Flow

1. User installs app; `IdentityClient.state = ANONYMOUS`
2. All data stored locally in SwiftData (no backend calls)
3. App is fully functional (timer, tasks, analytics)
4. User decides to register; `POST /auth/register` via AuthFeature
5. `SyncClient.initialUpload()` triggered: `POST /sync/initial-upload` (atomic, all local data)
6. `IdentityClient.state = REGISTERED`
7. Normal sync resumes (periodic + real-time)

#### Initial Upload on Registration

When an anonymous user registers, `SyncClient.initialUpload()` performs an atomic upload:

- `POST /sync/initial-upload` sends all local tasks, sessions, stats, and preferences in one request
- Backend processes atomically (all-or-nothing)
- On success, all local entities are marked synced

#### New Device Full Sync

When a registered user logs in on a new device:

- `SyncClient.performInitialSync()` calls `GET /sync/full` with cursor-based pagination
- Downloads all user data page by page
- `SyncClient.wipeAndSync()` clears local SwiftData, then pages through all data
- Cursor pagination avoids memory issues with large datasets
- After completion, normal sync resumes

#### Data Merge Dialog (Anonymous to Existing Account)

When an anonymous user logs into an account that already has data, `DataMergeView` (SwiftUI) presents two options:

- **Upload Local**: keep anonymous data and push it to the cloud via `SyncClient.initialUpload()`
- **Download Cloud**: replace local data with cloud data via `SyncClient.wipeAndSync()`
- Triggered in `AuthFeature` when login detects both local anonymous data and existing cloud data
- AuthView presents DataMergeView as a sheet

#### Real-Time Sync via WebSocket

- `WebSocketClient` uses `URLSessionWebSocketTask` (no third-party dependencies)
- Connects on app foreground, disconnects on background (managed by `AppFeature` scene phase handling in `PepinilloApp.swift`)
- Receives **notification-only** messages (e.g., `{ "type": "sync", "entity": "tasks" }`)
- WebSocket does NOT carry data payloads, only signals that trigger HTTP sync
- **X-Device-ID**: every sync HTTP request includes `X-Device-ID` header from `KeychainClient.getOrCreateDeviceId`; the backend WebSocket hub uses `SendToUserExcluding(userId, excludeDeviceId, msg)` to avoid notifying the device that originated the change
- **Reconnect strategy**: exponential backoff (1s, 2s, 4s, 8s, max 30s)

#### Auth Flow Integration

- **AuthFeature**: coordinates initial upload, merge dialog presentation, and initial sync wiring
- **AuthView**: presents merge dialog sheet via `DataMergeView`
- **AppFeature**: manages WebSocket lifecycle (connect on foreground, disconnect on background)
- **PepinilloApp**: background scene phase handling for WebSocket connect/disconnect

#### API Endpoints (iOS-Specific)

| Method | Endpoint                      | Description                                               |
| ------ | ----------------------------- | --------------------------------------------------------- |
| GET    | `/api/v1/preferences`         | Get user preferences (per-key LWW merge)                  |
| PUT    | `/api/v1/preferences`         | Update user preferences                                   |
| POST   | `/api/v1/sync/sessions`       | Batch session sync (replaces individual POSTs)            |
| POST   | `/api/v1/sync/initial-upload` | Atomic upload for anonymous-to-registered transition      |
| GET    | `/api/v1/sync/full`           | Cursor-based paginated full download for new device login |

#### API DTOs (9 New DTOs in APIDTOs.swift)

New DTOs added to support sync communication with the Go backend, including preference sync DTOs, session batch DTOs, initial upload DTOs, and full sync pagination DTOs.

#### Conflict Resolution

| Version          | Strategy          | Granularity  | Status      |
| ---------------- | ----------------- | ------------ | ----------- |
| **V1 (current)** | Last-Write-Wins   | Record-level | Implemented |
| **V2 (planned)** | Field-level merge | Field-level  | Planned     |

- V1: entire record is replaced by whichever version has the latest `updatedAt`
- V2 (future): individual fields compared and merged independently, reducing data loss on concurrent edits

### CloudKit (Secondary Sync Layer)

CloudKit is retained as a secondary sync layer for Apple-to-Apple device sync:

- **Private database**: only user data, encrypted at rest by Apple.
- **Automatic sync**: SwiftData configured with `cloudKitContainerIdentifier: "iCloud.com.pepinillo.app"`. No manual sync code.
- **Offline operation**: All operations write to the local SwiftData store first (instant). CloudKit syncs opportunistically when network is available.
- **Pending changes**: queued in `CKOperationGroup` until network is available.

### CloudKit Conflict Resolution

| Data type                       | Strategy                                                            |
| ------------------------------- | ------------------------------------------------------------------- |
| Scalar fields (title, status)   | Last-write-wins                                                     |
| Collections (subtasks)          | Additive merge (never delete remotely)                              |
| Automatic                       | SwiftData/CloudKit handles most via `CKRecord` merge policies       |

### App Group

Shared container `group.com.pepinillo.app` accessible from:

- Main app (iPhone/iPad/Mac)
- PepinilloWidget
- PepinilloLiveActivity
- PepinilloIntents
- PepinilloWatch
- ControlCenterExtension

---

## 11. On-Device AI

### Apple Foundation Models (iOS 26+)

The `OnDeviceReportGenerator` uses Apple's `FoundationModels` framework to generate productivity reports entirely on-device, without sending data to external servers.

**Flow:**

```
ReportDataBuilder          OnDeviceReportGenerator         TemplateReportGenerator
(aggregates data) -------->  (Foundation Models)  -----X---> (template fallback)
                               |                               |
                               v                               v
                        AIReportResponse                AIReportResponse
                               |                               |
                               └───────────> ProductivityReport (SwiftData)
```

**Availability check:**

```swift
func isAvailable() -> Bool {
    // only iOS 26+, only when the model is downloaded and ready
    SystemLanguageModel.default.availability == .available
}
```

**Use cases:**

- Weekly and monthly productivity reports
- Focus pattern analysis
- Personalized recommendations

**Privacy:** All processing occurs on-device. User data never leaves the device.

### Fallback: TemplateReportGenerator

When Foundation Models is unavailable (iOS < 26, model not downloaded, unsupported device), the system uses templates with conditional logic to generate reports based on pure statistical data.

---

## 12. Design

### Themes

4 built-in themes, managed via `AppTheme` environment key:

| Theme                 | Palette                         | Use                   |
| --------------------- | ------------------------------- | --------------------- |
| **Classic** (default) | Neutral tones + pickle green    | Base theme            |
| **Forest**            | Dark greens, browns             | Deep work, nature     |
| **Ocean**             | Blues, turquoises               | Calm, fluidity        |
| **Sunset**            | Oranges, pinks                  | Energy, warmth        |

### Accent Colors per Mode

Each focus mode has a unique accent color (defined in `ModeColors.swift`):

- Pomodoro: tomato red
- Flowtime: ocean blue
- Time Block: violet
- Stopwatch: green

### Visual Effects

- **Glassmorphism:** Frosted glass modifiers (`GlassModifier.swift`) for cards and surfaces.
- **Liquid Glass (iOS 26):** Apple's adaptive materials for the new iOS 26 aesthetic.
- **Celebration animations:** Particles and confetti on session/achievement completion (`CelebrationView.swift`).

### Haptic Feedback

`HapticManager` centralizes all haptic feedback:

- Session start/end
- Phase transition (work -> break)
- Task completion
- Achievement reached
- Button interactions

### Reduce Motion

All animations respect `UIAccessibility.isReduceMotionEnabled`. Animations are replaced by instant transitions via `ConditionalAnimation.swift`.

### Localization

3 languages via `Localizable.xcstrings`:

- English (EN) -- base language
- Spanish (ES)
- Portuguese (PT)

All strings use `String(localized:)` for native localization support.

---

## 13. Testing

### Framework

Swift Testing (`@Test` macro) para todos los tests. Compatible con Xcode 16+.

### TCA Test Pattern

```swift
@Test func pomodoroIniciaCuentaRegresiva() async {
    let clock = TestClock()
    let store = TestStore(
        initialState: FocusFeature.State(mode: .pomodoro),
        reducer: { FocusFeature() },
        withDependencies: { $0.continuousClock = clock }
    )

    await store.send(.startTapped) { $0.isRunning = true }
    await clock.advance(by: .seconds(1))
    await store.receive(.timerTicked) { $0.remainingSeconds = 1499 }
}
```

### 10 Test Suites

| Suite                      | File                               | Coverage                                                   |
| -------------------------- | ---------------------------------- | ---------------------------------------------------------- |
| FocusFeatureReducerTests   | `FocusFeatureReducerTests.swift`   | Focus reducer: all modes, pause, resume, stop              |
| FocusModeStrategyTests     | `FocusModeStrategyTests.swift`     | 4 strategies: phases, durations, auto-advance              |
| SessionJournalFeatureTests | `SessionJournalFeatureTests.swift` | Post-session journal                                        |
| TaskListFeatureTests       | `TaskListFeatureTests.swift`       | Task CRUD, filters, recurrence                             |
| AnalyticsFeatureTests      | `AnalyticsFeatureTests.swift`      | Dashboard, trends                                          |
| InsightsServiceTests       | `InsightsServiceTests.swift`       | Insights service                                           |
| PaywallFeatureTests        | `PaywallFeatureTests.swift`        | Paywall, RevenueCat mock                                   |
| ModeIntelligenceTests      | `ModeIntelligenceTests.swift`      | Mode suggestion                                            |
| SiriIntentsTests           | `SiriIntentsTests.swift`           | App Intents                                                |
| FocusWidgetProviderTests   | `FocusWidgetProviderTests.swift`   | Timeline provider                                          |
| WatchTimerFeatureTests     | `WatchTimerFeatureTests.swift`     | Watch feature                                              |
| AppFeatureIntegrationTests | `AppFeatureIntegrationTests.swift` | Root reducer integration                                   |

### Performance Criteria

| Metric                  | Target                               |
| ----------------------- | ------------------------------------ |
| Timer precision         | <= 100ms drift in 25 minutes         |
| Cold start              | < 1s on iPhone 14+                   |
| CloudKit sync           | < 10s for 100 tasks (Wi-Fi)          |

---

## 14. Dependencies

Philosophy: **minimal dependencies**. Use Apple frameworks for everything possible.

| Dependency                      | Version           | Purpose                          | Why external                                                             |
| ------------------------------- | ----------------- | -------------------------------- | ------------------------------------------------------------------------ |
| `swift-composable-architecture` | 1.17+             | State management and architecture | Core architecture, extensively tested, maintained by Point-Free          |
| `swift-dependencies`            | (included in TCA) | Dependency injection             | Required by TCA                                                          |
| `swift-snapshot-testing`        | 1.17+             | UI snapshot tests                | Point-Free testing ecosystem (test target only)                          |

**What we do NOT use (and why):**

- **RevenueCat SDK v5+:** Implemented to centralize subscription, entitlement, webhook, and user identification handling (via Sign in with Apple).
- **Firebase:** Private CloudKit for data, TelemetryDeck for analytics, Sign in with Apple for auth.
- **Alamofire/Moya:** URLSession is used directly for backend sync; CloudKit handles Apple-to-Apple sync automatically.
- **Realm/GRDB:** SwiftData is Apple's recommended framework with native CloudKit integration.

---

## 15. Security and Privacy

### Authentication

- **Sign in with Apple** as primary method, with email/password as alternative.
- The `appleUserID` is stored in `UserPreferences` (private CloudKit, encrypted).
- JWT tokens stored in **Keychain** (hardware-encrypted, protected by Secure Enclave).

### Data Storage

- **CloudKit private database:** All user data encrypted at rest by Apple.
- **SwiftData local:** File-level Data Protection (system encryption).
- **App Group container:** Shared only between targets of the same app (sandboxed).
- **Keychain:** JWT access/refresh tokens and device ID stored securely.

### Analytics

- **TelemetryDeck:** Privacy-respecting analytics. No PII (personally identifiable information) collected.
- **No tracking:** No third-party tracking frameworks used.

### Permissions

Only requested when the user explicitly opts in:

- **Notifications:** For session-end alerts and reminders
- **HealthKit:** For logging Mindful Minutes (opt-in in Settings)
- **EventKit:** For importing reminders (explicit user action)

**Not requested:** Camera, microphone, location, contacts, photos.

### App Transport Security

Enforced (HTTPS only). No custom HTTP endpoints.

### Privacy Nutrition Label

Minimal data collection for the App Store listing.

---

## 16. Accessibility

### VoiceOver

- Complete support on all platforms (iOS, iPadOS, macOS, watchOS).
- Custom accessibility labels for the timer circle, progress indicators, and session controls.
- Correct accessibility traits (`.button`, `.header`, `.updatesFrequently` for the timer).

### Dynamic Type

- All text scales with the system text size.
- Adaptive layouts that adjust to large and extra-large text sizes.

### Reduce Motion

- All animations respect `UIAccessibility.isReduceMotionEnabled`.
- Animations are replaced by instant transitions.
- Celebrations (confetti, particles) are disabled.

### Contrast

- Minimum contrast ratio of **4.5:1** for all text.
- High contrast mode support.
- Per-mode accent colors maintain the ratio in both light and dark themes.

### Haptic Feedback

- Alternative to purely visual indicators.
- Differentiated haptics by event type (start, pause, completion, achievement).
- Can be globally disabled in `UserPreferences.hapticEnabled`.

---

## 17. Targets and Platforms

### Target Distribution

| Target                     | Platform          | UI Framework       | Notes                                                     |
| -------------------------- | ----------------- | ------------------ | --------------------------------------------------------- |
| **Pepinillo** (main)       | iPhone, iPad, Mac | SwiftUI            | Main development target                                   |
| **PepinilloWatch**         | Apple Watch       | SwiftUI (WatchKit) | Companion app: remote timer, tasks, dashboard             |
| **PepinilloWidget**        | iPhone, iPad      | WidgetKit          | 3 families: Focus, Tasks, Dashboard (home + lock screen)  |
| **PepinilloLiveActivity**  | iPhone            | ActivityKit        | Dynamic Island + Live Activity banner                     |
| **PepinilloIntents**       | iPhone, iPad, Mac | App Intents        | 7 Siri intents in 3 languages                             |
| **ControlCenterExtension** | iPhone            | ControlWidget      | Toggle to start/stop session (iOS 18+)                    |

### Per-Platform Adaptations

| Platform           | Adaptation                                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **iPhone**         | Main target. All features available.                                                                                                                    |
| **iPad**           | Split View (`iPadSplitView.swift`), Stage Manager, adaptive layouts, physical keyboard shortcuts. Adaptive-size sheets (`iPadSheetModifier`).           |
| **Mac (Catalyst)** | Menu bar commands (`MacCommands.swift`), full window, sandbox entitlement. `#if os(macOS)` for platform-specific code.                                  |
| **watchOS**        | Simplified feature set: timer, tasks, dashboard, complications. Communication via WCSession. `ExtendedRuntimeSession` for alarm haptics.                |

### Shared Code

Domain models (`Domain/`), TCA features (`Features/`), services, and clients are shared across all platforms. Only views and platform-specific integrations differ by target.

### Identifiers

| Resource           | Identifier                 |
| ------------------ | -------------------------- |
| Bundle ID          | `com.pepinillo.app`        |
| App Group          | `group.com.pepinillo.app`  |
| CloudKit Container | `iCloud.com.pepinillo.app` |

### Project Generation

The Xcode project is generated from `project.yml` via XcodeGen:

```bash
xcodegen generate  # regenerate after changes to project.yml
```

---

## 18. Backend and Server Integration

### 18.1 Go Backend Overview

Pepinillo's backend is a REST API written in **Go** with hexagonal architecture. It is **not yet deployed** to production and is under active development in `backend/`.

| Aspect             | Technology                        |
| ------------------ | --------------------------------- |
| **Language**       | Go                                |
| **HTTP Framework** | Fiber                             |
| **Database**       | PostgreSQL                        |
| **Authentication** | JWT (access + refresh tokens)     |
| **Architecture**   | Hexagonal (ports and adapters)    |
| **Status**         | In development, not deployed      |

#### Endpoint Groups

| Group         | Endpoints                                                                          | Description                                                  |
| ------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| **Auth**      | `POST /auth/login`, `POST /auth/register`, `POST /auth/google`, `POST /auth/apple` | Email/password authentication + OAuth (Google/Apple)          |
| **Tasks**     | `GET/POST/PUT/DELETE /api/v1/tasks`                                                | Task CRUD                                                    |
| **Sessions**  | `GET/POST /api/v1/pomodoro-sessions`                                               | Register and query focus sessions                            |
| **Stats**     | `GET /api/v1/stats/daily`, `GET /api/v1/stats/weekly`                              | Aggregated statistics (pending)                              |
| **Billing**   | `POST /api/v1/billing/verify`                                                      | Server-side receipt verification (App Store and Play Store)  |
| **Push**      | `POST /api/v1/push/register`                                                       | APNs token registration for push notifications               |
| **WebSocket** | `WS /api/v1/ws`                                                                    | Real-time sync channel                                       |
| **AI**        | `POST /api/v1/ai/report`                                                           | Productivity report generation                               |
| **Users**     | `GET /api/v1/users/me`, `PUT /api/v1/users/me`                                     | User profile                                                 |

#### Backend User Model

```go
type User struct {
    ID               uuid.UUID
    Email            string
    Name             string
    PasswordHash     string
    ImageURL         string
    BirthDate        time.Time
    SubscriptionTier string    // "free" | "pro"
    EmailVerified    bool
    CreatedAt        time.Time
    UpdatedAt        time.Time
}
```

### 18.2 Authentication Flow

iOS uses **Sign In with Apple** as the primary authentication method, with email/password as an alternative.

#### Sign In with Apple (primary method)

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│   iOS App    │     │  Apple Identity   │     │  Backend Go  │
│              │     │  Services         │     │              │
│              │     │                   │     │              │
│ 1. ASAutho-  │────►│ 2. Biometric       │     │              │
│    rization  │     │    authentication │     │              │
│    Controller│◄────│ 3. identityToken  │     │              │
│              │     │    + authCode     │     │              │
│              │     │                   │     │              │
│ 4. POST      │────────────────────────────►│ 5. Verifies   │
│    /auth/    │     │                   │     │    identity  │
│    apple     │     │                   │     │    Token with│
│              │     │                   │     │    Apple     │
│              │◄────────────────────────────│ 6. JWT access │
│              │     │                   │     │    + refresh  │
│ 7. Stores    │     │                   │     │              │
│    in        │     │                   │     │              │
│    Keychain  │     │                   │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘
```

**Detailed steps:**

1. The user taps "Continue with Apple" -> `ASAuthorizationAppleIDProvider` is presented via `SignInWithAppleClient`
2. Apple authenticates with Face ID / Touch ID / device password
3. Apple returns an `identityToken` (JWT signed by Apple) and an `authorizationCode`
4. The app sends `POST /auth/apple` with the `identityToken` in the body
5. The backend validates the token against Apple servers (verifies signature, audience, issuer)
6. If the user does not exist, it creates one; returns Pepinillo JWT (access + refresh token)
7. Tokens are stored in **Keychain** (hardware-encrypted, protected by Secure Enclave)

> **Note:** Apple only sends the user's name and email on the **first** authorization. The backend persists them at that point. On subsequent authorizations, only the `identityToken` is received.

#### Email/Password (alternative)

- `POST /auth/register` -> creates account with email + password
- `POST /auth/login` -> returns JWT access + refresh tokens
- Tokens stored in Keychain same as with Sign In with Apple

#### Token Management

| Token             | Storage  | Duration          | Renewal                      |
| ----------------- | -------- | ----------------- | ---------------------------- |
| **Access Token**  | Keychain | Short (15-30 min) | Automatic via refresh token  |
| **Refresh Token** | Keychain | Long (30 days)    | Requires re-login on expiry  |

The API client (based on `URLSession`) includes automatic renewal logic:

- Attaches the access token as `Authorization: Bearer <token>` on each request
- Detects `401 Unauthorized` responses
- Attempts to renew the access token using the refresh token
- If renewal fails, emits a TCA action that redirects to the login flow

#### Transition from Standalone Sign In with Apple

Currently, `SignInWithAppleClient` stores `appleUserID` in `UserPreferences` (CloudKit). With the backend:

1. `SignInWithAppleClient` continues obtaining the `identityToken` from Apple
2. Instead of only storing the `appleUserID` locally, it now also sends the token to the backend
3. The backend becomes the source of truth for user identity
4. `UserPreferences.appleUserID` is kept as a local cache for quick verification

### 18.3 Dual Sync Strategy

iOS maintains **two sync layers** in parallel during the transition to the backend:

#### Layer 1: SwiftData + CloudKit (Apple Sync)

The existing sync via `NSPersistentCloudKitContainer` **is kept** intact:

- Automatic sync between Apple devices of the same user (iPhone, iPad, Mac, Watch)
- No manual sync code — CloudKit manages it
- Low latency between Apple devices (~1-5 seconds)
- Works without backend (full offline mode)

#### Layer 2: Backend Sync (Cross-Platform Sync)

New sync layer with the Go backend to share data with Android:

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App                               │
│                                                              │
│  SwiftData ◄──► CloudKit       SwiftData ◄──► BackendSync  │
│  (Apple sync,   (automatic)    (same data)     (REST API    │
│   unchanged)                                    + WebSocket) │
│                                                              │
│  Priority: CloudKit for Apple-to-Apple sync                  │
│            Backend for cross-platform sync                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │  Backend Go  │
                    │  PostgreSQL  │
                    └──────────────┘
```

#### Migration Strategy for Existing CloudKit Users

Users who already have data in CloudKit need a migration to the backend:

| Step | Action                     | Detail                                                                     |
| ---- | -------------------------- | -------------------------------------------------------------------------- |
| 1    | Login with backend         | The user authenticates (Apple/email) for the first time                    |
| 2    | Local data detection       | The app detects that data exists in SwiftData/CloudKit                     |
| 3    | Initial upload             | All tasks, sessions, and stats are uploaded to the backend via batch API   |
| 4    | ID mapping                 | The `serverId` values returned by the backend are saved in local models    |
| 5    | Active sync                | From this point on, changes are synchronized bidirectionally               |

> **Important:** CloudKit remains the primary layer for Apple-to-Apple sync. The backend is an additional "mirror" for cross-platform. CloudKit is not removed.

#### WebSocket (Real-Time Sync)

The backend exposes `WS /api/v1/ws` to notify about remote changes:

- On connection, the client sends its JWT for authentication
- The backend emits events when another device (e.g.: Android) of the same user modifies data
- The iOS client receives the event and performs a selective pull
- Automatic reconnection with exponential backoff

#### BackgroundTasks (Fallback)

When WebSocket is unavailable, `BGAppRefreshTask` is used as a fallback:

- Registered with `BGTaskScheduler` for periodic execution (~15 minutes)
- Executes `SyncClient.syncAll()` for push/pull of pending changes
- Constraint: requires internet connection

### 18.4 Cross-Platform Subscriptions

Subscriptions are verified **server-side** to guarantee parity across platforms. A user who purchases PRO on iOS can use PRO on Android and vice versa.

#### Verification Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   iOS App    │     │  Backend Go  │     │  App Store   │
│              │     │              │     │  Server API  │
│ 1. user      │     │              │     │              │
│    purchases │     │              │     │              │
│    with      │     │              │     │              │
│    StoreKit 2│     │              │     │              │
│              │     │              │     │              │
│ 2. POST      │────►│ 3. Validates │────►│ 4. Verifies  │
│    /billing/ │     │    receipt   │     │    with App  │
│    verify    │     │    with App  │◄────│    Store     │
│              │     │    Store API │     │    Server    │
│              │     │              │     │    Notif. V2 │
│              │◄────│ 5. Updates   │     │              │
│              │     │    user.sub  │     │              │
│ 6. Caches    │     │    tier=pro  │     │              │
│    PRO local │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Detailed steps:**

1. The user completes the purchase via `SubscriptionClient` (RevenueCat SDK v5+, wrapping StoreKit 2)
2. The app sends `POST /api/v1/billing/verify` with the `originalTransactionID` and the `signedPayload` (JWS)
3. The backend validates the receipt against the App Store Server API (verifies JWS signature, subscription status)
4. App Store confirms the purchase is legitimate and active
5. The backend updates `User.SubscriptionTier = "pro"` in PostgreSQL
6. The app caches PRO status locally; all future checks query `GET /api/v1/users/me`

**Sources of truth:**

| Context            | Source                                                                                                    |
| ------------------ | --------------------------------------------------------------------------------------------------------- |
| **Cross-platform** | Backend (`User.SubscriptionTier`) — queried via `/users/me`                                               |
| **Apple only**     | RevenueCat local entitlements (`RevenueCat.shared.entitlements`) — works offline with cache                |
| **Hierarchy**      | Backend > RevenueCat entitlements. If backend says PRO (purchase on Android), the iOS app unlocks PRO     |

**Cross-platform parity:** A user who purchases PRO on Android (Play Store) will see their PRO status reflected on iOS when querying `/users/me`, because the backend centralizes the tier. RevenueCat syncs entitlements cross-platform.

**RevenueCat as local cache:**

The `SubscriptionClient` now uses RevenueCat SDK v5+:

- `RevenueCat.shared.entitlements` for quick offline verification
- `configure()` and `logIn(userId)` for user identification (integrated with Sign in with Apple)
- Grace period: automatically handled by RevenueCat according to App Store Connect configuration
- Syncs with the backend for cross-platform parity and server-verified entitlements

### 18.5 User Profile

The user profile combines authentication data, statistics, and subscription state.

#### Profile Data Model

| Field                   | Source                            | Description                                    |
| ----------------------- | --------------------------------- | ---------------------------------------------- |
| `name`                  | Restored Apple identity + cached profile + backend (`User.Name`) | Display name; manual local editing is supported |
| `email`                 | Apple authorization, backend (`User.Email`), or local profile edit | Account email or Apple private relay; editable locally in Apple-local mode |
| `avatarUrl`             | Backend (`User.ImageURL`) or local cached image reference | Manual photo is supported; Apple does not provide a profile photo |
| `birthDate`             | Local cached profile              | Manual field; Apple does not provide it        |
| `subscriptionTier`      | Backend (`User.SubscriptionTier`) with cached local fallback | Legacy runtime `"free"` or `"pro"` while capability split is in progress |
| `subscriptionExpiresAt` | Backend or cached local fallback  | Active paid period expiration when applicable  |
| `linkedAccounts`        | Backend target model              | Current iOS runtime should not assume Google linking; Apple + email are the active paths |
| `emailVerified`         | Backend (`User.EmailVerified`)    | Whether the email is verified                  |
| `memberSince`           | Backend (`User.CreatedAt`) or cached profile | Registration date                              |

#### Profile Statistics (calculated)

| Statistic                | Calculation                                            | Source                                              |
| ------------------------ | ------------------------------------------------------ | --------------------------------------------------- |
| **Current streak**       | Consecutive days with at least one session              | `PersistenceClient` -> `DailyStats.hadFocusSession` |
| **Total focus hours**    | Sum of `totalFocusSeconds` across all `DailyStats`     | Local SwiftData                                     |
| **Sessions completed**   | Sum of `sessionsCompleted` across all `DailyStats`     | Local SwiftData                                     |
| **Tasks completed**      | Count of `TaskItem` with `isCompleted = true`          | Local SwiftData                                     |
| **Dominant mode**        | Mode with the most total seconds                       | Computed from `DailyStats`                          |

#### TCA Implementation

- `AppFeature` owns root auth/profile sheet routing and computes the merged `profileSummaryUser` shown by `More` and `Profile`.
- `ProfileFeature` owns the dedicated full-screen profile launched from `More`.
- `EditProfileFeature` supports manual editing of `name`, `email`, `birthDate`, and `photo`; when backend tokens are unavailable, it persists changes locally first.
- `ProfileAvatarImageView` renders both remote avatar URLs and Apple-local cached image references.

#### Profile Screen

The `ProfileView` (SwiftUI) shows:

- **Header:** Avatar, name, email, PRO/FREE badge
- **Profile details:** birth date when present, or a manual prompt when it is missing
- **Apple-local context:** explicit note that Apple does not provide birth date or profile photo and may not resend name/email after initial authorization
- **Statistics:** streak, total hours, sessions, completed tasks, member since
- **Subscription:** current status, expiration date, manage/upgrade button
- **Actions:** sign out; provider linking and account-deletion flows remain separate workstreams



