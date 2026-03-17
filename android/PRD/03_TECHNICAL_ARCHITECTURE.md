# Arquitectura Técnica — Pepinillo Android Nativo

**Versión:** 1.0
**Fecha:** 2026-03-12

---

## 1. Stack Tecnológico

| Capa | Tecnología | Justificación |
|------|------------|---------------|
| **Lenguaje** | Kotlin 2.x | First-class Android, coroutines, null safety |
| **UI** | Jetpack Compose + Material 3 | Declarativa, Material You dynamic color |
| **Arquitectura** | MVI con Circuit (Slack) | Análogo a TCA: unidirectional, testable, composable |
| **DI** | Hilt (Dagger) | Standard Android DI, constructor injection |
| **DB local** | Room + DataStore | SQLite typesafe + proto preferences |
| **Networking** | Ktor Client + Kotlinx Serialization | Kotlin-native, multiplatform ready |
| **Sync** | Custom sync engine (Room + Backend API) | Offline-first con conflict resolution |
| **Background** | Foreground Service + WorkManager | Timer accuracy + deferred work |
| **Widgets** | Glance (Jetpack Compose for widgets) | Modern, Compose-based widgets |
| **Wear OS** | Compose for Wear OS + Horologist | Modern watch UI |
| **Payments** | Google Play Billing 7 | In-app subscriptions |
| **Analytics** | Firebase Analytics (privacy-conscious) | Crash reporting + minimal events |
| **Testing** | JUnit 5 + Turbine + Robolectric | Unit + integration + UI tests |
| **Build** | Gradle 8.x + Version Catalogs | Modern dependency management |

---

## 2. Estructura del Proyecto

```
app/
├── src/main/
│   ├── kotlin/com/pepinillo/android/
│   │   ├── PepinilloApp.kt                    # Application class + Hilt entry point
│   │   ├── MainActivity.kt                     # Single Activity, Compose host
│   │   │
│   │   ├── core/                               # Shared utilities
│   │   │   ├── di/                             # Hilt modules
│   │   │   ├── navigation/                     # Navigation graph (Compose Navigation)
│   │   │   ├── theme/                          # Material You theme + dynamic color
│   │   │   ├── util/                           # Extensions, formatters
│   │   │   └── network/                        # Ktor client config, auth interceptor
│   │   │
│   │   ├── domain/                             # Pure Kotlin — no Android deps
│   │   │   ├── model/                          # Data classes: Task, FocusSession, DailyStats, etc.
│   │   │   ├── repository/                     # Repository interfaces (ports)
│   │   │   └── service/                        # Business logic: FocusModeStrategy, ModeIntelligence
│   │   │
│   │   ├── data/                               # Data layer implementations
│   │   │   ├── local/                          # Room DAOs + entities + database
│   │   │   ├── remote/                         # Ktor API client (Go backend)
│   │   │   ├── repository/                     # Repository implementations
│   │   │   ├── sync/                           # Sync engine (Room ↔ Backend)
│   │   │   └── datastore/                      # Proto DataStore (user preferences)
│   │   │
│   │   ├── feature/                            # Feature modules (Circuit Presenters + UIs)
│   │   │   ├── focus/                          # Multi-mode focus engine + UI
│   │   │   │   ├── FocusPresenter.kt           # Circuit Presenter (≈ TCA Reducer)
│   │   │   │   ├── FocusScreen.kt              # Compose UI
│   │   │   │   ├── FocusEngine.kt              # Timer engine (coroutines)
│   │   │   │   ├── strategy/                   # FocusModeStrategy implementations
│   │   │   │   │   ├── PomodoroStrategy.kt
│   │   │   │   │   ├── FlowtimeStrategy.kt
│   │   │   │   │   ├── TimeBlockStrategy.kt
│   │   │   │   │   └── StopwatchStrategy.kt
│   │   │   │   └── service/                    # FocusForegroundService
│   │   │   │
│   │   │   ├── tasks/                          # Task management
│   │   │   │   ├── TaskListPresenter.kt
│   │   │   │   ├── TaskListScreen.kt
│   │   │   │   ├── TaskDetailPresenter.kt
│   │   │   │   └── TaskDetailScreen.kt
│   │   │   │
│   │   │   ├── analytics/                      # Dashboard + weekly review
│   │   │   │   ├── DashboardPresenter.kt
│   │   │   │   ├── DashboardScreen.kt
│   │   │   │   ├── WeeklyReviewPresenter.kt
│   │   │   │   └── WeeklyReviewScreen.kt
│   │   │   │
│   │   │   ├── settings/                       # Settings + preferences
│   │   │   ├── auth/                           # JWT auth (Go backend)
│   │   │   ├── onboarding/                     # 5-step onboarding
│   │   │   └── soundscape/                     # Ambient sounds (ExoPlayer)
│   │   │
│   │   └── platform/                           # Android platform integrations
│   │       ├── widget/                         # Glance widgets
│   │       ├── notification/                   # Ongoing notification manager
│   │       ├── tile/                           # Quick Settings tile
│   │       ├── assistant/                      # Google Assistant App Actions
│   │       ├── health/                         # Health Connect integration
│   │       └── focusmode/                      # Android Focus Mode / DND
│   │
│   ├── res/                                    # Resources
│   │   ├── values/strings.xml                  # EN
│   │   ├── values-es/strings.xml               # ES
│   │   └── values-pt/strings.xml               # PT
│   │
│   └── AndroidManifest.xml
│
├── wear/                                       # Wear OS module
│   ├── src/main/kotlin/com/pepinillo/wear/
│   │   ├── WearMainActivity.kt
│   │   ├── presentation/
│   │   │   ├── FocusWearScreen.kt
│   │   │   ├── TaskPickerWearScreen.kt
│   │   │   └── theme/WearTheme.kt
│   │   ├── tile/FocusTile.kt                  # Wear OS Tile
│   │   ├── complication/FocusComplication.kt   # Watch face complications
│   │   └── communication/PhoneDataClient.kt   # DataLayer API (phone↔watch)
│   │
│   └── src/main/AndroidManifest.xml
│
└── build.gradle.kts                            # Version catalog refs
```

---

## 3. Arquitectura MVI con Circuit

### Por qué Circuit (no Orbit, no MvRx)
- **Open-source de Slack**, production-proven a escala
- Mismo mental model que TCA: `Presenter` (≈ Reducer) + `State` + `Event` (≈ Action)
- First-class Compose Navigation integration
- Built-in testing utilities (`Presenter.test {}`)
- Supports `Screen` as navigation node (como TCA's feature-level composition)

### Patrón Circuit

```kotlin
// Equivalente a TCA's @Reducer struct + @ObservableState
@CircuitInject(FocusScreen::class, ActivityComponent::class)
class FocusPresenter @Inject constructor(
    private val focusEngine: FocusEngine,
    private val taskRepository: TaskRepository,
    private val navigator: Navigator,
) : Presenter<FocusState> {

    @Composable
    override fun present(): FocusState {
        var selectedMode by remember { mutableStateOf(FocusMode.POMODORO) }
        var isRunning by remember { mutableStateOf(false) }
        // ...

        return FocusState(
            selectedMode = selectedMode,
            isRunning = isRunning,
            // ...
        ) { event ->
            when (event) {
                is FocusEvent.ModeSelected -> selectedMode = event.mode
                is FocusEvent.StartTapped -> focusEngine.start(selectedMode)
                is FocusEvent.StopTapped -> focusEngine.stop()
                // ...
            }
        }
    }
}

// State
@Immutable
data class FocusState(
    val selectedMode: FocusMode,
    val isRunning: Boolean,
    val isPaused: Boolean,
    val displayTime: String,
    val phase: FocusPhase,
    // ...
    val eventSink: (FocusEvent) -> Unit,
)

// Events (≈ TCA Actions)
sealed interface FocusEvent {
    data class ModeSelected(val mode: FocusMode) : FocusEvent
    data object StartTapped : FocusEvent
    data object PauseTapped : FocusEvent
    data object StopTapped : FocusEvent
    data object SkipPhaseTapped : FocusEvent
    data class LinkTask(val taskId: String?) : FocusEvent
}
```

---

## 4. Focus Engine

### Strategy Pattern (idéntico conceptualmente a iOS)

```kotlin
// domain/service/FocusModeStrategy.kt
interface FocusModeStrategy {
    val mode: FocusMode
    val direction: TimerDirection

    fun initialPhase(config: FocusConfig): FocusPhase
    fun targetDuration(phase: FocusPhase, config: FocusConfig): Duration?
    fun nextPhase(current: FocusPhase, config: FocusConfig): FocusPhase
    fun shouldAutoAdvance(phase: FocusPhase, config: FocusConfig): Boolean
}

// Implementations: PomodoroStrategy, FlowtimeStrategy, TimeBlockStrategy, StopwatchStrategy
```

### FocusEngine (Coroutine-based)

```kotlin
// feature/focus/FocusEngine.kt
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
                delay(100) // 100ms tick
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

        // Start foreground service
        notificationManager.startForegroundTimer(mode, target)
    }
    // ...
}
```

### Foreground Service (Background Timer)

```kotlin
// platform/notification/FocusForegroundService.kt
class FocusForegroundService : Service() {
    // TYPE_SPECIAL_USE for timer accuracy
    // Shows ongoing notification with:
    // - Mode icon + name
    // - Countdown/countup timer
    // - Pause/Resume, Skip, Stop buttons
    // - Chronometer widget for count-up modes
    // Updates every second via coroutine
}
```

---

## 5. Data Layer

### Room Database

```kotlin
// data/local/PepinilloDatabase.kt
@Database(
    entities = [
        TaskEntity::class,
        SubtaskEntity::class,
        FocusSessionEntity::class,
        DailyStatsEntity::class,
    ],
    version = 1,
)
@TypeConverters(Converters::class)
abstract class PepinilloDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun sessionDao(): SessionDao
    abstract fun statsDao(): StatsDao
}

// data/local/entity/TaskEntity.kt
@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey val id: String,                     // UUID string
    val title: String,
    val notes: String? = null,
    val isCompleted: Boolean = false,
    val completedAt: Instant? = null,
    val priority: Int = 0,                          // TaskPriority ordinal
    val sortOrder: Int = 0,
    val energyLevel: String = "deep",               // EnergyLevel name
    val estimatedPomodoros: Int = 1,
    val completedPomodoros: Int = 0,
    val preferredMode: String? = null,
    val recurrenceRule: String? = null,              // RRULE string
    val nextOccurrence: Instant? = null,
    val isRecurringTemplate: Boolean = false,
    val recurringTemplateId: String? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
    val syncedAt: Instant? = null,                  // Last synced with backend
    val isDirty: Boolean = true,                    // Needs sync
)
```

### Sync Engine

```kotlin
// data/sync/SyncEngine.kt
@Singleton
class SyncEngine @Inject constructor(
    private val taskDao: TaskDao,
    private val sessionDao: SessionDao,
    private val apiClient: PepinilloApiClient,
) {
    // Strategy: "dirty flag" sync
    // 1. On save: mark entity as isDirty = true
    // 2. On sync: push all dirty entities to backend
    // 3. Pull latest from backend, merge by updatedAt
    // 4. Clear dirty flag on successful push
    //
    // Conflict resolution: last-write-wins (same as iOS CloudKit)
    // WorkManager periodic sync (every 15 min when online)
    // Immediate sync on critical actions (task complete, session end)

    suspend fun syncAll() { /* ... */ }
    suspend fun syncTasks() { /* ... */ }
    suspend fun syncSessions() { /* ... */ }
}
```

### Backend API Client

```kotlin
// core/network/PepinilloApiClient.kt
@Singleton
class PepinilloApiClient @Inject constructor(
    private val httpClient: HttpClient,
    private val authStore: AuthStore,
) {
    // Endpoints match existing Go backend:
    // POST   /api/v1/auth/login
    // POST   /api/v1/auth/register
    // GET    /api/v1/tasks
    // POST   /api/v1/tasks
    // PUT    /api/v1/tasks/:id
    // DELETE /api/v1/tasks/:id
    // POST   /api/v1/pomodoro-sessions
    // GET    /api/v1/pomodoro-sessions
    // GET    /api/v1/health
}
```

---

## 6. Widgets (Glance Compose)

### Timer Widget

```kotlin
// platform/widget/FocusTimerWidget.kt
class FocusTimerWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<FocusWidgetState>()
            FocusTimerWidgetContent(state)
        }
    }
}

@Composable
private fun FocusTimerWidgetContent(state: FocusWidgetState) {
    // Shows:
    // - Current mode icon + name
    // - Timer display (countdown or countup)
    // - Phase indicator (Work 2/4, Break, Flow...)
    // - Pause/Resume + Stop action buttons
    // When idle: Quick-start buttons for each mode
}
```

### Daily Stats Widget

```kotlin
// platform/widget/DailyStatsWidget.kt
class DailyStatsWidget : GlanceAppWidget() {
    // Shows:
    // - Total focus time today
    // - Sessions completed
    // - Mode breakdown (mini bar chart)
    // - Streak count
    // Tapping opens the app's dashboard
}
```

---

## 7. Wear OS

### Arquitectura

```
wear/
├── presentation/
│   ├── FocusWearScreen.kt       # Timer display + controls
│   ├── ModePickerScreen.kt      # Rotary crown mode selection
│   └── TaskPickerScreen.kt      # Task linking on watch
├── tile/
│   └── FocusTile.kt             # Wear OS Tile (quick glance)
├── complication/
│   └── FocusComplication.kt     # Watch face complication
└── communication/
    └── PhoneDataClient.kt       # DataLayer API for phone↔watch sync
```

### Comunicación Phone ↔ Watch

```kotlin
// Wearable Data Layer API
// - MessageClient: Commands (start/pause/stop)
// - DataClient: State sync (current session, preferences)
// - CapabilityClient: Feature detection

class PhoneDataClient @Inject constructor(
    private val messageClient: MessageClient,
    private val dataClient: DataClient,
) {
    fun sendCommand(command: WatchCommand) { /* ... */ }
    fun observeState(): Flow<WatchState> { /* ... */ }
}
```

---

## 8. Quick Settings Tile

```kotlin
// platform/tile/FocusTileService.kt
class FocusTileService : TileService() {
    // Shows toggle icon (play/pause)
    // Single tap starts/stops focus session
    // Long press opens app
    // Icon changes based on active mode

    override fun onClick() {
        // Toggle focus session via FocusEngine
    }

    override fun onTileAdded() { /* register */ }

    override fun onStartListening() {
        // Update tile state from FocusEngine
    }
}
```

---

## 9. Google Assistant (App Actions)

```xml
<!-- shortcuts.xml -->
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <capability android:name="actions.intent.START_EXERCISE">
        <intent android:action="android.intent.action.VIEW"
                android:targetPackage="com.pepinillo.android"
                android:targetClass=".MainActivity">
            <parameter android:name="exercise.name"
                       android:key="focusMode" />
        </intent>
    </capability>
</shortcuts>

<!-- Voice triggers:
     "Hey Google, start Pomodoro in Pepinillo"
     "Hey Google, start focus session"
     "Hey Google, start deep work in Pepinillo"
-->
```

---

## 10. Health Connect

```kotlin
// platform/health/HealthConnectClient.kt
@Singleton
class HealthConnectManager @Inject constructor(
    private val context: Context,
) {
    private val healthClient = HealthConnectClient.getOrCreate(context)

    suspend fun writeMindfulSession(
        startTime: Instant,
        endTime: Instant,
        mode: FocusMode,
    ) {
        val record = MindfulnessSessionRecord(
            startTime = startTime,
            endTime = endTime,
            startZoneOffset = ZoneOffset.systemDefault().rules.getOffset(startTime),
            endZoneOffset = ZoneOffset.systemDefault().rules.getOffset(endTime),
            title = "Pepinillo ${mode.displayName}",
            mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_MEDITATION,
        )
        healthClient.insertRecords(listOf(record))
    }
}
```

---

## 11. Testing Strategy

| Layer | Tool | Coverage Target |
|-------|------|-----------------|
| Domain logic | JUnit 5 | 90%+ |
| Presenters (Circuit) | Presenter.test {} + Turbine | 80%+ |
| Room DAOs | Robolectric + in-memory DB | 80%+ |
| Sync engine | JUnit 5 + MockK | 70%+ |
| Compose UI | Compose testing APIs | Key flows |
| Wear OS | Horologist testing | Basic flows |
| Integration | Hilt test + real DB | Auth + sync + timer |

### Example Presenter Test

```kotlin
@Test
fun `start tapped begins pomodoro session`() = runTest {
    val presenter = FocusPresenter(fakeFocusEngine, fakeTaskRepo, fakeNavigator)
    presenter.test {
        val initial = awaitItem()
        assertThat(initial.isRunning).isFalse()

        initial.eventSink(FocusEvent.StartTapped)
        val running = awaitItem()
        assertThat(running.isRunning).isTrue()
        assertThat(running.selectedMode).isEqualTo(FocusMode.POMODORO)
    }
}
```

---

## 12. Dependencies (Version Catalog)

```toml
# gradle/libs.versions.toml
[versions]
kotlin = "2.1.0"
compose-bom = "2025.03.00"
circuit = "0.24.0"
room = "2.7.0"
ktor = "3.1.0"
hilt = "2.52"
health-connect = "1.1.0-alpha10"
glance = "1.1.1"
wear-compose = "1.4.0"
play-billing = "7.1.1"
exoplayer = "1.5.0"

[libraries]
circuit-foundation = { module = "com.slack.circuit:circuit-foundation", version.ref = "circuit" }
circuit-test = { module = "com.slack.circuit:circuit-test", version.ref = "circuit" }
room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
room-ktx = { module = "androidx.room:room-ktx", version.ref = "room" }
room-compiler = { module = "androidx.room:room-compiler", version.ref = "room" }
ktor-client-core = { module = "io.ktor:ktor-client-core", version.ref = "ktor" }
ktor-client-okhttp = { module = "io.ktor:ktor-client-okhttp", version.ref = "ktor" }
ktor-serialization = { module = "io.ktor:ktor-serialization-kotlinx-json", version.ref = "ktor" }
health-connect = { module = "androidx.health.connect:connect-client", version.ref = "health-connect" }
glance-appwidget = { module = "androidx.glance:glance-appwidget", version.ref = "glance" }
glance-material3 = { module = "androidx.glance:glance-material3", version.ref = "glance" }
wear-compose-material = { module = "androidx.wear.compose:compose-material", version.ref = "wear-compose" }
play-billing = { module = "com.android.billingclient:billing-ktx", version.ref = "play-billing" }
exoplayer = { module = "androidx.media3:media3-exoplayer", version.ref = "exoplayer" }
```

---

## 13. CI/CD

| Stage | Tool | Trigger |
|-------|------|---------|
| Lint | ktlint + detekt | Every PR |
| Unit tests | JUnit 5 + Robolectric | Every PR |
| UI tests | Compose test | Nightly |
| Build | Gradle (debug + release) | Every PR |
| Signing | Play App Signing | Release only |
| Distribution | Firebase App Distribution | Internal track |
| Release | Play Console (staged rollout) | Manual approval |
| Crash monitoring | Firebase Crashlytics | Always on |

---

## 14. Security

| Área | Implementación |
|------|----------------|
| Auth tokens | EncryptedSharedPreferences (AndroidX Security) |
| API calls | HTTPS only, certificate pinning opcional |
| Local DB | Room (no encryption needed — device encryption handles it) |
| No tracking | No third-party analytics SDK; Firebase minimal |
| ProGuard/R8 | Full obfuscation en release builds |
| Network security config | Clear-text traffic disabled |
