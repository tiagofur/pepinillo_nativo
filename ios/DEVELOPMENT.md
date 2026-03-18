# Pepinillo iOS — Development Reference

> Native iOS/iPadOS/macOS app built with SwiftUI, TCA, and SwiftData.
> All 5 development stages complete. Ready for Xcode project creation and App Store submission.

---

## What Was Built (Stages 1–5)

### Stage 1 — Foundation Layer
**Persistence**
- `Shared/Persistence/SwiftDataPersistenceService.swift` — `@MainActor` service wrapping all SwiftData operations: tasks, sessions, daily stats, preferences.
- `Domain/Clients/PersistenceClient.swift` — TCA `@DependencyClient`; `live(container:)` factory bridges `@MainActor` service into async TCA effects via `MainActor.run`.
- `Domain/Models/` — 5 `@Model` classes: `TaskItem`, `SubTask`, `FocusSessionRecord`, `DailyStats` (per-mode breakdown), `UserPreferences` (all user settings + streak).

**Design System**
- `Shared/Design/AppTheme.swift` — `AppTheme` value type with 4 built-in themes (Classic, Forest, Ocean, Sunset); `EnvironmentKey` injection so any view can read `@Environment(\.appTheme)`.

**Core Features**
- `Features/Focus/` — `FocusEngine` Swift actor (date-based timing, `AsyncStream<FocusEngineEvent>`), `FocusFeature` TCA reducer fully wired, `FocusModels` (modes, phases, config, result), 4 mode strategies (`PomodoroStrategy`, `FlowtimeStrategy`, `TimeBlockStrategy`, `StopwatchStrategy`).
- `Features/Tasks/` — `TaskListFeature` TCA reducer + `TaskListView`; full CRUD with SwiftData persistence.
- `Features/Settings/` — `SettingsFeature` TCA reducer; `SettingsSnapshot` value-type bridge; auto-save on every change.
- `Features/Analytics/` — `AnalyticsFeature` TCA reducer; `DayDataSnapshot` value type; SwiftCharts bar chart; period picker (7D / 30D / Year).
- `Features/Onboarding/` — 4-page `TabView` onboarding with mode explanation and default mode picker.
- `App/AppFeature.swift` — Root TCA reducer composing all child features; tab routing; cross-feature `tasks → focus` navigation.

---

### Stage 2 — Apple Ecosystem
**Live Activity / Dynamic Island**
- `PepinilloLiveActivity/FocusActivityAttributes.swift` — `ActivityAttributes` schema.
- `PepinilloLiveActivity/FocusLiveActivityView.swift` — Lock Screen banner + Dynamic Island compact/expanded views.
- `PepinilloLiveActivity/FocusLiveActivityWidget.swift` — `ActivityConfiguration` wiring.
- `PepinilloLiveActivity/LiveActivityManager.swift` — `actor LiveActivityManager`; start/update/end with `Activity<FocusActivityAttributes>`.
- `Domain/Clients/LiveActivityClient.swift` — TCA `@DependencyClient` wrapping `LiveActivityManager`.

**Widgets**
- `PepinilloWidget/FocusWidgetModels.swift` — `FocusWidgetEntry: TimelineEntry`; `WidgetModeStyle` helper.
- `PepinilloWidget/FocusWidgetProvider.swift` — `AppIntentTimelineProvider`; reads real data from App Group SwiftData store; 15-minute refresh; streak calculation.
- `PepinilloWidget/FocusWidgetViews.swift` — Small (2×2), Medium (4×2), Large (4×4), Lock Screen circular, Lock Screen rectangular.
- `PepinilloWidget/FocusWidget.swift` — `@main PepinilloWidgetBundle` with `FocusHomeScreenWidget` + `FocusLockScreenWidget`.

**Siri Shortcuts**
- `PepinilloIntents/StartFocusIntent.swift` — `StartFocusIntent`, `StopFocusIntent`, `FocusModeEntity`, `FocusModeQuery`, `TaskEntity`, `TaskEntityQuery`, `PepinilloShortcuts`.

---

### Stage 3 — Polish
**Notifications**
- `Domain/Clients/NotificationClient.swift` — TCA `@DependencyClient` for `UNUserNotificationCenter`; schedules: session-complete, break-end (with countdown), daily streak reminder (repeating calendar trigger). Categories with action buttons registered at launch.

**Subscription / Paywall**
- `Domain/Clients/SubscriptionClient.swift` — TCA `@DependencyClient` wrapping StoreKit 2; `SubscriptionManager` actor; product fetch, purchase, restore, entitlement check, transaction update stream.
- `Features/Paywall/PaywallFeature.swift` — Full TCA reducer for paywall flow.
- `Features/Paywall/PaywallView.swift` — Product cards with featured badge, purchase/restore buttons, result alerts.

**Soundscapes**
- `Domain/Clients/SoundscapeClient.swift` — TCA `@DependencyClient`; 9 presets: None, Rain, Forest, Café, White Noise (free) + Ocean, Fireplace, Binaural Beats, Lo-fi (Pro). Loops audio files with fade in/out.
- `Shared/Sounds/SoundscapeManager.swift` — `actor SoundscapeManager` using `AVAudioEngine`; smooth volume ramp via `Task.sleep` loop; `AVAudioSession.ambient` category (mixes with other audio).
- `Features/Focus/SoundscapePickerView.swift` — Bottom sheet; free vs Pro sections; locked presets route to paywall.

**Celebrations**
- `Shared/Design/CelebrationView.swift` — Canvas + `TimelineView` particle confetti overlay; streak milestones (3/7/14/30/60/100 days); `CelebrationMilestone` enum.

**Integration**
- `FocusFeature`: plays soundscape on start, fades out on stop/complete, schedules completion notification, shows paywall for locked modes.
- `AppFeature`: subscribes to StoreKit transaction stream at launch, requests notification permission, dispatches `celebrationTriggered` after session save, syncs daily reminder with Settings changes.

---

### Stage 4 — Apple Watch
- `PepinilloWatch/Features/WatchFocusFeature.swift` — TCA reducer; receives `WatchSessionState` from iOS via `WatchConnectivityClient`; dispatches WatchKit haptics on phase transitions.
- `PepinilloWatch/Connectivity/WatchConnectivityClient.swift` — TCA `@DependencyClient` + `WatchConnectivityManager` (`NSObject/WCSessionDelegate`); bidirectional `AsyncStream<WatchMessage>` delivery; encodes/decodes session state and commands.
- `PepinilloWatch/Views/WatchFocusView.swift` — Compact timer ring, horizontal mode chip scroller, pause/stop controls, stat pills (minutes + streak), connectivity indicator.
- `PepinilloWatch/Complications/FocusComplications.swift` — WidgetKit complications: `.accessoryCircular`, `.accessoryRectangular`, `.accessoryCorner`; shows active timer or daily totals.

---

### Stage 5 — iPad/Mac + Widget Data + Localization
**App Group / Shared Store**
- `Shared/Persistence/AppGroupContainer.swift` — `makeSharedModelContainer()` (main app, CloudKit on) and `makeWidgetModelContainer()` (widget extension, no CloudKit). Both resolve to `group.com.pepinillo.app/Pepinillo.sqlite`.

**Widget Real Data**
- `FocusWidgetProvider` now reads live `DailyStats` from the App Group store; computes streak by querying backwards through `DailyStats.hadFocusSession`; falls back to `.idle` gracefully.

**iPad / Mac Layout**
- `App/iPadSplitView.swift` — Three-column `NavigationSplitView` (`.balanced`); sidebar with task badge; content column for task list; detail column routes focus/analytics/settings; Focus view capped at 560pt.

**Keyboard Shortcuts / Mac Catalyst**
- `App/MacCommands.swift` — `PepinilloCommands: Commands`; Focus menu: `Space` (start/pause), `Cmd+.` (stop), `Cmd+1–4` (modes); Tasks menu: `Cmd+N` (new task); View additions: `Cmd+Shift+F/A`, `Cmd+,`.
- `FocusView`: hidden background buttons give `Space` + `Cmd+.` to external keyboards.
- `PepinilloApp`: `.defaultSize(1100×720)` + `.windowResizability(.contentMinSize)` for Mac Catalyst.

**Localization**
- `Shared/Resources/Localizable.xcstrings` — 45 string keys; Xcode 15 String Catalog format (JSON). Languages: `en` (source), `es` (informal), `pt` (informal). Covers all UI: timer phases, modes, soundscapes, paywall, notifications, widget labels, Siri phrases.

---

## Project Structure

```
pepinillo_ios/
├── App/
│   ├── AppFeature.swift          Root TCA reducer
│   ├── AppView.swift             Root view (iPhone tab / iPad split)
│   ├── iPadSplitView.swift       Three-column iPad/Mac layout
│   ├── MacCommands.swift         Mac menu bar commands
│   └── PepinilloApp.swift        @main, ModelContainer, Store init
│
├── Domain/
│   ├── Clients/
│   │   ├── FocusClient.swift           Engine ↔ TCA bridge
│   │   ├── LiveActivityClient.swift    ActivityKit TCA dependency
│   │   ├── NotificationClient.swift    UNUserNotificationCenter
│   │   ├── PersistenceClient.swift     SwiftData TCA dependency
│   │   ├── SoundscapeClient.swift      AVAudioEngine TCA dependency
│   │   ├── SubscriptionClient.swift    StoreKit 2 TCA dependency
│   │   └── WatchConnectivityClient.swift  WCSession TCA dependency (in PepinilloWatch/)
│   └── Models/
│       ├── DailyStats.swift            @Model, per-mode breakdown
│       ├── FocusSessionRecord.swift    @Model, completed session
│       ├── SubTask.swift               @Model
│       ├── TaskItem.swift              @Model
│       └── UserPreferences.swift       @Model, all settings + streak
│
├── Features/
│   ├── Analytics/      AnalyticsFeature + AnalyticsView (SwiftCharts)
│   ├── Focus/          FocusEngine, FocusFeature, FocusView, 4 mode strategies
│   ├── Onboarding/     4-page onboarding
│   ├── Paywall/        PaywallFeature + PaywallView (StoreKit 2)
│   ├── Settings/       SettingsFeature + SettingsView
│   └── Tasks/          TaskListFeature + TaskListView
│
├── Shared/
│   ├── Design/         AppTheme, CelebrationView
│   ├── Extensions/     Date+, Duration+ helpers
│   ├── Persistence/    SwiftDataPersistenceService, AppGroupContainer
│   ├── Resources/      Localizable.xcstrings (EN/ES/PT)
│   └── Sounds/         SoundscapeManager (AVAudioEngine actor)
│
├── PepinilloLiveActivity/   ActivityKit: attributes, views, widget, manager
├── PepinilloIntents/        Siri Shortcuts: StartFocus, StopFocus, entities
├── PepinilloWidget/         WidgetKit: provider, views, bundle
├── PepinilloWatch/          watchOS: feature, connectivity, views, complications
├── Tests/                   TCA TestStore tests for all features
└── Package.swift            SPM: TCA 1.17+, SnapshotTesting 1.17+
```

---

## What You Need to Do in Xcode

> These steps cannot be done in code — they require the Xcode IDE on a Mac.

### 1. Create the Xcode Project

1. Open Xcode → **File → New → Project → App**
2. Product name: `Pepinillo`, Bundle ID: `com.pepinillo.app`
3. Language: Swift, Interface: SwiftUI
4. Add the local Swift package: **File → Add Package Dependencies → Add Local** → select `pepinillo_ios/`

### 2. Add SPM Dependency (TCA)

In the package dependency screen (or **Project → Package Dependencies**):
- URL: `https://github.com/pointfreeco/swift-composable-architecture`
- Version: `1.17.0` or higher

### 3. Create Additional Targets

| Target | Template | Bundle ID |
|--------|----------|-----------|
| PepinilloWidget | Widget Extension | `com.pepinillo.app.widget` |
| PepinilloLiveActivity | (add files to main target) | — |
| PepinilloIntents | Intents Extension | `com.pepinillo.app.intents` |
| PepinilloWatch | watchOS App | `com.pepinillo.watch` |

Add the corresponding source files from each folder to the matching target.

### 4. App Group Entitlement (CRITICAL for widgets)

Add the **App Groups** capability to **all four targets**:

| Target | App Group |
|--------|-----------|
| Pepinillo (main) | `group.com.pepinillo.app` |
| PepinilloWidget | `group.com.pepinillo.app` |
| PepinilloIntents | `group.com.pepinillo.app` |
| PepinilloWatch | `group.com.pepinillo.app` |

> Without this the widget reads an empty database and shows 0 minutes.

### 5. CloudKit Capability

On the **main app target** only:
- Add **iCloud** capability → check **CloudKit**
- Container: `iCloud.com.pepinillo.app` (create it in the Apple Developer portal)

### 6. StoreKit Configuration File

1. **File → New → File → StoreKit Configuration**
2. Name it `Pepinillo.storekit`
3. Add three products:

| Type | Product ID | Reference Name | Price |
|------|-----------|----------------|-------|
| Auto-Renewable Subscription | `com.pepinillo.pro.monthly` | Pro Monthly | $2.99 |
| Auto-Renewable Subscription | `com.pepinillo.pro.annual` | Pro Annual | $14.99 |
| Non-Consumable | `com.pepinillo.pro.lifetime` | Pro Lifetime | $29.99 |

4. In **Scheme → Run → Options → StoreKit Configuration** select `Pepinillo.storekit`

### 7. Soundscape Audio Files

Add the following `.mp3` or `.m4a` files to the **main app bundle** (Target → Build Phases → Copy Bundle Resources):

| Filename | Description |
|----------|-------------|
| `rain.mp3` | Rain ambience loop |
| `forest.mp3` | Forest birds/wind loop |
| `cafe.mp3` | Coffee shop ambience loop |
| `white_noise.mp3` | White noise loop |
| `ocean.mp3` | Ocean waves loop (Pro) |
| `fireplace.mp3` | Fireplace crackle loop (Pro) |
| `binaural.mp3` | 40 Hz binaural beats loop (Pro) |
| `lofi.mp3` | Lo-fi music loop (Pro) |

Free royalty-free sources: [Freesound.org](https://freesound.org), [Pixabay](https://pixabay.com/music/).

### 8. Info.plist Keys

Add these keys to the **main app's Info.plist**:

```xml
<key>NSUserNotificationUsageDescription</key>
<string>Pepinillo notifies you when focus sessions complete and reminds you to keep your streak.</string>

<key>NSMotionUsageDescription</key>
<string>Used for haptic feedback during focus sessions.</string>
```

For the **Widget Extension** Info.plist — no special keys needed beyond the default.

### 9. Localization Setup

1. **Project → Info → Localizations** → click **+**
2. Add: **Spanish** and **Portuguese**
3. Select `Shared/Resources/Localizable.xcstrings` when prompted

The `.xcstrings` file already contains all translations for `es` and `pt`.

### 10. Watch App Connectivity (iOS side)

In the **main app target**, add `WatchConnectivityClient.swift` to the iOS target as well. The iOS `AppFeature` needs to forward `FocusEngine` ticks to the Watch. Wire it in `AppFeature.appLaunched`:

```swift
// In AppFeature.appLaunched, add:
.run { send in
    await watchClient.sendSessionState(WatchSessionState(...))
}
```

### 11. Mac Catalyst (optional, for macOS)

In the main target:
- **General → Deployment Info** → check **Mac (Catalyst)**
- Set minimum macOS version to 14.0
- In **Signing & Capabilities**, add `com.apple.security.app-sandbox` entitlement

### 12. App Store Connect Setup

1. Create the app record in [App Store Connect](https://appstoreconnect.apple.com)
2. Bundle ID: `com.pepinillo.app`
3. Add the **In-App Purchases** (monthly, annual, lifetime) in the Monetization section
4. Submit the StoreKit products for review alongside the first app version

---

## Architecture Notes

### TCA Pattern
Every feature follows the same pattern:
- `@Reducer struct XFeature` with `@ObservableState State`, `Action enum`, dependencies via `@Dependency`
- Views use `@Bindable var store: StoreOf<XFeature>` and send actions
- Effects use `.run { send in ... }` for async, `.send(...)` for synchronous

### SwiftData + TCA Bridge
`@Model` objects are `@unchecked Sendable` (SwiftData guarantees). The bridge:
1. `SwiftDataPersistenceService` is `@MainActor` — all operations on the main thread
2. `PersistenceClient.live(container:)` wraps each call in `MainActor.run { }` returning value types
3. TCA effects receive value types (never `@Model` references across async boundaries)

### Concurrency
- `FocusEngine`: Swift `actor` — timer state is thread-safe
- `SoundscapeManager`: Swift `actor` — audio engine operations serialised
- `SubscriptionManager`: Swift `actor` — StoreKit calls serialised
- `WatchConnectivityManager`: `NSObject` with `@unchecked Sendable` — delegates on main thread

### App Group Data Flow
```
Main App                    Widget Extension
    │                             │
    ▼                             ▼
makeSharedModelContainer()   makeWidgetModelContainer()
    │                             │
    └──────────────┬──────────────┘
                   ▼
        group.com.pepinillo.app/
              Pepinillo.sqlite
```

---

## Running Tests

The SPM test target (`PepinilloTests`) covers:
- `FocusFeatureReducerTests` — timer ticks, pause/resume, session completion
- `FocusModeStrategyTests` — phase transitions for all 4 modes
- `TaskListFeatureTests` — CRUD, filtering, persistence
- `AnalyticsFeatureTests` — period selection, data aggregation
- `AppFeatureIntegrationTests` — tab routing, tasks→focus handoff
- `PaywallFeatureTests` — purchase flow, restore, alert lifecycle
- `FocusWidgetProviderTests` — streak calculation, DailyStats accumulation

Run from the command line (once the Xcode project exists):
```bash
xcodebuild test -scheme Pepinillo -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or via SPM (for the core logic only, no UIKit/AppKit):
```bash
swift test
```
