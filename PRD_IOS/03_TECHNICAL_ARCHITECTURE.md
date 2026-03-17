# Technical Architecture: Pepinillo Native (Apple Platforms)

**Date:** March 11, 2026 (v2 — Deep Work Pivot)
**Stack:** Swift 6 · SwiftUI · TCA · SwiftData · CloudKit · WidgetKit · ActivityKit · WatchKit

---

## 1. Architecture Overview

### Pattern: The Composable Architecture (TCA) by Point-Free

TCA is chosen over MVVM, VIPER, or clean architecture for these reasons:
- **Unidirectional data flow** — predictable state management ideal for a timer app with complex state (running, paused, break, interruption)
- **Built-in side-effect management** — perfect for timer ticks, notifications, CloudKit sync, and Watch connectivity
- **Testability** — every reducer is a pure function; every effect is injectable and testable
- **Composability** — features compose into parent features, mirroring Pepinillo's modular structure
- **Point-Free maintains it actively** — strong community, well-documented, Swift 6 compatible

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Entry Point                          │
│                    PepinilloApp (SwiftUI)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  Focus    │  │  Tasks   │  │Analytics │  │  Settings     │   │
│  │  Feature  │  │  Feature │  │ Feature  │  │  Feature      │   │
│  │(4 modes) │  │          │  │(by mode) │  │              │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘   │
│       │              │             │                │           │
├───────┴──────────────┴─────────────┴────────────────┴───────────┤
│                      Shared Domain Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ FocusEngine  │  │ SyncEngine   │  │ AnalyticsEngine      │  │
│  │ (Actor)      │  │ (CloudKit)   │  │ (mode-aware charts)  │  │
│  │ 4 strategies │  │              │  │                      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                      Persistence Layer                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              SwiftData + CloudKit Container               │   │
│  │    (Automatic sync via NSPersistentCloudKitContainer)     │   │
│  └──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                    Platform Extensions                          │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌────────────────┐   │
│  │ Widget  │  │  Live    │  │ Watch   │  │  App Intents   │   │
│  │Extension│  │ Activity │  │  App    │  │  (Siri/Short.) │   │
│  └─────────┘  └──────────┘  └─────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Project Structure

```
Pepinillo/
├── App/
│   ├── PepinilloApp.swift              # @main entry, Store creation
│   ├── AppFeature.swift                # Root TCA feature (tab coordination)
│   └── AppDelegate.swift               # Push notifications, background tasks
│
├── Features/
│   ├── Focus/
│   │   ├── FocusFeature.swift          # TCA Reducer — orchestrates all 4 modes
│   │   ├── FocusView.swift             # SwiftUI view with mode selector
│   │   ├── FocusEngine.swift           # Actor for accurate timing (all modes)
│   │   ├── FocusModels.swift           # FocusMode enum, FocusPhase, Configuration
│   │   ├── Modes/
│   │   │   ├── PomodoroStrategy.swift  # 25/5/15 cycle logic
│   │   │   ├── FlowtimeStrategy.swift  # Open-ended + dynamic break calculation
│   │   │   ├── TimeBlockStrategy.swift # Fixed block countdown
│   │   │   └── StopwatchStrategy.swift # Count-up, no target
│   │   └── FocusModeProtocol.swift     # Protocol all strategies conform to
│   │
│   ├── Tasks/
│   │   ├── TaskListFeature.swift
│   │   ├── TaskDetailFeature.swift
│   │   ├── TaskListView.swift
│   │   ├── TaskDetailView.swift
│   │   └── TaskModels.swift
│   │
│   ├── Analytics/
│   │   ├── AnalyticsFeature.swift
│   │   ├── AnalyticsDashboardView.swift
│   │   ├── WeeklyReviewView.swift
│   │   └── ChartDataProviders.swift
│   │
│   ├── Settings/
│   │   ├── SettingsFeature.swift
│   │   ├── SettingsView.swift
│   │   └── ThemeManager.swift
│   │
│   └── Onboarding/
│       ├── OnboardingFeature.swift
│       └── OnboardingView.swift
│
├── Domain/
│   ├── Models/                         # SwiftData @Model classes
│   │   ├── PomodoroSession.swift
│   │   ├── TaskItem.swift
│   │   ├── SubTask.swift
│   │   ├── DailyStats.swift
│   │   └── UserPreferences.swift
│   │
│   ├── Services/
│   │   ├── FocusService.swift          # Protocol + Actor implementation (multi-mode)
│   │   ├── SyncService.swift           # CloudKit sync orchestration
│   │   ├── NotificationService.swift   # UNUserNotificationCenter wrapper
│   │   ├── HealthService.swift         # HealthKit integration
│   │   ├── FocusModeService.swift      # Focus Modes API
│   │   └── WatchConnectivityService.swift
│   │
│   └── Clients/                        # TCA Dependency clients
│       ├── FocusClient.swift
│       ├── PersistenceClient.swift
│       ├── NotificationClient.swift
│       ├── HealthClient.swift
│       └── WatchClient.swift
│
├── Shared/
│   ├── Design/
│   │   ├── Theme.swift                 # Color palettes, typography
│   │   ├── LiquidGlassModifiers.swift  # iOS 26 adaptive materials
│   │   └── Components/                 # Reusable SwiftUI components
│   │       ├── TimerCircle.swift
│   │       ├── TaskRow.swift
│   │       ├── StatCard.swift
│   │       └── StreakBadge.swift
│   │
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   ├── Duration+Formatting.swift
│   │   └── Color+Theme.swift
│   │
│   └── Resources/
│       ├── Localizable.xcstrings       # EN, ES, PT
│       ├── Assets.xcassets
│       └── Sounds/                     # Timer completion sounds
│
├── PepinilloWidget/                    # WidgetKit extension
│   ├── PepinilloWidgetBundle.swift
│   ├── TimerWidget.swift               # Small/Medium/Large
│   ├── StatsWidget.swift
│   ├── LockScreenWidget.swift
│   └── WidgetTimelineProvider.swift
│
├── PepinilloLiveActivity/             # ActivityKit extension
│   ├── FocusLiveActivity.swift
│   ├── FocusActivityAttributes.swift
│   └── DynamicIslandView.swift        # Adapts per FocusMode
│
├── PepinilloWatch/                    # watchOS app
│   ├── WatchApp.swift
│   ├── Features/
│   │   ├── WatchFocusFeature.swift     # Mode selection + timer
│   │   └── WatchTaskListFeature.swift
│   ├── Views/
│   │   ├── WatchFocusView.swift        # Mode picker + active session
│   │   ├── WatchModePickerView.swift   # Choose Pomodoro/Flowtime/Block/Stopwatch
│   │   └── WatchTaskListView.swift
│   ├── Complications/
│   │   └── TimerComplication.swift
│   └── Connectivity/
│       └── PhoneConnector.swift
│
├── PepinilloIntents/                  # App Intents extension
│   ├── StartFocusIntent.swift          # Multi-mode: Pomodoro/Flowtime/Block/Stopwatch
│   ├── StopFocusIntent.swift
│   ├── CheckStatsIntent.swift
│   ├── StartTaskIntent.swift
│   └── PepinilloShortcuts.swift       # AppShortcutsProvider (5+ phrases)
│
└── Tests/
    ├── FocusFeatureTests/              # Tests for all 4 mode strategies
    ├── TaskFeatureTests/
    ├── AnalyticsFeatureTests/
    ├── SyncServiceTests/
    └── IntegrationTests/
```

---

## 3. Key Technical Decisions

### 3.1 Data Persistence: SwiftData + CloudKit

**Decision:** Use SwiftData with `ModelContainer` configured for CloudKit sync.

**Rationale:**
- SwiftData is Apple's recommended persistence framework (2024+), replacing Core Data for new projects
- Built-in CloudKit integration via `cloudKitContainerIdentifier` — zero custom sync code for basic scenarios
- `@Model` macro makes model definitions concise and type-safe
- Automatic schema migration for most changes
- Works with App Groups for widget/extension data sharing

**Schema Design:**

```swift
@Model
final class TaskItem {
    var id: UUID
    var title: String
    var notes: String?
    var isCompleted: Bool
    var priority: Int          // 0=none, 1=low, 2=medium, 3=high
    var sortOrder: Int
    var estimatedPomodoros: Int
    var completedPomodoros: Int
    var createdAt: Date
    var completedAt: Date?

    @Relationship(deleteRule: .cascade)
    var subtasks: [SubTask]

    @Relationship(inverse: \PomodoroSession.task)
    var sessions: [PomodoroSession]
}

@Model
final class FocusSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var targetDuration: TimeInterval?    // nil for Flowtime/Stopwatch
    var actualDuration: TimeInterval     // actual elapsed
    var mode: String                     // "pomodoro", "flowtime", "timeBlock", "stopwatch"
    var phase: String                    // "work", "shortBreak", "longBreak", "focus", "block"
    var wasCompleted: Bool
    var interruptions: Int
    var pomodoroNumber: Int?             // only for Pomodoro mode (e.g., 3 of 4)
    var task: TaskItem?
}

@Model
final class DailyStats {
    var id: UUID
    var date: Date                   // normalized to start of day
    var totalFocusSeconds: Int
    var sessionsCompleted: Int
    var tasksCompleted: Int
    var longestStreak: Int           // consecutive sessions without interruption
    // Mode breakdown for analytics
    var pomodoroSeconds: Int
    var flowtimeSeconds: Int
    var timeBlockSeconds: Int
    var stopwatchSeconds: Int
    var pomodoroCount: Int
    var flowtimeCount: Int
    var timeBlockCount: Int
    var stopwatchCount: Int
}
```

**App Groups:** All targets (main app, widget, watch, intents) share data via App Group container: `group.com.pepinillo.shared`

### 3.2 Focus Engine: Multi-Mode Swift Actor (Strategy Pattern)

The Focus Engine is the most critical component. It must support 4 different focus techniques through a single, unified engine using the **Strategy pattern**. Each mode conforms to `FocusModeStrategy` protocol, while the engine handles timing accuracy, background survival, Live Activities, Watch sync, and notifications identically for all modes.

```swift
// MARK: - Strategy Protocol
protocol FocusModeStrategy: Sendable {
    var mode: FocusMode { get }
    var direction: TimerDirection { get }     // .countDown or .countUp
    var hasTarget: Bool { get }               // true for Pomodoro/TimeBlock, false for Flowtime/Stopwatch

    func targetDuration(config: FocusConfig) -> TimeInterval?
    func nextPhase(after phase: FocusPhase, elapsed: TimeInterval) -> FocusPhase?
    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval
}

// MARK: - Mode Implementations
struct PomodoroStrategy: FocusModeStrategy {
    let mode = FocusMode.pomodoro
    let direction = TimerDirection.countDown
    let hasTarget = true

    func nextPhase(after phase: FocusPhase, elapsed: TimeInterval) -> FocusPhase? {
        switch phase {
        case .work(let number, let total):
            return number >= total ? .longBreak : .shortBreak
        case .shortBreak: return .work(number: current + 1, total: total)
        case .longBreak: return nil  // cycle complete
        }
    }
}

struct FlowtimeStrategy: FocusModeStrategy {
    let mode = FocusMode.flowtime
    let direction = TimerDirection.countUp   // counts UP (open-ended)
    let hasTarget = false

    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval {
        // Flowtime formula: focus < 25min → 5min break, < 50min → 8min, < 90min → 10min, else 15min
        switch elapsed {
        case ..<(25 * 60): return 5 * 60
        case ..<(50 * 60): return 8 * 60
        case ..<(90 * 60): return 10 * 60
        default: return 15 * 60
        }
    }
}

struct TimeBlockStrategy: FocusModeStrategy {
    let mode = FocusMode.timeBlock
    let direction = TimerDirection.countDown
    let hasTarget = true
    // Single continuous block — no auto-breaks
    func nextPhase(after phase: FocusPhase, elapsed: TimeInterval) -> FocusPhase? { nil }
}

struct StopwatchStrategy: FocusModeStrategy {
    let mode = FocusMode.stopwatch
    let direction = TimerDirection.countUp
    let hasTarget = false
    func nextPhase(after phase: FocusPhase, elapsed: TimeInterval) -> FocusPhase? { nil }
}

// MARK: - Unified Focus Engine
actor FocusEngine {
    private var strategy: FocusModeStrategy
    private var timer: Task<Void, Never>?
    private var startDate: Date?
    private var elapsedAtPause: TimeInterval = 0

    // Uses Date arithmetic (not Timer) for accuracy
    // Date.now - startDate doesn't drift; Timer.scheduledTimer does

    func start(mode: FocusMode, config: FocusConfig, task: TaskItem?) {
        strategy = mode.strategy
        startDate = Date.now

        timer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.1))
                await tick()
            }
        }
        // Start Live Activity (all modes use same ActivityAttributes)
        // Schedule notification if hasTarget
        // Update Watch via WCSession
    }

    func tick() {
        guard let start = startDate else { return }
        let elapsed = Date.now.timeIntervalSince(start) + elapsedAtPause

        if strategy.hasTarget, let target = strategy.targetDuration(config: config) {
            let remaining = max(0, target - elapsed)
            // Broadcast remaining to UI
            if remaining <= 0 { phaseComplete() }
        } else {
            // Count-up modes: broadcast elapsed to UI
        }
    }
}
```

**Key design decision:** All 4 modes share 80% of the engine code. The Strategy pattern means adding a 5th mode (e.g., 52/17 technique) is just a new struct conforming to `FocusModeStrategy` — zero changes to engine, Live Activity, Widget, or Watch code.

**Background Strategy (all modes):**
1. App enters background → schedule `UNNotificationRequest` at end time (countdown modes) or as periodic reminder (count-up modes)
2. Live Activity continues showing countdown/count-up (system-managed)
3. App returns to foreground → recalculate elapsed from `startDate`
4. watchOS → `ExtendedRuntimeSession` for all modes

### 3.3 CloudKit Sync Strategy

**Architecture:**
- Use `NSPersistentCloudKitContainer` (via SwiftData's CloudKit configuration) for automatic sync
- Private database for user data (tasks, sessions, preferences)
- No shared/public database for v1

**Conflict Resolution:**
- Last-write-wins for scalar fields (task title, completion status)
- Additive merge for collections (subtasks — never delete remotely)
- SwiftData/CloudKit handles most conflicts automatically via CKRecord merge policies

**Offline Behavior:**
- All operations write to local SwiftData store first (instant)
- CloudKit sync happens opportunistically when network is available
- Pending changes queue in CKOperationGroup

### 3.4 App Intents Framework

```swift
struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a Focus Session"
    static var description = IntentDescription("Start a deep work session in Pepinillo")

    @Parameter(title: "Focus Mode")
    var mode: FocusModeEntity?        // Pomodoro, Flowtime, Time Block, Stopwatch

    @Parameter(title: "Duration (minutes)")
    var duration: Int?                // Required for Pomodoro/TimeBlock, ignored for Flowtime/Stopwatch

    @Parameter(title: "Task")
    var task: TaskEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$mode) for \(\.$duration) minutes on \(\.$task)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedMode = mode?.focusMode ?? .pomodoro
        let engine = FocusEngine.shared
        await engine.start(mode: selectedMode, duration: duration, task: task)
        return .result(dialog: "Started \(selectedMode.displayName) session")
    }
}

struct PepinilloShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start deep work in \(.applicationName)",
                "Start a Pomodoro in \(.applicationName)",
                "Focus time with \(.applicationName)",
                "Start a time block in \(.applicationName)",
                "Start flow mode in \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "brain.head.profile"
        )
    }
}
```

### 3.5 Live Activities & Dynamic Island

```swift
struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int          // always tracked (all modes)
        var remainingSeconds: Int?       // nil for count-up modes
        var focusMode: String            // "pomodoro", "flowtime", "timeBlock", "stopwatch"
        var phase: String                // "Focus" / "Short Break" / "Long Break" / "Flow" / "Block"
        var taskName: String?
        var progress: Double?            // 0.0-1.0 for countdown, nil for count-up
        var pomodoroNumber: Int?         // only for Pomodoro mode
        var totalPomodoros: Int?
    }

    var startedAt: Date
    var targetDuration: TimeInterval?    // nil for open-ended modes
    var focusMode: String
}
```

**Dynamic Island adapts per mode:**
- **Pomodoro:** 🍅 icon, countdown, "3 of 4", progress ring
- **Flowtime:** 🌊 icon, count-up, "Take a break" nudge after threshold
- **Time Block:** 📦 icon, countdown, linear progress bar
- **Stopwatch:** ⏱️ icon, count-up, minimal chrome

All modes: tap to open app, long-press for pause/stop actions.

### 3.6 watchOS Architecture

**Communication:** `WCSession` (WatchConnectivity framework)
- `transferCurrentComplicationUserInfo` for complication updates
- `sendMessage` for real-time timer sync (when both devices are active)
- `updateApplicationContext` for background state sync

**Timer on Watch:**
- Watch maintains its own timer instance (doesn't depend on phone)
- Phone and Watch sync state on session start/stop
- If both are active, phone is source of truth
- Watch uses `ExtendedRuntimeSession` with `.smartAlarm` for haptics

**Complications:**
- Circular: Current session countdown or daily focus time
- Rectangular: Timer + task name
- Corner: Session count "🍅 4/8"

### 3.7 Multiplatform Strategy

**Approach:** Single Xcode project with multiple targets

| Platform | UI Framework | Notes |
|----------|-------------|-------|
| iPhone | SwiftUI | Primary development target |
| iPad | SwiftUI + Stage Manager | Same views with adaptive layouts, keyboard shortcuts |
| Mac | SwiftUI (native, not Catalyst) | Menu bar extra + full window. `#if os(macOS)` for platform specifics |
| watchOS | SwiftUI (WatchKit) | Simplified feature set: timer + task list + complications |

**Shared code:** Domain models, TCA features, services, and clients are shared across all platforms. Only views and platform-specific integrations differ.

---

## 4. Testing Strategy

### Unit Tests (TCA Reducer Tests)
```swift
@Test func pomodoroModeStartsAndCountsDown() async {
    let clock = TestClock()
    let store = TestStore(
        initialState: FocusFeature.State(mode: .pomodoro, duration: 1500),
        reducer: { FocusFeature() },
        withDependencies: { $0.continuousClock = clock }
    )

    await store.send(.startTapped) {
        $0.isRunning = true
        $0.phase = .work
        $0.activeMode = .pomodoro
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.timerTicked) {
        $0.remainingSeconds = 1499
    }
}

@Test func flowtimeModeCountsUp() async {
    let clock = TestClock()
    let store = TestStore(
        initialState: FocusFeature.State(mode: .flowtime),
        reducer: { FocusFeature() },
        withDependencies: { $0.continuousClock = clock }
    )

    await store.send(.startTapped) {
        $0.isRunning = true
        $0.phase = .flow
        $0.activeMode = .flowtime
    }

    await clock.advance(by: .seconds(60))
    // Elapsed should be 60, no remaining (open-ended)
    await store.receive(.timerTicked) {
        $0.elapsedSeconds = 60
        $0.remainingSeconds = nil
    }
}
```

### Integration Tests
- CloudKit sync: Test with `NSPersistentCloudKitContainer` mock
- Watch connectivity: Test with `WCSession` mock
- Background timer: Test date arithmetic accuracy

### UI Tests
- Onboarding flow completion
- Timer full cycle (start → work → break → work)
- Task CRUD operations
- Widget tap → app navigation

### Performance Tests
- Timer accuracy: ≤100ms drift over 25 minutes
- App launch: cold start < 1s on iPhone 14+
- CloudKit sync: < 10s for 100 tasks on Wi-Fi

---

## 5. CI/CD Pipeline

**Recommended: Xcode Cloud** (free tier for individual developers, integrates natively)

```
Push to main → Build all targets → Run tests → Archive → TestFlight
Push to develop → Build + Test only
Tag v*.*.* → Production build → App Store submission
```

**Alternative:** GitHub Actions with `xcodebuild` if more customization needed.

---

## 6. Dependencies (Minimal)

| Dependency | Purpose | Why External |
|-----------|---------|-------------|
| swift-composable-architecture | State management | Core architecture, extensively tested |
| swift-dependencies | Dependency injection (part of TCA) | Required by TCA |
| swift-snapshot-testing | UI snapshot tests | Point-Free testing ecosystem |

**Philosophy:** Minimize third-party dependencies. Use Apple frameworks (SwiftUI, SwiftData, CloudKit, WidgetKit, ActivityKit, HealthKit, App Intents) for everything possible. RevenueCat is NOT used — StoreKit 2 native API is sufficient for Pepinillo's subscription needs.

---

## 7. Security & Privacy

- **Authentication:** Sign in with Apple only (no email/password, no Firebase Auth)
- **Data storage:** All user data in CloudKit private database (encrypted at rest by Apple)
- **Local data:** SwiftData with Data Protection (file-level encryption)
- **No tracking:** TelemetryDeck for privacy-first analytics (no user PII collected)
- **Permissions:** Only request HealthKit, Notifications when user opts in. No camera, microphone, location, contacts.
- **App Transport Security:** Enforced (HTTPS only)
- **Privacy Nutrition Label:** Minimal data collection for App Store listing

---

## 8. Accessibility

- Full VoiceOver support on all platforms
- Dynamic Type support (all text scales)
- Reduce Motion support (disable animations)
- High contrast mode support
- Haptic feedback as alternative to visual-only indicators
- Minimum 4.5:1 contrast ratios for all text
- Custom accessibility labels for timer circle and progress indicators
