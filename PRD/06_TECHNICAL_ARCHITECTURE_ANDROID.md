# Arquitectura Técnica — Android & Wear OS

**Versión:** 1.0
**Fecha:** 2026-03-20
**Plataformas:** Android (teléfono/tablet/foldable) + Wear OS (reloj)

---

## 1. Stack Tecnológico

| Capa | Tecnología | Versión | Justificación |
|------|------------|---------|---------------|
| **Lenguaje** | Kotlin | 2.0.21 | Coroutines, null safety, first-class Android. Limitado a 2.0.x por compatibilidad con Hilt 2.52 (APT no lee metadata Kotlin 2.1.x) |
| **KSP** | kotlin-symbol-processing | 2.0.21-1.0.28 | Debe coincidir exactamente con la versión de Kotlin |
| **Build** | AGP + Gradle | 8.10.0 + 8.14.3 | Version Catalogs (`libs.versions.toml`), configuration cache habilitado |
| **UI** | Jetpack Compose + Material 3 | BOM 2025.03.00 | Declarativa, Material You dynamic color, interop con Glance |
| **Arquitectura** | MVVM | — | ViewModel por pantalla, StateFlow para reactividad. Originalmente planificado MVI/Circuit pero evolucionó a MVVM con ViewModels |
| **DI** | Hilt (Dagger) | 2.52 | Constructor injection, `@AssistedInject` para Circuit Presenters, `@HiltWorker` para WorkManager |
| **DB Local** | Room | 2.7.0 | SQLite typesafe con KSP, exportSchema=true, migraciones versionadas |
| **Preferencias** | DataStore | Proto | `UserPreferencesRepository` para configuraciones de usuario |
| **Networking** | Ktor Client | 3.1.0 | Motor OkHttp, Kotlinx Serialization, DTOs alineados con backend Go |
| **Background** | Foreground Service + WorkManager | 2.10.0 | Timer accuracy + sync diferido periódico (15 min) |
| **Widgets** | Glance | 1.1.1 | Compose-based widgets para Home Screen y Lock Screen |
| **Wear OS UI** | Compose for Wear OS | 1.4.0 | Interfaz moderna para reloj |
| **Wear Tiles** | Horologist | 0.6.20 | `SuspendingTileService` para Wear OS Tiles |
| **Wear Complications** | watchface-complications | 1.2.1 | `SuspendingComplicationDataSourceService` |
| **Wear Data Layer** | play-services-wearable | 18.2.0 | `DataClient` + `MessageClient` para sync phone↔watch |
| **Billing** | RevenueCat Purchases SDK | v8.10.0 | Suscripciones in-app (FREE/PRO); shared `premium` entitlement with iOS |
| **Health** | Health Connect | 1.1.0-rc01 | Mindful Sessions (API experimental) |
| **Audio** | Media3/ExoPlayer | 1.5.0 | Soundscapes (6 pistas ambientales) |
| **Charts** | Vico | 1.14.0 | Gráficos `compose-m3` para dashboard |
| **Adaptive** | material3-window-size-class | via BOM | `WindowWidthSizeClass` para layouts responsivos |
| **Foldable** | androidx.window | 1.3.0 | `FoldingFeature` + hinge avoidance |
| **Testing** | JUnit 5 + Turbine + Robolectric | — | Unit + integration tests |
| **Lint** | ktlint + detekt | — | Estilo de código y análisis estático |

---

## 2. Arquitectura — MVVM

### Patrón General

El proyecto utiliza **MVVM (Model-View-ViewModel)** con Clean Architecture en capas. Originalmente se planificó MVI con Circuit (Slack), pero evolucionó a MVVM con ViewModels y StateFlow para mayor simplicidad.

```
┌─────────────────────────────────────────────────┐
│                     UI Layer                     │
│  Jetpack Compose Screens (feature/)             │
│  Observan StateFlow del ViewModel               │
└───────────────────┬─────────────────────────────┘
                    │ collect / events
┌───────────────────▼─────────────────────────────┐
│                  ViewModel Layer                 │
│  ViewModel por pantalla (@HiltViewModel)        │
│  Expone StateFlow<UiState>                      │
│  Procesa eventos del usuario                    │
└───────────────────┬─────────────────────────────┘
                    │ suspend calls
┌───────────────────▼─────────────────────────────┐
│                 Domain Layer                     │
│  Interfaces de Repository (puertos)             │
│  Servicios: FocusModeStrategy, ModeIntelligence │
│  Modelos puros de Kotlin (sin dependencias Android) │
└───────────────────┬─────────────────────────────┘
                    │ implementaciones
┌───────────────────▼─────────────────────────────┐
│                  Data Layer                      │
│  Room DAOs + Entities                           │
│  DataStore (preferencias)                       │
│  Ktor API Client (backend Go)                   │
│  SyncEngine + SyncWorker                        │
└─────────────────────────────────────────────────┘
```

### Principios

- **Un ViewModel por pantalla**: cada screen tiene su propio ViewModel inyectado con Hilt
- **StateFlow para reactividad**: el ViewModel expone `StateFlow<UiState>` que la UI colecta
- **Hilt para DI**: `@HiltViewModel`, `@Inject constructor`, módulos en `core/di/`
- **Circuit legacy**: algunos Presenters originales permanecen registrados manualmente en `AppModule.provideCircuit()` (sin `@CircuitInject` KSP por warnings)
- **Clean Architecture**: separación estricta entre `data/`, `domain/`, `feature/`

---

## 3. Estructura del Proyecto

### Módulo Principal (`app/`)

```
app/src/main/kotlin/dev/creapolis/pepinillo/
├── PepinilloApp.kt                    # @HiltAndroidApp + WorkManager Configuration.Provider
├── MainActivity.kt                     # Single Activity, Compose host
│                                       # Adaptive nav (BottomBar/Rail/Drawer)
│                                       # Onboarding condicional + auth gate
│                                       # Google Assistant intent handling
│
├── core/
│   ├── di/                            # Módulos Hilt
│   │   ├── AppModule.kt              #   Circuit wiring manual, singletons globales
│   │   ├── DatabaseModule.kt         #   Room database + DAOs
│   │   ├── NetworkModule.kt          #   Ktor HttpClient config
│   │   └── RepositoryModule.kt       #   Bindings de interfaces → implementaciones
│   ├── navigation/
│   │   └── PepinilloNavGraph.kt      # Compose Navigation (9 screens)
│   ├── network/
│   │   └── PepinilloApiClient.kt     # Ktor client con auth interceptor
│   ├── theme/
│   │   ├── Color.kt                  # Material You colores + FocusModeColors
│   │   ├── Theme.kt                  # PepinilloTheme con dynamic color
│   │   └── Type.kt                   # Tipografía Material 3
│   └── ui/
│       └── FoldableUtils.kt          # rememberFoldingFeature() para hinge avoidance
│
├── domain/                            # Kotlin puro — sin dependencias Android
│   ├── model/
│   │   ├── FocusMode.kt              # enum: POMODORO, FLOWTIME, TIME_BLOCK, STOPWATCH
│   │   ├── FocusPhase.kt             # enum: WORK, SHORT_BREAK, LONG_BREAK, FLOW
│   │   ├── FocusConfig.kt            # Duraciones configurables
│   │   ├── Task.kt                   # typealias → shared/
│   │   ├── Subtask.kt                # typealias → shared/
│   │   ├── FocusSession.kt           # typealias → shared/
│   │   ├── EnergyLevel.kt            # enum: DEEP, SHALLOW, ADMIN
│   │   └── DailyStats.kt            # Estadísticas diarias agregadas
│   ├── repository/
│   │   ├── TaskRepository.kt         # Interface (puerto)
│   │   ├── SessionRepository.kt
│   │   └── StatsRepository.kt
│   └── service/
│       ├── FocusModeStrategy.kt      # Interface del patrón Strategy
│       └── ModeIntelligenceService.kt # Sugerencias basadas en historial
│
├── data/
│   ├── local/
│   │   ├── PepinilloDatabase.kt      # Room DB (version 5, 4 entidades, 3 DAOs)
│   │   ├── Converters.kt             # TypeConverters para Room
│   │   ├── entity/
│   │   │   ├── TaskEntity.kt         # Con campos de sync: serverId, isDirty, syncedAt, isDeleted
│   │   │   ├── SubtaskEntity.kt
│   │   │   ├── FocusSessionEntity.kt
│   │   │   └── DailyStatsEntity.kt
│   │   └── dao/
│   │       ├── TaskDao.kt            # CRUD + queries de dirty items para sync
│   │       ├── SessionDao.kt
│   │       └── StatsDao.kt           # Incluye CTE recursivo para streak count
│   ├── datastore/
│   │   └── UserPreferencesRepository.kt # DataStore para preferencias del usuario
│   ├── repository/                    # Implementaciones concretas
│   │   ├── TaskRepositoryImpl.kt
│   │   ├── SessionRepositoryImpl.kt
│   │   └── StatsRepositoryImpl.kt
│   └── sync/
│       ├── SyncEngine.kt             # Dirty-flag sync, last-write-wins
│       ├── SyncWorker.kt             # @HiltWorker, periódico 15 min + OneTime expedited
│       └── RecurringTaskEngine.kt    # Genera siguiente tarea al completar recurrente
│
├── feature/
│   ├── focus/
│   │   ├── FocusEngine.kt            # @Singleton, coroutine-based timer (100ms tick)
│   │   ├── FocusPresenter.kt         # Circuit Presenter (legacy)
│   │   ├── FocusScreen.kt            # Compose UI (two-pane en tablet ≥600dp)
│   │   └── strategy/
│   │       ├── PomodoroStrategy.kt   # 25/5/15 min configurable
│   │       ├── FlowtimeStrategy.kt   # Sin límite de trabajo, break calculado
│   │       ├── TimeBlockStrategy.kt  # Bloques fijos configurables
│   │       └── StopwatchStrategy.kt  # Conteo ascendente sin límite
│   ├── tasks/
│   │   ├── TaskListScreen.kt         # Master-detail en tablet
│   │   └── TaskDetailScreen.kt
│   ├── auth/
│   │   └── AuthScreen.kt             # JWT login/register vía backend Go
│   ├── onboarding/
│   │   └── OnboardingScreen.kt       # 5 pantallas de introducción
│   ├── analytics/
│   │   ├── DashboardScreen.kt        # Vico charts, modo breakdown, streaks
│   │   ├── WeeklyReviewScreen.kt     # Revisión semanal
│   │   └── AchievementsSection.kt    # Logros con progreso
│   ├── settings/
│   │   └── SettingsScreen.kt         # Two-column en tablet, FocusConfig sliders
│   └── soundscape/
│       ├── SoundscapePlayer.kt       # ExoPlayer wrapper
│       └── SoundscapeScreen.kt       # 6 pistas ambientales
│
└── platform/
    ├── billing/
    │   └── BillingManager.kt          # Play Billing 7.1.1, FREE/PRO tiers
    ├── calendar/
    │   └── GoogleCalendarManager.kt   # blockFocusTime() al completar WORK session
    ├── focusmode/
    │   └── DndManager.kt             # Do Not Disturb durante focus sessions
    ├── googletasks/
    │   └── GoogleTasksImportManager.kt # OAuth + REST import desde Google Tasks
    ├── health/
    │   └── HealthConnectManager.kt    # writeMindfulSession para sesiones WORK
    ├── notification/
    │   └── FocusNotificationManager.kt # Canal IMPORTANCE_LOW, acciones Pause/Resume/Stop
    ├── datalayer/
    │   ├── PhoneDataLayerManager.kt   # Envía estado a Wear OS vía DataClient
    │   └── PhoneMessageListenerService.kt # Recibe comandos del reloj
    ├── tile/
    │   └── FocusTileService.kt        # Quick Settings Tile (Android 7+)
    └── widget/
        ├── FocusTimerWidget.kt        # Glance Home Screen widget
        ├── DailyStatsWidget.kt        # Glance Home Screen widget
        ├── LockScreenTimerWidget.kt   # Glance KEYGUARD widget (Android 14+)
        └── WidgetStateStore.kt        # updateAppWidgetState via PreferencesGlanceStateDefinition
```

### Módulo Wear OS (`wear/`)

```
wear/src/main/kotlin/dev/creapolis/pepinillo/wear/
├── data/
│   ├── WearDataRepository.kt         # StateFlows para datos sincronizados del teléfono
│   ├── WearDataLayerListener.kt      # WearableListenerService que recibe updates del phone
│   └── WearMessageSender.kt          # Envía comandos al teléfono vía MessageClient
├── presentation/
│   ├── WearFocusViewModel.kt         # Usa datos sincronizados + fallback local
│   ├── FocusWearScreen.kt            # Timer display + controles en reloj
│   ├── ModePickerScreen.kt           # Selección de modo con rotary crown
│   └── TaskPickerScreen.kt           # Linking de tareas en reloj
├── tile/
│   └── FocusTileService.kt           # SuspendingTileService (idle/active layouts)
└── complication/
    └── FocusComplicationDataSource.kt # SHORT_TEXT + LONG_TEXT (tiempo activo o streak)
```

---

## 4. Modelos de Datos (Room)

La base de datos Room está en la **versión 5**, con migraciones 1→2→3→4→5.

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
    // --- Campos de sincronización (Android-específicos) ---
    val serverId: String? = null,            // ID en el backend Go
    val syncedAt: Instant? = null,           // Último sync exitoso
    val isDirty: Boolean = true,             // Necesita sync con backend
    val isDeleted: Boolean = false,          // Soft delete para sync
)
```

> **Nota:** Los campos `serverId`, `isDirty`, `syncedAt`, `isDeleted` son específicos de Android. iOS no los necesita porque CloudKit maneja la sincronización automáticamente con `CKRecord`.

### FocusSessionEntity

```kotlin
@Entity(tableName = "focus_sessions")
data class FocusSessionEntity(
    @PrimaryKey val id: String,
    val mode: String,                        // FocusMode name
    val startedAt: Instant,
    val endedAt: Instant? = null,
    val duration: Long = 0,                  // Duración en segundos
    val phase: String,                       // FocusPhase name
    val linkedTaskId: String? = null,        // FK a TaskEntity.id
    val isCompleted: Boolean = false,
    val pomodoroCount: Int = 0,
    val createdAt: Instant = Instant.now(),
    // Campos de sync
    val serverId: String? = null,
    val syncedAt: Instant? = null,
    val isDirty: Boolean = true,
)
```

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
    val taskId: String,                      // FK a TaskEntity
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
    val content: String,                     // Reporte generado (texto/JSON)
    val generatedAt: Instant = Instant.now(),
)
```

---

## 5. Motor de Enfoque (FocusEngine)

El `FocusEngine` es el corazón de la aplicación — gestiona el temporizador de enfoque con precisión de milisegundos.

### Arquitectura del Motor

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
           ├── UI (Compose Screens) vía StateFlow
           ├── Widgets (Glance) vía WidgetStateStore
           ├── Wear OS vía PhoneDataLayerManager
           ├── Notificación persistente vía FocusNotificationManager
           └── FocusForegroundService
```

### FocusModeStrategy (Patrón Strategy)

```kotlin
interface FocusModeStrategy {
    val mode: FocusMode
    val direction: TimerDirection           // COUNTDOWN o COUNTUP

    fun initialPhase(config: FocusConfig): FocusPhase
    fun targetDuration(phase: FocusPhase, config: FocusConfig): Duration?
    fun nextPhase(current: FocusPhase, config: FocusConfig): FocusPhase
    fun shouldAutoAdvance(phase: FocusPhase, config: FocusConfig): Boolean
}
```

| Estrategia | Dirección | Fases | Auto-avance |
|------------|-----------|-------|-------------|
| **PomodoroStrategy** | Countdown | WORK → SHORT_BREAK → WORK → ... → LONG_BREAK (cada N ciclos) | Configurable |
| **FlowtimeStrategy** | Countup (work) / Countdown (break) | FLOW → BREAK (duración calculada según tiempo de flow) | No en flow, sí en break |
| **TimeBlockStrategy** | Countdown | WORK (bloques fijos configurables) | No |
| **StopwatchStrategy** | Countup | WORK (sin límite) | No |

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
                delay(100) // Tick cada 100ms
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

    fun pause() { /* Cancela timerJob, guarda elapsed, emite Paused */ }
    fun resume() { /* Re-crea timerJob desde elapsed guardado */ }
    fun stop() { /* Cancela timerJob, persiste sesión, emite Idle */ }
    fun skipPhase() { /* Avanza a nextPhase del strategy */ }
}
```

### Foreground Service

```kotlin
class FocusForegroundService : Service() {
    // FOREGROUND_SERVICE_SPECIAL_USE (TYPE_SPECIAL_USE)
    // START_STICKY — se reinicia si el sistema lo mata
    //
    // Notificación persistente con:
    //   - Ícono del modo + nombre
    //   - Timer countdown/countup
    //   - Botones: Pause/Resume, Skip, Stop
    //   - Chronometer widget para modos countup
    //   - Actualización cada segundo vía coroutine
    //
    // El estado sobrevive a process death:
    //   - FocusEngine es @Singleton
    //   - El servicio se re-vincula al reiniciar
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

## 6. Capa de Datos

### Room Database

- **Versión actual:** 5 (con migraciones 1→2→3→4→5)
- **Entidades:** TaskEntity, SubtaskEntity, FocusSessionEntity, DailyStatsEntity, ProductivityReportEntity
- **DAOs:** TaskDao, SessionDao, StatsDao
- **Schemas exportados** en `app/schemas/` para validación de migraciones
- **TypeConverters** para `Instant`, `List<String>`, enums

### DAOs Relevantes

| DAO | Queries Clave |
|-----|---------------|
| **TaskDao** | `getActiveTasks()`, `getDirtyTasks()`, `getByServerId()`, `markSynced()`, `softDelete()` |
| **SessionDao** | `getSessionsForDate()`, `getDirtySessions()`, `getTotalFocusToday()` |
| **StatsDao** | `getStatsForDate()`, `getStreakCount()` (CTE recursivo para días consecutivos) |

### DataStore

`UserPreferencesRepository` almacena configuración del usuario:

- Duración de pomodoro, break corto, break largo
- Modo de enfoque por defecto
- Sonido activo y volumen
- Sync de calendario habilitado
- Tema seleccionado
- Idioma preferido
- Flag de onboarding completado

### Repositorios

Los repositorios implementan el patrón **Repository** como intermediarios entre domain y data:

```
TaskRepository (interface) ←── TaskRepositoryImpl (Room + sync flags)
SessionRepository          ←── SessionRepositoryImpl
StatsRepository            ←── StatsRepositoryImpl
```

Cada repositorio:
- Expone `Flow<List<T>>` para observación reactiva
- Marca entidades como `isDirty = true` al modificar
- Provee métodos `suspend` para CRUD

---

## 7. Red y Sincronización

### Ktor HTTP Client

```kotlin
@Singleton
class PepinilloApiClient @Inject constructor(
    private val httpClient: HttpClient,  // Motor OkHttp
    private val authStore: AuthStore,
) {
    // Configuración:
    // - ContentNegotiation con Kotlinx JSON
    // - Auth interceptor (JWT Bearer token)
    // - Retry automático con refresh token
    // - Timeout: 30s connect, 30s read
}
```

### Endpoints del Backend Go

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/v1/auth/login` | Autenticación (retorna JWT access + refresh) |
| POST | `/api/v1/auth/register` | Registro de usuario |
| GET | `/api/v1/tasks` | Listar tareas del usuario |
| POST | `/api/v1/tasks` | Crear tarea |
| PUT | `/api/v1/tasks/:id` | Actualizar tarea |
| DELETE | `/api/v1/tasks/:id` | Eliminar tarea |
| POST | `/api/v1/pomodoro-sessions` | Registrar sesión de enfoque |
| GET | `/api/v1/pomodoro-sessions` | Listar sesiones |
| GET | `/api/v1/health` | Health check |

**Endpoints pendientes en backend:**
- `GET /api/v1/stats/daily` — Stats diarias
- `GET /api/v1/stats/weekly` — Stats semanales
- `POST /api/v1/subscriptions/verify` — Verificación de recibos Play Store
- Expandir modelo sesión: agregar campo `mode`

### Autenticación JWT

- **AuthStore**: almacena tokens en `EncryptedSharedPreferences`
- **Access Token**: JWT de corta duración para requests
- **Refresh Token**: JWT de larga duración para renovar access token
- **Auth Gate**: `MainActivity` verifica token válido al iniciar → redirige a `AuthScreen` si no existe

### Sync Engine (Offline-First)

```
┌─────────────────────────────────────────────────┐
│              Estrategia de Sync                  │
│                                                  │
│  1. On save: isDirty = true en la entidad       │
│  2. On sync: push todas las entidades dirty     │
│  3. Pull latest del backend, merge por updatedAt│
│  4. isDirty = false + syncedAt = now() si éxito │
│                                                  │
│  Resolución de conflictos: LAST-WRITE-WINS      │
│  (misma estrategia que iOS con CloudKit)        │
└─────────────────────────────────────────────────┘
```

| Tipo de Sync | Trigger | Mecanismo |
|--------------|---------|-----------|
| **Periódico** | Cada 15 minutos | `SyncWorker` vía WorkManager (`PeriodicWorkRequest`) |
| **Inmediato** | Tarea completada, sesión finalizada | `OneTimeWorkRequest` expedited |
| **Manual** | Pull-to-refresh del usuario | Llamada directa a `SyncEngine.syncAll()` |

---

## 8. Wear OS

### Arquitectura de Comunicación Phone ↔ Watch

La comunicación es **bidireccional** usando la Wearable Data Layer API:

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

### Flujos de Datos

**Phone → Watch (DataItems):**

| Path | Contenido | Frecuencia |
|------|-----------|------------|
| `/pepinillo/timer` | Estado del timer (modo, fase, elapsed, remaining, isRunning, linkedTask) | En cada tick del FocusEngine |
| `/pepinillo/tasks` | Lista de tareas activas (id, title, isCompleted, priority) | En cada cambio de tarea |
| `/pepinillo/stats` | Stats diarias (focusTime, sessions, streak, tasksCompleted) | Al completar sesión o tarea |

**Watch → Phone (Messages/Commands):**

| Path | Acción |
|------|--------|
| `/pepinillo/cmd/timer/start` | Iniciar sesión (incluye modo seleccionado) |
| `/pepinillo/cmd/timer/pause` | Pausar timer |
| `/pepinillo/cmd/timer/resume` | Reanudar timer |
| `/pepinillo/cmd/timer/stop` | Detener sesión |
| `/pepinillo/cmd/timer/skip` | Saltar fase actual |
| `/pepinillo/cmd/task/complete` | Marcar tarea como completada |
| `/pepinillo/cmd/task/link` | Vincular tarea al timer |
| `/pepinillo/cmd/task/unlink` | Desvincular tarea del timer |

### Componentes Wear OS

**WearDataRepository:**
- `StateFlow` para cada tipo de dato sincronizado (timer, tasks, stats)
- Fallback a datos locales cuando el teléfono no está conectado
- Persistencia local para acceso offline

**WearPendingCommandQueue:**
- Buffer de comandos cuando el teléfono no está disponible
- Envío automático al reconectar

**WearFocusViewModel:**
- Consume datos del `WearDataRepository`
- Motor de enfoque local como fallback
- Envía comandos vía `WearMessageSender`

### Tile (Wear OS)

```kotlin
class FocusTileService : SuspendingTileService() {
    // Basado en Horologist 0.6.20
    //
    // Layout IDLE:
    //   - Botones quick-start por modo (Pomodoro, Flow, etc.)
    //   - Streak actual
    //
    // Layout ACTIVE:
    //   - Timer display (countdown/countup)
    //   - Nombre del modo + fase
    //   - Botones: Pause/Resume, Stop
    //   - Tarea vinculada (si existe)
}
```

### Complication

```kotlin
class FocusComplicationDataSource : SuspendingComplicationDataSourceService() {
    // Tipos soportados:
    //   - SHORT_TEXT: tiempo de enfoque activo o streak actual
    //   - LONG_TEXT: "25:00 Pomodoro" o "🔥 5 días"
    //
    // Se actualiza al cambiar estado del timer o al iniciar nuevo día
}
```

---

## 9. Widgets (Glance Compose)

### Arquitectura de Widgets

Todos los widgets usan **Glance 1.1.1** con `PreferencesGlanceStateDefinition`:

```
FocusEngine ──► WidgetStateStore ──► GlanceAppWidget.update()
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
            FocusTimerWidget       DailyStatsWidget      LockScreenTimerWidget
            (Home Screen)         (Home Screen)          (Lock Screen, API 33+)
```

### FocusTimerWidget

- Muestra: modo actual, timer (countdown/countup), fase, indicador de progreso
- Botones de acción: Pause/Resume, Stop
- Estado idle: botones quick-start por modo
- Actualización: cada segundo durante sesión activa

### DailyStatsWidget

- Muestra: tiempo total de enfoque hoy, sesiones completadas, breakdown por modo, streak
- Tap abre el dashboard de la app
- Actualización: al completar sesión o tarea

### LockScreenTimerWidget

- `widgetCategory="home_screen|keyguard"` en widget info XML
- Solo disponible en Android 14+ (API 33+)
- Layout simplificado: timer y modo actual
- Permite ver el progreso sin desbloquear

### WidgetStateStore / WidgetTaskStateManager

- `WidgetStateStore`: gestiona estado del widget de timer vía `updateAppWidgetState`
- `WidgetTaskStateManager`: gestiona estado de tareas para widgets
- `CompleteTaskWorker`: ejecuta acción de completar tarea desde el widget

### Restricciones de Glance

- No soporta `stringResource()` → usar `context.getString(R.string.xxx)`
- No soporta custom state classes en `currentState<T>()` → usar `PreferencesGlanceStateDefinition` + `Preferences`
- Composables limitados vs Jetpack Compose estándar

---

## 10. Extensiones del Sistema

### Quick Settings Tile

```kotlin
class FocusTileService : TileService() {
    // Android 7+ (API 24)
    // Toggle play/pause con un tap
    // Ícono cambia según modo activo
    // Long press abre la app
    //
    // onClick() → toggle FocusEngine (start/pause/resume)
    // onStartListening() → actualiza estado desde FocusEngine
}
```

### Google Assistant App Actions

Configurado en `actions.xml` con 3 Built-In Intents (BIIs):

| BII | Voice Trigger | Acción |
|-----|---------------|--------|
| `START_EXERCISE` | "Hey Google, start Pomodoro in Pepinillo" | Inicia sesión de enfoque |
| `STOP_EXERCISE` | "Hey Google, stop focus in Pepinillo" | Detiene sesión activa |
| `GET_EXERCISE_OBSERVATION` | "Hey Google, how was my focus today?" | Muestra stats del día |

**Deep Links:** `pepinillo://focus/{start|stop|status}`

**shortcuts.xml:** 4 shortcuts estáticos (Pomodoro, Flow, Stopwatch, Tasks)

**Intent handling:** `MainActivity` con `launchMode="singleTask"` + `onNewIntent()` para recibir deep links.

### Lock Screen Widget

- Categoría KEYGUARD en widget info XML
- Disponible en Android 14+ (API 33+)
- Timer visible sin desbloquear el dispositivo

### Notificación Persistente

- Canal `IMPORTANCE_LOW` (sin sonido)
- Muestra modo, timer, fase actual
- Acciones: Pause/Resume, Skip, Stop
- Chronometer widget para modos countup
- Se actualiza cada segundo

---

## 11. IA On-Device

### Generación de Reportes de Productividad

```
┌─────────────────────┐
│  ReportDataBuilder   │ ←── Agrega datos de Room (sesiones, tareas, stats)
└──────────┬──────────┘
           │
     ┌─────▼──────┐
     │ ¿ML disp.? │
     └─────┬──────┘
      Sí   │   No
     ┌─────▼──────┐  ┌──────────────────────┐
     │ OnDevice    │  │ TemplateReport        │
     │ Report      │  │ Generator             │
     │ Generator   │  │ (fallback basado en   │
     │ (local ML)  │  │  plantillas)          │
     └─────────────┘  └──────────────────────┘
```

- **OnDeviceReportGenerator**: utiliza ML local para generar insights personalizados sobre productividad
- **TemplateReportGenerator**: fallback con plantillas predefinidas cuando ML no está disponible
- **ReportDataBuilder**: agrega y prepara datos de múltiples fuentes (sesiones, tareas, stats diarias)
- **Tipos de reportes**: semanal y mensual
- **Almacenamiento**: `ProductivityReportEntity` en Room

---

## 12. Diseño

### Sistema Visual

| Aspecto | Implementación |
|---------|----------------|
| **Design System** | Material 3 + Material You dynamic colors |
| **Temas** | 4+ temas (claro, oscuro, dynamic light, dynamic dark) |
| **Colores por Modo** | `FocusModeColors` — cada modo de enfoque tiene paleta propia |
| **Loading States** | Shimmer loading placeholders (esqueletos animados) |
| **Tipografía** | Material 3 Type Scale |
| **Íconos** | Material Symbols |

### Layouts Adaptativos

Implementados con `WindowSizeClass` de Material 3:

| WindowWidthSizeClass | Navegación | Layout |
|---------------------|------------|--------|
| **Compact** (<600dp) | `NavigationBar` (bottom) | Single-column, layouts originales |
| **Medium** (600-840dp) | `NavigationRail` (lateral izq.) | Two-pane donde aplique |
| **Expanded** (>840dp) | `PermanentNavigationDrawer` (240dp) | Multi-column completo |

**Pantallas con layout adaptativo:**

| Pantalla | Compact | Expanded (≥600dp) |
|----------|---------|-------------------|
| **FocusScreen** | Layout original | Two-pane: timer 320dp (60%) + controles (40%) |
| **TaskListScreen** | Lista con navegación a detalle | Master-detail: lista (40%) + detalle (60%) |
| **DashboardScreen** | Single-column | WeeklyChart (60%) + ModeBreakdown (40%) side-by-side |
| **SettingsScreen** | Single-column | Two-column: focus config + sound/calendar/import |

### Soporte Foldable

- **androidx.window 1.3.0** + `window-core`
- `FoldableUtils.kt` con `rememberFoldingFeature()`
- Spacer dinámico entre panes que respeta la posición del hinge
- `hingePadding.coerceAtLeast(24.dp)` para evitar contenido detrás del pliegue
- Integrado en FocusScreen y SettingsScreen

### Internacionalización

3 idiomas soportados con ~100+ strings localizados:

| Idioma | Archivo |
|--------|---------|
| Inglés (default) | `res/values/strings.xml` |
| Español | `res/values-es/strings.xml` |
| Portugués | `res/values-pt/strings.xml` |

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
    // Configuración:
    // - Android Public API Key: goog_ITPYSPEdubAzAeoNGxezZuZJELT
    // - Entitlement: "premium" (shared with iOS)
    // - Productos: monthly, annual, lifetime
    //
    // Flujo de compra:
    // 1. RevenueCat.logIn(userId) → autenticación del usuario
    // 2. RevenueCat.getPackages() → obtener ofertas disponibles
    // 3. RevenueCat.purchasePackage() → mostrar paywall
    // 4. RevenueCat.purchaserInfo → verificar entitlements
    //
    // Tiers:
    //   - FREE: funcionalidad básica (Pomodoro, tasks limitadas)
    //   - PRO: todos los modos, soundscapes, analytics avanzados, widgets
}
```

#### Product IDs
| Plan | Product ID |
|------|-----------|
| Monthly | com.pepinillo.app.pro.monthly |
| Annual | com.pepinillo.app.pro.annual |
| Lifetime | com.pepinillo.app.pro.lifetime |

#### Entitlement Verification

- **Entitlement ID:** `premium` (shared across iOS and Android)
- **Local caching:** Estado de suscripción cacheado via RevenueCat SDK
- **Server-side verification:** Backend Go integrado con RevenueCat REST API
- **Grace period:** 3 días soportados via RevenueCat
- **User identification:** Integrado con auth flow de la app

### FeatureGate

- Verifica tier de suscripción antes de permitir acceso a features PRO
- Cachea estado de suscripción localmente via RevenueCat SDK
- Verificación server-side vía backend Go (endpoint `/api/v1/webhooks/revenuecat` implementado)

---

## 14. Testing

### Estrategia de Testing

| Capa | Herramienta | Coverage Target | Estado Actual |
|------|-------------|-----------------|---------------|
| **Domain logic** | JUnit 5 | 90%+ | ~20 tests implementados |
| **ViewModels/Presenters** | Turbine + Presenter.test{} | 80%+ | Pendiente (Sprint 5) |
| **Room DAOs** | Robolectric + in-memory DB | 80%+ | Pendiente |
| **Sync engine** | JUnit 5 + MockK | 70%+ | Pendiente |
| **Compose UI** | Compose testing APIs | Key flows | Pendiente |
| **Wear OS** | Horologist testing | Basic flows | Pendiente |
| **Integration** | Hilt test + real DB | Auth + sync + timer | Pendiente |

### Tests Existentes

- `FocusStateTest` — pruebas del estado del motor de enfoque
- `GoogleTaskDtoTest` — serialización de DTOs de Google Tasks
- `GoogleImportStateTest` — estados de importación
- **Total actual:** 3 archivos de test, ~20 tests, 0 failures

### Herramientas de Calidad

| Herramienta | Propósito |
|-------------|-----------|
| **ktlint** | Formato de código Kotlin |
| **detekt** | Análisis estático (code smells, complejidad) |

---

## 15. Seguridad

| Área | Implementación |
|------|----------------|
| **Tokens de autenticación** | `EncryptedSharedPreferences` (AndroidX Security) — cifrado AES-256 |
| **Comunicación de red** | HTTPS obligatorio, clear-text traffic deshabilitado en `network_security_config.xml` |
| **Certificate pinning** | Opcional — configurado pero desactivado por defecto |
| **Base de datos local** | Room sin cifrado adicional (cifrado a nivel de dispositivo es suficiente) |
| **Ofuscación** | R8/ProGuard en builds de release (full obfuscation) |
| **Analytics** | Sin SDKs de tracking de terceros; Firebase Analytics mínimo y privacy-conscious |
| **OAuth tokens** | Google Tasks import: tokens manejados por GMS, no almacenados por la app |

---

## 16. CI/CD

| Etapa | Herramienta | Trigger | Estado |
|-------|-------------|---------|--------|
| **Lint** | ktlint + detekt | Every PR | ⬜ Pendiente (Sprint 5) |
| **Unit Tests** | JUnit 5 + Robolectric | Every PR | ⬜ Pendiente |
| **UI Tests** | Compose testing | Nightly | ⬜ Pendiente |
| **Build** | Gradle (debug + release) | Every PR | ⬜ Pendiente |
| **Signing** | Play App Signing | Release only | ⬜ Pendiente |
| **Distribution** | Firebase App Distribution | Internal track | ⬜ Pendiente |
| **Release** | Play Console (staged rollout) | Manual approval | ⬜ Pendiente |
| **Crash monitoring** | Firebase Crashlytics | Always on | ⬜ Requiere `google-services.json` |

### Pipeline Planificado (GitHub Actions)

```
PR → ktlint → detekt → assembleDebug → unit tests → ✅/❌
Release → assembleRelease → sign → Firebase App Distribution
Production → Play Console: 10% → 50% → 100%
```

---

## 17. Requisitos No-Funcionales

### Compatibilidad

| Requisito | Valor |
|-----------|-------|
| **Min SDK** | API 26 (Android 8.0 Oreo) |
| **Target SDK** | API 35 (Android 15) |
| **Wear OS Min SDK** | API 30 (Wear OS 3.0) |

### Rendimiento

| Métrica | Objetivo |
|---------|----------|
| **Cold start** | < 1.5 segundos |
| **Timer drift** | < 100ms de desviación acumulada |
| **Frame rate** | 60 FPS consistente en animaciones |
| **Memoria** | < 150MB en uso normal |

### Tamaño

| Configuración | Tamaño |
|---------------|--------|
| **APK sin soundscapes** | < 15MB |
| **APK con soundscapes** | < 30MB |
| **App Bundle (AAB)** | Optimizado por dispositivo vía Play Delivery |

### Accesibilidad

| Feature | Implementación |
|---------|----------------|
| **TalkBack** | Content descriptions en 9 pantallas |
| **Font scaling** | Soporte completo de escalado de fuentes del sistema |
| **Alto contraste** | Colores que pasan WCAG AA |
| **Reduce motion** | Respeta `Settings.Global.ANIMATOR_DURATION_SCALE` |

### Estabilidad

| Métrica | Objetivo |
|---------|----------|
| **Crash-free rate** | ≥ 99.5% |
| **ANR rate** | < 0.1% |

---

## 18. Gotchas y Decisiones Técnicas

Las siguientes son las decisiones técnicas clave tomadas durante el desarrollo, documentadas para referencia futura:

### 1. Kotlin 2.0.21 en lugar de 2.1.x
**Problema:** Hilt 2.52 no puede leer metadata generada por Kotlin 2.1.0 (limitación de APT).
**Solución:** Fijado en Kotlin **2.0.21** con KSP **2.0.21-1.0.28**. Se actualizará cuando Hilt 2.53+ sea compatible.

### 2. Circuit sin @CircuitInject KSP
**Problema:** `@CircuitInject` con KSP genera warnings y complejidad adicional.
**Solución:** Wiring manual de Presenters en `AppModule.provideCircuit()` con `@AssistedInject` + `@AssistedFactory`.

### 3. Glance: PreferencesGlanceStateDefinition obligatorio
**Problema:** `currentState<T>()` con clases custom causa crashes en Glance.
**Solución:** Usar `PreferencesGlanceStateDefinition` + `Preferences` estándar para todo estado de widgets.

### 4. Glance: no soporta stringResource()
**Problema:** `stringResource()` no funciona en composables de Glance.
**Solución:** Usar `context.getString(R.string.xxx)` directamente.

### 5. Firebase condicionado a google-services.json
**Problema:** Build falla si Firebase plugins están activos sin `google-services.json`.
**Solución:** Plugins de Firebase comentados en `build.gradle.kts`. Activar manualmente al agregar el archivo.

### 6. Health Connect API experimental
**Problema:** `MindfulnessSessionRecord` y APIs de deduplicación son experimentales.
**Solución:** `@OptIn(ExperimentalMindfulnessSessionApi, ExperimentalDeduplicationApi)` donde se usen.

### 7. Foreground Service en Android 14+
**Problema:** Android 14 requiere declarar tipo de foreground service y justificación.
**Solución:** `FOREGROUND_SERVICE_SPECIAL_USE` + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` en Manifest con valor `"focus_timer"`.

### 8. libs.versions.toml carga automática
**Problema:** Gradle 8 auto-descubre el version catalog; usar `from()` en `settings.gradle.kts` causa carga duplicada.
**Solución:** NO usar `from()` — Gradle lo detecta automáticamente.

### 9. kotlin-parcelize sin versión
**Problema:** Especificar versión de `kotlin-parcelize` causa conflicto.
**Solución:** `id("kotlin-parcelize")` sin versión — viene bundled con el plugin de Kotlin.

### 10. Destructuring con >5 componentes
**Problema:** Kotlin no soporta destructuring con más de 5 componentes en `val (a,b,c,d,e,f) = ...`.
**Solución:** Usar `when(state)` con asignaciones explícitas en lugar de destructuring.

### 11. roundIcon sin mipmap causa AAPT fail
**Problema:** `android:roundIcon` referenciando un mipmap inexistente causa error de AAPT.
**Solución:** Removido `android:roundIcon` del `<application>` tag en AndroidManifest.

### 12. SoundscapePlayer con assets faltantes
**Problema:** ExoPlayer crashea si el archivo de audio no existe.
**Solución:** `Player.Listener.onPlayerError` emite `ERROR` en StateFlow; UI muestra mensaje de error + spinner en lugar de crash.

### 13. Google Tasks import requiere OAuth Client ID
**Problema:** `GoogleTasksImportManager.getSignInIntent()` funciona en debug, pero producción requiere OAuth 2.0 Client ID configurado.
**Solución:** Para producción: crear OAuth 2.0 Client ID (tipo Android) en Google Cloud Console y agregar SHA-1 del release keystore.

### 14. Lock Screen Widget solo Android 14+
**Problema:** Widgets en lock screen requieren API 33+.
**Solución:** `widgetCategory="home_screen|keyguard"` en widget info XML. Degradación graceful en versiones anteriores.

### 15. Adaptive Layouts con Circuit
**Problema:** Circuit no propaga fácilmente `WindowSizeClass` a través de su stack de navegación.
**Solución:** `BoxWithConstraints` local en cada screen; branching en `maxWidth >= 600.dp` sin depender de Circuit.

### 16. NavigationRail vs BottomBar
**Problema:** Decidir cuándo mostrar cada tipo de navegación.
**Solución:** `calculateWindowSizeClass(activity)` en `setContent{}`, pasar `widthSizeClass` a `MainScaffold`. Compact→Bottom, Medium→Rail, Expanded→Drawer.

### 17. App Actions deep links
**Problema:** Deep links de Google Assistant requieren `singleTask` para funcionar con `onNewIntent`.
**Solución:** `android:launchMode="singleTask"` en MainActivity + scheme `pepinillo://focus/{start|stop|status}`.

### 18. WorkManager con Hilt
**Problema:** Workers necesitan inyección de dependencias pero no soportan `@Inject` estándar.
**Solución:** `@HiltWorker` + `hilt-work 1.2.0`; `PepinilloApp implements Configuration.Provider` para inicialización custom de WorkManager.

---

## 19. Backend e Integración con Servidor

### 19.1 Visión General del Backend Go

El backend de Pepinillo es una API REST escrita en **Go** con arquitectura hexagonal. Aún **no está desplegado** en producción — se encuentra en desarrollo activo en `backend/`.

| Aspecto | Tecnología |
|---------|------------|
| **Lenguaje** | Go |
| **Framework HTTP** | Fiber |
| **Base de datos** | PostgreSQL |
| **Autenticación** | JWT (access + refresh tokens) |
| **Arquitectura** | Hexagonal (puertos y adaptadores) |
| **Estado** | En desarrollo, no desplegado |

#### Grupos de Endpoints

| Grupo | Endpoints | Descripción |
|-------|-----------|-------------|
| **Auth** | `POST /auth/login`, `POST /auth/register`, `POST /auth/google`, `POST /auth/apple` | Autenticación por email/password + OAuth (Google/Apple) |
| **Tasks** | `GET/POST/PUT/DELETE /api/v1/tasks` | CRUD de tareas |
| **Sessions** | `GET/POST /api/v1/pomodoro-sessions` | Registro y consulta de sesiones de enfoque |
| **Stats** | `GET /api/v1/stats/daily`, `GET /api/v1/stats/weekly` | Estadísticas agregadas (pendiente) |
| **Billing** | `POST /api/v1/billing/verify-receipt` | Verificación server-side de recibos (Play Store y App Store) |
| **Push** | `POST /api/v1/push/register` | Registro de tokens FCM para notificaciones push |
| **WebSocket** | `WS /api/v1/ws` | Canal de sincronización en tiempo real |
| **AI** | `POST /api/v1/ai/report` | Generación de reportes de productividad |
| **Users** | `GET /api/v1/users/me`, `PUT /api/v1/users/me` | Perfil del usuario |

#### Modelo de Usuario en Backend

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

### 19.2 Flujo de Autenticación

Android utiliza **Google Sign-In** como método principal de autenticación, con email/password como alternativa.

#### Google Sign-In (método principal)

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│   Android    │     │  Google Identity  │     │  Backend Go  │
│   App        │     │  Services         │     │              │
│              │     │                   │     │              │
│ 1. Credential│────►│ 2. Autenticación  │     │              │
│    Manager   │     │    con Google     │     │              │
│              │◄────│ 3. idToken (JWT)  │     │              │
│              │     │                   │     │              │
│ 4. POST      │────────────────────────────►│ 5. Verifica   │
│    /auth/    │     │                   │     │    idToken    │
│    google    │     │                   │     │    con Google │
│              │◄────────────────────────────│ 6. JWT access │
│              │     │                   │     │    + refresh  │
│ 7. Almacena  │     │                   │     │              │
│    en Auth   │     │                   │     │              │
│    Store     │     │                   │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘
```

**Pasos detallados:**

1. El usuario toca "Continuar con Google" en `AuthScreen`
2. Se invoca **Credential Manager** (`androidx.credentials`) para obtener una `GoogleIdTokenCredential`
3. Google retorna un `idToken` (JWT firmado por Google)
4. La app envía `POST /auth/google` con el `idToken` en el body
5. El backend valida el `idToken` contra los servidores de Google, extrae email/nombre/foto
6. Si el usuario no existe, lo crea; retorna JWT (access + refresh token) de Pepinillo
7. Los tokens se almacenan en `AuthStore` (basado en `EncryptedSharedPreferences`, cifrado AES-256)

#### Email/Password (alternativa)

- `POST /auth/register` → crea cuenta con email + password
- `POST /auth/login` → retorna JWT access + refresh tokens
- Tokens almacenados en `AuthStore` igual que con Google Sign-In

#### Gestión de Tokens

| Token | Almacenamiento | Duración | Renovación |
|-------|---------------|----------|------------|
| **Access Token** | `AuthStore` (EncryptedSharedPreferences) | Corta (15-30 min) | Automática vía refresh token |
| **Refresh Token** | `AuthStore` (EncryptedSharedPreferences) | Larga (30 días) | Requiere re-login al expirar |

El `PepinilloApiClient` (Ktor) incluye un interceptor de autenticación que:
- Adjunta el access token como `Authorization: Bearer <token>` en cada request
- Detecta respuestas `401 Unauthorized`
- Intenta renovar el access token usando el refresh token
- Si la renovación falla, redirige al usuario a `AuthScreen`

### 19.3 Estrategia de Sincronización Cloud

El backend Go es la **fuente de verdad** para datos cross-platform. La sincronización es bidireccional con resolución last-write-wins.

#### Arquitectura de Sync

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
              │   PostgreSQL (fuente de      │
              │   verdad cross-platform)     │
              └──────────────────────────────┘
```

#### Flujo de Sincronización

| Paso | Dirección | Descripción |
|------|-----------|-------------|
| 1. Escritura local | — | El usuario crea/edita/elimina → Room guarda con `isDirty = true` |
| 2. Push (upload) | App → Backend | `SyncEngine` envía todas las entidades con `isDirty = true` al backend |
| 3. Pull (download) | Backend → App | `SyncEngine` consulta el backend por cambios desde `syncedAt` |
| 4. Merge | — | Resolución last-write-wins basada en `updatedAt` |
| 5. Mark synced | — | Entidades sincronizadas: `isDirty = false`, `syncedAt = now()` |

#### Triggers de Sincronización

| Tipo | Trigger | Mecanismo | Latencia |
|------|---------|-----------|----------|
| **Tiempo real** | Cambio remoto (otro dispositivo) | WebSocket push desde backend | ~1 segundo |
| **Inmediato** | Tarea completada, sesión finalizada | `OneTimeWorkRequest` expedited | ~2-5 segundos |
| **Periódico** | Cada 15 minutos | `PeriodicWorkRequest` vía WorkManager | ≤ 15 minutos |
| **Manual** | Pull-to-refresh del usuario | `SyncEngine.syncAll()` directo | Inmediato |

#### WebSocket (Sincronización en Tiempo Real)

El backend expone `WS /api/v1/ws` para notificar a los dispositivos conectados sobre cambios remotos:

- Al conectar, el cliente envía su JWT para autenticarse
- El backend emite eventos cuando otro dispositivo del mismo usuario modifica datos
- El cliente recibe el evento y ejecuta un pull selectivo de los datos modificados
- Reconexión automática con backoff exponencial si se pierde la conexión

#### WorkManager Fallback

`SyncWorker` actúa como red de seguridad cuando el WebSocket no está disponible:

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

- **Periódico:** `PeriodicWorkRequestBuilder<SyncWorker>(15, MINUTES)` con constraint `NetworkType.CONNECTED`
- **Inmediato:** `OneTimeWorkRequestBuilder<SyncWorker>().setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)` tras acciones del usuario

### 19.4 Suscripciones Cross-Platform

Las suscripciones se verifican **server-side** para garantizar paridad entre plataformas. Un usuario que compra PRO en Android puede usar PRO en iOS y viceversa.

#### Flujo de Verificación

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Android    │     │  Backend Go  │     │  Google Play  │
│              │     │              │     │  Developer    │
│ 1. Usuario   │     │              │     │  API          │
│    compra    │     │              │     │              │
│    en Play   │     │              │     │              │
│    Store     │     │              │     │              │
│              │     │              │     │              │
│ 2. POST      │────►│ 3. Valida    │────►│ 4. Verifica  │
│    /billing/ │     │    recibo    │     │    compra    │
│    verify-   │     │    con Play  │◄────│ 5. Confirma  │
│    receipt   │     │    API       │     │    válido    │
│              │     │              │     │              │
│              │◄────│ 6. Actualiza │     │              │
│              │     │    user.sub  │     │              │
│ 7. Cachea    │     │    tier=pro  │     │              │
│    PRO local │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Pasos detallados:**

1. El usuario completa la compra vía Play Billing Library 7.1.1
2. La app envía `POST /api/v1/billing/verify-receipt` con el token de compra y el product ID
3. El backend valida el recibo contra la Google Play Developer API
4-5. Google confirma que la compra es legítima
6. El backend actualiza `User.SubscriptionTier = "pro"` en PostgreSQL
7. La app cachea el estado PRO localmente; todas las verificaciones futuras consultan `GET /api/v1/users/me`

**Fuente de verdad:** El campo `subscription_tier` del backend. La app consulta `/users/me` al iniciar y periódicamente para sincronizar el estado de suscripción. El `BillingManager` local actúa como cache.

**Paridad cross-platform:** Un usuario que compra PRO en iOS (App Store) verá su estado PRO reflejado en Android al hacer login, porque el backend centraliza el tier.

### 19.5 Perfil de Usuario

El perfil de usuario combina datos de autenticación, estadísticas y suscripción.

#### Modelo de Datos del Perfil

| Campo | Origen | Descripción |
|-------|--------|-------------|
| `name` | Backend (`User.Name`) | Nombre para mostrar (de Google/Apple o manual) |
| `email` | Backend (`User.Email`) | Email de la cuenta |
| `avatarUrl` | Backend (`User.ImageURL`) | Foto de perfil (URL de Google/Apple) |
| `subscriptionTier` | Backend (`User.SubscriptionTier`) | `"free"` o `"pro"` |
| `subscriptionExpiresAt` | Backend | Fecha de vencimiento de suscripción PRO |
| `linkedAccounts` | Backend | Proveedores vinculados: Google, Apple, email |
| `emailVerified` | Backend (`User.EmailVerified`) | Si el email está verificado |
| `memberSince` | Backend (`User.CreatedAt`) | Fecha de registro |

#### Estadísticas del Perfil (calculadas)

| Estadística | Cálculo | Fuente |
|-------------|---------|--------|
| **Racha actual** | Días consecutivos con al menos una sesión | `StatsDao.getStreakCount()` (CTE recursivo) |
| **Horas totales de enfoque** | Suma de `totalFocusSeconds` de todos los `DailyStatsEntity` | Room local |
| **Sesiones completadas** | Suma de `sessionsCompleted` de todos los `DailyStatsEntity` | Room local |
| **Tareas completadas** | Conteo de `TaskEntity` con `isCompleted = true` | Room local |
| **Modo dominante** | Modo con más segundos totales | Cálculo sobre `DailyStatsEntity` |

#### Pantalla de Perfil

La pantalla de perfil (`ProfileScreen`) muestra:

- **Header:** Avatar, nombre, email, badge PRO/FREE
- **Estadísticas:** Racha, horas totales, sesiones, tareas completadas, miembro desde
- **Cuenta:** Cuentas vinculadas (Google, Apple, email), opción de vincular/desvincular
- **Suscripción:** Estado actual, fecha de vencimiento, botón de gestionar/upgrade
- **Acciones:** Cerrar sesión, eliminar cuenta
