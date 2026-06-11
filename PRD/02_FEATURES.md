# Pepinillo — Unified Features Document

**Version:** 1.3  
**Last Updated:** 2026-06-11  
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

### Commercial Labels

| Label | Meaning |
| ----- | ------- |
| **FREE** | Core offline Pepinillo experience |
| **PEPINILLO+** | One-time purchase — full Apple experience with Apple Intelligence (not a subscription) |
| **EVERYWHERE/AI+** | Recurring subscription — cross-platform sync + Advanced AI (Coach, Scheduling, Subtask Gen) + 100 AI credits/month |

**Commercial note:** older parts of this document still use legacy `PRO` or `APPLE` wording in places. Unless explicitly stated otherwise, `APPLE` should now be interpreted as **PEPINILLO+** and `EVERYWHERE` as **EVERYWHERE/AI+**. The canonical rollout lives in [PRD/04_MONETIZATION.md](PRD/04_MONETIZATION.md) v3.0.

## Product Reset (2026-04-21)

### Product Pillars

| Pillar | Role | Must own |
| ------ | ---- | -------- |
| **Execute** | Help users start and sustain deep work fast | Focus screen, timer state, mode choice, in-session task link, post-session reflection entry |
| **Plan** | Turn work into a realistic deep-work plan | Inbox, Today, Upcoming, lightweight projects/areas, dates, energy, recurrence, task detail |
| **Reflect** | Teach the user what works and what to improve | Dashboard, Weekly Review, Monthly Review, goals, AI coaching, progress summaries |
| **Admin** | Manage identity, settings, subscription, export, and support | Profile, auth, paywall, settings, sync state, help |

### Core Screen Architecture

| Surface | Responsibility | Rule |
| ------- | -------------- | ---- |
| **Focus** | Hero execution surface | Must always be the fastest path to timer-running |
| **Plan** | Task planning and daily shaping | Medium-depth personal planning, not generic project management |
| **Dashboard** | Reflection, reviews, goals, and coaching | Reviews live here, not as hidden duplicate destinations |
| **Account / Admin** | Profile, auth, subscription, settings, export, help | Essential, but not a co-equal productivity destination |
| **Contextual flows** | Paywall, auth, session reflection, task detail, calendar pickers | Should appear when needed, not live as primary tabs |

### IA Rules

- Phone apps should expose only **3 primary productivity destinations**: `Focus`, `Plan`, and `Dashboard`.
- `Settings`, `Profile`, `Subscription`, and support belong under **Account / Admin**, not the main productivity axis.
- `Weekly Review` and `Monthly Review` belong to `Dashboard`.
- `Focus` remains the hero. `Plan` supports Focus. `Dashboard` teaches the user what to change next.
- During the current transition, the shipping phone runtime may temporarily expose a fourth tab labeled `More` to host **Account / Admin** while ownership is consolidated. This does not change the target-state rule of 3 primary productivity destinations.

---

## P0 — Must-Have (Mandatory)

### Multi-Modal Focus Engine [All]

Pepinillo's primary differentiator: 4 focus techniques in one app, implemented with **Strategy pattern** to share 80% of timer logic across modes.

#### Available Modes

| Mode                   | Description                                                                                                                                                                                                  | Tier |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- |
| **Pomodoro**           | Classic 25/5/15 intervals. Automatic work-break-work cycles. Tracks pomodoro count (e.g., "3 of 4"). Customizable durations.                                                                             | FREE |
| **Flowtime**           | Open-ended session without fixed intervals. When fatigue hits, user takes a break. App suggests break duration based on focused time (10 min -> 2 min break, 50 min -> 10 min break). Ideal for creative work. | APPLE  |
| **Time Block**         | Fixed time block (e.g., "2 hours of writing"). Continuous countdown with optional mid-point check-ins. Tracks completed blocks per day.                                                                  | APPLE  |
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

Integrated planning layer for the focus engine. Pepinillo Tasks should be **deeper than a timer app** and **lighter than Todoist/Things**: serious enough for daily deep work, without becoming bloated personal PM software.

#### Planning Guardrails

- Canonical planning views: **Inbox**, **Today**, **Upcoming**, and **lightweight projects/areas**.
- Dates and calendar context should support planning, not replace the calendar app.
- Energy, recurrence, estimates, and task-to-session linkage remain part of the core model.
- No collaboration, team boards, document sprawl, or enterprise-style task management.

#### Core Functionality

| Feature                    | Tier                            | Details                                                                                                |
| -------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Task CRUD                  | FREE                            | Create, edit, delete tasks with title and description                                                  |
| Drag-to-reorder            | FREE                            | Reorder tasks by priority via drag                                                                     |
| Subtasks                   | APPLE                           | Nested subtasks (up to 20 per task) with individual checkboxes                                         |
| Priority                   | FREE                            | None / Low / Medium / High — visual indicator                                                          |
| Energy Levels              | FREE                            | Deep Work / Shallow Work / Admin — group similar tasks                                                 |
| Est./Completed Pomodoros   | FREE                            | Assign pomodoro estimate to task, track completed                                                      |
| Link Task to Focus Session | FREE                            | Any focus mode can link to active task. Session records: task, mode used, duration, completion status |
| Recurring Tasks            | APPLE                           | 5 presets: daily, weekdays, weekly, biweekly, monthly                                                  |
| Task Limit                 | FREE: 3 active / APPLE: unlimited | Natural upgrade motivation                                                                            |

---

### Dashboard / Reflect [All]

Dashboard is the **reflection home** of Pepinillo. It should not just show charts; it should help the user understand progress, review the week, and make better next decisions.

#### Reflect Model (Product Reset)

- `Dashboard` owns **Weekly Review**, **Monthly Review**, goals, trend interpretation, and coaching.
- Calendar access and date filters support Dashboard, but do not become separate primary destinations.
- MVP intelligence means **reports, mode recommendations, and priority coaching**.
- Post-MVP exploration can include planning assistant, scheduling help, and subtask generation.

#### Time Views

| View                | Tier |
| ------------------- | ---- |
| Today + Last 7 Days | FREE |
| 30 Days             | APPLE  |
| 1 Year              | APPLE  |

#### Dashboard Components

| Component               | Tier | Details                                                                                             |
| ----------------------- | ---- | --------------------------------------------------------------------------------------------------- |
| Daily Summary           | FREE | Focus hours, completed sessions, finished tasks                                                     |
| Mode Breakdown          | APPLE  | Charts showing time distribution across Pomodoro/Flowtime/TimeBlock/Chrono                         |
| Most Productive Hours   | APPLE  | Analysis by hour of day and day of week                                                             |
| Completion Rate by Mode | APPLE  | Helps users discover which technique works best                                                     |
| Achievements            | FREE | 6 badge types: First Session, Weekly Streak, Pomodoro Master, Deep Diver, Century Club, Early Bird |
| Weekly Review           | APPLE  | Weekly comparison: focus hours, mode distribution, tasks, streaks. Trend arrows vs. previous week  |
| Monthly Review          | APPLE  | Monthly review with long-term trends and productivity patterns                                      |
| AI Productivity Reports | APPLE  | Local/on-device AI-generated reports. Cloud credit-based AI workflows belong to Everywhere          |

#### AI Reports Implementation by Platform

- **[iOS]**: Apple Foundation Models (iOS 18+). Fallback to predefined templates with interpolated data if device doesn't support Foundation Models.
- **[Android]**: On-device ML (Gemini Nano / smart templates). Fallback to templates with interpolated data if ML unavailable.
- **Pepinillo Everywhere**: monthly AI credits unlock cloud-backed AI workflows that should not depend on local model availability.

---

### Widgets [All]

Multiple widgets to interact with Pepinillo without opening the app.

#### Home Screen Widgets

| Size       | Content                                | Tier |
| ---------- | -------------------------------------- | ---- |
| Small (S)  | Active timer or daily progress         | FREE |
| Medium (M) | Timer + top 3 tasks of the day         | APPLE  |
| Large (L)  | Timer + tasks + daily mode-based stats | APPLE  |

**Implementation:**

- **[iOS]**: WidgetKit with Timeline Provider. Interactive widget support (iOS 17+).
- **[Android]**: Glance Compose (Jetpack). No legacy RemoteViews.

#### Lock Screen Widget

- **[iOS]**: WidgetKit Lock Screen widgets (circular, rectangular, inline)
- **[Android]**: Glance widget with `KEYGUARD` category (API 33+, Android 13+)

**Tier:** Basic timer widget = FREE. Additional widgets = APPLE.

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
| Focus Timer Tile | Enhanced tile with progress arc (colored by mode), timer display, phase label, session counter, linked task name. Distinct idle/running/paused states. Built with Tiles 1.4.1 + ProtoLayout Material 1.2.1. Free users see a locked state and upgrade CTA. | PEPINILLO+ / EVERYWHERE/AI+ |
| Tasks Tile       | Second tile showing top 4 tasks with energy emoji, truncated title, pomodoro progress, and completed/total header. Free users see a locked state and upgrade CTA.                                                                                    | PEPINILLO+ / EVERYWHERE/AI+ |
| Complication     | Focus data in watch face. Free users receive a locked fallback instead of live premium timer data.                                                                                                                                             | PEPINILLO+ / EVERYWHERE/AI+ |
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

#### [iOS] — Backend REST API + SwiftData + WebSocket

- **Go backend** with REST API + WebSocket for data sync (replacing CloudKit as primary sync)
- **SwiftData** as local database with TCA dependency clients
- **SyncClient** (TCA `@DependencyClient`): syncSettings(), batch syncSessions(), initialUpload(), performInitialSync() (cursor pagination), wipeAndSync(), hasLocalData()
- **IdentityClient** (TCA `@DependencyClient`): manages ANONYMOUS/REGISTERED/VERIFIED state transitions
- **WebSocketClient** (TCA `@DependencyClient`): URLSessionWebSocketTask, exponential backoff (1s, 2s, 4s, 8s, max 30s), message dispatch
- **SettingsFeature**: dirty tracking per preference key with PreferenceDirtyTracker (UserDefaults-based)
- **Settings sync**: per-key LWW for 17 syncable keys (5 device-specific excluded)
- **Batch session sync**: `POST /sync/sessions` replaces individual POSTs
- **Initial upload**: `POST /sync/initial-upload` atomic upload when anonymous user registers
- **New device sync**: `GET /sync/full` with cursor-based pagination
- **DataMergeView**: SwiftUI merge dialog for anonymous-to-existing-account choice (upload local vs download cloud)
- **Auth flow integration**: AuthFeature + AppFeature coordinate initial upload, merge dialog, and initial sync wiring
- **App lifecycle**: WebSocket connects/disconnects on foreground/background via AppFeature scene phase handling
- **Conflict resolution**: Record-level Last-Write-Wins with detection
- **X-Device-ID**: KeychainClient.getOrCreateDeviceId provides device identification for sync requests
- Offline-first: SwiftData is source of truth, sync occurs when reconnected
- Synced entities: Tasks, Sessions, Stats, Preferences
- **CloudKit**: retained as secondary sync layer for Apple-to-Apple device sync
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
- **Outcome rule:** onboarding should end in `Focus`, ready to start the first session, while `Plan` and `Dashboard` are introduced progressively.

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
- **Pepinillo+** (one-time, not a subscription): `com.pepinillo.app.pro.lifetime`
- **Everywhere/AI+ Monthly**: `com.pepinillo.app.pro.monthly`
- **Everywhere/AI+ Annual**: `com.pepinillo.app.pro.annual`
- iOS Public API Key: `appl_xnChlVXXtUFhusIfJyNrNDcMGLj`
- Entitlement resolution: `everywhere_plus` > `pepinillo_plus` > legacy `premium`/`pro`
- Server-side verification via Go backend + RevenueCat
- Native restore purchases
- Grace period: 3 days supported

#### [Android] — RevenueCat Purchases SDK v8.10.0 ✅ NEW

- RevenueCat Purchases SDK v8.10.0
- Rollout products: Everywhere Monthly, Everywhere Annual
- Android Public API Key: `goog_ITPYSPEdubAzAeoNGxezZuZJELT`
- Current runtime entitlement: `premium` (legacy naming drift to remove)
- Server-side verification via Go backend + RevenueCat
- Grace period: 3 days supported
- **Cross-platform billing stack parity:** both platforms use RevenueCat, but packaging still needs migration to Apple Unlock + Everywhere

#### Prices

| Offer | Global (US/EU) | LATAM (MX/CO/AR/BR/CL/PE) | Type |
| ----- | -------------- | -------------------------- | ---- |
| Pepinillo+ | $19.99 one-time | $9.99 one-time | **Not a subscription** |
| Everywhere/AI+ Monthly | $4.99/month | $2.49/month | Subscription |
| Everywhere/AI+ Annual | $34.99/year (~$2.92/month) | $17.99/year (~$1.50/month) | Subscription |

---

### Account / Admin Hub [All]

Administrative surface for account information and productivity identity. It owns profile, auth state, subscription, settings, sync state, export, and support without competing with Focus, Plan, or Dashboard in primary navigation.

**Current runtime note:** on phone, this surface may be labeled `More`. `More` is the current shipping label for the Account / Admin hub on iPhone, and Android phone is converging to the same label during the active parity phase.

#### Account Information

| Field            | Detail                                                        | Tier |
| ---------------- | ------------------------------------------------------------- | ---- |
| Avatar           | User profile photo (from Google/Apple or custom)             | FREE |
| Name and Email   | Basic account data                                            | FREE |
| Account Type     | Free, Apple Unlock, or Everywhere (with cycle / expiration when applicable) | FREE |
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

- **[iOS]**: SwiftUI/TCA `More` tab that owns auth, profile, subscription, settings, export, help/support, and about, with profile data coming from backend plus Apple-local cached state where needed
- **[Android]**: Compose + ViewModel `More` hub that owns profile, auth entry points, paywall, settings, app setup, and support entry points; `Export` remains an explicit parity gap

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

Pepinillo supports **two sync layers** during the Apple-first monetization rollout.

#### Apple-Local Sync [iOS]

- CloudKit / iCloud synchronization between Apple devices on the same Apple account
- No backend account, no store-portable entitlement, and no cross-platform promise
- **Tier:** APPLE or EVERYWHERE

#### Backend Sync [All]

Bidirectional data synchronization between supported devices via the Go backend.

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

- **[Android]**: SyncEngine + Room dirty flags + WorkManager + SyncWebSocketClient (OkHttp)
- **[iOS]**: SyncClient + IdentityClient + WebSocketClient (TCA dependencies) + URLSession API client, with CloudKit retained as secondary sync layer

**Tier:** EVERYWHERE

---

### Pepinillo Everywhere Subscription [All]

Pepinillo Everywhere is the recurring layer that funds backend sync, account-based restore, and monthly AI credits.

#### Flow

1. User purchases Pepinillo Everywhere in App Store or Google Play
2. Client sends receipt to Go backend (`/api/v1/billing/verify`)
3. Backend verifies receipt with corresponding store (Apple App Store Server API / Google Play Developer API)
4. Backend updates user capabilities (`backend_sync`, `ai_credits_monthly`, and any bundled local premium access)
5. All supported user devices receive updated paid status on sync

#### Architecture

| Component           | Detail                                                                     |
| ------------------- | -------------------------------------------------------------------------- |
| Source of truth     | Go backend capability model (not local device)                             |
| Apple verification  | App Store Server API v2 (server-to-server)                                |
| Google verification | Google Play Developer API (server-to-server)                              |
| Grace period        | 3 days before revoking access after renewal failure                        |
| Polling             | Client checks subscription status on app start and periodically            |
| AI credits          | Reset monthly; no rollover in launch scope                                 |

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
| Flowtime mode                          | ✅  | ✅      | ⬜      | ✅      | APPLE / EVERYWHERE  |
| Time Block mode                        | ✅  | ✅      | ⬜      | ✅      | APPLE / EVERYWHERE  |
| Stopwatch/Chrono mode                  | ✅  | ✅      | ⬜      | ✅      | FREE |
| Strategy pattern engine                | ✅  | ✅      | ⬜      | ✅      | —    |
| Background timer survival              | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Pause/Resume tracking                  | ✅  | ✅      | ⬜      | ✅      | FREE |
| Session journaling                     | ✅  | ✅      | ➖      | ➖      | FREE |
| **Task Management**                    |     |         |         |         |      |
| Task CRUD                              | ✅  | ✅      | ⬜      | ✅      | FREE |
| Drag-to-reorder                        | ✅  | ✅      | ➖      | ➖      | FREE |
| Subtasks                               | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Priority (none/low/med/high)           | ✅  | ✅      | ➖      | ➖      | FREE |
| Energy levels                          | ✅  | ✅      | ➖      | ➖      | FREE |
| Estimated/completed pomodoros          | ✅  | ✅      | ➖      | ➖      | FREE |
| Link task to session                   | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Recurring tasks                        | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| **Analytics and Dashboard**            |     |         |         |         |      |
| Daily summary (7 days)                 | ✅  | ✅      | ⬜      | ✅      | FREE |
| 30-day view                            | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| 1-year view                            | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Mode breakdown (charts)                | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Achievements (6 types)                 | ✅  | ✅      | ➖      | ➖      | FREE |
| Weekly Review                          | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Monthly Review                         | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| AI Productivity Reports                | ✅  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| **Widgets**                            |     |         |         |         |      |
| Home Screen — Small                    | ✅  | ⬜      | ➖      | ➖      | FREE |
| Home Screen — Medium                   | ✅  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Home Screen — Large                    | ✅  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
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
| Watch timer                            | ✅  | ➖      | ✅      | ✅      | APPLE / EVERYWHERE  |
| Mode selection                         | ✅  | ➖      | ✅      | ✅      | APPLE / EVERYWHERE  |
| Watch task list                        | ✅  | ➖      | ✅      | ✅      | APPLE / EVERYWHERE  |
| Watch dashboard/stats                  | ✅  | ➖      | ✅      | ✅      | APPLE / EVERYWHERE  |
| Complications (enhanced)               | ✅  | ➖      | ✅      | ✅      | APPLE / EVERYWHERE  |
| Focus Timer Tile (enhanced)            | ➖  | ➖      | ➖      | ✅      | APPLE / EVERYWHERE  |
| Tasks Tile                             | ➖  | ➖      | ✅      | ✅      | APPLE / EVERYWHERE  |
| Watch haptics                          | ⬜  | ➖      | ⬜      | ⬜      | APPLE / EVERYWHERE  |
| **Voice Assistant**                    |     |         |         |         |      |
| Siri Shortcuts + App Intents           | ✅  | ➖      | ➖      | ➖      | FREE |
| Google Assistant App Actions           | ➖  | ⬜      | ➖      | ➖      | FREE |
| **Synchronization**                    |     |         |         |         |      |
| CloudKit sync (Apple-to-Apple)         | 📋  | ➖      | 📋      | ➖      | 1.1 candidate after non-blocking sync validation |
| Backend REST API sync                  | ✅  | ✅      | ➖      | 🔄      | EVERYWHERE  |
| **Themes and Design**                  |     |         |         |         |      |
| Classic theme                          | ✅  | ✅      | ✅      | ✅      | FREE |
| Forest / Ocean / Sunset                | ✅  | ✅      | ⬜      | ✅      | APPLE / EVERYWHERE  |
| Theme picker (horizontal scroll cards) | ✅  | ✅      | ➖      | ➖      | FREE |
| Liquid Glass (iOS 26)                  | ⬜  | ➖      | ⬜      | ➖      | APPLE / EVERYWHERE  |
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
| Soundscapes (8 total)             | ✅  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Mode Intelligence                 | ✅  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Streaks                           | ✅  | ✅      | ⬜      | ⬜      | FREE |
| Streak Protection (1 skip/week)   | ✅  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Apple Health (Mindful Minutes)    | ✅  | ➖      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Health Connect (Mindful Minutes)  | ➖  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Control Center widget (iOS 18+)   | ✅  | ➖      | ➖      | ➖      | FREE |
| Quick Settings Tile               | ➖  | ⬜      | ➖      | ➖      | FREE |
| Apple Reminders import            | ✅  | ➖      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Google Tasks import               | ➖  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Apple Calendar integration        | ✅  | ➖      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Google Calendar integration       | ➖  | ✅      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Focus Modes (FocusFilterIntent)   | ⬜  | ➖      | ➖      | ➖      | APPLE / EVERYWHERE  |
| DND / Focus Mode API              | ➖  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| StoreKit 2 subscriptions          | ✅  | ➖      | ➖      | ➖      | —    |
| Google Play Billing 7             | ➖  | 🔄      | ➖      | ➖      | —    |

### P2 — Future

| Feature                               | iOS | Android | watchOS | Wear OS | Tier |
| ------------------------------------- | --- | ------- | ------- | ------- | ---- |
| Advanced AI Insights                  | ⬜  | ⬜      | ➖      | ➖      | EVERYWHERE  |
| Social Accountability                 | ⬜  | ⬜      | ➖      | ➖      | PRO  |
| CSV/PDF Export                        | ✅  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Apple Vision Pro                      | ⬜  | ➖      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Device handoff                        | ⬜  | ➖      | ⬜      | ➖      | APPLE / EVERYWHERE  |
| Shortcuts automation                  | ⬜  | ➖      | ➖      | ➖      | APPLE / EVERYWHERE  |
| Cross-platform sync (iOS <-> Android) | ⬜  | ⬜      | ⬜      | ⬜      | EVERYWHERE  |
| Pomodoro -> Flowtime auto-switch      | ⬜  | ⬜      | ➖      | ➖      | APPLE / EVERYWHERE  |
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
| Bidirectional sync via Go backend             | ✅  | 🔄      | ⬜      | 🔄      | EVERYWHERE  |
| WebSocket real-time sync                      | ✅  | ✅      | ⬜      | ⬜      | EVERYWHERE  |
| Multi-device coordination                     | ✅  | ✅      | ⬜      | ⬜      | EVERYWHERE  |
| **Cross-Platform Subscriptions**              |     |         |         |         |      |
| Server-side receipt verification              | ⬜  | ⬜      | ➖      | ➖      | —    |
| Shared paid state across stores               | ⬜  | ⬜      | ⬜      | ⬜      | —    |

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

1. **Enhanced Wear OS and watchOS tiles/widgets**: Wear OS now has two rich tiles (Focus Timer with progress arc + Tasks with top 4 tasks) and enhanced complications with live countdown. watchOS Smart Stack widgets were redesigned with live countdowns, phase info, linked task names, and smart relevance scoring. watchOS now also has a Tasks complication (accessoryRectangular, accessoryCircular, accessoryCorner). Both platforms persist extended snapshot data (linked task, session count, theme colors, phase dates) for tile/widget access. Pomodoro live countdown verified working on both platforms (Wear OS tile updates live; watchOS complication shows countdown even at progress=0). **watchOS complications and widgets now read from the shared app group UserDefaults suite (`group.com.pepinillo.app`) so they remain accurate when running as a separate process.**

2. **iOS is ahead in ecosystem integrations**: Widgets, Live Activity, Siri, Calendar, Control Center, Mode Intelligence, and Soundscapes are already implemented on iOS. Android still has pending work for widgets, Quick Settings, Assistant, and Soundscapes.

3. **Android paywall is in progress**: `PaywallScreen` and `PaywallViewModel` exist, but complete feature-gating enforcement is still pending.

4. **Capability split still pending**: The docs now distinguish Apple Unlock from Everywhere, but runtime gating still needs to migrate from the legacy single-Pro model to capability-based enforcement.

5. **Theme parity achieved**: Both platforms (Android + iOS) have 4 named themes (Classic, Forest, Ocean, Sunset) with a horizontal-scroll-card theme picker, consistent focus mode colors (Pomodoro=red, TimeBlock=purple, Chrono=green), and premium gating for Forest/Ocean/Sunset. Android additionally offers Material You as an option. iOS has a Light/Dark/System selector. Wear OS syncs the selected theme from Android phone.

6. **Session Journaling promoted to P0**: Originally P2 in iOS PRD, now implemented on both phone platforms as part of the focus engine.

7. **Go backend exists but is not deployed**: The backend in `backend/` implements a complete REST API (auth, tasks, sessions, stats, billing verify, push notifications, WebSocket, AI insights) but is not yet in production. It needs hosting (Railway/Fly.io/VPS) + PostgreSQL + Redis.

8. **Social login planned**: Google Sign-In (Android via Credential Manager) and Sign In with Apple (iOS via AuthenticationServices) are planned. Backend must add OAuth providers. Account linking will allow multiple providers per account.

9. **Unified cloud sync architecture achieved**: Both iOS and Android now have full sync architecture via Go backend. iOS uses TCA-based sync clients (SyncClient, IdentityClient, WebSocketClient) with URLSession. Android uses SyncEngine + Room dirty flags + SyncWebSocketClient (OkHttp). Both platforms support: settings sync (per-key LWW), batch session sync, initial upload on registration, cursor-paginated full sync for new devices, WebSocket real-time notifications, and data merge dialogs for anonymous-to-existing-account transitions. Commercially, backend sync now maps to `Everywhere`, while iOS retains CloudKit as Apple-local sync under Apple Unlock.

10. **WatchConnectivity transport reliability (iOS/watchOS, 2026-06-11)**: Phone→watch updates were previously all sent via `sendMessage`, which is silently dropped when the watch app is backgrounded. Fixed with a transport split: `updateApplicationContext` for state/stats/dashboard (background-safe), `transferUserInfo` for tasks (queued FIFO), `sendMessage` kept only as a fast path when the watch is reachable. This resolves stale complications and dashboard data after the watch app goes to background. Android Wear was already correct — DataClient/DataItems handle background delivery natively.

11. **Android parity ports (2026-06-11)**: Focus engine tick reduced 10 Hz → 4 Hz (battery, matches iOS). Widget reloads scoped to the affected widget class. Paywall text and CTAs now grow with large font scales (matches iOS Dynamic Type fix, WCAG compliant). Streak promoted to dashboard emotional hero and deduplicated (matches iOS Dashboard P4 design). Timer ring display floor added for count-up modes on both Android phone and Wear OS (matches iOS). Onboarding now uses full-bleed color scenes with a WCAG-compliant skip pill (matches iOS onboarding visual redesign).