# Pepinillo — Unified Features Document

**Version:** 1.0  
**Last Updated:** 2026-03-24  
**Platforms:** iOS (iPhone/iPad/Mac), Android (Phone/Tablet), watchOS, Wear OS  
**Author:** Tiago David + Claude Code  
**Status:** Active

---

## Label Conventions

| Label         | Meaning                                        |
| ------------- | ---------------------------------------------- |
| **[All]**     | Supported on all platforms                     |
| **[iOS]**     | Exclusive to iOS (iPhone, iPad, Mac)           |
| **[Android]** | Exclusive to Android (Phone, Tablet, Foldable) |
| **[watchOS]** | Exclusive to Apple Watch                       |
| **[Wear OS]** | Exclusive to Wear OS                           |

---

## P0 — Must-Have (Mandatory)

### Multi-Modal Focus Engine [All]

Pepinillo's primary differentiator: 4 focus techniques in one app, implemented with **Strategy pattern** to share 80% of timer logic across modes.

#### Available Modes

| Mode                   | Description                                                                                                                                                                                                  | Tier |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- |
| **Pomodoro**           | Classic 25/5/15 intervals. Automatic work-break-work cycles. Tracks pomodoro count (e.g., "3 of 4"). Customizable durations.                                                                             | FREE |
| **Flowtime**           | Open-ended session without fixed intervals. When fatigue hits, user takes a break. App suggests break duration based on focused time (10 min -> 2 min break, 50 min -> 10 min break). Ideal for creative work. | PRO  |
| **Time Block**         | Fixed time block (e.g., "2 hours of writing"). Continuous countdown with optional mid-point check-ins. Tracks completed blocks per day.                                                                  | PRO  |
| **Stopwatch (Chrono)** | Ascending timer without pressure. No goals or structure. Just tracks how long you work. Pause and stop. Ideal for casual/flexible segment.                                                                | FREE |

#### Engine Architecture

- **Unified Strategy pattern:** one common interface (`FocusModeStrategy` / `FocusModeProtocol`) with mode-specific implementations
- **Shared state:** timer, pause/resume, interruption tracking, session linking
- **Background supervision:** timer must survive app minimization, app switching, and screen lock
  - **[iOS]**: Live Activity + `Date` arithmetic to recalculate on foreground return. No background timers.
  - **[Android]**: Foreground Service (`START_STICKY`) with persistent notification. Survives process death.
- **Pause/Resume:** precise tracking of paused time and interruption count per session
- **Session Journaling:** post-session reflection with free-text note ("What did I accomplish?") + 1-5 star satisfaction rating

---

### Task Management [All]

Integrated task system with the focus engine. Not a generic task manager: designed to plan and execute deep work sessions.

#### Core Functionality

| Feature                    | Tier                            | Details                                                                                                |
| -------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Task CRUD                  | FREE                            | Create, edit, delete tasks with title and description                                                  |
| Drag-to-reorder            | FREE                            | Reorder tasks by priority via drag                                                                     |
| Subtasks                   | PRO                             | Nested subtasks (up to 20 per task) with individual checkboxes                                         |
| Priority                   | FREE                            | None / Low / Medium / High — visual indicator                                                          |
| Energy Levels              | FREE                            | Deep Work / Shallow Work / Admin — group similar tasks                                                 |
| Est./Completed Pomodoros   | FREE                            | Assign pomodoro estimate to task, track completed                                                      |
| Link Task to Focus Session | FREE                            | Any focus mode can link to active task. Session records: task, mode used, duration, completion status |
| Recurring Tasks            | PRO                             | 5 presets: daily, weekdays, weekly, biweekly, monthly                                                  |
| Task Limit                 | FREE: 3 active / PRO: unlimited | Natural upgrade motivation                                                                              |

---

### Analytics & Dashboard [All]

Analytic dashboard with mode-specific breakdown — not just "total hours" but how each technique performs for the user.

#### Time Views

| View                | Tier |
| ------------------- | ---- |
| Today + Last 7 Days | FREE |
| 30 Days             | PRO  |
| 1 Year              | PRO  |

#### Dashboard Components

| Component               | Tier | Details                                                                                             |
| ----------------------- | ---- | --------------------------------------------------------------------------------------------------- |
| Daily Summary           | FREE | Focus hours, completed sessions, finished tasks                                                     |
| Mode Breakdown          | PRO  | Charts showing time distribution across Pomodoro/Flowtime/TimeBlock/Chrono                         |
| Most Productive Hours   | PRO  | Analysis by hour of day and day of week                                                             |
| Completion Rate by Mode | PRO  | Helps users discover which technique works best                                                     |
| Achievements            | FREE | 6 badge types: First Session, Weekly Streak, Pomodoro Master, Deep Diver, Century Club, Early Bird |
| Weekly Review           | PRO  | Weekly comparison: focus hours, mode distribution, tasks, streaks. Trend arrows vs. previous week  |
| Monthly Review          | PRO  | Monthly review with long-term trends and productivity patterns                                      |
| AI Productivity Reports | PRO  | On-device AI-generated reports, no cloud data sent                                                  |

#### AI Reports Implementation by Platform

- **[iOS]**: Apple Foundation Models (iOS 18+). Fallback to predefined templates with interpolated data if device doesn't support Foundation Models.
- **[Android]**: On-device ML (Gemini Nano / smart templates). Fallback to templates with interpolated data if ML unavailable.

---

### Widgets [All]

Multiple widgets to interact with Pepinillo without opening the app.

#### Home Screen Widgets

| Size       | Content                                | Tier |
| ---------- | -------------------------------------- | ---- |
| Small (S)  | Active timer or daily progress         | FREE |
| Medium (M) | Timer + top 3 tasks of the day         | PRO  |
| Large (L)  | Timer + tasks + daily mode-based stats | PRO  |

**Implementation:**

- **[iOS]**: WidgetKit with Timeline Provider. Interactive widget support (iOS 17+).
- **[Android]**: Glance Compose (Jetpack). No legacy RemoteViews.

#### Lock Screen Widget

- **[iOS]**: WidgetKit Lock Screen widgets (circular, rectangular, inline)
- **[Android]**: Glance widget with `KEYGUARD` category (API 33+, Android 13+)

**Tier:** Basic timer widget = FREE. Additional widgets = PRO.

---

### Notifications [All]

| Type                  | Detail                                                                   | Tier |
| --------------------- | ------------------------------------------------------------------------ | ---- |
| Phase Transition      | Alert when Pomodoro work/break ends, and when Flowtime suggests a break | FREE |
| Daily Reminder        | Configurable notification to remind users to start a session            | FREE |
| Session Completed     | Celebration and summary when a session ends                             | FREE |
| Notification Actions  | Pause/Resume/Stop directly from notification without opening the app    | FREE |

**Action Implementation:**

- **[Android]**: Action buttons in the Foreground Service notification (pause, skip, stop)
- **[iOS]**: `UNNotificationAction` with registered categories. Actions handled via `UNUserNotificationCenterDelegate`.

---

### Live Activity / Persistent Notification

Permanent visual indicator of the active timer outside the app.

#### [iOS] — Live Activity + Dynamic Island

- **ActivityKit** to create and update Live Activities
- **Dynamic Island**: compact view (mode icon + countdown), expanded view (mode, task, progress, controls)
- Shows: countdown, mode icon, task name, progress bar
- Quick actions: pause, skip, stop
- Works for all 4 focus modes
- **Tier:** FREE

#### [Android] — Persistent Foreground Notification

- Ongoing notification linked to Foreground Service
- Shows: countdown, active mode, task name
- Action buttons: pause/resume, skip, stop
- Priority `FOREGROUND_SERVICE_IMMEDIATE` for visibility
- Custom layout with progress bar
- **Tier:** FREE

---

### Smartwatch

#### [watchOS] — Apple Watch Companion App

Complete and standalone Apple Watch app:

| Feature            | Detail                                                                                                                                                                                                                                                                                  | Tier |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| Timer              | Start any focus mode from the watch                                                                                                                                                                                                                                                     | PRO  |
| Mode Selection     | Choose among the 4 focus modes                                                                                                                                                                                                                                                          | PRO  |
| Task List          | View today's tasks, mark them as completed                                                                                                                                                                                                                                              | PRO  |
| Dashboard          | Daily stats: focus hours, sessions, streak                                                                                                                                                                                                                                              | PRO  |
| Haptics            | Haptic feedback on session completion and phase transitions                                                                                                                                                                                                                             | PRO  |
| Complications      | Enhanced: circular uses actual progress, corner uses live countdown, rectangular shows live countdown + phase + linked task. Smart Stack relevance (score 100 active, 10 idle). 5-min refresh when active (15-min idle). Live countdown works even when progress=0 (timer just started). | PRO  |
| Tasks Complication | accessoryRectangular (top tasks list), accessoryCircular (completed count), accessoryCorner (task count badge).                                                                                                                                                                        | PRO  |
| Sync               | Bidirectional communication with iPhone via WatchConnectivity                                                                                                                                                                                                                           | PRO  |

#### [Wear OS] — Wear OS Companion App

Complete Wear OS app:

| Feature          | Detail                                                                                                                                                                                                     | Tier |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| Timer            | Start/pause/stop focus sessions                                                                                                                                                                             | PRO  |
| Mode Selection   | All 4 focus modes available                                                                                                                                                                                 | PRO  |
| Task List        | Today's tasks with mark-complete                                                                                                                                                                            | PRO  |
| Stats            | Daily summary of focus time and sessions                                                                                                                                                                    | PRO  |
| Focus Timer Tile | Enhanced tile with progress arc (colored by mode), timer display, phase label, session counter, linked task name. Distinct idle/running/paused states. Built with Tiles 1.4.1 + ProtoLayout Material 1.2.1. | PRO  |
| Tasks Tile       | Second tile showing top 4 tasks with energy emoji, truncated title, pomodoro progress, and completed/total header.                                                                                        | PRO  |
| Complication     | Focus data in watch face                                                                                                                                                                                    | PRO  |
| Sync             | Data Layer API for communication with phone                                                                                                                                                                 | PRO  |

---

### Voice Assistant

#### [iOS] — Siri Shortcuts + App Intents

- Framework: **App Intents** (iOS 16+) for native Siri and Shortcuts integration
- Supported commands:
  - "Start deep work in Pepinillo"
  - "Start a Pomodoro"
  - "How much did I focus today?"
  - "Start working on [Task]"
  - "Pause my session"
  - "Give me my weekly report"
  - "Which mode do you recommend?"
- **3 languages**: EN, ES, PT
- User-customizable shortcuts in the Shortcuts app
- **Tier:** FREE

#### [Android] — Google Assistant App Actions

- Framework: **App Actions** with `actions.xml`
- Supported commands equivalent to iOS
- Built-in intents (BII) for productivity
- **3 languages**: EN, ES, PT
- **Tier:** FREE

---

### Synchronization

#### [iOS] — CloudKit

- **CloudKit private database** for automatic synchronization across iPhone, iPad, Mac
- Merge strategy: **last-write-wins** with timestamps
- Offline-first: all data saved locally first (SwiftData), sync is opportunistic
- Synced entities: tasks, focus sessions, preferences, streaks, achievements
- **Tier:** PRO

#### [Android] — Backend REST API + Room + WebSocket

- **Go backend** with REST API + WebSocket for data sync
- **Room** as local database with dirty-flag pattern (isDirty / syncedAt / serverId)
- **WorkManager** for background sync (respects Doze mode and battery optimization)
- **SyncWebSocketClient** (OkHttp) for real-time notifications that trigger HTTP sync
- **SettingsSyncEngine**: per-key LWW bidirectional sync for 17 preference keys via `user_preferences` table
- **Batch session sync**: `POST /sync/sessions` replaces individual POSTs
- **Initial upload**: `POST /sync/initial-upload` atomic upload when anonymous user registers
- **New device sync**: `GET /sync/full` with cursor-based pagination
- **DataMergeDialog**: when anonymous user logs into existing account (upload local vs download cloud)
- **IdentityManager**: state machine ANONYMOUS/REGISTERED/VERIFIED
- **X-Device-ID**: header on all sync requests; backend WebSocket hub excludes originating device
- Offline-first: Room is source of truth, sync occurs when reconnected
- Synced entities: Tasks, Sessions, Stats, Preferences
- **Tier:** PRO

---

### Themes & Design

#### Available Themes [All]

| Theme             | Tier |
| ----------------- | ---- |
| Classic (Default) | FREE |
| Forest            | PRO  |
| Ocean             | PRO  |
| Sunset            | PRO  |

#### Theme Picker [All]

- Theme selector with **horizontal scroll cards** showing a preview of each theme
- Focus mode colors consistent across themes: Pomodoro=red, Time Block=purple, Chrono=green
- **[Android]**: Includes an additional **Material You** option (dynamic colors based on wallpaper)
- **[iOS]**: Integrated in the Settings screen
- **[Wear OS]**: Theme selected on Android phone syncs automatically to watch via Data Layer API
- **Tier:** FREE (Classic) / PRO (Forest, Ocean, Sunset)

#### Appearance Modes [All]

- **[iOS]**: Light / Dark / System appearance selector in Settings
- **[Android]**: Follows system theme (automatic Dark/Light)
- **Tier:** FREE

#### Platform-Specific Effects

- **[iOS]**: Support for **Liquid Glass** (iOS 26) as an additional premium theme. Glassmorphism effects in UI components.
- **[Android]**: **Material You** dynamic colors as an additional option alongside the 4 named themes. Material 3 theming system.

---

### Localization [All]

3 complete languages on all platforms:

| Language   | Code |
| ---------- | ---- |
| English    | EN   |
| Spanish    | ES   |
| Portuguese | PT   |

**Implementation:**

- **[iOS]**: `.xcstrings` (Xcode String Catalogs). Localized Siri phrases.
- **[Android]**: `strings.xml` with `values/`, `values-es/`, `values-pt/` directories. Localized App Actions.

**Tier:** FREE

---

### Onboarding [All]

First-run flow to introduce users to Pepinillo.

| Screen                    | Content                                        |
| ------------------------- | ---------------------------------------------- |
| 1. Welcome                | Branding, value proposition                    |
| 2. Focus Modes            | Visual explanation of the 4 modes              |
| 3. Default Mode Selection | User chooses their preferred mode              |
| 4. Setup                  | Durations, permissions (notifications, Health) |
| 5. Start                  | Ready to begin                                 |

- **[Android]**: 5 screens with interactive onboarding
- **[iOS]**: 3-4 screens including permission setup

**Tier:** FREE

---

### Offline Support [All]

- **Offline-first** architecture on both platforms
- 100% functional without internet connection
- All data is saved locally first:
  - **[iOS]**: SwiftData (local) -> CloudKit (sync)
  - **[Android]**: Room (local) -> Backend API (sync)
- Changes are queued and synced automatically when connectivity is restored
- No functional degradation offline (timer, tasks, local analytics)

**Tier:** FREE

---

## P1 — Nice-to-Have (Desirable)

### Soundscapes / Ambient Sounds [All]

Background sounds during focus sessions. They start automatically when a session starts and pause during breaks.

#### Sound Catalog

| Soundscape     | Tier |
| -------------- | ---- |
| Rain           | FREE |
| Forest         | FREE |
| Cafe           | FREE |
| White Noise    | FREE |
| Binaural Beats | PRO  |
| Lo-fi          | PRO  |
| Ocean          | PRO  |
| Fireplace      | PRO  |

**Total:** 4 free, 8 with PRO.

**Implementation:**

- **[iOS]**: `AVAudioEngine` with actor pattern for thread safety. Crossfade between play and pause.
- **[Android]**: Media3 / ExoPlayer for efficient playback. Audio focus management.

---

### Mode Intelligence [All]

Historical session analysis to suggest the best focus mode by task type.

- Requires 2+ weeks of data to activate
- Suggests a mode when confidence is >70%
- Example: "You complete 80% more writing tasks with Flowtime. Want to try it for today's blog post?"
- Non-intrusive banner on focus screen when selecting a task

**Tier:** PRO

---

### Streaks and Achievements [All]

#### Streaks

- Consecutive days with at least 1 completed session
- Milestones at: 7, 30, 100, 365 days
- Streak Protection: 1 free skip per week (PRO)
- Celebration animations when reaching milestones

#### Achievements

| Achievement     | Criterion                        |
| --------------- | -------------------------------- |
| First Session   | Complete the first focus session |
| Weekly Streak   | 7 consecutive days               |
| Pomodoro Master | 100 completed Pomodoro sessions  |
| Deep Diver      | 10 accumulated hours in Flowtime |
| Century Club    | 100 total sessions               |
| Early Bird      | 10 sessions started before 7 AM  |

- Horizontal scroll in the Analytics view
- Progress indicator for each achievement

**Tier:** FREE (basic streaks), PRO (streak protection, advanced achievements)

---

### Health Integration

#### [iOS] — Apple Health (HealthKit)

- Writes `HKCategorySample` as **Mindful Minutes** for each completed session
- Reads sleep data to suggest optimal focus windows (future)
- Requires user permission

#### [Android] — Health Connect

- Writes `MindfulnessSessionRecord` for each completed session
- Health Connect API (Android 14+)
- Requires user permission

**Tier:** PRO

---

### Quick Controls

#### [iOS] — Control Center Widget

- Widget for Control Center (iOS 18+)
- Quick-start focus session without opening app
- Shows current status (idle / in session)

#### [Android] — Quick Settings Tile

- `TileService` in notifications panel
- Quick start/stop session toggle
- Visual indicator of current status

**Tier:** FREE

---

### Import Tasks

#### [iOS] — Apple Reminders

- One-way import via **EventKit**
- Select Reminders list -> import as Pepinillo tasks
- No bidirectional sync

#### [Android] — Google Tasks

- Import via **OAuth** + Google Tasks API
- Select list -> import tasks
- No bidirectional sync

**Tier:** PRO

---

### Calendar Integration

#### [iOS] — Apple Calendar (EventKit)

- Block focus time in native calendar
- Read existing events to suggest available slots
- Display past sessions as events

#### [Android] — Google Calendar

- **Google Calendar API** + content provider
- Same functionality: block time, read events, suggest slots
- Parity with Apple Calendar integration

**Tier:** PRO

---

### System Focus Modes

#### [iOS] — Focus Modes (Apple Focus Filters)

- **FocusFilterIntent** to automatically activate a system Focus Mode when a session starts
- User links a Pepinillo focus mode to an iOS Focus Mode
- Contextual notification silencing

#### [Android] — DND / Focus Mode

- Integration with **Digital Wellbeing Focus Mode** API
- Automatically activates Do Not Disturb when session starts
- Restores previous status when session ends

**Tier:** PRO

---

### Subscription / Billing

#### [iOS] — RevenueCat SDK v5+

- RevenueCat SDK v5+ wrapping native StoreKit 2
- Products: Monthly, Annual, Lifetime
- iOS Public API Key: `appl_xnChlVXXtUFhusIfJyNrNDcMGLj`
- Entitlement: `pro` (unified as `premium` in backend)
- Server-side verification via Go backend + RevenueCat
- Native restore purchases
- Grace period: 3 days supported

#### [Android] — RevenueCat Purchases SDK v8.10.0 ✅ NEW

- RevenueCat Purchases SDK v8.10.0
- Products: Monthly, Annual, Lifetime
  - com.pepinillo.app.pro.monthly
  - com.pepinillo.app.pro.annual
  - com.pepinillo.app.pro.lifetime
- Android Public API Key: `goog_ITPYSPEdubAzAeoNGxezZuZJELT`
- Entitlement: `premium` (unified with iOS)
- Server-side verification via Go backend + RevenueCat
- Grace period: 3 days supported
- **Cross-platform parity ACHIEVED:** Both iOS and Android now use RevenueCat

#### Prices

| Plan     | Global (US/EU)                        | LATAM (MX/CO/AR/BR/CL/PE) |
| -------- | ------------------------------------- | -------------------------- |
| Monthly  | $3.99/month                           | $1.99/month                |
| Annual   | $24.99/year (~$2.08/month, 48% save) | $12.99/year (~$1.08/month) |
| Lifetime | $49.99                                | $29.99                     |

---

### User Profile [All]

Profile screen with account information and productivity statistics.

#### Account Information

| Field            | Detail                                                        | Tier |
| ---------------- | ------------------------------------------------------------- | ---- |
| Avatar           | User profile photo (from Google/Apple or custom)             | FREE |
| Name and Email   | Basic account data                                            | FREE |
| Account Type     | Free or Pro (tier: monthly/annual/lifetime + expiration date) | FREE |
| Linked Accounts  | Connected providers (Google, Apple, email/password)          | FREE |

#### Profile Statistics

| Statistic         | Detail                                         | Tier |
| ----------------- | ---------------------------------------------- | ---- |
| Current Streak    | Consecutive days with at least 1 session       | FREE |
| Longest Streak    | Historical record of consecutive days           | FREE |
| Total Focus Hours | Accumulated sum of all sessions                 | FREE |
| Total Sessions    | Total number of completed sessions              | FREE |
| Completed Tasks   | Total number of tasks marked as completed       | FREE |
| Member Since      | Account registration date                       | FREE |

**Implementation:**

- **[iOS]**: SwiftUI screen with profile data from backend + local/synced statistics
- **[Android]**: Compose screen with Circuit presenter, backend data via Ktor

---

### Social Login [All]

Authentication with social providers in addition to email/password.

#### Providers

| Provider           | Platform      | Implementation                                               | Tier |
| ------------------ | ------------- | ------------------------------------------------------------ | ---- |
| Google Sign-In     | **[Android]** | Credential Manager API (replaces legacy play-services-auth) | FREE |
| Sign In with Apple | **[iOS]**     | AuthenticationServices framework (native)                    | FREE |
| Email / Password   | **[All]**     | JWT via Go backend (already implemented)                     | FREE |

#### Account Linking

- Connect multiple providers to one account (e.g., Google + Apple + email)
- Allows user to access from any device with any linked provider
- Backend is source of truth for user identity
- **Tier:** FREE

---

### Cloud Sync and Multi-Device [All]

Bidirectional data synchronization between devices via Go backend.

#### Synced Data

| Entity         | Direction     | Conflict Resolution            |
| -------------- | ------------- | ------------------------------ |
| Tasks          | Bidirectional | last-write-wins by `updatedAt` |
| Focus Sessions | Bidirectional | last-write-wins by `updatedAt` |
| Statistics     | Bidirectional | Additive merge                 |
| Preferences    | Bidirectional | last-write-wins by `updatedAt` |

#### Sync Mechanisms

| Mechanism         | Use Case  | Detail                                                            |
| ----------------- | --------- | ----------------------------------------------------------------- |
| WebSocket         | Real-time | Instant notification of changes between connected devices         |
| Periodic REST API | Fallback  | WorkManager (Android) / BackgroundTasks (iOS) every 15 min       |
| Dirty Flags       | Offline   | Local changes marked as pending and sent when reconnected         |

#### Multi-Device

- Same account across multiple devices (phone + watch + tablet) stays synchronized
- Backend coordinates status across devices
- Offline-first: each device works independently, syncs when reconnected

**Implementation:**

- **[Android]**: SyncEngine + Room dirty flags + WorkManager (already exists, needs WebSocket improvements)
- **[iOS]**: New API client Ktor/URLSession, replacing CloudKit as the primary sync source

**Tier:** PRO

---

### Cross-Platform Subscriptions [All]

Pay in either store (App Store or Google Play) and get PRO on all platforms.

#### Flow

1. User purchases subscription in App Store or Google Play
2. Client sends receipt to Go backend (`/api/v1/billing/verify`)
3. Backend verifies receipt with corresponding store (Apple App Store Server API / Google Play Developer API)
4. Backend updates user subscription status
5. All user devices receive PRO status on sync

#### Architecture

| Component           | Detail                                                                     |
| ------------------- | -------------------------------------------------------------------------- |
| Source of truth     | Go backend (not local device)                                              |
| Apple verification  | App Store Server API v2 (server-to-server)                                |
| Google verification | Google Play Developer API (server-to-server)                              |
| Grace period        | 3 days before revoking access after renewal failure                        |
| Polling             | Client checks subscription status on app start and periodically            |

**Tier:** — (billing infrastructure)

---

## P2 — Future

| Feature                          | Platform  | Description                                                                                      |
| -------------------------------- | --------- | ------------------------------------------------------------------------------------------------ |
| Advanced AI Insights             | [All]     | Predict productive windows, suggest task scheduling, detect burnout patterns                     |
| Social Accountability            | [All]     | Shared focus sessions with a partner. CloudKit shared zones (iOS) / Backend (Android)           |
| CSV/PDF Export                   | [All]     | Export productivity data in standard formats                                                      |
| Apple Vision Pro                 | [iOS]     | Immersive focus environment with SwiftUI multiplatform                                            |
| Device Handoff                   | [iOS]     | `NSUserActivity` to continue sessions across iPhone/iPad/Mac without interruptions               |
| Shortcuts Automation             | [iOS]     | Complex workflows: "When I arrive at the library, start Pomodoro" via Shortcuts                |
| Cross-platform Sync              | [All]     | iOS <-> Android synchronization via shared Go backend                                             |
| Pomodoro -> Flowtime auto-switch | [All]     | If user consistently skips Pomodoro breaks, suggest switching to Flowtime                         |
| Tablet optimized                 | [Android] | Samsung tablets, split-screen productivity, adaptive layouts for foldables                       |

---

## Feature Parity Table

### Legend

| Symbol | Meaning               |
| ------ | --------------------- |
| ✅     | Implemented           |
| 🔄     | In progress           |
| ⬜     | Pending               |
| ➖     | Does not apply (N/A)  |

### P0 — Must-Have

| Feature                                | iOS | Android | watchOS | Wear OS | Tier |
| -------------------------------------- | --- | ------- | ------- | ------- | ---- |
| **Focus Engine**                       |     |         |         |         |      |
| Pomodoro mode                          | ✅  | ✅      | ⬜      | ✅      | FREE |
| Flowtime mode                          | ✅  | ✅      | ⬜      | ✅      | PRO  |
| Time Block mode                        | ✅  | ✅      | ⬜      | ✅      | PRO  |
| Stopwatch/Chrono mode                  | ✅  | ✅      | ⬜      | ✅      | FREE |
| Strategy pattern engine                | ✅  | ✅      | ⬜      | ✅      | —    |
| Background timer survival              | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Pause/Resume tracking                  | ✅  | ✅      | ⬜      | ✅      | FREE |
| Session journaling                     | ✅  | ✅      | ➖      | ➖      | FREE |
| **Task Management**                    |     |         |         |         |      |
| Task CRUD                              | ✅  | ✅      | ⬜      | ✅      | FREE |
| Drag-to-reorder                        | ✅  | ✅      | ➖      | ➖      | FREE |
| Subtasks                               | ✅  | ✅      | ➖      | ➖      | PRO  |
| Priority (none/low/med/high)           | ✅  | ✅      | ➖      | ➖      | FREE |
| Energy levels                          | ✅  | ✅      | ➖      | ➖      | FREE |
| Estimated/completed pomodoros          | ✅  | ✅      | ➖      | ➖      | FREE |
| Link task to session                   | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Recurring tasks                        | ✅  | ✅      | ➖      | ➖      | PRO  |
| **Analytics and Dashboard**            |     |         |         |         |      |
| Daily summary (7 days)                 | ✅  | ✅      | ⬜      | ✅      | FREE |
| 30-day view                            | ✅  | ✅      | ➖      | ➖      | PRO  |
| 1-year view                            | ✅  | ✅      | ➖      | ➖      | PRO  |
| Mode breakdown (charts)                | ✅  | ✅      | ➖      | ➖      | PRO  |
| Achievements (6 types)                 | ✅  | ✅      | ➖      | ➖      | FREE |
| Weekly Review                          | ✅  | ✅      | ➖      | ➖      | PRO  |
| Monthly Review                         | ✅  | ✅      | ➖      | ➖      | PRO  |
| AI Productivity Reports                | 🔄  | 🔄      | ➖      | ➖      | PRO  |
| **Widgets**                            |     |         |         |         |      |
| Home Screen — Small                    | ✅  | ⬜      | ➖      | ➖      | FREE |
| Home Screen — Medium                   | ✅  | ⬜      | ➖      | ➖      | PRO  |
| Home Screen — Large                    | ✅  | ⬜      | ➖      | ➖      | PRO  |
| Lock Screen widget                     | ✅  | ⬜      | ➖      | ➖      | FREE |
| **Notifications**                      |     |         |         |         |      |
| Phase transition                       | ✅  | ✅      | ✅      | ✅      | FREE |
| Daily reminder                         | ✅  | ✅      | ➖      | ➖      | FREE |
| Session completed                      | ✅  | ✅      | ✅      | ✅      | FREE |
| Notification actions                   | ✅  | ✅      | ➖      | ➖      | FREE |
| **Live Activity / Persistent Notif.**  |     |         |         |         |      |
| Dynamic Island + Live Activity         | ✅  | ➖      | ➖      | ➖      | FREE |
| Foreground notification with progress  | ➖  | ✅      | ➖      | ➖      | FREE |
| **Smartwatch**                         |     |         |         |         |      |
| Watch timer                            | ⬜  | ➖      | ⬜      | ✅      | PRO  |
| Mode selection                         | ⬜  | ➖      | ⬜      | ✅      | PRO  |
| Watch task list                        | ⬜  | ➖      | ⬜      | ✅      | PRO  |
| Watch dashboard/stats                  | ⬜  | ➖      | ⬜      | ✅      | PRO  |
| Complications (enhanced)               | ⬜  | ➖      | ✅      | ✅      | PRO  |
| Focus Timer Tile (enhanced)            | ➖  | ➖      | ➖      | ✅      | PRO  |
| Tasks Tile                             | ➖  | ➖      | ✅      | ✅      | PRO  |
| Watch haptics                          | ⬜  | ➖      | ⬜      | ⬜      | PRO  |
| **Voice Assistant**                    |     |         |         |         |      |
| Siri Shortcuts + App Intents           | ✅  | ➖      | ➖      | ➖      | FREE |
| Google Assistant App Actions           | ➖  | ⬜      | ➖      | ➖      | FREE |
| **Synchronization**                    |     |         |         |         |      |
| CloudKit sync                          | ✅  | ➖      | ✅      | ➖      | PRO  |
| Backend REST API + Room sync           | ➖  | 🔄      | ➖      | 🔄      | PRO  |
| **Themes and Design**                  |     |         |         |         |      |
| Classic theme                          | ✅  | ✅      | ✅      | ✅      | FREE |
| Forest / Ocean / Sunset                | ✅  | ✅      | ⬜      | ✅      | PRO  |
| Theme picker (horizontal scroll cards) | ✅  | ✅      | ➖      | ➖      | FREE |
| Liquid Glass (iOS 26)                  | ⬜  | ➖      | ⬜      | ➖      | PRO  |
| Material You dynamic colors            | ➖  | ✅      | ➖      | ✅      | FREE |
| Light/Dark/System appearance selector  | ✅  | ✅      | ✅      | ✅      | FREE |
| Focus mode colors (red/purple/green)   | ✅  | ✅      | ✅      | ✅      | FREE |
| Theme sync phone -> watch              | ➖  | ➖      | ✅      | ✅      | FREE |
| Glassmorphism effects                  | ✅  | ✅      | ➖      | ➖      | FREE |
| **Localization**                       |     |         |         |         |      |
| English (EN)                           | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Spanish (ES)                           | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Portuguese (PT)                        | ✅  | ✅      | ⬜      | ⬜      | FREE |
| **Onboarding**                         |     |         |         |         |      |
| First-run flow                         | ✅  | ✅      | ➖      | ➖      | FREE |
| Default mode selection                 | ✅  | ✅      | ➖      | ➖      | FREE |
| Permission requests                    | ✅  | ✅      | ➖      | ➖      | FREE |
| **Offline Support**                    |     |         |         |         |      |
| Offline-first architecture             | ✅  | ✅      | ⬜      | ✅      | FREE |

### P1 — Nice-to-Have

| Feature                           | iOS | Android | watchOS | Wear OS | Tier |
| --------------------------------- | --- | ------- | ------- | ------- | ---- |
| Soundscapes (4 basic)             | ✅  | ⬜      | ➖      | ➖      | FREE |
| Soundscapes (8 total)             | ✅  | ⬜      | ➖      | ➖      | PRO  |
| Mode Intelligence                 | ✅  | ⬜      | ➖      | ➖      | PRO  |
| Streaks                           | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Streak Protection (1 skip/week)   | ⬜  | ⬜      | ➖      | ➖      | PRO  |
| Apple Health (Mindful Minutes)    | ⬜  | ➖      | ➖      | ➖      | PRO  |
| Health Connect (Mindful Minutes)  | ➖  | ⬜      | ➖      | ➖      | PRO  |
| Control Center widget (iOS 18+)   | ✅  | ➖      | ➖      | ➖      | FREE |
| Quick Settings Tile               | ➖  | ⬜      | ➖      | ➖      | FREE |
| Apple Reminders import            | ⬜  | ➖      | ➖      | ➖      | PRO  |
| Google Tasks import               | ➖  | ⬜      | ➖      | ➖      | PRO  |
| Apple Calendar integration        | ✅  | ➖      | ➖      | ➖      | PRO  |
| Google Calendar integration       | ➖  | ✅      | ➖      | ➖      | PRO  |
| Focus Modes (FocusFilterIntent)   | ⬜  | ➖      | ➖      | ➖      | PRO  |
| DND / Focus Mode API              | ➖  | ⬜      | ➖      | ➖      | PRO  |
| StoreKit 2 subscriptions          | ✅  | ➖      | ➖      | ➖      | —    |
| Google Play Billing 7             | ➖  | 🔄      | ➖      | ➖      | —    |

### P2 — Future

| Feature                               | iOS | Android | watchOS | Wear OS | Tier |
| ------------------------------------- | --- | ------- | ------- | ------- | ---- |
| Advanced AI Insights                  | ⬜  | ⬜      | ➖      | ➖      | PRO  |
| Social Accountability                 | ⬜  | ⬜      | ➖      | ➖      | PRO  |
| CSV/PDF Export                        | ⬜  | ⬜      | ➖      | ➖      | PRO  |
| Apple Vision Pro                      | ⬜  | ➖      | ➖      | ➖      | PRO  |
| Device handoff                        | ⬜  | ➖      | ⬜      | ➖      | PRO  |
| Shortcuts automation                  | ⬜  | ➖      | ➖      | ➖      | PRO  |
| Cross-platform sync (iOS <-> Android) | ⬜  | ⬜      | ⬜      | ⬜      | PRO  |
| Pomodoro -> Flowtime auto-switch      | ⬜  | ⬜      | ➖      | ➖      | PRO  |
| Tablet/Foldable optimized             | ➖  | ⬜      | ➖      | ➖      | FREE |

### Planned — Backend and Accounts

| Feature                                        | iOS | Android | watchOS | Wear OS | Tier |
| ---------------------------------------------- | --- | ------- | ------- | ------- | ---- |
| **User Profile**                               |     |         |         |         |      |
| Profile screen (avatar, name, account type)   | ⬜  | ⬜      | ➖      | ➖      | FREE |
| Profile stats (streak, hours, sessions)        | ⬜  | ⬜      | ➖      | ➖      | FREE |
| Linked accounts (Google/Apple/email)          | ⬜  | ⬜      | ➖      | ➖      | FREE |
| **Social Login**                               |     |         |         |         |      |
| Google Sign-In (Credential Manager)           | ➖  | ⬜      | ➖      | ➖      | FREE |
| Sign In with Apple                             | ⬜  | ➖      | ➖      | ➖      | FREE |
| Account linking (multiple providers)          | ⬜  | ⬜      | ➖      | ➖      | FREE |
| **Cloud Sync and Multi-Device**               |     |         |         |         |      |
| Bidirectional sync via Go backend             | ⬜  | 🔄      | ⬜      | 🔄      | PRO  |
| WebSocket real-time sync                      | ⬜  | ⬜      | ⬜      | ⬜      | PRO  |
| Multi-device coordination                     | ⬜  | ⬜      | ⬜      | ⬜      | PRO  |
| **Cross-Platform Subscriptions**              |     |         |         |         |      |
| Server-side receipt verification              | ⬜  | ⬜      | ➖      | ➖      | —    |
| Shared PRO status across stores               | ⬜  | ⬜      | ⬜      | ⬜      | —    |

---

## Feature Count Summary

| Category                       | Total  | Implemented (at least 1 platform) | Pending |
| ------------------------------ | ------ | ---------------------------------- | ------- |
| P0 — Must-Have                 | 52     | 38                                 | 14      |
| P1 — Nice-to-Have              | 17     | 8                                  | 9       |
| Planned — Backend and Accounts | 12     | 0                                  | 12      |
| P2 — Future                    | 9      | 0                                  | 9       |
| **Total**                      | **90** | **46**                             | **44**  |

---

## Cross-Platform Parity Notes

1. **Enhanced Wear OS and watchOS tiles/widgets**: Wear OS now has two rich tiles (Focus Timer with progress arc + Tasks with top 4 tasks) and enhanced complications with live countdown. watchOS Smart Stack widgets were redesigned with live countdowns, phase info, linked task names, and smart relevance scoring. watchOS now also has a Tasks complication (accessoryRectangular, accessoryCircular, accessoryCorner). Both platforms persist extended snapshot data (linked task, session count, theme colors, phase dates) for tile/widget access. Pomodoro live countdown verified working on both platforms (Wear OS tile updates live; watchOS complication shows countdown even at progress=0).

2. **iOS is ahead in ecosystem integrations**: Widgets, Live Activity, Siri, Calendar, Control Center, Mode Intelligence, and Soundscapes are already implemented on iOS. Android still has pending work for widgets, Quick Settings, Assistant, and Soundscapes.

3. **Android paywall is in progress**: `PaywallScreen` and `PaywallViewModel` exist, but complete feature-gating enforcement is still pending.

4. **Inconsistent feature-gating on iOS**: According to the `PLAN_FREE_PRO_TIERS` analysis, several features advertised as PRO in the iOS paywall are not truly gated yet (analytics >7 days, sync, widgets, themes, subtasks, recurrence). Alignment is required.

5. **Theme parity achieved**: Both platforms (Android + iOS) have 4 named themes (Classic, Forest, Ocean, Sunset) with a horizontal-scroll-card theme picker, consistent focus mode colors (Pomodoro=red, TimeBlock=purple, Chrono=green), and PRO gating for Forest/Ocean/Sunset. Android additionally offers Material You as an option. iOS has a Light/Dark/System selector. Wear OS syncs the selected theme from Android phone.

6. **Session Journaling promoted to P0**: Originally P2 in iOS PRD, now implemented on both phone platforms as part of the focus engine.

7. **Go backend exists but is not deployed**: The backend in `backend/` implements a complete REST API (auth, tasks, sessions, stats, billing verify, push notifications, WebSocket, AI insights) but is not yet in production. It needs hosting (Railway/Fly.io/VPS) + PostgreSQL + Redis.

8. **Social login planned**: Google Sign-In (Android via Credential Manager) and Sign In with Apple (iOS via AuthenticationServices) are planned. Backend must add OAuth providers. Account linking will allow multiple providers per account.

9. **Unified cloud sync planned**: iOS currently uses CloudKit and Android uses Go backend. The plan is to migrate both platforms to Go-backend sync to enable cross-platform sync and shared subscriptions.