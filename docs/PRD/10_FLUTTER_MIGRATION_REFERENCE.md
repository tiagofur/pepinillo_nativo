# Migration Reference: Flutter to Native Platforms

**Unified migration reference from Flutter to native iOS and native Android.**

---

## 1. Original Flutter Inventory

| Component                    | Count                                     |
| ---------------------------- | ----------------------------------------- |
| Providers (state management) | 13                                        |
| Screens                      | 15                                        |
| Domain entities              | 6 (+supporting models)                    |
| Firebase services            | 4 (Auth, Firestore, Storage, Crashlytics) |
| Monetization                 | RevenueCat (`purchases_flutter`)          |
| Localization keys (EN)       | ~644                                      |
| Localization keys (ES)       | ~310                                      |
| Localization keys (PT)       | ~310                                      |
| Total dependencies           | 30+                                       |

### Flutter Providers

| Provider                     | Responsibility                                                                                                            |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| SessionProvider              | User session, RevenueCat subscription status, profile CRUD, image upload, account deletion, sign-out                      |
| AuthenticationProvider       | Sign-in/sign-up form status (name, email, birth date, password, username)                                                 |
| ThemeProvider                | Theme selection, Material 3 dynamic colors, premium theme gating (4 free, rest premium)                                   |
| DynamicColorProvider         | Wrapper for Material 3 dynamic color generation                                                                           |
| PomodoroProvider             | Timer configuration (work/break/rest durations, quantity, daily goal, auto-advance), state persistence                    |
| PomodoroDashboardProvider    | Load daily stats/date-range stats, chart color palette                                                                    |
| ProductivityInsightsProvider | Advanced analytics: 90-day heatmap, streaks, weekly comparison, most productive day, productivity prediction              |
| TimerProvider                | Countdown vs stopwatch mode toggle, configuration persistence                                                             |
| CountdownProvider            | Countdown timer with duration configuration, wakelock, notifications                                                      |
| CronometerProvider           | Stopwatch implementation with wakelock                                                                                    |
| TaskProvider                 | Task CRUD, search, filtering (all/pending/completed/today/overdue), calendar integration, My Day view, sync with Firebase |
| TaskDashboardProvider        | Task analytics: distribution, Pomodoro accuracy (estimated vs completed), weekly speed                                    |

### Flutter Screens

| Screen                    | Module   | Function                                                       |
| ------------------------- | -------- | -------------------------------------------------------------- |
| signin_screen             | Auth     | Login email/password                                           |
| signup_screen             | Auth     | Registration (name, email, birth date, password, username)     |
| account_screen            | Auth     | Profile view with session/task/Pomodoro status                 |
| edit_user_screen          | Auth     | Edit profile (name, email, birth date)                         |
| home_screen               | Home     | Main shell with 3-tab navigation (Pomodoro, Timer, Tasks)      |
| pomodoro_screen           | Pomodoro | Active Pomodoro timer display with circular progress           |
| pomodoro_dashboard_screen | Pomodoro | Daily goals, session summary, productivity insights            |
| pomodoro_settings_screen  | Pomodoro | Configure durations, auto-advance, daily goals, notifications  |
| timer_screen              | Timer    | Countdown/stopwatch with mode toggle                           |
| countdown_settings_screen | Timer    | Configure countdown duration, notification toggle              |
| tasks_screen              | Tasks    | Task list with filters, search, calendar view                  |
| task_screen               | Tasks    | Single-task detail with subtasks                               |
| task_dashboard_screen     | Tasks    | Task stats and analytics                                       |
| theme_settings_screen     | Theme    | Palette selection, background image picker, premium indicators |
| paywall                   | Store    | RevenueCat subscription offers                                 |

### Domain Entities

- **TaskEntity**: id, title, description, createdDate, finishDate, isFinished, priority, category, subTasks (List), updatedAt, estimatedPomodoros, completedPomodoros, focusedSeconds, activeSessionId
- **SubTaskEntity**: id, title, isFinished, taskId
- **PomodoroEntity**: pomodoroTime, breakTime, restTime, qtyPomodoros, dailyGoal, notifications, autoPomodoro, autoBreak, lastUpdate
- **PomodoroSessionEntity**: id, taskId, startedAt, endedAt, phase, durationSeconds, elapsedSeconds, pauseCount, totalPauseSeconds, wasCompleted, sharedWithTaskIds, createdAt
- **PomodoroStatsEntity**: date, pomodoros, pomodoroDuration, breaks, breakDuration, rests, restDuration, dailyGoal, dailyCompleted, count, lastUpdate
- **UserModel**: email, name, uid, subscriptionExpireAt, subscriptionStartDate, imageProfile, birthDate
- **Supporting Models**: TimerModel, CountdownModel, ThemeModel

---

## 2. Flutter to Native iOS Mapping

| Flutter                     | iOS native                               |
| --------------------------- | ---------------------------------------- |
| Provider + ChangeNotifier   | TCA @Reducer + Store                     |
| GoRouter                    | NavigationStack / NavigationSplitView    |
| Freezed models              | Swift structs / SwiftData @Model         |
| SharedPreferences           | UserDefaults / @AppStorage / SwiftData   |
| sqflite (SQLite)            | SwiftData (Core Data under the hood)     |
| Firebase Auth               | Sign in with Apple                       |
| Cloud Firestore             | CloudKit (via SwiftData)                 |
| Firebase Storage            | CloudKit Assets                          |
| Firebase Crashlytics        | Xcode Organizer / TelemetryDeck          |
| RevenueCat                  | StoreKit 2 (native)                      |
| fl_chart                    | Swift Charts                             |
| table_calendar              | Custom SwiftUI calendar                  |
| audioplayers                | AVAudioEngine / AVFoundation             |
| flutter_intl (ARB)          | String Catalog (.xcstrings)              |
| connectivity_plus           | NWPathMonitor                            |
| wakelock_plus               | UIApplication.shared.isIdleTimerDisabled |
| image_picker                | PhotosUI (PHPickerViewController)        |
| flutter_local_notifications | UNUserNotificationCenter                 |
| http                        | URLSession                               |
| google_fonts                | System fonts / bundled fonts             |

---

## 3. Flutter to Native Android Mapping

| Flutter                     | Android native                            |
| --------------------------- | ----------------------------------------- |
| Provider + ChangeNotifier   | ViewModel + StateFlow / Circuit Presenter |
| GoRouter                    | Navigation Compose / Circuit screens      |
| Freezed models              | Kotlin data class                         |
| SharedPreferences           | Jetpack DataStore (Proto)                 |
| sqflite (SQLite)            | Room                                      |
| Firebase Auth               | JWT + backend Go                          |
| Cloud Firestore             | Room (local) + REST API (remote)          |
| Firebase Storage            | Backend upload                            |
| Firebase Crashlytics        | Play Console / Sentry                     |
| RevenueCat                  | Google Play Billing 7                     |
| fl_chart                    | Vico (Compose charts)                     |
| table_calendar              | Custom Compose calendar                   |
| audioplayers                | Media3 / ExoPlayer                        |
| flutter_intl (ARB)          | strings.xml (res/values/)                 |
| connectivity_plus           | ConnectivityManager                       |
| wakelock_plus               | WakeLock + Foreground Service             |
| image_picker                | CameraX / Gallery intent                  |
| flutter_local_notifications | NotificationCompat + Foreground Service   |
| http                        | Retrofit / Ktor Client                    |
| google_fonts                | System fonts / bundled fonts              |

---

## 4. New Features (Did Not Exist in Flutter)

The following features are completely new in the native versions and have no equivalent in the original Flutter app:

| #   | Feature                                 | Description                                                                        | Priority |
| --- | --------------------------------------- | ---------------------------------------------------------------------------------- | -------- |
| 1   | Flowtime                                | Open-ended focus + dynamic breaks proportional to time worked                      | P0       |
| 2   | Time Block                              | Fixed-duration deep work blocks                                                    | P0       |
| 3   | Multi-mode engine                       | Strategy pattern, 4 modes sharing one common core engine                           | P0       |
| 4   | Energy levels                           | Task categorization (deep/shallow/admin)                                           | P0       |
| 5   | Recurring tasks                         | Automatic daily/weekly/monthly generation                                          | P0       |
| 6   | Home Screen widgets                     | At-a-glance timer and stats (WidgetKit / Glance Compose)                           | P0       |
| 7   | Live Activity / Persistent notification | Always-visible timer status (Dynamic Island on iOS, Foreground Service on Android) | P0       |
| 8   | Watch / Wear OS                         | Standalone watch timer app + complications                                         | P0       |
| 9   | Siri / Google Assistant                 | Voice-triggered focus sessions                                                     | P0       |
| 10  | Apple Health / Health Connect           | Mindful Minutes writing                                                            | P1       |
| 11  | Soundscape engine                       | Ambient sounds during focus sessions                                               | P1       |
| 12  | Mode Intelligence                       | AI/pattern-based mode suggestions                                                  | P1       |
| 13  | Weekly / Monthly Review                 | Comparative analytics by mode and period                                           | P1       |
| 14  | AI Reports                              | AI-generated productivity reports                                                  | P1       |
| 15  | Streaks and achievements                | Consecutive-day tracking and gamification                                          | P1       |
| 16  | Adaptive layouts                        | Support for iPad/tablets/large screens                                             | P1       |
| 17  | Quick Settings Tile (Android)           | Focus toggle from notification shade                                               | P0       |
| 18  | Google Tasks import                     | One-way import from Google Tasks                                                   | P1       |

---

## 5. Flutter Data and Migration Strategy

### Flutter Storage

| Data              | Flutter Storage           | Format                                          |
| ----------------- | ------------------------- | ----------------------------------------------- |
| Tasks             | SharedPreferences         | JSON array (key: `pepinillo_tasks`)             |
| Pomodoro sessions | SQLite (sqflite)          | Table `pomodoro_sessions` with indexes          |
| Pomodoro stats    | SharedPreferences         | JSON by date (key: `pomodoro_stats_YYYY-MM-DD`) |
| Timer preferences | SharedPreferences         | Individual keys                                 |
| User profile      | Firebase Auth + Firestore | Document per user                               |
| Profile image     | Firebase Storage          | Remote URL                                      |

### Data Migration Strategy

**There is no automatic migration.** The native apps are new apps in their respective stores.

| Scenario                          | Solution                                                                                                                     |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| User with Flutter account         | Backend sync as a bridge: login in the native app syncs data via API                                                         |
| User without account (local data) | Data is lost when switching apps (there is no safe way to read another app's data)                                           |
| iOS: Import from Flutter          | Does not apply (separate apps in App Store)                                                                                  |
| Android: Import from Flutter      | Optional button "Import from Pepinillo Classic" that reads SharedPreferences/sqflite from the Flutter package (if installed) |

### Limitations

- Firebase Auth to Sign in with Apple/JWT requires that the user logs in again.
- Historical stats may have a different format (Pomodoro-only vs multi-mode).
- Subtask IDs may require remapping.
- Not all Flutter strings apply (many are Firebase-specific or Flutter-specific).

---

## 6. Strings and Localization

### String Migration

```
Flutter: lib/l10n/intl_en.arb (644 keys)
   |
   +---> iOS:     Localizable.xcstrings (EN)
   +---> Android: res/values/strings.xml

Flutter: lib/l10n/intl_es.arb (310 keys)
   |
   +---> iOS:     Localizable.xcstrings (ES)
   +---> Android: res/values-es/strings.xml

Flutter: lib/l10n/intl_pt.arb (309 keys)
   |
   +---> iOS:     Localizable.xcstrings (PT-BR)
   +---> Android: res/values-pt/strings.xml
```

### Considerations

- Not all Flutter strings apply -- many are for Firebase-specific or Flutter-specific features.
- Only migrate the strings that apply to each native platform.
- **~100+ new strings** required for native-exclusive features:
  - 4 focus mode names + descriptions
  - Energy level names
  - Recurrence preset names
  - Widget labels
  - Watch / Wear OS strings
  - Quick Settings labels (Android)
  - Siri / Google Assistant phrases
  - Health / Health Connect permissions
  - StoreKit / Play Billing UI strings
  - Notification channel names

---

## 7. Backend Endpoints

### Existing Endpoints

| Endpoint                     | Method     | Used by             |
| ---------------------------- | ---------- | ------------------- |
| `/api/v1/auth/register`      | POST       | Authentication flow |
| `/api/v1/auth/login`         | POST       | Authentication flow |
| `/api/v1/auth/refresh`       | POST       | Token refresh       |
| `/api/v1/auth/logout`        | POST       | Session termination |
| `/api/v1/users/me`           | GET/PUT    | User profile        |
| `/api/v1/users/me/avatar`    | POST       | Profile image       |
| `/api/v1/tasks`              | GET/POST   | Task sync           |
| `/api/v1/tasks/:id`          | PUT/DELETE | Task sync           |
| `/api/v1/tasks/:id/subtasks` | GET/POST   | Subtask sync        |
| `/api/v1/pomodoro-sessions`  | GET/POST   | Session sync        |
| `/api/v1/health`             | GET        | Health check        |

### Pending Endpoints to Create

| Feature                             | Required Endpoint                                        | Status                  |
| ----------------------------------- | -------------------------------------------------------- | ----------------------- |
| Daily stats                         | `GET /api/v1/stats/daily?date=...`                       | to be created           |
| Weekly stats                        | `GET /api/v1/stats/weekly?week=...`                      | to be created           |
| Subscription verification (iOS)     | `POST /api/v1/subscriptions/verify` (App Store receipt)  | to be created           |
| Subscription verification (Android) | `POST /api/v1/subscriptions/verify` (Play Store receipt) | to be created           |
| Multi-mode sessions                 | `POST /api/v1/focus-sessions` (with `mode` field)        | Partial -- update model |

### Endpoints That Already Support New Features

- **Energy levels**: field already exists in the task model.
- **Recurring tasks**: recurrence fields already exist in tasks (verify completeness).

---

## 8. Database Schema: Flutter vs Native

### Tasks

| Aspect     | Flutter                  | iOS native                                 | Android native                                                |
| ---------- | ------------------------ | ------------------------------------------ | ------------------------------------------------------------- |
| Storage    | SharedPreferences (JSON) | SwiftData @Model                           | Room @Entity                                                  |
| ID         | Auto-increment int       | UUID                                       | String (UUID)                                                 |
| New fields | --                       | energyLevel, preferredMode, recurrenceRule | energyLevel, preferredMode, recurrenceRule, syncedAt, isDirty |
| Migrations | No support               | SwiftData auto-migration                   | Room auto-migration                                           |
| Sync       | Firebase Firestore       | CloudKit via SwiftData                     | REST API custom                                               |

### Focus Sessions

| Aspect     | Flutter            | iOS native         | Android native                        |
| ---------- | ------------------ | ------------------ | ------------------------------------- |
| Storage    | sqflite            | SwiftData @Model   | Room @Entity                          |
| Table name | pomodoro_sessions  | FocusSession       | focus_sessions                        |
| Mode field | No (Pomodoro only) | mode (String)      | mode (String)                         |
| New fields | --                 | mode, linkedTaskId | mode, linkedTaskId, syncedAt, isDirty |

---

## 9. Assets and Resources

### Sounds

- tick.wav, complete.wav, break_start.wav, session_start.wav
- **New (native):** ambient soundscapes (rain, forest, cafe, white noise, etc.)

### Fonts

- Fasthand, Kalam (weights 300, 400, 700)
- System fonts as an alternative in native apps.

### Shared Enums (maintain parity)

| Enum        | Values                                    |
| ----------- | ----------------------------------------- |
| FocusMode   | pomodoro, flowtime, timeBlock, stopwatch  |
| FocusPhase  | work, shortBreak, longBreak, dynamicBreak |
| TimerStatus | idle, running, paused, completed          |
| TaskFilter  | all, pending, completed, today, overdue   |
| EnergyLevel | deep, shallow, admin                      |
| SoundType   | tick, complete, breakStart, sessionStart  |
