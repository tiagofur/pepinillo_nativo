# Flutter App Feature Inventory: Pepinillo v2.0.1

**Purpose:** Complete reference of the current Flutter app's features for native iOS rewrite parity planning.
**App Version:** 2.0.1+16
**Architecture:** Clean Architecture + Provider + GoRouter + Freezed

---

## 1. Providers (State Management)

| Provider | Responsibility |
|----------|---------------|
| **SessionProvider** | User session, RevenueCat subscription status, profile CRUD, image upload, account deletion, sign-out |
| **AuthenticationProvider** | Sign-in/sign-up form state (name, email, birthDate, password, username), auth methods |
| **ThemeProvider** | Theme selection, Material 3 dynamic colors, premium theme gating (4 free, rest premium), background image |
| **DynamicColorProvider** | Material 3 dynamic color generation wrapper |
| **PomodoroProvider** | Timer settings (work/break/rest durations, qty, daily goal, auto-advance), timer state persistence via SharedPreferences, sound service, lifecycle observer |
| **PomodoroDashboardProvider** | Daily/date-range stats loading, chart color palette |
| **ProductivityInsightsProvider** | Advanced analytics: 90-day heatmap, streaks (current/best), weekly comparison, most productive weekday, avg daily focus, productivity prediction (high/medium/low) |
| **TimerProvider** | Countdown vs stopwatch mode toggle, settings persistence |
| **CountdownProvider** | Countdown timer with duration config, wakelock, notification toggle, stream-based ticks |
| **CronometerProvider** | Stopwatch/chronometer implementation with wakelock |
| **TaskProvider** | Task CRUD, search, filtering (all/pending/completed/today/overdue), calendar integration, My Day view, sync with Firebase |
| **TaskDashboardProvider** | Task analytics: distribution, Pomodoro accuracy (estimated vs completed), weekly velocity |

**Total: 13 providers**

---

## 2. Screens

| Screen | Module | Function |
|--------|--------|----------|
| signin_screen | Auth | Email/password login |
| signup_screen | Auth | Registration (name, email, birth date, password, username) |
| account_screen | Auth | Profile view with session/task/Pomodoro status |
| edit_user_screen | Auth | Edit profile (name, email, birth date) |
| home_screen | Home | Main shell with 3-tab bottom navigation (Pomodoro, Timer, Tasks) |
| pomodoro_screen | Pomodoro | Active Pomodoro timer display with circular progress |
| pomodoro_dashboard_screen | Pomodoro | Daily goals, session summary, productivity insights |
| pomodoro_settings_screen | Pomodoro | Configure timings, auto-advance, daily goals, notifications |
| timer_screen | Timer | Countdown/stopwatch with mode toggle |
| countdown_settings_screen | Timer | Set countdown duration, notification toggle |
| tasks_screen | Tasks | Task list with filters, search, calendar view |
| task_screen | Tasks | Individual task detail with subtasks |
| task_dashboard_screen | Tasks | Task statistics and analytics |
| theme_settings_screen | Theme | Palette selection, background image picker, premium indicators |
| paywall | Store | RevenueCat subscription offerings |

**Total: 15 screens**

---

## 3. Domain Entities

### TaskEntity (Freezed)
`id`, `title`, `description`, `createdDate`, `finishDate`, `isFinished`, `priority`, `category`, `subTasks` (List), `updatedAt`, `estimatedPomodoros`, `completedPomodoros`, `focusedSeconds`, `activeSessionId`

### SubTaskEntity (Freezed)
`id`, `title`, `isFinished`, `taskId`

### PomodoroEntity (Freezed)
`pomodoroTime`, `breakTime`, `restTime`, `qtyPomodoros`, `dailyGoal`, `notifications`, `autoPomodoro`, `autoBreak`, `lastUpdate`

### PomodoroSessionEntity
`id`, `taskId`, `startedAt`, `endedAt`, `phase`, `durationSeconds`, `elapsedSeconds`, `pauseCount`, `totalPauseSeconds`, `wasCompleted`, `sharedWithTaskIds`, `createdAt`

### PomodoroStatsEntity
`date`, `pomodoros`, `pomodoroDuration`, `breaks`, `breakDuration`, `rests`, `restDuration`, `dailyGoal`, `dailyCompleted`, `count`, `lastUpdate`

### UserModel
`email`, `name`, `uid`, `subscriptionExpireAt`, `subscriptionStartDate`, `imageProfile`, `birthDate`

### Supporting Models
`TimerModel` (isCountdown, lastUpdate), `CountdownModel` (duration, notifications, lastUpdate), `ThemeModel` (isDarkMode, palette colors, dynamic color settings)

---

## 4. Local Database Schema

### Tasks (SharedPreferences)
- Key: `pepinillo_tasks` — JSON array of full TaskModel objects
- Key: `pepinillo_last_task_id` — auto-increment counter
- In-memory cache for performance

### Pomodoro Sessions (SQLite)
```sql
CREATE TABLE pomodoro_sessions (
    id TEXT PRIMARY KEY,
    task_id INTEGER,
    started_at INTEGER,        -- ms since epoch
    ended_at INTEGER,
    phase TEXT,
    duration_seconds INTEGER,
    elapsed_seconds INTEGER DEFAULT 0,
    pause_count INTEGER DEFAULT 0,
    total_pause_seconds INTEGER DEFAULT 0,
    was_completed INTEGER DEFAULT 0,
    shared_with_task_ids TEXT,
    created_at INTEGER
);
CREATE INDEX idx_sessions_task_id ON pomodoro_sessions(task_id);
CREATE INDEX idx_sessions_started_at ON pomodoro_sessions(started_at);
```

### Pomodoro Stats (SharedPreferences)
- Key: `pomodoro_stats_dates` — StringList of date keys
- Per-date keys: `pomodoro_stats_YYYY-MM-DD` — serialized stats JSON

### Timer State Persistence (SharedPreferences)
- Various `_TimerStateKeys` for persisting active timer state across app restarts

---

## 5. Firebase Services

| Service | Package | Usage |
|---------|---------|-------|
| Firebase Auth | firebase_auth: ^6.1.4 | Email/password authentication |
| Cloud Firestore | cloud_firestore: ^6.1.2 | User profiles, potentially tasks/sessions remote |
| Firebase Storage | firebase_storage: ^13.0.6 | Profile image uploads |
| Firebase Crashlytics | firebase_crashlytics: ^5.0.7 | Crash reporting and error tracking |

Firebase init is conditional — skipped for web platform.

---

## 6. Localization

| Language | ARB File | Approx. Keys |
|----------|----------|-------------|
| English | intl_en.arb | ~644 keys (master) |
| Spanish | intl_es.arb | ~309 lines |
| Portuguese | intl_pt.arb | ~310 lines |

Generated via `flutter_intl` into `S` class. Covers: weekday names, task/Pomodoro labels, settings, dialogs, errors, accessibility.

---

## 7. Subscription / Premium (RevenueCat)

- **Entitlement:** `premium`
- **Stores:** App Store (iOS), Play Store (Android), Amazon
- **Premium-gated features:**
  - Additional theme palettes (4 free: focus_green, calm_purple, warm_red, ocean_blue)
  - Potentially advanced Pomodoro/task features (flags exist in providers)
- **API keys:** Passed via `--dart-define` at build time
- **Paywall:** Custom screen using RevenueCat offerings API

---

## 8. Key Dependencies (30+)

**State:** provider, freezed_annotation, json_annotation
**Navigation:** go_router
**Firebase:** firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_crashlytics
**Storage:** sqflite, shared_preferences, path, path_provider
**UI:** fl_chart, table_calendar, card_swiper, shimmer, google_fonts, font_awesome_flutter
**Utility:** connectivity_plus, image_picker, url_launcher, wakelock_plus, audioplayers, intl, http
**Monetization:** purchases_flutter (RevenueCat)
**Platform:** windows_notification
**Dev:** build_runner, freezed, json_serializable, flutter_gen_runner, mockito

---

## 9. What Does NOT Exist (Gaps for Native Rewrite)

| Missing Feature | Impact | Native Priority |
|----------------|--------|----------------|
| Home Screen Widgets | No quick-glance timer/tasks | P0 |
| Live Activities / Dynamic Island | No persistent timer visibility | P0 |
| Apple Watch / watchOS | No wrist-based timer control | P0 |
| Siri / Shortcuts / App Intents | No voice or automation control | P0 |
| Focus Modes integration | No automatic DND during sessions | P1 |
| Apple Health integration | No Mindful Minutes tracking | P1 |
| Recurring tasks | Manual re-creation daily | P1 |
| Push notifications (FCM) | Only local notifications | P1 |
| Deep linking / Universal Links | No external URL navigation | P1 |
| Offline sync queue | Basic sync, no conflict resolution | P0 (CloudKit) |
| Analytics events tracking | Only Crashlytics, no usage analytics | P1 |
| A/B testing | No experimentation framework | P2 |
| Accessibility enhancements | Limited semantic labels | P0 |
| Database migrations | Version 1 only, no migration path | P0 (SwiftData) |
| Real AI/ML insights | All insights are local heuristics | P2 |
| Calendar app integration | No EventKit | P2 |
| Social sharing | No share functionality | P2 |

---

## 10. Assets & Resources

**Sounds:** tick.wav, complete.wav, break_start.wav, session_start.wav (via SoundService + audioplayers)
**Fonts:** Fasthand, Kalam (weights 300, 400, 700)
**Images:** avatar.png, theme previews (modern_light/dark, paper_studio_light/dark)

**Enums:**
- PomodoroPhase: idle, pomodoro, shortBreak, longBreak
- TimerStatus: stopped, running, paused
- TaskFilter: all, pending, completed, today, overdue
- SoundType: tick, complete, breakStart, sessionStart

---

## 11. Parity Mapping: Flutter → Native

| Flutter Component | Native Equivalent |
|-------------------|-------------------|
| Provider + ChangeNotifier | TCA Store + Reducer |
| GoRouter | NavigationStack / NavigationSplitView |
| Freezed models | SwiftData @Model (or plain structs for non-persisted) |
| SharedPreferences | UserDefaults / @AppStorage |
| sqflite (SQLite) | SwiftData (Core Data underneath) |
| Firebase Auth | Sign in with Apple |
| Cloud Firestore | CloudKit (via SwiftData) |
| Firebase Storage | CloudKit Assets |
| Firebase Crashlytics | Xcode Organizer / TelemetryDeck |
| RevenueCat | StoreKit 2 (native) |
| fl_chart | Swift Charts |
| table_calendar | Custom SwiftUI calendar |
| audioplayers | AVFoundation |
| connectivity_plus | NWPathMonitor |
| wakelock_plus | UIApplication.shared.isIdleTimerDisabled |
| intl / flutter_intl | String Catalog (.xcstrings) |
| image_picker | PhotosUI (PHPickerViewController) |
| flutter_local_notifications | UNUserNotificationCenter |
