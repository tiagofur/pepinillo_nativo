# Technical Architecture — Android & Wear OS

**Version:** 1.0
**Last Updated:** 2026-03-24
**Platforms:** Android (phone/tablet/foldable) + Wear OS (watch)

---

## 1. Technology Stack

| Layer                  | Technology                       | Version         | Rationale                                                                                                                                    |
| ---------------------- | -------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **Language**           | Kotlin                           | 2.0.21          | Coroutines, null safety, first-class Android. Limited to 2.0.x due to compatibility with Hilt 2.52 (APT does not read metadata Kotlin 2.1.x) |
| **KSP**                | kotlin-symbol-processing         | 2.0.21-1.0.28   | Must match Kotlin version exactly                                                                                                            |
| **Build**              | AGP + Gradle                     | 8.10.0 + 8.14.3 | Version Catalogs (`libs.versions.toml`), configuration cache enabled                                                                         |
| **UI**                 | Jetpack Compose + Material 3     | BOM 2025.03.00  | Declarative, Material You dynamic color, interop with Glance                                                                                 |
| **Architecture**       | MVVM                             | —               | One ViewModel per screen, StateFlow for reactivity. Originally planned as MVI/Circuit but evolved to MVVM with ViewModels                    |
| **DI**                 | Hilt (Dagger)                    | 2.52            | Constructor injection, `@AssistedInject` for Circuit Presenters, `@HiltWorker` for WorkManager                                               |
| **Local DB**           | Room                             | 2.7.0           | SQLite type-safe with KSP, exportSchema=true, Versioned migrations                                                                           |
| **Preferences**        | DataStore                        | Proto           | `UserPreferencesRepository` for user configuration                                                                                           |
| **Networking**         | Ktor Client                      | 3.1.0           | OkHttp engine, Kotlinx Serialization, DTOs aligned with backend Go                                                                           |
| **Background**         | Foreground Service + WorkManager | 2.10.0          | Timer accuracy + sync deferred periodic (15 min)                                                                                             |
| **Widgets**            | Glance                           | 1.1.1           | Compose-based widgets for Home Screen and Lock Screen                                                                                        |
| **Wear OS UI**         | Compose for Wear OS              | 1.4.0           | Modern interface for watch                                                                                                                   |
| **Wear Tiles**         | Horologist                       | 0.6.20          | `SuspendingTileService` for Wear OS Tiles                                                                                                    |
| **Wear Complications** | watchface-complications          | 1.2.1           | `SuspendingComplicationDataSourceService`                                                                                                    |
| **Wear Data Layer**    | play-services-wearable           | 18.2.0          | `DataClient` + `MessageClient` for sync phone↔watch                                                                                          |
| **Billing**            | RevenueCat Purchases SDK         | v8.10.0         | In-app subscriptions (FREE/PRO); shared `premium` entitlement with iOS                                                                       |
| **Health**             | Health Connect                   | 1.1.0-rc01      | Mindful Sessions (API experimental)                                                                                                          |
| **Audio**              | Media3/ExoPlayer                 | 1.5.0           | Soundscapes (6 ambient tracks)                                                                                                               |
| **Charts**             | Vico                             | 1.14.0          | `compose-m3` charts for dashboard                                                                                                            |
| **Adaptive**           | material3-window-size-class      | via BOM         | `WindowWidthSizeClass` for responsive layouts                                                                                                |
| **Foldable**           | androidx.window                  | 1.3.0           | `FoldingFeature` + hinge avoidance                                                                                                           |
| **Testing**            | JUnit 5 + Turbine + Robolectric  | —               | Unit + integration tests                                                                                                                     |
| **Lint**               | ktlint + detekt                  | —               | Code style and static analysis                                                                                                               |

---

## 2. Architecture — MVVM

### General Pattern

The project uses **MVVM (Model-View-ViewModel)** with layered Clean Architecture. It was originally planned as MVI with Circuit (Slack), but evolved to MVVM with ViewModels and StateFlow for simplicity.

```
┌─────────────────────────────────────────────────┐
│                     UI Layer                     │
│  Jetpack Compose Screens (feature/)             │
│  Observe ViewModel StateFlow               │
└───────────────────┬─────────────────────────────┘
                    │ collect / events
┌───────────────────▼─────────────────────────────┐
│                  ViewModel Layer                 │
│  One ViewModel per screen (@HiltViewModel)        │
│  Exposes StateFlow<UiState>                      │
│  Processes user events                    │
└───────────────────┬─────────────────────────────┘
                    │ suspend calls
┌───────────────────▼─────────────────────────────┐
│                 Domain Layer                     │
│  Repository interfaces (ports)             │
│  Services: FocusModeStrategy, ModeIntelligence │
│  Pure Kotlin models (no Android dependencies) │
└───────────────────┬─────────────────────────────┘
                    │ implementations
┌───────────────────▼─────────────────────────────┐
│                  Data Layer                      │
│  Room DAOs + Entities                           │
│  DataStore (preferences)                       │
│  Ktor API Client (backend Go)                   │
│  SyncEngine + SyncWorker                        │
└─────────────────────────────────────────────────┘
```

### Principles

- **One ViewModel per screen**: each screen has its own Hilt-injected ViewModel
- **StateFlow for reactivity**: the ViewModel exposes StateFlow<UiState> that the UI collects
- **Hilt for DI**: `@HiltViewModel`, `@Inject constructor`, modules in `core/di/`
- **Circuit legacy**: some original Presenters remain manually registered in `AppModule.provideCircuit()` (without `@CircuitInject` KSP due to warnings)
- **Clean Architecture**: strict separation between `data/`, `domain/`, `feature/`

---

## 3. Project Structure

### Main Module (`app/`)

```
app/src/main/kotlin/dev/creapolis/pepinillo/
├── PepinilloApp.kt                    # @HiltAndroidApp + WorkManager Configuration.Provider
├── MainActivity.kt                     # Single Activity, Compose host
│                                       # Adaptive nav (BottomBar/Rail/Drawer)
│                                       # Conditional onboarding + auth gate
│                                       # Google Assistant intent handling
│
├── core/
│   ├── di/                            # Modules Hilt
│   │   ├── AppModule.kt              #   Circuit wiring manual, global singletons
│   │   ├── DatabaseModule.kt         #   Room database + DAOs
│   │   ├── NetworkModule.kt          #   Ktor HttpClient config
│   │   └── RepositoryModule.kt       #   Interface bindings → implementations
│   ├── navigation/
│   │   └── PepinilloNavGraph.kt      # Compose Navigation (9 screens)
│   ├── network/
│   │   └── PepinilloApiClient.kt     # Ktor client with auth interceptor
│   ├── theme/
│   │   ├── Color.kt                  # Material You colors + FocusModeColors
│   │   ├── Theme.kt                  # PepinilloTheme with dynamic color
│   │   └── Type.kt                   # Typography Material 3
│   └── ui/
│       └── FoldableUtils.kt          # rememberFoldingFeature() for hinge avoidance
│
├── domain/                            # Pure Kotlin — no Android dependencies
│   ├── model/
│   │   ├── FocusMode.kt              # enum: POMODORO, FLOWTIME, TIME_BLOCK, STOPWATCH
│   │   ├── FocusPhase.kt             # enum: WORK, SHORT_BREAK, LONG_BREAK, FLOW
│   │   ├── FocusConfig.kt            # Configurable durations
│   │   ├── Task.kt                   # typealias → shared/
│   │   ├── Subtask.kt                # typealias → shared/
│   │   ├── FocusSession.kt           # typealias → shared/
│   │   ├── EnergyLevel.kt            # enum: DEEP, SHALLOW, ADMIN
│   │   └── DailyStats.kt            # Aggregated daily statistics
│   ├── repository/
│   │   ├── TaskRepository.kt         # Interface (port)
│   │   ├── SessionRepository.kt
│   │   └── StatsRepository.kt
│   └── service/
│       ├── FocusModeStrategy.kt      # Interface of the Strategy pattern
│       └── ModeIntelligenceService.kt # History-based suggestions
│
├── data/
│   ├── local/
│   │   ├── PepinilloDatabase.kt      # Room DB (version 7, 5 entities, 4 DAOs)
│   │   ├── Converters.kt             # TypeConverters for Room
│   │   ├── entity/
│   │   │   ├── TaskEntity.kt         # With sync fields: serverId, isDirty, syncedAt, isDeleted
│   │   │   ├── SubtaskEntity.kt
│   │   │   ├── FocusSessionEntity.kt
│   │   │   └── DailyStatsEntity.kt
│   │   └── dao/
│   │       ├── TaskDao.kt            # CRUD + dirty-item queries for sync
│   │       ├── SessionDao.kt
│   │       └── StatsDao.kt           # Includes recursive CTE for streak count
│   ├── datastore/
│   │   └── UserPreferencesRepository.kt # DataStore for user preferences
│   ├── repository/                    # concrete implementations
│   │   ├── TaskRepositoryImpl.kt
│   │   ├── SessionRepositoryImpl.kt
│   │   └── StatsRepositoryImpl.kt
│   └── sync/
│       ├── SyncEngine.kt             # Dirty-flag sync, last-write-wins
│       ├── SyncWorker.kt             # @HiltWorker, periodic 15 min + OneTime expedited
│       └── RecurringTaskEngine.kt    # Generates next task when recurring tasks are completed
│
├── feature/
│   ├── focus/
│   │   ├── FocusEngine.kt            # @Singleton, coroutine-based timer (100ms tick)
│   │   ├── FocusPresenter.kt         # Circuit Presenter (legacy)
│   │   ├── FocusScreen.kt            # Compose UI (two-pane on tablet ≥600dp)
│   │   └── strategy/
│   │       ├── PomodoroStrategy.kt   # 25/5/15 min configurable
│   │       ├── FlowtimeStrategy.kt   # No work limit, calculated break
│   │       ├── TimeBlockStrategy.kt  # Configurable fixed blocks
│   │       └── StopwatchStrategy.kt  # Upward count with no limit
│   ├── tasks/
│   │   ├── TaskListScreen.kt         # Master-detail on tablet
│   │   └── TaskDetailScreen.kt
│   ├── auth/
│   │   └── AuthScreen.kt             # JWT login/register via Go backend
│   ├── onboarding/
│   │   └── OnboardingScreen.kt       # 5 introduction screens
│   ├── analytics/
│   │   ├── DashboardScreen.kt        # Vico Charts, mode breakdown, streaks
│   │   ├── WeeklyReviewScreen.kt     # Weekly review
│   │   └── AchievementsSection.kt    # Achievements with progress
│   ├── settings/
│   │   └── SettingsScreen.kt         # Two-column on tablet, FocusConfig sliders
│   └── soundscape/
│       ├── SoundscapePlayer.kt       # ExoPlayer wrapper
│       └── SoundscapeScreen.kt       # 6 ambient tracks
│
└── platform/
    ├── billing/
    │   └── BillingManager.kt          # Play Billing 7.1.1, FREE/PRO tiers
    ├── calendar/
    │   └── GoogleCalendarManager.kt   # blockFocusTime() on completion WORK session
    ├── focusmode/
    │   └── DndManager.kt             # Do Not Disturb during focus sessions
    ├── googletasks/
    │   └── GoogleTasksImportManager.kt # OAuth + REST import from Google Tasks
    ├── health/
    │   └── HealthConnectManager.kt    # writeMindfulSession for WORK sessions
    ├── notification/
    │   └── FocusNotificationManager.kt # IMPORTANCE_LOW channel, Pause/Resume/Stop actions
    ├── datalayer/
    │   ├── PhoneDataLayerManager.kt   # Sends status to Wear OS via DataClient
    │   └── PhoneMessageListenerService.kt # Receives commands from the watch
    ├── tile/
    │   └── FocusTileService.kt        # Quick Settings Tile (Android 7+)
    └── widget/
        ├── FocusTimerWidget.kt        # Glance Home Screen widget
        ├── DailyStatsWidget.kt        # Glance Home Screen widget
        ├── LockScreenTimerWidget.kt   # Glance KEYGUARD widget (Android 14+)
        └── WidgetStateStore.kt        # updateAppWidgetState via PreferencesGlanceStateDefinition
```

### Module Wear OS (`wear/`)

```
wear/src/main/kotlin/dev/creapolis/pepinillo/wear/
├── data/
│   ├── WearDataRepository.kt         # StateFlows for synchronized phone data
│   ├── WearDataLayerListener.kt      # WearableListenerService that receives updates from phone
│   └── WearMessageSender.kt          # Sends commands to phone via MessageClient
├── presentation/
│   ├── WearFocusViewModel.kt         # Uses synchronized data + local fallback
│   ├── FocusWearScreen.kt            # Timer display + watch controls
│   ├── ModePickerScreen.kt           # Mode selection with rotary crown
│   └── TaskPickerScreen.kt           # Task linking on watch
├── tile/
│   └── FocusTileService.kt           # SuspendingTileService (idle/active layouts)
└── complication/
    └── FocusComplicationDataSource.kt # SHORT_TEXT + LONG_TEXT (tiempo activo o streak)
```

---

## 4. Data Models (Room)

The Room database is at **version 5**, with migrations 1→2→3→4→5.

### TaskEntity

```kotlin
@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey val id: String,              // UUID generado localmente
    val title: String,
    val notes: String? = null,
    val isCompleted: Boolean = false,
    val completedAt: Instant? = null,
    val priority: Int = 0,                   // TaskPriority ordinal
    val sortOrder: Int = 0,
    val energyLevel: String = "deep",        // EnergyLevel name
    val estimatedPomodoros: Int = 1,
    val completedPomodoros: Int = 0,
    val preferredMode: String? = null,
    val recurrenceRule: String? = null,       // RRULE string (RFC 5545)
    val nextOccurrence: Instant? = null,
    val isRecurringTemplate: Boolean = false,
    val recurringTemplateId: String? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
    // --- Synchronization fields (Android-specific) ---
    val serverId: String? = null,            // ID in the Go backend
    val syncedAt: Instant? = null,           // Last successful sync
    val isDirty: Boolean = true,             // Needs backend sync
    val isDeleted: Boolean = false,          // Soft delete for sync
)
```

> **Note:** The fields `serverId`, `isDirty`, `syncedAt`, `isDeleted` are Android-specific. iOS does not need them because CloudKit handles synchronization automatically with `CKRecord`.

### FocusSessionEntity

```kotlin
@Entity(tableName = "focus_sessions")
data class FocusSessionEntity(
    @PrimaryKey val id: String,
    val mode: String,                        // FocusMode name
    val startedAt: Instant,
    val endedAt: Instant? = null,
    val duration: Long = 0,                  // Duration in seconds
    val phase: String,                       // FocusPhase name
    val linkedTaskId: String? = null,        // FK to TaskEntity.id
    val isCompleted: Boolean = false,
    val pomodoroCount: Int = 0,
    val interruptions: Int = 0,              // Number of interruptions during session
    val pomodoroNumber: Int = 0,             // Which pomodoro in the cycle (1-4)
    val satisfactionRating: Int? = null,     // 1-5 post-session rating
    val journalNote: String? = null,         // Post-session reflection text
    val createdAt: Instant = Instant.now(),
    // Sync fields
    val serverId: String? = null,
    val syncedAt: Instant? = null,
    val isDirty: Boolean = true,
)
```

> **Note (Migration v6->v7):** Added `PreferenceSyncEntity` for settings sync, and added `interruptions`, `pomodoroNumber`, `satisfactionRating`, `journalNote` fields to FocusSessionEntity. Added `isDirty`, `syncedAt` fields to DailyStatsEntity. `FocusSessionDao` changed from insert-only to upsert. `deleteAll()` methods added to 5 DAOs for wipeAndSync support.

### SubtaskEntity

```kotlin
@Entity(
    tableName = "subtasks",
    foreignKeys = [ForeignKey(
        entity = TaskEntity::class,
        parentColumns = ["id"],
        childColumns = ["taskId"],
        onDelete = ForeignKey.CASCADE
    )]
)
data class SubtaskEntity(
    @PrimaryKey val id: String,
    val taskId: String,                      // FK to TaskEntity
    val title: String,
    val isCompleted: Boolean = false,
    val sortOrder: Int = 0,
)
```

### DailyStatsEntity

```kotlin
@Entity(tableName = "daily_stats")
data class DailyStatsEntity(
    @PrimaryKey val date: String,            // "YYYY-MM-DD"
    val totalFocusSeconds: Long = 0,
    val sessionsCompleted: Int = 0,
    val tasksCompleted: Int = 0,
    val pomodoroCount: Int = 0,
    val flowtimeSeconds: Long = 0,
    val timeBlockSeconds: Long = 0,
    val stopwatchSeconds: Long = 0,
    val streakDays: Int = 0,
    val longestSessionSeconds: Long = 0,     // Longest single session duration
    // Sync fields
    val isDirty: Boolean = true,
    val syncedAt: Instant? = null,
)
```

### ProductivityReportEntity

```kotlin
@Entity(tableName = "productivity_reports")
data class ProductivityReportEntity(
    @PrimaryKey val id: String,
    val type: String,                        // "weekly" | "monthly"
    val periodStart: String,                 // "YYYY-MM-DD"
    val periodEnd: String,
    val content: String,                     // Generated report (text/JSON)
    val generatedAt: Instant = Instant.now(),
)
```

---

## 5. Focus Engine (FocusEngine)

`FocusEngine` is the core of the app and manages the focus timer with millisecond precision.

### Engine Architecture

```
┌──────────────────────────────────────────────────────┐
│                    FocusEngine                        │
│                  (@Singleton)                         │
│                                                      │
│  ┌─────────────┐    ┌──────────────────────────┐    │
│  │ StateFlow   │◄───│ Coroutine Timer Job      │    │
│  │ <EngineState>│    │ delay(100) tick loop     │    │
│  └──────┬──────┘    └──────────────────────────┘    │
│         │                                            │
│  ┌──────▼──────┐    ┌──────────────────────────┐    │
│  │ Strategy    │◄───│ FocusModeStrategy        │    │
│  │ Pattern     │    │ (Pomodoro/Flow/Block/SW) │    │
│  └─────────────┘    └──────────────────────────┘    │
└──────────┬───────────────────────────────────────────┘
           │ Broadcasts a:
           ├── UI (Compose Screens) via StateFlow
           ├── Widgets (Glance) via WidgetStateStore
           ├── Wear OS via PhoneDataLayerManager
           ├── Persistent notification via FocusNotificationManager
           └── FocusForegroundService
```

### FocusModeStrategy (Strategy Pattern)

```kotlin
interface FocusModeStrategy {
    val mode: FocusMode
    val direction: TimerDirection           // COUNTDOWN or COUNTUP

    fun initialPhase(config: FocusConfig): FocusPhase
    fun targetDuration(phase: FocusPhase, config: FocusConfig): Duration?
    fun nextPhase(current: FocusPhase, config: FocusConfig): FocusPhase
    fun shouldAutoAdvance(phase: FocusPhase, config: FocusConfig): Boolean
}
```

| Strategy              | Direction                          | Phases                                                        | Auto-advance             |
| --------------------- | ---------------------------------- | ------------------------------------------------------------- | ------------------------ |
| **PomodoroStrategy**  | Countdown                          | WORK → SHORT_BREAK → WORK → ... → LONG_BREAK (every N cycles) | Configurable             |
| **FlowtimeStrategy**  | Countup (work) / Countdown (break) | FLOW → BREAK (duration calculated from flow time)             | No in flow, yes in break |
| **TimeBlockStrategy** | Countdown                          | WORK (Configurable fixed blocks)                              | No                       |
| **StopwatchStrategy** | Countup                            | WORK (no limit)                                               | No                       |

### FocusEngine (Coroutine-based)

```kotlin
@Singleton
class FocusEngine @Inject constructor(
    private val notificationManager: FocusNotificationManager,
    private val sessionRepository: SessionRepository,
) {
    private val _state = MutableStateFlow<FocusEngineState>(FocusEngineState.Idle)
    val state: StateFlow<FocusEngineState> = _state.asStateFlow()

    private var timerJob: Job? = null

    fun start(mode: FocusMode, config: FocusConfig, linkedTaskId: String? = null) {
        val strategy = mode.createStrategy()
        val phase = strategy.initialPhase(config)
        val target = strategy.targetDuration(phase, config)

        timerJob = CoroutineScope(Dispatchers.Default).launch {
            val startTime = Instant.now()
            while (isActive) {
                delay(100) // Tick every 100ms
                val elapsed = Duration.between(startTime, Instant.now())
                val remaining = target?.minus(elapsed)

                _state.value = FocusEngineState.Running(
                    mode = mode,
                    phase = phase,
                    elapsed = elapsed,
                    remaining = remaining,
                    progress = target?.let { elapsed.toMillis().toFloat() / it.toMillis() },
                )

                if (remaining != null && remaining <= Duration.ZERO) {
                    onPhaseComplete(strategy, phase, config)
                    break
                }
            }
        }

        notificationManager.startForegroundTimer(mode, target)
    }

    fun pause() { /* Cancels timerJob, saves elapsed, emits Paused */ }
    fun resume() { /* Re-creates timerJob from saved elapsed */ }
    fun stop() { /* Cancels timerJob, persists session, emits Idle */ }
    fun skipPhase() { /* Advances to nextPhase of the strategy */ }
}
```

### Foreground Service

```kotlin
class FocusForegroundService : Service() {
    // FOREGROUND_SERVICE_SPECIAL_USE (TYPE_SPECIAL_USE)
    // START_STICKY — restarts if the system kills it
    //
    // Persistent notification with:
    //   - Mode icon + name
    //   - Timer countdown/countup
    //   - buttons: Pause/Resume, Skip, Stop
    //   - Chronometer widget for countup modes
    //   - Updated every second via coroutine
    //
    // State survives process death:
    //   - FocusEngine is @Singleton
    //   - The service re-binds on restart
}
```

**Manifest requirements (Android 14+):**

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

<service
    android:name=".feature.focus.FocusForegroundService"
    android:foregroundServiceType="specialUse"
    android:exported="false">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="focus_timer" />
</service>
```

---

## 6. Data Layer

### Room Database

- **Current version:** 7 (with migrations 1→2→3→4→5→6→7)
- **entities:** TaskEntity, SubtaskEntity, FocusSessionEntity, DailyStatsEntity, ProductivityReportEntity
- **DAOs:** TaskDao, SessionDao, StatsDao
- **Schemas exported** in `app/schemas/` for migration validation
- **TypeConverters** for `Instant`, `List<String>`, enums

### Key DAOs

| DAO            | Key Queries                                                                              |
| -------------- | ---------------------------------------------------------------------------------------- |
| **TaskDao**    | `getActiveTasks()`, `getDirtyTasks()`, `getByServerId()`, `markSynced()`, `softDelete()` |
| **SessionDao** | `getSessionsForDate()`, `getDirtySessions()`, `getTotalFocusToday()`                     |
| **StatsDao**   | `getStatsForDate()`, `getStreakCount()` (recursive CTE for consecutive days)             |

### DataStore

`UserPreferencesRepository` stores user configuration:

- Pomodoro duration, short break, long break
- Default focus mode
- Active sound and volume
- Calendar sync enabled
- Selected theme
- Preferred language
- Onboarding completed flag

### Repositories

Repositories implement the **Repository** pattern as intermediaries between domain and data:

```
TaskRepository (interface) ←── TaskRepositoryImpl (Room + sync flags)
SessionRepository          ←── SessionRepositoryImpl
StatsRepository            ←── StatsRepositoryImpl
```

Each repository:

- Exposes `Flow<List<T>>` for reactive observation
- Marks entities as `isDirty = true` when modified
- Provides `suspend` methods for CRUD

---

## 7. Network and Synchronization (Updated 2026-03-24)

### Ktor HTTP Client

```kotlin
@Singleton
class PepinilloApiClient @Inject constructor(
    private val httpClient: HttpClient,  // OkHttp engine
    private val authStore: AuthStore,
) {
    // Configuration:
    // - ContentNegotiation with Kotlinx JSON
    // - Auth interceptor (JWT Bearer token)
    // - Automatic retry with refresh token
    // - Timeout: 30s connect, 30s read
    // - X-Device-ID header on all sync requests (from AuthStore.localDeviceId)
    // - Gzip response decompression
}
```

### Go Backend Endpoints

| Method | Endpoint                      | Description                                               |
| ------ | ----------------------------- | --------------------------------------------------------- |
| POST   | `/api/v1/auth/login`          | Authentication (returns JWT access + refresh)             |
| POST   | `/api/v1/auth/register`       | User registration                                         |
| GET    | `/api/v1/tasks`               | List user tasks                                           |
| POST   | `/api/v1/tasks`               | Create task                                               |
| PUT    | `/api/v1/tasks/:id`           | Update task                                               |
| DELETE | `/api/v1/tasks/:id`           | Delete task                                               |
| POST   | `/api/v1/pomodoro-sessions`   | Register focus session                                    |
| GET    | `/api/v1/pomodoro-sessions`   | List sessions                                             |
| GET    | `/api/v1/preferences`         | Get user preferences (per-key LWW merge)                  |
| PUT    | `/api/v1/preferences`         | Update user preferences                                   |
| POST   | `/api/v1/sync/sessions`       | Batch session sync (replaces individual POSTs)            |
| POST   | `/api/v1/sync/initial-upload` | Atomic upload for anonymous-to-registered transition      |
| GET    | `/api/v1/sync/full`           | Cursor-based paginated full download for new device login |
| GET    | `/api/v1/health`              | Health check                                              |
| WS     | `/ws`                         | Real-time sync notifications (WebSocket)                  |

**Pending backend endpoints:**

- `GET /api/v1/stats/daily` — Stats daily
- `GET /api/v1/stats/weekly` — Stats weekly
- `POST /api/v1/billing/verify` — Play Store receipt verification

### JWT Authentication

- **AuthStore**: stores tokens in `EncryptedSharedPreferences`, plus `localDeviceId` (UUID generated once per install)
- **Access Token**: JWT short-lived for requests
- **Refresh Token**: JWT long-lived to renew access token
- **Auth Gate**: `MainActivity` checks valid token on startup; redirects to `AuthScreen` if missing
- **IdentityManager**: state machine managing user identity transitions (ANONYMOUS / REGISTERED / VERIFIED)

### IdentityManager -- User Identity State Machine

```
ANONYMOUS ---register---> REGISTERED ---verify email---> VERIFIED
    |                          ^
    +--------- login ----------+
```

- **ANONYMOUS**: app works fully offline with no account; all data stored locally in Room
- **REGISTERED**: user has created an account; sync is active; initial upload triggered
- **VERIFIED**: email confirmed; full feature access

### Sync Architecture (Offline-First)

The sync system follows an **offline-first** design where Room is always the source of truth. Sync is opportunistic and the app is fully functional without network connectivity.

#### Core Design Principles

- **Source of Truth**: Room (local SQLite)
- **Sync Pattern**: Dirty-flag with isDirty / syncedAt / serverId
- **Conflict Resolution**: Record-level Last-Write-Wins (LWW)
- **Transport**: HTTPS + WebSocket notifications
- **Compression**: Gzip on all sync responses
- **Protocol order**: Settings -> Tasks -> Sessions (batch) -> Stats (pull)

#### Dirty-Flag Pattern

Every syncable entity carries these fields:

| Field       | Type     | Purpose                                    |
| ----------- | -------- | ------------------------------------------ |
| `serverId`  | String?  | ID assigned by backend (null until synced)  |
| `isDirty`   | Boolean  | `true` when locally modified, needs push    |
| `syncedAt`  | Instant? | Timestamp of last successful sync           |
| `isDeleted` | Boolean  | Soft delete flag for sync (tasks only)      |

On local write: `isDirty = true`. On successful sync: `isDirty = false, syncedAt = now()`.

#### Sync Triggers

| Sync Type      | Trigger                           | Mechanism                                            |
| -------------- | --------------------------------- | ---------------------------------------------------- |
| **Periodic**   | Every 15 minutes                  | `SyncWorker` via WorkManager (`PeriodicWorkRequest`) |
| **Immediate**  | Task completed, session finalized | `OneTimeWorkRequest` expedited                       |
| **Manual**     | User pull-to-refresh              | Direct call to `SyncEngine.syncAll()`                |
| **Real-time**  | WebSocket notification received   | Triggers HTTP sync for the affected entity type      |

#### Settings Sync -- SettingsSyncEngine

Bidirectional settings sync using per-key Last-Write-Wins via the `user_preferences` backend table.

- **17 syncable keys**: pomodoro duration, break durations, auto-advance, theme, language, sound settings, etc.
- **6 device-specific keys excluded**: notification permissions, calendar sync toggle, DND toggle, onboarding completed, device-specific UI preferences, local widget config
- **Per-key LWW**: each preference key has its own `updatedAt` timestamp; conflicts resolved at key level, not bulk
- **SyncMetadataStore**: tracks `lastSyncAt` per entity type (settings, tasks, sessions, stats) via DataStore

#### Batch Session Sync

Sessions use batch upload instead of individual POSTs for efficiency:

- `POST /sync/sessions` accepts an array of dirty sessions
- Backend recomputes `focus_stats` after batch insert
- Client UUIDs are preserved (server no longer overwrites session IDs)
- FocusSessionEntity includes full fields: `interruptions`, `pomodoroNumber`, `satisfactionRating`, `journalNote`
- `FocusSessionDao` uses **upsert** (INSERT OR REPLACE) instead of insert-only, enabling journal edits to sync

#### Anonymous User Flow

1. User installs app; `IdentityManager.state = ANONYMOUS`
2. All data stored locally in Room (no backend calls)
3. App is fully functional (timer, tasks, analytics)
4. User decides to register; `POST /auth/register`
5. `InitialSyncManager.initialUpload()` triggered: `POST /sync/initial-upload` (atomic, all local data)
6. `IdentityManager.state = REGISTERED`
7. Normal sync resumes (periodic + real-time)

#### Initial Upload on Registration

When an anonymous user registers, `InitialSyncManager` performs an atomic upload:

- `POST /sync/initial-upload` sends all local tasks, sessions, stats, and preferences in one request
- Backend processes atomically (all-or-nothing)
- On success, all local entities are marked synced

#### New Device Full Sync

When a registered user logs in on a new device:

- `GET /sync/full` with cursor-based pagination downloads all user data
- `InitialSyncManager.wipeAndSync()` clears local Room DB, then pages through all data
- Cursor pagination avoids memory issues with large datasets
- After completion, normal sync resumes

#### Data Merge Dialog (Anonymous to Existing Account)

When an anonymous user logs into an account that already has data, `DataMergeDialog` (Composable) presents two options:

- **Upload Local**: keep anonymous data and push it to the cloud via `InitialSyncManager.initialUpload()`
- **Download Cloud**: replace local data with cloud data via `InitialSyncManager.wipeAndSync()`
- Triggered in `AuthViewModel` when login detects both local anonymous data and existing cloud data

#### Real-Time Sync via WebSocket -- SyncWebSocketClient

- `SyncWebSocketClient` (OkHttp WebSocket) connects on app foreground, disconnects on background
- Receives **notification-only** messages (e.g., `{ "type": "sync", "entity": "tasks" }`)
- WebSocket does NOT carry data payloads, only signals that trigger HTTP sync
- **SyncLifecycleObserver**: ProcessLifecycleOwner observer that connects WS on `ON_START` and disconnects on `ON_STOP`
- **X-Device-ID**: every sync HTTP request includes `X-Device-ID` header; the backend WebSocket hub uses `SendToUserExcluding(userId, excludeDeviceId, msg)` to avoid notifying the device that originated the change
- **Reconnect strategy**: exponential backoff (1s, 2s, 4s, 8s, max 30s)

#### Conflict Resolution

| Version          | Strategy          | Granularity  | Status      |
| ---------------- | ----------------- | ------------ | ----------- |
| **V1 (current)** | Last-Write-Wins   | Record-level | Implemented |
| **V2 (planned)** | Field-level merge | Field-level  | Planned     |

- V1: entire record is replaced by whichever version has the latest `updatedAt`
- V2 (future): individual fields compared and merged independently, reducing data loss on concurrent edits

#### Key Sync Components

| Component          | Class                   | Responsibility                                            |
| ------------------ | ----------------------- | --------------------------------------------------------- |
| Sync orchestrator  | `SyncEngine`            | Coordinates all sync operations in order                  |
| Settings sync      | `SettingsSyncEngine`    | Bidirectional per-key LWW for 17 preference keys          |
| Session batch sync | `SyncEngine`            | Batch POST for dirty sessions                             |
| Initial upload     | `InitialSyncManager`    | Atomic upload on registration                             |
| Full download      | `InitialSyncManager`    | Cursor-paginated download + wipeAndSync                   |
| Metadata tracking  | `SyncMetadataStore`     | Per-entity `lastSyncAt` via DataStore                     |
| WebSocket client   | `SyncWebSocketClient`   | OkHttp WebSocket with exponential backoff                 |
| Lifecycle observer | `SyncLifecycleObserver` | Connect/disconnect WS on foreground/background            |
| Merge UI           | `DataMergeDialog`       | Composable for anonymous-to-existing-account merge choice |
| Identity           | `IdentityManager`       | ANONYMOUS/REGISTERED/VERIFIED state machine               |
| Device ID          | `AuthStore`             | Persists `localDeviceId` UUID for X-Device-ID header      |

---

## 8. Wear OS

### Phone ↔ Watch Communication Architecture

Communication is **bidirectional** using the Wearable Data Layer API:

```
┌─────────────────┐                    ┌─────────────────┐
│     PHONE       │                    │     WATCH       │
│                 │   DataClient       │                 │
│ PhoneDataLayer  │ ─── DataItems ───► │ WearDataLayer   │
│ Manager         │                    │ Listener        │
│                 │   MessageClient    │                 │
│ PhoneMessage    │ ◄── Messages ───── │ WearMessage     │
│ ListenerService │                    │ Sender          │
└─────────────────┘                    └─────────────────┘
```

### Data Flows

**Phone → Watch (DataItems):**

| Path               | Content                                                              | Frequency                  |
| ------------------ | -------------------------------------------------------------------- | -------------------------- |
| `/pepinillo/timer` | Timer state (mode, phase, elapsed, remaining, isRunning, linkedTask) | On each FocusEngine tick   |
| `/pepinillo/tasks` | Active task list (id, title, isCompleted, priority)                  | On each task change        |
| `/pepinillo/stats` | Daily stats (focusTime, sessions, streak, tasksCompleted)            | On task/session completion |

**Watch → Phone (Messages/Commands):**

| Path                           | Action                                 |
| ------------------------------ | -------------------------------------- |
| `/pepinillo/cmd/timer/start`   | Start session (includes selected mode) |
| `/pepinillo/cmd/timer/pause`   | Pause timer                            |
| `/pepinillo/cmd/timer/resume`  | Resume timer                           |
| `/pepinillo/cmd/timer/stop`    | Stop session                           |
| `/pepinillo/cmd/timer/skip`    | Skip current phase                     |
| `/pepinillo/cmd/task/complete` | Mark task as completed                 |
| `/pepinillo/cmd/task/link`     | Link task to timer                     |
| `/pepinillo/cmd/task/unlink`   | Unlink task from timer                 |

### Wear OS Components

**WearDataRepository:**

- `StateFlow` for each synchronized data type (timer, tasks, stats)
- Fallback to local data when the phone is disconnected
- Local persistence for offline access

**WearPendingCommandQueue:**

- Command buffer when the phone is unavailable
- Automatic send on reconnection

**WearFocusViewModel:**

- Consumes data from `WearDataRepository`
- Local focus engine as fallback
- Sends commands via `WearMessageSender`

### Tile (Wear OS)

```kotlin
class FocusTileService : SuspendingTileService() {
    // Based on Horologist 0.6.20
    //
    // Layout IDLE:
    //   - buttons quick-start by mode (Pomodoro, Flow, etc.)
    //   - Streak current
    //
    // Layout ACTIVE:
    //   - Timer display (countdown/countup)
    //   - Mode name + phase
    //   - buttons: Pause/Resume, Stop
    //   - Linked task (if present)
}
```

### Complication

```kotlin
class FocusComplicationDataSource : SuspendingComplicationDataSourceService() {
    // Supported types:
    //   - SHORT_TEXT: active focus time or current streak
    //   - LONG_TEXT: "25:00 Pomodoro" or "🔥 5 days"
    //
    // Updated when timer state changes or a new day starts
}
```

---

## 9. Widgets (Glance Compose)

### Widget Architecture

All widgets use **Glance 1.1.1** with `PreferencesGlanceStateDefinition`:

```
FocusEngine ──► WidgetStateStore ──► GlanceAppWidget.update()
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
            FocusTimerWidget       DailyStatsWidget      LockScreenTimerWidget
            (Home Screen)         (Home Screen)          (Lock Screen, API 33+)
```

### FocusTimerWidget

- Shows: current mode, timer (countdown/countup), phase, progress indicator
- Action buttons: Pause/Resume, Stop
- Idle state: quick-start buttons by mode
- Update: every second during active session

### DailyStatsWidget

- Shows: total focus time today, sessions completed, breakdown by mode, streak
- Tap opens the app dashboard
- Update: on task/session completion

### LockScreenTimerWidget

- `widgetCategory="home_screen|keyguard"` in widget info XML
- Only available on Android 14+ (API 33+)
- Simplified layout: timer and current mode
- Allows checking progress without unlocking

### WidgetStateStore / WidgetTaskStateManager

- `WidgetStateStore`: manages timer widget state via `updateAppWidgetState`
- `WidgetTaskStateManager`: manages task state for widgets
- `CompleteTaskWorker`: executes task completion actions from the widget

### Glance Limitations

- Does not support `stringResource()` → use `context.getString(R.string.xxx)`
- Does not support custom state classes in `currentState<T>()` → use `PreferencesGlanceStateDefinition` + `Preferences`
- Limited composables compared to standard Jetpack Compose

---

## 10. System Extensions

### Quick Settings Tile

```kotlin
class FocusTileService : TileService() {
    // Android 7+ (API 24)
    // Toggle play/pause with one tap
    // Icon changes based on active mode
    // Long press opens the app
    //
    // onClick() → toggle FocusEngine (start/pause/resume)
    // onStartListening() → updates state from FocusEngine
}
```

### Google Assistant App Actions

Configured in `actions.xml` with 3 Built-In Intents (BIIs):

| BII                        | Voice Trigger                             | Action                   |
| -------------------------- | ----------------------------------------- | ------------------------ |
| `START_EXERCISE`           | "Hey Google, start Pomodoro in Pepinillo" | Starts a focus session   |
| `STOP_EXERCISE`            | "Hey Google, stop focus in Pepinillo"     | Stops the active session |
| `GET_EXERCISE_OBSERVATION` | "Hey Google, how was my focus today?"     | Shows today's stats      |

**Deep Links:** `pepinillo://focus/{start|stop|status}`

**shortcuts.xml:** 4 static shortcuts (Pomodoro, Flow, Stopwatch, Tasks)

**Intent handling:** `MainActivity` with `launchMode="singleTask"` + `onNewIntent()` to receive deep links.

### Lock Screen Widget

- KEYGUARD category in widget info XML
- Available on Android 14+ (API 33+)
- Timer visible without unlocking the device

### Persistent notification

- Channel `IMPORTANCE_LOW` (no sound)
- Shows mode, timer, current phase
- Actions: Pause/Resume, Skip, Stop
- Chronometer widget for countup modes
- Updates every second

---

## 11. On-Device AI

### Productivity Report Generation

```
┌─────────────────────┐
│  ReportDataBuilder   │ ←── Aggregates Room data (sessions, tasks, stats)
└──────────┬──────────┘
           │
     ┌─────▼──────┐
    │ ML available? │
     └─────┬──────┘
     Yes   │   No
     ┌─────▼──────┐  ┌──────────────────────┐
     │ OnDevice    │  │ TemplateReport        │
     │ Report      │  │ Generator             │
    │ Generator   │  │ (template-based       │
    │ (local ML)  │  │  fallback)            │
     └─────────────┘  └──────────────────────┘
```

- **OnDeviceReportGenerator**: uses local ML to generate personalized productivity insights
- **TemplateReportGenerator**: fallback with predefined templates when ML is unavailable
- **ReportDataBuilder**: aggregates and prepares data from multiple sources (sessions, tasks, daily stats)
- **Report types**: weekly and monthly
- **Storage**: `ProductivityReportEntity` in Room

---

## 12. Design

### Visual System

| Aspect             | Implementation                                          |
| ------------------ | ------------------------------------------------------- |
| **Design System**  | Material 3 + Material You dynamic colors                |
| **Themes**         | 4+ themes (light, dark, dynamic light, dynamic dark)    |
| **Colors by mode** | `FocusModeColors` — each focus mode has its own palette |
| **Loading States** | Shimmer loading placeholders (animated skeletons)       |
| **Typography**     | Material 3 Type Scale                                   |
| **Icons**          | Material Symbols                                        |

### Adaptive Layouts

Implemented with `WindowSizeClass` from Material 3:

| WindowWidthSizeClass   | Navigation                          | Layout                          |
| ---------------------- | ----------------------------------- | ------------------------------- |
| **Compact** (<600dp)   | `NavigationBar` (bottom)            | Single-column, original layouts |
| **Medium** (600-840dp) | `NavigationRail` (left rail)        | Two-pane where applicable       |
| **Expanded** (>840dp)  | `PermanentNavigationDrawer` (240dp) | Full multi-column layout        |

**Screens with adaptive layout:**

| Screen              | Compact                     | Expanded (≥600dp)                                    |
| ------------------- | --------------------------- | ---------------------------------------------------- |
| **FocusScreen**     | Original layout             | Two-pane: timer 320dp (60%) + controls (40%)         |
| **TaskListScreen**  | List with detail navigation | Master-detail: list (40%) + detail (60%)             |
| **DashboardScreen** | Single-column               | WeeklyChart (60%) + ModeBreakdown (40%) side-by-side |
| **SettingsScreen**  | Single-column               | Two-column: focus config + sound/calendar/import     |

### Foldable Support

- **androidx.window 1.3.0** + `window-core`
- `FoldableUtils.kt` with `rememberFoldingFeature()`
- Dynamic spacer between panes that respects hinge position
- `hingePadding.coerceAtLeast(24.dp)` to avoid content behind the hinge
- Integrated in FocusScreen and SettingsScreen

### Internationalization

3 languages supported with ~100+ localized strings:

| Language          | File                        |
| ----------------- | --------------------------- |
| English (default) | `res/values/strings.xml`    |
| Spanish           | `res/values-es/strings.xml` |
| Portuguese        | `res/values-pt/strings.xml` |

---

## 13. Billing

### RevenueCat Integration (Android)

**Status:** ✅ Fully Configured (2026-03-21)

#### SDK Setup

```kotlin
@Singleton
class BillingManager @Inject constructor(
    private val context: Context,
) {
    // RevenueCat Purchases SDK v8.10.0
    //
    // Configuration:
    // - Android Public API Key: goog_ITPYSPEdubAzAeoNGxezZuZJELT
    // - Entitlement: "premium" (shared with iOS)
    // - Products: monthly, annual, lifetime
    //
    // Purchase flow:
    // 1. RevenueCat.logIn(userId) → authenticate the user
    // 2. RevenueCat.getPackages() → fetch available offers
    // 3. RevenueCat.purchasePackage() → show paywall
    // 4. RevenueCat.purchaserInfo → verify entitlements
    //
    // Tiers:
    //   - FREE: basic functionality (Pomodoro, limited tasks)
    //   - PRO: all modes, soundscapes, advanced analytics, widgets
}
```

#### Product IDs

| Plan     | Product ID                     |
| -------- | ------------------------------ |
| Monthly  | com.pepinillo.app.pro.monthly  |
| Annual   | com.pepinillo.app.pro.annual   |
| Lifetime | com.pepinillo.app.pro.lifetime |

#### Entitlement Verification

- **Entitlement ID:** `premium` (shared across iOS and Android)
- **Local caching:** subscription state cached via RevenueCat SDK
- **Server-side verification:** Go backend integrated with RevenueCat REST API
- **Grace period:** 3 days supported via RevenueCat
- **User identification:** integrated with the app auth flow

### FeatureGate

- Checks subscription tier before allowing access to PRO features
- Caches subscription state locally via RevenueCat SDK
- Server-side verification via Go backend (endpoint `/api/v1/webhooks/revenuecat` implemented)

---

## 14. Testing

### Testing Strategy

| Layer                     | Tool                       | Coverage Target     | Current status          |
| ------------------------- | -------------------------- | ------------------- | ----------------------- |
| **Domain logic**          | JUnit 5                    | 90%+                | ~20 tests implemented   |
| **ViewModels/Presenters** | Turbine + Presenter.test{} | 80%+                | Pending (Sprint 5)      |
| **Room DAOs**             | Robolectric + in-memory DB | 80%+                | Pending                 |
| **Sync engine**           | JUnit 5 + MockK            | 70%+                | Pending                 |
| **Compose UI**            | Compose testing APIs       | Key flows           | Pending                 |
| **Wear OS**               | Horologist testing         | Basic flows         | Pending                 |
| **Integration**           | Hilt test + real DB        | Auth + sync + timer | Pending                 |

### Existing Tests

- `FocusStateTest` — focus engine state tests
- `GoogleTaskDtoTest` — Google Tasks DTO serialization tests
- `GoogleImportStateTest` — import state tests
- **Total current:** 3 test files, ~20 tests, 0 failures

### Quality Tools

| Tool       | Purpose                                   |
| ---------- | ----------------------------------------- |
| **ktlint** | Kotlin code formatting                    |
| **detekt** | Static analysis (code smells, complexity) |

---

## 15. Security

| Area                      | Implementation                                                                 |
| ------------------------- | ------------------------------------------------------------------------------ |
| **Authentication tokens** | `EncryptedSharedPreferences` (AndroidX Security) - AES-256 encryption          |
| **Network communication** | HTTPS required, clear-text traffic disabled in `network_security_config.xml`   |
| **Certificate pinning**   | Optional - configured but disabled by default                                  |
| **Local database**        | Room without additional encryption (device-level encryption is sufficient)     |
| **Obfuscation**           | R8/ProGuard in release builds (full obfuscation)                               |
| **Analytics**             | No third-party tracking SDKs; minimal and privacy-conscious Firebase Analytics |
| **OAuth tokens**          | Google Tasks import: tokens managed by GMS, not stored by the app              |

---

## 16. CI/CD

| Stage                | Tool                          | Trigger         | Status                             |
| -------------------- | ----------------------------- | --------------- | ---------------------------------- |
| **Lint**             | ktlint + detekt               | Every PR        | ⬜ Pending (Sprint 5)              |
| **Unit Tests**       | JUnit 5 + Robolectric         | Every PR        | ⬜ Pending                         |
| **UI Tests**         | Compose testing               | Nightly         | ⬜ Pending                         |
| **Build**            | Gradle (debug + release)      | Every PR        | ⬜ Pending                         |
| **Signing**          | Play App Signing              | Release only    | ⬜ Pending                         |
| **Distribution**     | Firebase App Distribution     | Internal track  | ⬜ Pending                         |
| **Release**          | Play Console (staged rollout) | Manual approval | ⬜ Pending                         |
| **Crash monitoring** | Firebase Crashlytics          | Always on       | ⬜ Requires `google-services.json` |

### Planned Pipeline (GitHub Actions)

```
PR → ktlint → detekt → assembleDebug → unit tests → ✅/❌
Release → assembleRelease → sign → Firebase App Distribution
Production → Play Console: 10% → 50% → 100%
```

---

## 17. Non-Functional Requirements

### Compatibility

| Requirement         | Value                     |
| ------------------- | ------------------------- |
| **Min SDK**         | API 26 (Android 8.0 Oreo) |
| **Target SDK**      | API 35 (Android 15)       |
| **Wear OS Min SDK** | API 30 (Wear OS 3.0)      |

### Performance

| Metric          | Target                            |
| --------------- | --------------------------------- |
| **Cold start**  | < 1.5 seconds                     |
| **Timer drift** | < 100ms cumulative deviation      |
| **Frame rate**  | 60 FPS consistent in animations   |
| **Memory**      | < 150MB in normal use             |

### Size

| Configuration               | Size                                   |
| --------------------------- | -------------------------------------- |
| **APK without soundscapes** | < 15MB                                 |
| **APK with soundscapes**    | < 30MB                                 |
| **App Bundle (AAB)**        | Optimized per device via Play Delivery |

### Accessibility

| Feature           | Implementation                                     |
| ----------------- | -------------------------------------------------- |
| **TalkBack**      | Content descriptions across 9 screens              |
| **Font scaling**  | Full support for system font scaling               |
| **High contrast** | Colors that pass WCAG AA                           |
| **Reduce motion** | Respects `Settings.Global.ANIMATOR_DURATION_SCALE` |

### Stability

| Metric              | Target  |
| ------------------- | ------- |
| **Crash-free rate** | ≥ 99.5% |
| **ANR rate**        | < 0.1%  |

---

## 18. Gotchas and Technical Decisions

The following key technical decisions were made during development and are documented for future reference:

### 1. Kotlin 2.0.21 instead of 2.1.x

**Problem:** Hilt 2.52 cannot read metadata generated by Kotlin 2.1.0 (APT limitation).
**Solution:** Pinned to Kotlin **2.0.21** with KSP **2.0.21-1.0.28**. It will be updated when Hilt 2.53+ becomes compatible.

### 2. Circuit without `@CircuitInject` KSP

**Problem:** `@CircuitInject` with KSP generates warnings and adds complexity.
**Solution:** Manual Presenter wiring in `AppModule.provideCircuit()` with `@AssistedInject` + `@AssistedFactory`.

### 3. Glance: `PreferencesGlanceStateDefinition` is required

**Problem:** `currentState<T>()` with custom classes causes crashes in Glance.
**Solution:** Use `PreferencesGlanceStateDefinition` + standard `Preferences` for all widget state.

### 4. Glance: no `stringResource()` support

**Problem:** `stringResource()` does not work in Glance composables.
**Solution:** Use `context.getString(R.string.xxx)` directly.

### 5. Firebase depends on `google-services.json`

**Problem:** Build fails if Firebase plugins are enabled without `google-services.json`.
**Solution:** Firebase plugins are commented out in `build.gradle.kts`. Enable manually once the file is added.

### 6. Health Connect API is experimental

**Problem:** `MindfulnessSessionRecord` and deduplication APIs are experimental.
**Solution:** Use `@OptIn(ExperimentalMindfulnessSessionApi, ExperimentalDeduplicationApi)` where needed.

### 7. Foreground Service on Android 14+

**Problem:** Android 14 requires declaring foreground service type and rationale.
**Solution:** Use `FOREGROUND_SERVICE_SPECIAL_USE` + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` in the Manifest with value `"focus_timer"`.

### 8. `libs.versions.toml` auto-loading

**Problem:** Gradle 8 auto-discovers the version catalog; using `from()` in `settings.gradle.kts` causes duplicate loading.
**Solution:** Do not use `from()` - Gradle detects it automatically.

### 9. `kotlin-parcelize` without explicit version

**Problem:** Specifying a version for `kotlin-parcelize` causes conflicts.
**Solution:** Use `id("kotlin-parcelize")` without a version - it is bundled with the Kotlin plugin.

### 10. Destructuring with >5 components

**Problem:** Kotlin does not support destructuring with more than 5 components in `val (a,b,c,d,e,f) = ...`.
**Solution:** Use `when(state)` with explicit assignments instead of destructuring.

### 11. `roundIcon` without mipmap causes AAPT failure

**Problem:** `android:roundIcon` referencing a missing mipmap causes an AAPT error.
**Solution:** Removed `android:roundIcon` from the `<application>` tag in AndroidManifest.

### 12. `SoundscapePlayer` with missing assets

**Problem:** ExoPlayer crashes if the audio file does not exist.
**Solution:** `Player.Listener.onPlayerError` emits `ERROR` in StateFlow; UI shows an error message + spinner instead of crashing.

### 13. Google Tasks import requires OAuth Client ID

**Problem:** `GoogleTasksImportManager.getSignInIntent()` works in debug, but production requires a configured OAuth 2.0 Client ID.
**Solution:** For production: create an OAuth 2.0 Client ID (Android type) in Google Cloud Console and add the release keystore SHA-1.

### 14. Lock Screen Widget only on Android 14+

**Problem:** Lock screen widgets require API 33+.
**Solution:** `widgetCategory="home_screen|keyguard"` in widget info XML. Graceful degradation on earlier versions.

### 15. Adaptive layouts with Circuit

**Problem:** Circuit does not easily propagate `WindowSizeClass` through its navigation stack.
**Solution:** Use local `BoxWithConstraints` in each screen; branch on `maxWidth >= 600.dp` without depending on Circuit.

### 16. `NavigationRail` vs `BottomBar`

**Problem:** Choosing when to show each navigation type.
**Solution:** Use `calculateWindowSizeClass(activity)` in `setContent{}`, pass `widthSizeClass` to `MainScaffold`. Compact→Bottom, Medium→Rail, Expanded→Drawer.

### 17. App Actions deep links

**Problem:** Google Assistant deep links require `singleTask` to work with `onNewIntent`.
**Solution:** Set `android:launchMode="singleTask"` in MainActivity + use the `pepinillo://focus/{start|stop|status}` scheme.

### 18. WorkManager with Hilt

**Problem:** Workers need dependency injection but do not support standard `@Inject`.
**Solution:** Use `@HiltWorker` + `hilt-work 1.2.0`; `PepinilloApp` implements `Configuration.Provider` for custom WorkManager initialization.

---

## 19. Backend and Server Integration

### 19.1 Go Backend Overview

Pepinillo's backend is a REST API written in **Go** with hexagonal architecture. It is **not deployed yet** to production and is under active development in `backend/`.

| Aspect             | Technology                     |
| ------------------ | ------------------------------ |
| **Language**       | Go                             |
| **Framework HTTP** | Fiber                          |
| **Database**       | PostgreSQL                     |
| **Authentication** | JWT (access + refresh tokens)  |
| **Architecture**   | Hexagonal (ports and adapters) |
| **Status**         | In development, not deployed   |

#### Endpoint Groups

| Group         | Endpoints                                                                          | Description                                                 |
| ------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| **Auth**      | `POST /auth/login`, `POST /auth/register`, `POST /auth/google`, `POST /auth/apple` | Email/password authentication + OAuth (Google/Apple)        |
| **Tasks**     | `GET/POST/PUT/DELETE /api/v1/tasks`                                                | Task CRUD                                                   |
| **Sessions**  | `GET/POST /api/v1/pomodoro-sessions`                                               | Register and query focus sessions                           |
| **Stats**     | `GET /api/v1/stats/daily`, `GET /api/v1/stats/weekly`                              | Aggregated statistics (pending)                             |
| **Billing**   | `POST /api/v1/billing/verify`                                                      | Server-side receipt verification (Play Store and App Store) |
| **Push**      | `POST /api/v1/push/register`                                                       | Register FCM tokens for push notifications                  |
| **WebSocket** | `WS /api/v1/ws`                                                                    | Real-time synchronization channel                           |
| **AI**        | `POST /api/v1/ai/report`                                                           | Productivity report generation                              |
| **Users**     | `GET /api/v1/users/me`, `PUT /api/v1/users/me`                                     | User profile                                                |

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

### 19.2 Authentication Flow

Android uses **Google Sign-In** as the primary authentication method, with email/password as an alternative.

#### Google Sign-In (primary method)

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│   Android    │     │  Google Identity  │     │  Backend Go  │
│   App        │     │  Services         │     │              │
│              │     │                   │     │              │
│ 1. Credential│────►│ 2. authentication  │     │              │
│    Manager   │     │    with Google     │     │              │
│              │◄────│ 3. idToken (JWT)  │     │              │
│              │     │                   │     │              │
│ 4. POST      │────────────────────────────►│ 5. Verifies   │
│    /auth/    │     │                   │     │    idToken    │
│    google    │     │                   │     │    with Google │
│              │◄────────────────────────────│ 6. JWT access │
│              │     │                   │     │    + refresh  │
│ 7. Stores    │     │                   │     │              │
│    in Auth   │     │                   │     │              │
│    Store     │     │                   │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘
```

**Detailed steps:**

1. The user taps "Continue with Google" in `AuthScreen`
2. **Credential Manager** (`androidx.credentials`) is invoked to obtain a `GoogleIdTokenCredential`
3. Google returns an `idToken` (JWT signed by Google)
4. The app sends `POST /auth/google` with the `idToken` in the request body
5. The backend validates the `idToken` against Google servers and extracts email/name/photo
6. If the user does not exist, it creates one and returns Pepinillo JWT tokens (access + refresh)
7. Tokens are stored in `AuthStore` (based on `EncryptedSharedPreferences`, AES-256 encryption)

#### Email/Password (alternative)

- `POST /auth/register` → creates an account with email + password
- `POST /auth/login` → returns JWT access + refresh tokens
- Tokens are stored in `AuthStore`, same as with Google Sign-In

#### Token Management

| Token             | Storage                                  | Duration          | Renewal                     |
| ----------------- | ---------------------------------------- | ----------------- | --------------------------- |
| **Access Token**  | `AuthStore` (EncryptedSharedPreferences) | Short (15-30 min) | Automatic via refresh token |
| **Refresh Token** | `AuthStore` (EncryptedSharedPreferences) | Long (30 days)    | Requires re-login on expiry |

The `PepinilloApiClient` (Ktor) includes an authentication interceptor that:

- Attaches the access token as `Authorization: Bearer <token>` on each request
- Detects `401 Unauthorized` responses
- Attempts to renew the access token using the refresh token
- If renewal fails, redirects the user to `AuthScreen`

### 19.3 Cloud Synchronization Strategy

The Go backend is the **source of truth** for cross-platform data. Synchronization is bidirectional with last-write-wins conflict resolution.

#### Sync Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Android App                         │
│                                                          │
│  Room DB ◄──► SyncEngine ◄──► PepinilloApiClient ──────┤
│  (local)      (dirty flags)    (Ktor HTTP)               │
│                    ▲                                     │
│                    │                                     │
│               SyncWorker          WebSocket              │
│              (WorkManager)     (real-time push)          │
└────────────────────┼──────────────────┼─────────────────┘
                     │                  │
                     ▼                  ▼
              ┌──────────────────────────────┐
              │        Backend Go            │
              │   PostgreSQL (cross-platform │
              │   source of truth)           │
              └──────────────────────────────┘
```

#### Synchronization Flow

| Step               | Direction     | Description                                                          |
| ------------------ | ------------- | -------------------------------------------------------------------- |
| 1. Local write     | —             | User creates/edits/deletes → Room stores with `isDirty = true`       |
| 2. Push (upload)   | App → Backend | `SyncEngine` sends all entities with `isDirty = true` to the backend |
| 3. Pull (download) | Backend → App | `SyncEngine` queries backend changes since `syncedAt`                |
| 4. Merge           | —             | Last-write-wins resolution based on `updatedAt`                      |
| 5. Mark synced     | —             | Synced entities: `isDirty = false`, `syncedAt = now()`               |

#### Synchronization Triggers

| Type          | Trigger                           | Mechanism                             | Latency      |
| ------------- | --------------------------------- | ------------------------------------- | ------------ |
| **Real-time** | Remote change (another device)    | WebSocket push from backend           | ~1 second    |
| **Immediate** | Task completed, session finalized | `OneTimeWorkRequest` expedited        | ~2-5 seconds |
| **Periodic**  | Every 15 minutes                  | `PeriodicWorkRequest` via WorkManager | ≤ 15 minutes |
| **Manual**    | User pull-to-refresh              | `SyncEngine.syncAll()` direct call    | Immediate    |

#### WebSocket (Real-Time Synchronization)

The backend exposes `WS /api/v1/ws` to notify connected devices about remote changes:

- On connection, the client sends its JWT to authenticate
- The backend emits events when another device for the same user modifies data
- The client receives the event and performs a selective pull of changed data
- Automatic reconnection with exponential backoff if the connection is lost

#### WorkManager Fallback

`SyncWorker` acts as a safety net when WebSocket is unavailable:

```kotlin
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val syncEngine: SyncEngine,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        return try {
            syncEngine.syncAll()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
```

- **Periodic:** `PeriodicWorkRequestBuilder<SyncWorker>(15, MINUTES)` with `NetworkType.CONNECTED` constraint
- **Immediate:** `OneTimeWorkRequestBuilder<SyncWorker>().setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)` after user actions

### 19.4 Cross-Platform Subscriptions

Subscriptions are verified **server-side** to guarantee parity across platforms. A user who purchases PRO on Android can use PRO on iOS and vice versa.

#### Verification Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Android    │     │  Backend Go  │     │  Google Play  │
│              │     │              │     │  Developer    │
│ 1. user       │     │              │     │  API          │
│    purchases  │     │              │     │              │
│    from Play  │     │              │     │              │
│    Store      │     │              │     │              │
│              │     │              │     │              │
│ 2. POST      │────►│ 3. Validates │────►│ 4. Verifies  │
│    /billing/ │     │    receipt   │     │    purchase  │
│    verify    │     │    with Play │◄────│ 5. Confirms  │
│              │     │    API       │     │    valid     │
│              │     │              │     │              │
│              │◄────│ 6. Updates   │     │              │
│              │     │    user.sub  │     │              │
│ 7. Caches    │     │    tier=pro  │     │              │
│    local PRO │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Detailed steps:**

1. The user completes the purchase via Play Billing Library 7.1.1
2. The app sends `POST /api/v1/billing/verify` with the purchase token and product ID
3. The backend validates the receipt against the Google Play Developer API
   4-5. Google confirms that the purchase is legitimate
4. The backend updates `User.SubscriptionTier = "pro"` in PostgreSQL
5. The app caches PRO state locally; all future checks query `GET /api/v1/users/me`

**Source of truth:** the backend `subscription_tier` field. The app queries `/users/me` at startup and periodically to synchronize subscription state. Local `BillingManager` acts as cache.

**Cross-platform parity:** a user who purchases PRO on iOS (App Store) will see PRO status on Android after login, because the backend centralizes tier state.

### 19.5 User Profile

The user profile combines authentication data, statistics, and subscription state.

#### Profile Data Model

| Field                   | Source                            | Description                                |
| ----------------------- | --------------------------------- | ------------------------------------------ |
| `name`                  | Backend (`User.Name`)             | Display name (from Google/Apple or manual) |
| `email`                 | Backend (`User.Email`)            | Account email                              |
| `avatarUrl`             | Backend (`User.ImageURL`)         | Profile photo (Google/Apple URL)           |
| `subscriptionTier`      | Backend (`User.SubscriptionTier`) | `"free"` or `"pro"`                        |
| `subscriptionExpiresAt` | Backend                           | PRO subscription expiration date           |
| `linkedAccounts`        | Backend                           | Linked providers: Google, Apple, email     |
| `emailVerified`         | Backend (`User.EmailVerified`)    | Whether the email is verified              |
| `memberSince`           | Backend (`User.CreatedAt`)        | Registration date                          |

#### Profile Statistics (calculated)

| Statistic              | Calculation                                              | Source                                      |
| ---------------------- | -------------------------------------------------------- | ------------------------------------------- |
| **Current streak**     | Consecutive days with at least one session               | `StatsDao.getStreakCount()` (recursive CTE) |
| **Total focus hours**  | Sum of `totalFocusSeconds` across all `DailyStatsEntity` | Local Room                                  |
| **Sessions completed** | Sum of `sessionsCompleted` across all `DailyStatsEntity` | Local Room                                  |
| **Tasks completed**    | Count of `TaskEntity` where `isCompleted = true`         | Local Room                                  |
| **Dominant mode**      | Mode with the highest total seconds                      | Computed from `DailyStatsEntity`            |

#### Profile Screen

The profile screen (`ProfileScreen`) shows:

- **Header:** Avatar, name, email, PRO/FREE badge
- **Statistics:** streak, total hours, sessions, completed tasks, member since
- **Account:** Linked accounts (Google, Apple, email), option to link/unlink
- **Subscription:** current status, expiration date, manage/upgrade button
- **Actions:** sign out, delete account
