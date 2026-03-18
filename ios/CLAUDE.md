# Pepinillo iOS — Claude Code Reference

## Project Overview
Deep Work companion for Apple platforms. Native SwiftUI app with TCA architecture, targeting iOS 17+, watchOS 10+, macOS 14+ (Catalyst).

## Build & Run
```bash
# Generate/regenerate Xcode project (after project.yml changes)
xcodegen generate

# Build main app
xcodebuild -scheme Pepinillo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild -scheme Pepinillo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Build watch app
xcodebuild -scheme PepinilloWatch -destination 'generic/platform=watchOS Simulator' build
```

## Architecture

### TCA (The Composable Architecture)
Every feature follows this pattern:
- `@Reducer struct XFeature` with `@ObservableState State`, `Action` enum
- Dependencies via `@Dependency(\.clientName)`
- Effects use `.run { send in ... }` for async work
- Views use `@Bindable var store: StoreOf<XFeature>` and send actions

### SwiftData + TCA Bridge
- `@Model` classes live in `Domain/Models/`
- `SwiftDataPersistenceService` is `@MainActor` — all operations on main thread
- `PersistenceClient.live(container:)` wraps calls in `MainActor.run {}` returning DTOs (value types)
- TCA effects receive DTOs, never `@Model` references across async boundaries

### Concurrency (Swift 6 strict)
- `FocusEngine`: Swift `actor` — timer state is thread-safe, date-based timing
- `SoundscapeManager`: Swift `actor` — AVAudioEngine operations
- `SubscriptionManager`: Swift `actor` — StoreKit 2 calls
- All new code must compile under Swift 6 strict concurrency

## Project Structure
```
App/              → Root app: @main, AppFeature (root reducer), AppView, iPad/Mac layouts
Features/         → Feature modules (Focus, Tasks, Analytics, Settings, Paywall, Onboarding)
Domain/Models/    → SwiftData @Model classes (TaskItem, FocusSessionRecord, DailyStats, etc.)
Domain/Clients/   → TCA @DependencyClient wrappers (Persistence, Focus, Subscription, etc.)
Domain/Services/  → Pure logic (ModeIntelligenceService)
Shared/           → Design system, extensions, persistence layer, soundscape manager, resources
Tests/            → Swift Testing (@Test macro) — one directory per feature
```

### Extension Targets
- `PepinilloWidget/` + `PepinilloLiveActivity/` → WidgetKit (home/lock screen + Dynamic Island)
- `PepinilloWatch/` → watchOS companion
- `PepinilloIntents/` → Siri App Intents (compiled into main app)
- `ControlCenterExtension/` → iOS 18 Control Center widget

## Key Conventions
- **App Group:** `group.com.pepinillo.app` — shared between all targets for data access
- **CloudKit container:** `iCloud.com.pepinillo.app`
- **Bundle ID prefix:** `com.pepinillo.app`
- **Localization:** EN, ES, PT via `Localizable.xcstrings`
- **Focus modes:** Pomodoro, Flowtime, TimeBlock, Stopwatch — all share `FocusEngine` actor via strategy pattern
- **Themes:** 4 built-in (Classic, Forest, Ocean, Sunset) via `AppTheme` environment key

## Dependencies (SPM)
- `swift-composable-architecture` 1.17+ (TCA)
- `swift-snapshot-testing` 1.17+ (test only)

## XcodeGen
Project is generated from `project.yml`. After modifying it, run `xcodegen generate` to regenerate `Pepinillo.xcodeproj`.
