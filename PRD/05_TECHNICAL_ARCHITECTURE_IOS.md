# Arquitectura Tecnica: Pepinillo iOS / watchOS

**Fecha:** Marzo 2026
**Plataformas:** iOS 17+ / iPadOS 17+ / macOS 14+ (Catalyst) / watchOS 10+
**Lenguaje:** Swift 6 (strict concurrency)
**Framework UI:** SwiftUI
**Arquitectura:** The Composable Architecture (TCA) by Point-Free

---

## 1. Stack Tecnologico

| Capa | Tecnologia | Version minima |
|------|-----------|----------------|
| Lenguaje | Swift 6 (strict concurrency) | Xcode 16+ |
| UI | SwiftUI | iOS 17 / watchOS 10 |
| Arquitectura | TCA (swift-composable-architecture) | 1.17+ |
| Persistencia | SwiftData + CloudKit | iOS 17 |
| Sincronizacion | NSPersistentCloudKitContainer | iOS 17 |
| Widgets | WidgetKit | iOS 17 |
| Dynamic Island | ActivityKit | iOS 16.1+ |
| Siri / Shortcuts | App Intents | iOS 17 |
| Watch | WatchConnectivity (WCSession) | watchOS 10 |
| Control Center | ControlWidget | iOS 18 |
| IA On-Device | Apple Foundation Models | iOS 26 |
| Salud | HealthKit (Mindful Minutes) | iOS 17 |
| Analytics | TelemetryDeck | -- |
| Sonido | AVAudioEngine | iOS 17 |
| Autenticacion | Sign in with Apple | iOS 17 |
| Suscripciones | RevenueCat SDK v5+ (wrapping StoreKit 2) | iOS 17 |

### Decisiones clave

- **RevenueCat SDK v5+:** Wraps StoreKit 2 nativo para manejo centralizado de suscripciones, entitlements, y webhooks. Soporta 3 productos (mensual, anual, lifetime) con entitlement unificado `pro`.
- **Sin Firebase:** CloudKit privado para datos, TelemetryDeck para analytics anonimos, Sign in with Apple para autenticacion.
- **Swift 6 strict concurrency:** Todo el codigo compila bajo el modo estricto de concurrencia. Los actores (`FocusEngine`, `SoundscapeManager`, `SubscriptionManager`) garantizan seguridad de hilos sin locks manuales.

---

## 2. Arquitectura -- TCA (The Composable Architecture)

### Por que TCA

TCA fue elegido sobre MVVM, VIPER y Clean Architecture por las siguientes razones:

1. **Flujo de datos unidireccional** -- estado predecible, ideal para una app de temporizador con estados complejos (ejecutando, pausado, descanso, interrupcion, transicion de fase).
2. **Gestion de efectos secundarios integrada** -- perfecto para ticks del temporizador, notificaciones, sincronizacion CloudKit, conectividad Watch y Live Activities.
3. **Testabilidad** -- cada reducer es una funcion pura; cada efecto es inyectable y testeable con `TestStore`.
4. **Composabilidad** -- los features se componen en features padres, reflejando la estructura modular de Pepinillo.
5. **Mantenimiento activo** -- Point-Free lo mantiene activamente, documentacion extensa, compatible con Swift 6.

### Patron fundamental

```
Vista (SwiftUI) --[envia Action]--> Reducer --[produce State + Effect]--> Vista (re-render)
                                       |
                                       v
                                   Effect --[operacion asincrona]--> Reducer (recibe Action de respuesta)
```

Cada feature sigue este patron:

```swift
@Reducer
struct MiFeature {
    @ObservableState
    struct State: Equatable { /* estado observable */ }

    enum Action: Equatable { /* acciones del usuario + respuestas del sistema */ }

    @Dependency(\.miClient) var miClient  // dependencias inyectables

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .botonTapped:
                state.isLoading = true
                return .run { send in
                    let resultado = await miClient.operacion()
                    await send(.resultadoRecibido(resultado))
                }
            case .resultadoRecibido(let data):
                state.isLoading = false
                state.data = data
                return .none
            }
        }
    }
}
```

Las vistas usan `@Bindable var store: StoreOf<MiFeature>` y envian acciones al store. Nunca mutan estado directamente.

---

## 3. Estructura del Proyecto

```
ios/
├── App/
│   ├── PepinilloApp.swift              # @main, creacion del Store raiz, ModelContainer
│   ├── AppFeature.swift                # Reducer raiz: coordina tabs, Watch listener, auth
│   ├── AppView.swift                   # Vista raiz con TabView / NavigationSplitView
│   ├── DrawerView.swift                # Drawer lateral (iPad/Mac)
│   ├── iPadSplitView.swift             # Layout adaptativo iPad Split View + Stage Manager
│   ├── MacCommands.swift               # Comandos de menu para Mac (Catalyst)
│   └── DemoDataSeeder.swift            # Datos de demo para previews y testing
│
├── Domain/
│   ├── Models/                         # Clases SwiftData @Model
│   │   ├── TaskItem.swift              # Tarea del usuario (ver seccion 4)
│   │   ├── FocusSessionRecord.swift    # Registro de sesion completada/abandonada
│   │   ├── DailyStats.swift            # Estadisticas diarias agregadas
│   │   ├── ProductivityReport.swift    # Reporte IA cacheado (semanal/mensual)
│   │   ├── UserPreferences.swift       # Preferencias del usuario
│   │   ├── Achievement.swift           # Logros / badges con progreso
│   │   └── SubTask.swift               # Subtareas de una TaskItem
│   │
│   ├── Clients/                        # TCA @DependencyClient (ver seccion 6)
│   │   ├── PersistenceClient.swift     # CRUD SwiftData con DTOs Sendable
│   │   ├── FocusClient.swift           # Puente TCA <-> FocusEngine actor
│   │   ├── WatchConnectivityClient.swift  # WCSession bidireccional
│   │   ├── AIReportClient.swift        # Generacion de reportes IA
│   │   ├── NotificationClient.swift    # UNUserNotificationCenter
│   │   ├── SubscriptionClient.swift    # RevenueCat SDK v5+ (wrapping StoreKit 2)
│   │   ├── SoundscapeClient.swift      # Reproduccion de sonidos ambiente
│   │   ├── CalendarClient.swift        # EventKit (lectura de calendario)
│   │   ├── HealthClient.swift          # HealthKit Mindful Minutes
│   │   ├── SignInWithAppleClient.swift  # Autenticacion Apple
│   │   ├── SpotlightClient.swift       # CoreSpotlight indexing
│   │   └── LiveActivityClient.swift    # ActivityKit (Dynamic Island)
│   │
│   └── Services/                       # Logica de negocio pura (ver seccion 7)
│       ├── ModeIntelligenceService.swift     # Sugerencia de modo basada en historial
│       ├── InsightsService.swift             # Calculo de insights y tendencias
│       ├── OnDeviceReportGenerator.swift     # Apple Foundation Models (iOS 26+)
│       ├── TemplateReportGenerator.swift     # Fallback basado en plantillas
│       ├── ReportDataBuilder.swift           # Construccion del payload para reportes
│       ├── WeeklyReportService.swift         # Orquestacion de reportes semanales
│       └── RemindersImportService.swift      # Importacion desde Apple Reminders
│
├── Features/
│   ├── Focus/
│   │   ├── FocusFeature.swift          # Reducer: orquesta los 4 modos
│   │   ├── FocusView.swift             # Vista principal con selector de modo
│   │   ├── FocusEngine.swift           # Actor: temporizador unificado (ver seccion 5)
│   │   ├── FocusModels.swift           # FocusMode, FocusPhase, FocusConfig, etc.
│   │   ├── FocusModeProtocol.swift     # Protocolo Strategy
│   │   ├── TaskPickerView.swift        # Picker de tarea para vincular a sesion
│   │   ├── SessionJournalFeature.swift # Diario post-sesion (nota + satisfaccion)
│   │   ├── SessionJournalView.swift    # Vista del diario
│   │   ├── ModeIntelligenceBanner.swift # Banner de sugerencia de modo
│   │   ├── SoundscapePickerView.swift  # Selector de sonido ambiente
│   │   ├── ADHDBreakView.swift         # Vista de descanso ADHD-friendly
│   │   └── Modes/
│   │       ├── PomodoroStrategy.swift  # 25/5/15 con ciclos configurables
│   │       ├── FlowtimeStrategy.swift  # Abierto + calculo dinamico de descanso
│   │       ├── TimeBlockStrategy.swift # Bloque fijo con check-in opcional
│   │       └── StopwatchStrategy.swift # Conteo ascendente sin objetivo
│   │
│   ├── Tasks/
│   │   ├── TaskListFeature.swift       # Reducer: CRUD, filtros, ordenamiento, recurrencia
│   │   ├── TaskListView.swift          # Lista de tareas con filtros de energia
│   │   ├── TaskDetailFeature.swift     # Reducer: edicion de tarea individual
│   │   └── TaskDetailView.swift        # Vista de detalle/edicion
│   │
│   ├── Analytics/
│   │   ├── AnalyticsFeature.swift      # Reducer: dashboard de productividad
│   │   ├── AnalyticsView.swift         # Graficos por modo, tendencias
│   │   ├── WeeklyReviewFeature.swift   # Reducer: revision semanal comparativa
│   │   ├── WeeklyReviewView.swift      # Comparativa semana vs semana
│   │   ├── MonthlyReviewFeature.swift  # Reducer: revision mensual
│   │   ├── MonthlyReviewView.swift     # Vista de revision mensual
│   │   ├── AIReportFeature.swift       # Reducer: generacion de reportes IA
│   │   ├── AIReportView.swift          # Vista del reporte IA
│   │   ├── TaskAnalyticsFeature.swift  # Reducer: analytics por tarea
│   │   ├── TaskAnalyticsView.swift     # Tiempo de foco por tarea
│   │   └── AchievementsView.swift      # Vista de logros/badges
│   │
│   ├── Calendar/
│   │   ├── CalendarFeature.swift       # Reducer: integracion calendario
│   │   └── CalendarView.swift          # Vista de calendario con sesiones
│   │
│   ├── Settings/
│   │   ├── SettingsFeature.swift       # Reducer: configuracion global
│   │   ├── SettingsView.swift          # Vista de ajustes
│   │   ├── AboutFeature.swift          # Reducer: acerca de / legal
│   │   └── AboutView.swift             # Vista acerca de
│   │
│   ├── Paywall/
│   │   ├── PaywallFeature.swift        # Reducer: suscripcion con RevenueCat
│   │   └── PaywallView.swift           # Vista del paywall
│   │
│   └── Onboarding/
│       └── OnboardingView.swift        # Flujo de onboarding
│
├── Shared/
│   ├── Design/
│   │   ├── AppTheme.swift              # 4 temas: Classic, Forest, Ocean, Sunset
│   │   ├── ModeColors.swift            # Colores de acento por modo de foco
│   │   ├── GlassModifier.swift         # Efectos glassmorphism
│   │   ├── HapticManager.swift         # Retroalimentacion haptica
│   │   ├── CelebrationView.swift       # Animaciones de celebracion
│   │   └── iPadSheetModifier.swift     # Modificador de sheets para iPad
│   │
│   ├── Extensions/
│   │   ├── Date+Extensions.swift       # Extensiones de Date
│   │   ├── Duration+Formatting.swift   # Formateo de duracion (mm:ss, hh:mm)
│   │   ├── ConditionalAnimation.swift  # Animaciones condicionales (Reduce Motion)
│   │   └── PressableButtonStyle.swift  # Estilo de boton con feedback tactil
│   │
│   ├── Sounds/
│   │   └── SoundscapeManager.swift     # Actor: AVAudioEngine para sonidos ambiente
│   │
│   ├── HandoffActivity.swift           # Soporte Handoff entre dispositivos
│   └── NotificationDelegate.swift      # UNUserNotificationCenterDelegate
│
├── PepinilloWatch/                     # watchOS companion app
│   ├── PepinilloWatchApp.swift         # @main entry point watchOS
│   ├── Features/
│   │   └── WatchDashboardFeature.swift # TCA: timer + tareas + dashboard
│   └── Views/
│       └── WatchDashboardView.swift    # Vista principal del Watch
│
├── PepinilloWidget/                    # WidgetKit (home + lock screen)
│   ├── FocusWidget.swift               # Widget de sesion de foco activa
│   ├── FocusWidgetProvider.swift       # TimelineProvider para foco
│   ├── FocusWidgetViews.swift          # Vistas small/medium/large
│   ├── FocusWidgetModels.swift         # Modelos del widget
│   ├── TasksWidget.swift              # Widget de lista de tareas
│   ├── TasksWidgetProvider.swift       # TimelineProvider para tareas
│   ├── TasksWidgetViews.swift          # Vistas de tareas
│   ├── DashboardWidget.swift          # Widget de dashboard diario
│   ├── DashboardWidgetProvider.swift   # TimelineProvider para dashboard
│   ├── DashboardWidgetViews.swift      # Vistas de dashboard
│   └── WidgetIntents.swift             # Configuracion interactiva de widgets
│
├── PepinilloLiveActivity/             # Dynamic Island + Live Activity
│   ├── FocusLiveActivityWidget.swift   # Widget de Live Activity
│   ├── FocusLiveActivityView.swift     # Vistas del Dynamic Island
│   ├── FocusActivityAttributes.swift   # Atributos de la actividad
│   └── LiveActivityManager.swift       # Gestion del ciclo de vida
│
├── PepinilloIntents/                   # App Intents (Siri)
│   ├── StartFocusIntent.swift          # "Start deep work in Pepinillo"
│   ├── PauseFocusIntent.swift          # "Pause my focus session"
│   ├── CheckStatsIntent.swift          # "How much did I focus today?"
│   ├── GetInsightsIntent.swift         # "Show my productivity insights"
│   ├── GetModeSuggestionIntent.swift   # "Which mode should I use?"
│   ├── GetWeeklyReportIntent.swift     # "Show my weekly report"
│   └── FocusFilterIntent.swift         # Integracion con Focus Modes del sistema
│
├── ControlCenterExtension/            # iOS 18+ Control Center widget
│   └── PepinilloControlCenter.swift    # ControlWidgetToggle: iniciar/detener sesion
│
├── Tests/
│   ├── FocusFeatureTests/
│   │   ├── FocusFeatureReducerTests.swift    # Tests del reducer de foco
│   │   ├── FocusModeStrategyTests.swift      # Tests de las 4 estrategias
│   │   └── SessionJournalFeatureTests.swift  # Tests del diario post-sesion
│   ├── TaskFeatureTests/
│   │   └── TaskListFeatureTests.swift        # Tests CRUD de tareas
│   ├── AnalyticsFeatureTests/
│   │   ├── AnalyticsFeatureTests.swift       # Tests de analytics
│   │   └── InsightsServiceTests.swift        # Tests del servicio de insights
│   ├── PaywallFeatureTests/
│   │   └── PaywallFeatureTests.swift         # Tests del paywall
│   ├── ModeIntelligenceTests/
│   │   └── ModeIntelligenceTests.swift       # Tests de sugerencia de modo
│   ├── SiriIntentsTests/
│   │   └── SiriIntentsTests.swift            # Tests de intents
│   ├── WidgetTests/
│   │   └── FocusWidgetProviderTests.swift    # Tests del timeline provider
│   ├── WatchFeatureTests/
│   │   └── WatchTimerFeatureTests.swift      # Tests del Watch
│   └── IntegrationTests/
│       └── AppFeatureIntegrationTests.swift  # Tests de integracion
│
└── Package.swift                       # Dependencias SPM
```

---

## 4. Modelos de Datos (SwiftData)

Todos los modelos usan el macro `@Model` de SwiftData y se sincronizan automaticamente via CloudKit (base de datos privada). El contenedor compartido via App Group (`group.com.pepinillo.app`) permite acceso desde widgets, intents y la app del Watch.

### 4.1 TaskItem

Tarea del usuario. Soporta recurrencia, niveles de energia, vinculacion con sesiones de foco y subtareas.

```swift
@Model
public final class TaskItem {
    // Identificacion
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date

    // Contenido
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var completedAt: Date?

    // Organizacion
    public var priority: TaskPriority        // .none(0), .low(1), .medium(2), .high(3)
    public var sortOrder: Int
    public var energyLevel: EnergyLevel      // .deep, .shallow, .admin
    public var dueDate: Date?
    public var scheduledForToday: Bool

    // Integracion con foco
    public var estimatedPomodoros: Int
    public var completedPomodoros: Int
    public var preferredMode: String?        // FocusMode.rawValue sugerido por ModeIntelligence

    // Recurrencia (iCalendar RRULE)
    public var recurrenceRule: String?        // ej: "FREQ=DAILY", "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    public var nextOccurrence: Date?
    public var isRecurringTemplate: Bool
    public var recurringTemplateID: UUID?     // para instancias generadas

    // Relaciones
    @Relationship(deleteRule: .cascade) var subtasks: [SubTask]
    @Relationship(inverse: \FocusSessionRecord.task) var sessions: [FocusSessionRecord]

    // Computed
    var totalFocusTime: TimeInterval         // suma de sesiones completadas
    var completionPercentage: Double          // completedPomodoros / estimatedPomodoros
    var subtaskProgress: (completed: Int, total: Int)
}
```

**Enums de soporte:**
- `TaskPriority`: `.none(0)`, `.low(1)`, `.medium(2)`, `.high(3)` -- `Codable, Comparable`
- `EnergyLevel`: `.deep`, `.shallow`, `.admin` -- clasificacion de trabajo profundo (Cal Newport)
- `RecurrencePreset`: `.daily`, `.weekdays`, `.weekly`, `.biweekly`, `.monthly` -- presets de recurrencia con calculo de siguiente fecha

### 4.2 FocusSessionRecord

Registro persistido de una sesion de foco completada o abandonada. Un registro por cada sesion.

```swift
@Model
public final class FocusSessionRecord {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?

    // Modo y fase
    public var mode: String                  // "pomodoro", "flowtime", "timeBlock", "stopwatch"
    public var phase: String                 // "work", "shortBreak", "longBreak", "flow", "block", "freeform"

    // Duracion
    public var targetDuration: TimeInterval? // nil para Flowtime/Stopwatch
    public var actualDuration: TimeInterval  // tiempo real de foco

    // Completitud
    public var wasCompleted: Bool            // completo naturalmente vs abandonado
    public var interruptions: Int

    // Pausas
    public var pauseCount: Int
    public var totalPauseDuration: TimeInterval

    // Pomodoro-especifico
    public var pomodoroNumber: Int?          // ej: 3 (de 4)

    // Diario post-sesion
    public var journalNote: String?
    public var satisfactionRating: Int?      // 1-5 (emoji-based)

    // Relacion
    public var task: TaskItem?
}
```

### 4.3 DailyStats

Estadisticas diarias agregadas. Un registro por dia. Incluye desglose por modo para analytics unicos.

```swift
@Model
public final class DailyStats {
    public var id: UUID
    public var date: Date                    // normalizado a medianoche

    // Totales
    public var totalFocusSeconds: Int
    public var sessionsCompleted: Int
    public var tasksCompleted: Int
    public var longestStreak: Int            // sesiones consecutivas sin interrupcion

    // Desglose por modo (segundos + conteo)
    public var pomodoroSeconds: Int
    public var flowtimeSeconds: Int
    public var timeBlockSeconds: Int
    public var stopwatchSeconds: Int
    public var pomodoroCount: Int
    public var flowtimeCount: Int
    public var timeBlockCount: Int
    public var stopwatchCount: Int

    // Racha
    public var hadFocusSession: Bool         // se enfoco al menos una vez hoy

    // Computed
    var totalFocusMinutes: Int
    var totalFocusHours: Double
    var dominantMode: FocusMode?             // modo con mas segundos
    var modeDistribution: [FocusMode: Double] // porcentajes
}
```

### 4.4 ProductivityReport

Reporte de productividad generado por IA (o plantilla fallback), cacheado en SwiftData.

```swift
@Model
public final class ProductivityReport {
    public var id: UUID
    public var period: String                // "week" o "month"
    public var periodStart: Date
    public var periodEnd: Date
    public var generatedAt: Date
    public var title: String
    public var highlightsJSON: String         // JSON [String]
    public var insightsJSON: String           // JSON [ReportInsight]
    public var recommendationsJSON: String    // JSON [String]
    public var rawPayload: String            // JSON del payload enviado a IA (debug)
}
```

**Tipos de soporte:**
- `ReportInsight`: `{ category: "pattern"|"improvement"|"achievement", text: String }`
- `AIReportResponse`: DTO para la respuesta del generador de reportes
- `ProductivityReportDTO`: struct `Sendable` para cruzar fronteras de concurrencia

### 4.5 UserPreferences

Preferencias del usuario sincronizadas via CloudKit. Un unico registro por usuario.

```swift
@Model
public final class UserPreferences {
    public var id: UUID

    // Configuracion de Pomodoro
    public var pomodoroDuration: TimeInterval       // default: 25 min
    public var shortBreakDuration: TimeInterval      // default: 5 min
    public var longBreakDuration: TimeInterval       // default: 15 min
    public var pomodorosPerCycle: Int                 // default: 4
    public var autoStartBreaks: Bool                  // default: true
    public var autoStartWork: Bool                    // default: false

    // Configuracion de Time Block
    public var defaultBlockDuration: TimeInterval    // default: 60 min
    public var blockMidpointCheckIn: Bool             // default: false

    // Configuracion de Flowtime
    public var flowtimeMinSessionMinutes: Int         // default: 5
    public var flowtimeShowBreakSuggestion: Bool      // default: true

    // General
    public var soundEnabled: Bool
    public var hapticEnabled: Bool
    public var keepScreenOn: Bool
    public var defaultMode: String                   // FocusMode.rawValue

    // Tema
    public var themeName: String                     // "default", "forest", "ocean", "sunset"
    public var followSystemAppearance: Bool

    // Notificaciones
    public var dailyReminderEnabled: Bool
    public var dailyReminderHour: Int                // 0-23
    public var dailyReminderMinute: Int              // 0-59

    // Onboarding
    public var hasCompletedOnboarding: Bool

    // Racha
    public var currentStreakDays: Int
    public var longestStreakDays: Int
    public var lastFocusDate: Date?

    // Apple Health
    public var healthLoggingEnabled: Bool

    // Suscripcion (cache local -- fuente de verdad es StoreKit)
    public var isProUser: Bool
    public var subscriptionExpiresAt: Date?

    // Modo ADHD-friendly
    public var adhdFriendlyEnabled: Bool

    // Calendario
    public var calendarIntegrationEnabled: Bool

    // Sign in with Apple
    public var appleUserID: String?
    public var displayName: String?
    public var userEmail: String?

    // Computed
    var focusConfig: FocusConfig                     // convierte a value type para el FocusEngine
}
```

### 4.6 Achievement

Logros predefinidos con seguimiento de progreso. Enum sin persistencia SwiftData -- el progreso se calcula en tiempo real a partir de `FocusSessionRecord` y `DailyStats`.

```swift
enum Achievement: String, CaseIterable {
    case firstSession      // "First Focus" -- 1 sesion completada
    case weekStreak        // "Week Warrior" -- racha de 7 dias
    case pomodoroMaster    // "Pomodoro Master" -- 100 pomodoros
    case deepDiver         // "Deep Diver" -- 10 sesiones de deep work
    case centuryClub       // "Century Club" -- 100 sesiones totales
    case earlyBird         // "Early Bird" -- 10 sesiones antes de las 8am
}
```

### 4.7 SubTask

Subtarea dentro de una TaskItem.

```swift
@Model
public final class SubTask {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var parent: TaskItem?
}
```

---

## 5. Motor de Enfoque (FocusEngine)

El FocusEngine es el componente mas critico de la aplicacion. Es un **Swift Actor** que maneja de forma segura (thread-safe) el temporizador unificado para los 4 modos de foco.

### Arquitectura

```
┌───────────────────────────────────────────────────────┐
│                    FocusFeature (TCA)                  │
│     Consume AsyncStream<FocusEngineEvent>              │
│     Traduce eventos a State + despacha Effects         │
└─────────────────────┬─────────────────────────────────┘
                      │ start / pause / resume / stop
                      v
┌───────────────────────────────────────────────────────┐
│                 FocusEngine (actor)                    │
│                                                       │
│  ┌──────────────┐    ┌─────────────────────────┐      │
│  │ Strategy     │    │ Timing Loop (10 Hz)     │      │
│  │ (protocol)   │    │ Date.now - phaseStart   │      │
│  │              │    │ - totalPausedDuration    │      │
│  │ Pomodoro     │    │                         │      │
│  │ Flowtime     │    │ Emite: tick, phase,     │      │
│  │ TimeBlock    │    │ completed, interrupted  │      │
│  │ Stopwatch    │    └─────────────────────────┘      │
│  └──────────────┘                                     │
└───────────────────────────────────────────────────────┘
```

### Strategy Pattern (FocusModeStrategy)

Protocolo que los 4 modos implementan. El engine delega toda la logica especifica de modo a la estrategia activa.

```swift
protocol FocusModeStrategy: Sendable {
    var mode: FocusMode { get }
    var direction: TimerDirection { get }     // .countDown o .countUp
    var hasTarget: Bool { get }              // true: Pomodoro/TimeBlock, false: Flowtime/Stopwatch
    var supportsAutoAdvance: Bool { get }    // avance automatico entre fases

    func targetDuration(config: FocusConfig, phase: FocusPhase) -> TimeInterval?
    func initialPhase(config: FocusConfig) -> FocusPhase
    func nextPhase(after phase: FocusPhase, elapsed: TimeInterval, config: FocusConfig) -> FocusPhase?
    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval
}
```

### Las 4 estrategias

| Estrategia | Direccion | Target | Auto-avance | Fases |
|-----------|-----------|--------|-------------|-------|
| **PomodoroStrategy** | countDown | Si (25 min) | Si | work(n/total) -> shortBreak -> work -> ... -> longBreak |
| **FlowtimeStrategy** | countUp | No | No | flow (abierto, con sugerencia de descanso dinamica) |
| **TimeBlockStrategy** | countDown | Si (configurable) | No | block (bloque continuo, check-in opcional a mitad) |
| **StopwatchStrategy** | countUp | No | No | freeform (solo cuenta) |

**Formula de descanso Flowtime:**
- < 25 min de foco -> 5 min de descanso
- < 50 min -> 8 min
- < 90 min -> 10 min
- >= 90 min -> 15 min

### Timing basado en Date (libre de drift)

El motor usa **aritmetica de fechas** (`Date.now - phaseStartDate - totalPausedDuration`) en lugar de `Timer.scheduledTimer`. Esto elimina la desviacion (drift) acumulada que ocurre con timers basados en intervalos, especialmente cuando la app sale y regresa del background.

### Eventos del engine

```swift
public enum FocusEngineEvent: Sendable {
    case tick(FocusSessionState)              // cada 100ms: estado actualizado
    case phaseCompleted(FocusPhase)           // fase completada (ej: work -> break)
    case sessionCompleted(FocusSessionResult) // sesion terminada
    case breakSuggested(duration: TimeInterval) // Flowtime: sugerencia de descanso
    case midpointReached                      // TimeBlock: mitad del bloque
    case interrupted                          // interrupcion registrada
}
```

El reducer `FocusFeature` consume estos eventos via `AsyncStream` y actualiza el estado de la UI, notificaciones, Live Activity y Watch de forma reactiva.

### Gestion de pausas

El engine rastrea las pausas preservando la fase exacta que estaba activa antes de pausar (`phaseBeforePause`). Al reanudar, restaura la fase correcta y ajusta `totalPausedDuration` para que el calculo de tiempo transcurrido sea preciso.

### Estrategia de background

1. La app entra en background -> se programa `UNNotificationRequest` al tiempo final (modos countdown) o como recordatorio periodico (modos count-up).
2. Live Activity continua mostrando countdown/count-up (gestionado por el sistema).
3. La app regresa a foreground -> recalcula el tiempo transcurrido desde `phaseStartDate`.
4. watchOS -> `ExtendedRuntimeSession` para mantener el timer activo.

### Extensibilidad

Agregar un 5to modo (ej: tecnica 52/17) requiere solo un nuevo struct conformando `FocusModeStrategy`. Cero cambios al engine, Live Activity, Widget o Watch.

---

## 6. Clients TCA (@DependencyClient)

Todos los clientes siguen el patron `@DependencyClient` de TCA. Son structs `Sendable` con closures que abstrae la implementacion real, permitiendo inyectar mocks en tests.

### Puente SwiftData <-> TCA

Las clases `@Model` de SwiftData no son `Sendable` y estan vinculadas al `@MainActor`. El `PersistenceClient` resuelve esto con DTOs (Data Transfer Objects):

```
@Model (SwiftData, @MainActor) --> MainActor.run { } --> DTO (Sendable, value type) --> TCA Effect
```

### Lista de clientes

| # | Cliente | Responsabilidad |
|---|---------|-----------------|
| 1 | **PersistenceClient** | CRUD SwiftData: tareas, sesiones, stats, preferencias. Todas las operaciones via `MainActor.run {}` devolviendo DTOs `Sendable`. |
| 2 | **FocusClient** | Puente entre TCA y el actor `FocusEngine`. Inicia/pausa/reanuda/detiene sesiones. Expone `AsyncStream<FocusEngineEvent>` para el reducer. |
| 3 | **WatchConnectivityClient** | Comunicacion bidireccional `WCSession`. iOS envia: `WatchSessionState` (cada tick), stats, tareas. Watch envia: `WatchCommand`. |
| 4 | **AIReportClient** | Genera reportes de productividad. Intenta primero con `OnDeviceReportGenerator` (Foundation Models, iOS 26+), fallback a `TemplateReportGenerator`. |
| 5 | **NotificationClient** | Wrapper de `UNUserNotificationCenter`. Programa notificaciones de fin de sesion, recordatorios diarios, sugerencias de descanso. |
| 6 | **SubscriptionClient** | RevenueCat SDK v5+. Consulta offerings/packages, realiza compras via StoreKit 2, restaura transacciones, verifica entitlements. Soporta configure/logIn/logOut flow para user identification. |
| 7 | **SoundscapeClient** | Reproduccion de sonidos ambiente durante sesiones de foco. Actor `SoundscapeManager` con `AVAudioEngine`. 8 soundscapes incluidos. |
| 8 | **CalendarClient** | Lectura de eventos de `EventKit`. Muestra eventos del calendario junto a sesiones de foco programadas. |
| 9 | **HealthClient** | Escribe `HKCategorySample` de tipo `.mindfulSession` a Apple Health al completar una sesion. Solicita autorizacion de forma explicita. |
| 10 | **SignInWithAppleClient** | Flujo de autenticacion con `ASAuthorizationAppleIDProvider`. Almacena `appleUserID`, nombre y email en `UserPreferences`. |
| 11 | **SpotlightClient** | Indexa tareas en CoreSpotlight para busqueda del sistema. Actualiza el indice al crear/editar/eliminar tareas. |
| 12 | **LiveActivityClient** | Gestiona Live Activities via `ActivityKit`. Inicia, actualiza y termina actividades. Adapta la presentacion del Dynamic Island segun el modo de foco. |

---

## 7. Servicios

Los servicios contienen logica de negocio pura, sin dependencia de TCA ni de frameworks UI.

| Servicio | Responsabilidad |
|----------|-----------------|
| **ModeIntelligenceService** | Analiza `FocusSessionRecord` historico por tarea. Calcula `completionRateByMode` y `averageDurationByMode`. Devuelve `SuggestedMode` con nivel de confianza (>70% para mostrar sugerencia). |
| **InsightsService** | Calcula tendencias, patrones, horas pico de productividad, mejor dia de la semana, y comparativas semana-sobre-semana a partir de `DailyStats`. |
| **OnDeviceReportGenerator** | Genera reportes de productividad usando Apple Foundation Models (`FoundationModels` framework, iOS 26+). Envia un prompt con datos agregados y parsea la respuesta JSON. Falla graciosamente si el modelo no esta disponible. |
| **TemplateReportGenerator** | Fallback cuando Foundation Models no esta disponible. Genera reportes basados en plantillas con logica condicional (ej: "Tu tasa de completitud subio un 15%"). |
| **ReportDataBuilder** | Construye el payload `ReportPayload` agregando datos de `DailyStats`, `FocusSessionRecord` y `TaskItem` para el periodo solicitado (semanal/mensual). |
| **WeeklyReportService** | Orquesta la generacion de reportes semanales: construye payload via `ReportDataBuilder`, intenta `OnDeviceReportGenerator`, fallback a `TemplateReportGenerator`, persiste en `ProductivityReport`. |
| **RemindersImportService** | Importa tareas desde Apple Reminders via `EventKit.EKEventStore`. Import unidireccional (no sincronizacion continua). Solicita acceso de forma explicita. |

---

## 8. watchOS

### Arquitectura de comunicacion

La app del Watch se comunica con iOS via `WCSession` (WatchConnectivity framework). El mismo archivo `WatchConnectivityClient.swift` compila en ambos targets (iOS y watchOS), usando `#if os(iOS)` para metodos requeridos solo en un lado.

### Flujo de datos iOS -> Watch

```
iOS (FocusFeature)
  |-- cada tick: sendSessionState(WatchSessionState)
  |     isActive, isPaused, modeID, displayTime, phaseLabel,
  |     progress, pomodoroNumber, linkedTaskTitle, isPhaseTransition
  |
  |-- al completar sesion: sendStats(todayMinutes, sessions, streak)
  |
  |-- al lanzar app / cambio de tareas: sendTasks([WatchTaskItem])
  |     id, title, isCompleted, priority, estimatedPomodoros, completedPomodoros
  |
  |-- bajo demanda: sendDashboardStats(WatchDashboardStats)
        todayMinutes, sessionsCompleted, tasksCompleted, tasksTotal,
        streakDays, pomodoroMinutes, flowtimeMinutes, timeBlockMinutes,
        stopwatchMinutes, longestSessionMinutes
```

### Flujo de datos Watch -> iOS

```
Watch (WatchDashboardFeature)
  |-- WatchCommand:
  |     .startSession(mode: String)
  |     .pauseSession
  |     .resumeSession
  |     .stopSession
  |     .skipPhase
  |     .linkTask(id: String)
  |     .unlinkTask
  |     .toggleTaskCompleted(id: String)
  |     .requestTasks
  |     .requestDashboard
```

### Protocolo de transporte

- **`sendMessage`** para comunicacion en tiempo real (ambos dispositivos activos, Watch reachable).
- **`updateApplicationContext`** para sincronizacion en background (estado persistente).
- **`transferCurrentComplicationUserInfo`** para actualizaciones de complications.
- Todos los mensajes usan `[String: Any]` con un campo `"type"` como discriminador.

### Fuente de verdad

Cuando ambos dispositivos estan activos, **iOS es la fuente de verdad**. El Watch muestra el estado recibido y envia comandos; no mantiene su propio timer independiente mientras iOS esta conectado.

### Features independientes del Watch

- **Timer remoto:** muestra countdown/count-up recibido de iOS.
- **Dashboard:** estadisticas diarias, desglose por modo, racha.
- **Lista de tareas:** tareas activas con toggle de completitud.
- **Selector de modo:** iniciar sesion en cualquiera de los 4 modos.

### Complications

| Tipo | Contenido |
|------|-----------|
| Circular | Countdown de sesion activa o tiempo de foco diario |
| Rectangular | Timer + nombre de tarea vinculada |
| Corner | Conteo de sesiones: "3/4" |

---

## 9. Ecosystem Extensions

### 9.1 WidgetKit (Home Screen + Lock Screen)

Tres familias de widgets:

| Widget | Tamanos | Contenido |
|--------|---------|-----------|
| **FocusWidget** | small, medium, large | Sesion activa (modo, tiempo, progreso) o "Start Focus" |
| **TasksWidget** | small, medium | Tareas pendientes de hoy con prioridad |
| **DashboardWidget** | small, medium, large | Estadisticas diarias: tiempo, sesiones, racha |

- Lock screen widgets: versiones compactas circular e inline.
- Configuracion interactiva via `WidgetIntents.swift`.
- Datos compartidos via App Group container.

### 9.2 ActivityKit (Dynamic Island + Live Activity)

```swift
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var remainingSeconds: Int?        // nil para count-up
        var focusMode: String
        var phase: String
        var taskName: String?
        var progress: Double?             // 0.0-1.0 para countdown
        var pomodoroNumber: Int?
        var totalPomodoros: Int?
    }
    var startedAt: Date
    var targetDuration: TimeInterval?
    var focusMode: String
}
```

**Adaptacion por modo en Dynamic Island:**

| Modo | Icono | Visualizacion |
|------|-------|---------------|
| Pomodoro | Timer | Countdown + "3 of 4" + anillo de progreso |
| Flowtime | Wind | Count-up + sugerencia "Take a break" |
| Time Block | Rectangle | Countdown + barra de progreso lineal |
| Stopwatch | Stopwatch | Count-up + cromo minimo |

Todos los modos: tap para abrir la app, long-press para pausa/stop.

### 9.3 App Intents (Siri Shortcuts)

7 intents disponibles en 3 idiomas (EN, ES, PT):

| Intent | Frases ejemplo |
|--------|---------------|
| `StartFocusIntent` | "Start deep work in Pepinillo", "Start a Pomodoro" |
| `PauseFocusIntent` | "Pause my focus session" |
| `CheckStatsIntent` | "How much did I focus today?" |
| `GetInsightsIntent` | "Show my productivity insights" |
| `GetModeSuggestionIntent` | "Which focus mode should I use?" |
| `GetWeeklyReportIntent` | "Show my weekly report" |
| `FocusFilterIntent` | Integracion con Focus Modes del sistema iOS |

El `FocusFilterIntent` permite que los Focus Modes del sistema (ej: "Do Not Disturb", "Work") activen/desactiven automaticamente sesiones en Pepinillo.

Las entidades de tareas (`TaskEntityQuery`) consultan el App Group ModelContainer para sugerir tareas reales del usuario.

### 9.4 Control Center (iOS 18+)

`ControlWidgetToggle` que permite iniciar/detener la sesion de foco activa directamente desde el Control Center sin abrir la app.

### 9.5 Handoff

Soporte para continuar sesiones en otro dispositivo Apple via `NSUserActivity`. Si el usuario esta enfocado en iPhone, puede continuar en iPad o Mac.

### 9.6 Spotlight

CoreSpotlight indexa todas las tareas para busqueda del sistema. El indice se actualiza al crear, editar o eliminar tareas.

---

## 10. Sincronizacion

### CloudKit (NSPersistentCloudKitContainer)

- **Base de datos:** Privada (solo datos del usuario, encriptados en reposo por Apple).
- **Sync automatico:** SwiftData configurado con `cloudKitContainerIdentifier: "iCloud.com.pepinillo.app"`. Sin codigo de sincronizacion manual.
- **Operacion offline:** Todas las operaciones escriben al store local de SwiftData primero (instantaneo). CloudKit sincroniza oportunisticamente cuando hay red.
- **Cambios pendientes:** Se encolan en `CKOperationGroup` hasta que la red este disponible.

### Resolucion de conflictos

| Tipo de dato | Estrategia |
|-------------|-----------|
| Campos escalares (titulo, estado) | Last-write-wins |
| Colecciones (subtareas) | Merge aditivo (nunca eliminar remotamente) |
| Automatico | SwiftData/CloudKit maneja la mayoria via `CKRecord` merge policies |

### App Group

Container compartido `group.com.pepinillo.app` accesible desde:
- App principal (iPhone/iPad/Mac)
- PepinilloWidget
- PepinilloLiveActivity
- PepinilloIntents
- PepinilloWatch
- ControlCenterExtension

---

## 11. IA On-Device

### Apple Foundation Models (iOS 26+)

El generador de reportes `OnDeviceReportGenerator` usa el framework `FoundationModels` de Apple para generar reportes de productividad completamente on-device, sin enviar datos a servidores externos.

**Flujo:**

```
ReportDataBuilder          OnDeviceReportGenerator         TemplateReportGenerator
(agrega datos)  -------->  (Foundation Models)  -----X---> (fallback plantillas)
                               |                               |
                               v                               v
                        AIReportResponse                AIReportResponse
                               |                               |
                               └───────────> ProductivityReport (SwiftData)
```

**Verificacion de disponibilidad:**

```swift
func isAvailable() -> Bool {
    // Solo iOS 26+, solo cuando el modelo esta descargado y listo
    SystemLanguageModel.default.availability == .available
}
```

**Casos de uso:**
- Reportes de productividad semanales y mensuales
- Analisis de patrones de foco
- Recomendaciones personalizadas

**Privacidad:** Todo el procesamiento ocurre on-device. Los datos del usuario nunca salen del dispositivo.

### Fallback: TemplateReportGenerator

Cuando Foundation Models no esta disponible (iOS < 26, modelo no descargado, dispositivo no soportado), el sistema usa plantillas con logica condicional para generar reportes basados en datos estadisticos puros.

---

## 12. Diseno

### Temas

4 temas integrados, gestionados via `AppTheme` environment key:

| Tema | Paleta | Uso |
|------|--------|-----|
| **Classic** (default) | Tonos neutros + verde pepinillo | Tema base |
| **Forest** | Verdes oscuros, marrones | Deep work, naturaleza |
| **Ocean** | Azules, turquesas | Calma, fluidez |
| **Sunset** | Naranjas, rosados | Energia, calidez |

### Colores de acento por modo

Cada modo de foco tiene un color de acento unico (definido en `ModeColors.swift`):
- Pomodoro: rojo tomate
- Flowtime: azul oceano
- Time Block: violeta
- Stopwatch: verde

### Efectos visuales

- **Glassmorphism:** Modificadores de vidrio esmerilado (`GlassModifier.swift`) para cards y superficies.
- **Liquid Glass (iOS 26):** Materiales adaptativos de Apple para la nueva estetica de iOS 26.
- **Animaciones de celebracion:** Particulas y confetti al completar sesiones/logros (`CelebrationView.swift`).

### Retroalimentacion haptica

`HapticManager` centraliza toda la retroalimentacion haptica:
- Inicio/fin de sesion
- Transicion de fase (work -> break)
- Completar tarea
- Alcanzar logro
- Interacciones de botones

### Reduce Motion

Todas las animaciones respetan `UIAccessibility.isReduceMotionEnabled`. Las animaciones se reemplazan por transiciones instantaneas via `ConditionalAnimation.swift`.

### Localizacion

3 idiomas via `Localizable.xcstrings`:
- Ingles (EN) -- idioma base
- Espanol (ES)
- Portugues (PT)

Todas las cadenas usan `String(localized:)` para soporte nativo de localizacion.

---

## 13. Testing

### Framework

Swift Testing (`@Test` macro) para todos los tests. Compatible con Xcode 16+.

### Patron de tests TCA

```swift
@Test func pomodoroIniciaCuentaRegresiva() async {
    let clock = TestClock()
    let store = TestStore(
        initialState: FocusFeature.State(mode: .pomodoro),
        reducer: { FocusFeature() },
        withDependencies: { $0.continuousClock = clock }
    )

    await store.send(.startTapped) { $0.isRunning = true }
    await clock.advance(by: .seconds(1))
    await store.receive(.timerTicked) { $0.remainingSeconds = 1499 }
}
```

### 10 suites de tests

| Suite | Archivo | Cobertura |
|-------|---------|-----------|
| FocusFeatureReducerTests | `FocusFeatureReducerTests.swift` | Reducer de foco: todos los modos, pausa, reanudacion, stop |
| FocusModeStrategyTests | `FocusModeStrategyTests.swift` | Las 4 estrategias: fases, duraciones, auto-avance |
| SessionJournalFeatureTests | `SessionJournalFeatureTests.swift` | Diario post-sesion |
| TaskListFeatureTests | `TaskListFeatureTests.swift` | CRUD tareas, filtros, recurrencia |
| AnalyticsFeatureTests | `AnalyticsFeatureTests.swift` | Dashboard, tendencias |
| InsightsServiceTests | `InsightsServiceTests.swift` | Servicio de insights |
| PaywallFeatureTests | `PaywallFeatureTests.swift` | Paywall, RevenueCat mock |
| ModeIntelligenceTests | `ModeIntelligenceTests.swift` | Sugerencia de modo |
| SiriIntentsTests | `SiriIntentsTests.swift` | App Intents |
| FocusWidgetProviderTests | `FocusWidgetProviderTests.swift` | Timeline provider |
| WatchTimerFeatureTests | `WatchTimerFeatureTests.swift` | Feature del Watch |
| AppFeatureIntegrationTests | `AppFeatureIntegrationTests.swift` | Integracion del reducer raiz |

### Criterios de rendimiento

| Metrica | Objetivo |
|---------|----------|
| Precision del timer | <= 100ms de desviacion en 25 minutos |
| Arranque en frio | < 1s en iPhone 14+ |
| Sincronizacion CloudKit | < 10s para 100 tareas (Wi-Fi) |

---

## 14. Dependencias

Filosofia: **dependencias minimas**. Usar frameworks de Apple para todo lo posible.

| Dependencia | Version | Proposito | Por que externa |
|-----------|---------|-----------|-----------------|
| `swift-composable-architecture` | 1.17+ | Gestion de estado y arquitectura | Core de la arquitectura, extensamente testeado, mantenido por Point-Free |
| `swift-dependencies` | (incluido en TCA) | Inyeccion de dependencias | Requerido por TCA |
| `swift-snapshot-testing` | 1.17+ | Tests de snapshot UI | Ecosistema de testing de Point-Free (solo test target) |

**Lo que NO usamos (y por que):**
- **RevenueCat SDK v5+:** Implementado para centralizar manejo de suscripciones, entitlements, webhooks, y user identification (via Sign in with Apple).
- **Firebase:** CloudKit privado para datos, TelemetryDeck para analytics, Sign in with Apple para auth.
- **Alamofire/Moya:** No hay networking custom -- todo es CloudKit automatico.
- **Realm/GRDB:** SwiftData es el framework recomendado de Apple con integracion CloudKit nativa.

---

## 15. Seguridad y Privacidad

### Autenticacion

- **Sign in with Apple** exclusivamente. Sin email/password, sin Firebase Auth.
- El `appleUserID` se almacena en `UserPreferences` (CloudKit privado, encriptado).

### Almacenamiento de datos

- **CloudKit private database:** Todos los datos del usuario encriptados en reposo por Apple.
- **SwiftData local:** Data Protection a nivel de archivo (encriptacion del sistema).
- **App Group container:** Compartido solo entre targets de la misma app (sandbox).

### Analytics

- **TelemetryDeck:** Analytics respetuosos de la privacidad. No recopila PII (informacion personal identificable).
- **Sin tracking:** No se usan frameworks de tracking de terceros.

### Permisos

Solo se solicitan cuando el usuario opta explicitamente:
- **Notificaciones:** Para alertas de fin de sesion y recordatorios
- **HealthKit:** Para registrar Mindful Minutes (opt-in en Settings)
- **EventKit:** Para importar recordatorios (accion explicita del usuario)

**No se solicitan:** Camara, microfono, ubicacion, contactos, fotos.

### App Transport Security

Aplicado (solo HTTPS). No hay endpoints HTTP custom.

### Privacy Nutrition Label

Recopilacion minima de datos para el listing de App Store.

---

## 16. Accesibilidad

### VoiceOver

- Soporte completo en todas las plataformas (iOS, iPadOS, macOS, watchOS).
- Labels de accesibilidad personalizados para el circulo del timer, indicadores de progreso, y controles de sesion.
- Traits de accesibilidad correctos (`.button`, `.header`, `.updatesFrequently` para el timer).

### Dynamic Type

- Todo el texto escala con el tamano de texto del sistema.
- Layouts adaptativos que se ajustan a tamanos de texto grandes y extra-grandes.

### Reduce Motion

- Todas las animaciones respetan `UIAccessibility.isReduceMotionEnabled`.
- Las animaciones se reemplazan por transiciones instantaneas.
- Celebraciones (confetti, particulas) se desactivan.

### Contraste

- Ratio minimo de contraste de **4.5:1** para todo el texto.
- Soporte de modo de alto contraste.
- Los colores de acento por modo mantienen el ratio en ambos temas claro y oscuro.

### Retroalimentacion haptica

- Alternativa a indicadores puramente visuales.
- Haptics diferenciados por tipo de evento (inicio, pausa, completitud, logro).
- Se puede desactivar globalmente en `UserPreferences.hapticEnabled`.

---

## 17. Targets y Plataformas

### Distribucion de targets

| Target | Plataforma | UI Framework | Notas |
|--------|-----------|-------------|-------|
| **Pepinillo** (principal) | iPhone, iPad, Mac | SwiftUI | Target principal de desarrollo |
| **PepinilloWatch** | Apple Watch | SwiftUI (WatchKit) | App companion: timer remoto, tareas, dashboard |
| **PepinilloWidget** | iPhone, iPad | WidgetKit | 3 familias: Focus, Tasks, Dashboard (home + lock screen) |
| **PepinilloLiveActivity** | iPhone | ActivityKit | Dynamic Island + banner de Live Activity |
| **PepinilloIntents** | iPhone, iPad, Mac | App Intents | 7 intents Siri en 3 idiomas |
| **ControlCenterExtension** | iPhone | ControlWidget | Toggle para iniciar/detener sesion (iOS 18+) |

### Adaptaciones por plataforma

| Plataforma | Adaptacion |
|-----------|-----------|
| **iPhone** | Target principal. Todas las features disponibles. |
| **iPad** | Split View (`iPadSplitView.swift`), Stage Manager, layouts adaptativos, teclado fisico shortcuts. Sheets con tamano adaptativo (`iPadSheetModifier`). |
| **Mac (Catalyst)** | Menu bar commands (`MacCommands.swift`), ventana completa, sandbox entitlement. `#if os(macOS)` para especificos de plataforma. |
| **watchOS** | Feature set simplificado: timer, tareas, dashboard, complications. Comunicacion via WCSession. `ExtendedRuntimeSession` para haptics de alarma. |

### Codigo compartido

Los modelos de dominio (`Domain/`), features TCA (`Features/`), servicios y clientes se comparten entre todas las plataformas. Solo las vistas y las integraciones especificas de plataforma difieren por target.

### Identificadores

| Recurso | Identificador |
|---------|--------------|
| Bundle ID | `com.pepinillo.app` |
| App Group | `group.com.pepinillo.app` |
| CloudKit Container | `iCloud.com.pepinillo.app` |

### Generacion del proyecto

El proyecto Xcode se genera desde `project.yml` via XcodeGen:

```bash
xcodegen generate  # regenerar despues de cambios en project.yml
```

---

## 18. Backend e Integracion con Servidor

### 18.1 Vision General del Backend Go

El backend de Pepinillo es una API REST escrita en **Go** con arquitectura hexagonal. Aun **no esta desplegado** en produccion — se encuentra en desarrollo activo en `backend/`.

| Aspecto | Tecnologia |
|---------|------------|
| **Lenguaje** | Go |
| **Framework HTTP** | Fiber |
| **Base de datos** | PostgreSQL |
| **Autenticacion** | JWT (access + refresh tokens) |
| **Arquitectura** | Hexagonal (puertos y adaptadores) |
| **Estado** | En desarrollo, no desplegado |

#### Grupos de Endpoints

| Grupo | Endpoints | Descripcion |
|-------|-----------|-------------|
| **Auth** | `POST /auth/login`, `POST /auth/register`, `POST /auth/google`, `POST /auth/apple` | Autenticacion por email/password + OAuth (Google/Apple) |
| **Tasks** | `GET/POST/PUT/DELETE /api/v1/tasks` | CRUD de tareas |
| **Sessions** | `GET/POST /api/v1/pomodoro-sessions` | Registro y consulta de sesiones de enfoque |
| **Stats** | `GET /api/v1/stats/daily`, `GET /api/v1/stats/weekly` | Estadisticas agregadas (pendiente) |
| **Billing** | `POST /api/v1/billing/verify-receipt` | Verificacion server-side de recibos (App Store y Play Store) |
| **Push** | `POST /api/v1/push/register` | Registro de tokens APNs para notificaciones push |
| **WebSocket** | `WS /api/v1/ws` | Canal de sincronizacion en tiempo real |
| **AI** | `POST /api/v1/ai/report` | Generacion de reportes de productividad |
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

### 18.2 Flujo de Autenticacion

iOS utiliza **Sign In with Apple** como metodo principal de autenticacion, con email/password como alternativa.

#### Sign In with Apple (metodo principal)

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│   iOS App    │     │  Apple Identity   │     │  Backend Go  │
│              │     │  Services         │     │              │
│              │     │                   │     │              │
│ 1. ASAutho-  │────►│ 2. Autenticacion  │     │              │
│    rization  │     │    biometrica     │     │              │
│    Controller│◄────│ 3. identityToken  │     │              │
│              │     │    + authCode     │     │              │
│              │     │                   │     │              │
│ 4. POST      │────────────────────────────►│ 5. Verifica   │
│    /auth/    │     │                   │     │    identity  │
│    apple     │     │                   │     │    Token con │
│              │     │                   │     │    Apple     │
│              │◄────────────────────────────│ 6. JWT access │
│              │     │                   │     │    + refresh  │
│ 7. Almacena  │     │                   │     │              │
│    en        │     │                   │     │              │
│    Keychain  │     │                   │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘
```

**Pasos detallados:**

1. El usuario toca "Continuar con Apple" → se presenta `ASAuthorizationAppleIDProvider` via `SignInWithAppleClient`
2. Apple autentica con Face ID / Touch ID / password del dispositivo
3. Apple retorna un `identityToken` (JWT firmado por Apple) y un `authorizationCode`
4. La app envia `POST /auth/apple` con el `identityToken` en el body
5. El backend valida el token contra los servidores de Apple (verifica firma, audience, issuer)
6. Si el usuario no existe, lo crea; retorna JWT (access + refresh token) de Pepinillo
7. Los tokens se almacenan en **Keychain** (cifrado por hardware, protegido por Secure Enclave)

> **Nota:** Apple solo envia el nombre y email del usuario en la **primera** autorizacion. El backend los persiste en ese momento. En autorizaciones subsecuentes, solo se recibe el `identityToken`.

#### Email/Password (alternativa)

- `POST /auth/register` → crea cuenta con email + password
- `POST /auth/login` → retorna JWT access + refresh tokens
- Tokens almacenados en Keychain igual que con Sign In with Apple

#### Gestion de Tokens

| Token | Almacenamiento | Duracion | Renovacion |
|-------|---------------|----------|------------|
| **Access Token** | Keychain | Corta (15-30 min) | Automatica via refresh token |
| **Refresh Token** | Keychain | Larga (30 dias) | Requiere re-login al expirar |

El cliente API (basado en `URLSession`) incluye logica de renovacion automatica:
- Adjunta el access token como `Authorization: Bearer <token>` en cada request
- Detecta respuestas `401 Unauthorized`
- Intenta renovar el access token usando el refresh token
- Si la renovacion falla, emite una accion TCA que redirige al flujo de login

#### Transicion desde Sign In with Apple Standalone

Actualmente, `SignInWithAppleClient` almacena `appleUserID` en `UserPreferences` (CloudKit). Con el backend:

1. `SignInWithAppleClient` continua obteniendo el `identityToken` de Apple
2. En lugar de solo guardar el `appleUserID` localmente, ahora tambien envia el token al backend
3. El backend se convierte en la fuente de verdad para la identidad del usuario
4. `UserPreferences.appleUserID` se mantiene como cache local para verificacion rapida

### 18.3 Estrategia de Sincronizacion Dual

iOS mantiene **dos capas de sincronizacion** en paralelo durante la transicion al backend:

#### Capa 1: SwiftData + CloudKit (sincronizacion Apple)

La sincronizacion existente via `NSPersistentCloudKitContainer` **se mantiene** intacta:

- Sync automatico entre dispositivos Apple del mismo usuario (iPhone, iPad, Mac, Watch)
- Sin codigo de sync manual — CloudKit lo gestiona
- Baja latencia entre dispositivos Apple (~1-5 segundos)
- Funciona sin backend (modo offline completo)

#### Capa 2: Backend Sync (sincronizacion cross-platform)

Nueva capa de sincronizacion con el backend Go para compartir datos con Android:

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App                               │
│                                                              │
│  SwiftData ◄──► CloudKit       SwiftData ◄──► BackendSync  │
│  (Apple sync,   (automatico)   (mismos datos)  (API REST    │
│   sin cambios)                                  + WebSocket) │
│                                                              │
│  Prioridad: CloudKit para sync Apple-Apple                   │
│             Backend para sync cross-platform                 │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │  Backend Go  │
                    │  PostgreSQL  │
                    └──────────────┘
```

#### Estrategia de Migracion para Usuarios Existentes de CloudKit

Los usuarios que ya tienen datos en CloudKit necesitan una migracion al backend:

| Paso | Accion | Detalle |
|------|--------|---------|
| 1 | Login con backend | El usuario se autentica (Apple/email) por primera vez |
| 2 | Deteccion de datos locales | La app detecta que existen datos en SwiftData/CloudKit |
| 3 | Upload inicial | Se suben todas las tareas, sesiones y stats al backend via batch API |
| 4 | Mapeo de IDs | Se guardan los `serverId` retornados por el backend en los modelos locales |
| 5 | Sync activo | A partir de este punto, los cambios se sincronizan bidireccionalmente |

> **Importante:** CloudKit sigue siendo la capa primaria para sync Apple-Apple. El backend es un "mirror" adicional para cross-platform. No se elimina CloudKit.

#### WebSocket (Sincronizacion en Tiempo Real)

El backend expone `WS /api/v1/ws` para notificar cambios remotos:

- Al conectar, el cliente envia su JWT para autenticarse
- El backend emite eventos cuando otro dispositivo (ej: Android) del mismo usuario modifica datos
- El cliente iOS recibe el evento y ejecuta un pull selectivo
- Reconexion automatica con backoff exponencial

#### BackgroundTasks (Fallback)

Cuando el WebSocket no esta disponible, se usa `BGAppRefreshTask` como fallback:

- Registrado con `BGTaskScheduler` para ejecucion periodica (~15 minutos)
- Ejecuta `BackendSyncClient.syncAll()` para push/pull de cambios pendientes
- Constraint: requiere conexion a internet

### 18.4 Suscripciones Cross-Platform

Las suscripciones se verifican **server-side** para garantizar paridad entre plataformas. Un usuario que compra PRO en iOS puede usar PRO en Android y viceversa.

#### Flujo de Verificacion

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   iOS App    │     │  Backend Go  │     │  App Store   │
│              │     │              │     │  Server API  │
│ 1. Usuario   │     │              │     │              │
│    compra    │     │              │     │              │
│    con       │     │              │     │              │
│    StoreKit 2│     │              │     │              │
│              │     │              │     │              │
│ 2. POST      │────►│ 3. Valida    │────►│ 4. Verifica  │
│    /billing/ │     │    recibo    │     │    con App   │
│    verify-   │     │    con App   │◄────│    Store     │
│    receipt   │     │    Store API │     │    Server    │
│              │     │              │     │    Notif. V2 │
│              │◄────│ 5. Actualiza │     │              │
│              │     │    user.sub  │     │              │
│ 6. Cachea    │     │    tier=pro  │     │              │
│    PRO local │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Pasos detallados:**

1. El usuario completa la compra via `SubscriptionClient` (RevenueCat SDK v5+, wrapping StoreKit 2)
2. La app envia `POST /api/v1/billing/verify-receipt` con el `originalTransactionID` y el `signedPayload` (JWS)
3. El backend valida el recibo contra la App Store Server API (verifica firma JWS, estado de suscripcion)
4. App Store confirma que la compra es legitima y activa
5. El backend actualiza `User.SubscriptionTier = "pro"` en PostgreSQL
6. La app cachea el estado PRO localmente; todas las verificaciones futuras consultan `GET /api/v1/users/me`

**Fuentes de verdad:**

| Contexto | Fuente |
|----------|--------|
| **Cross-platform** | Backend (`User.SubscriptionTier`) — consultado via `/users/me` |
| **Solo Apple** | RevenueCat entitlements local (`RevenueCat.shared.entitlements`) — funciona offline con cache |
| **Jerarquia** | Backend > RevenueCat entitlements. Si el backend dice PRO (compra en Android), la app iOS desbloquea PRO |

**Paridad cross-platform:** Un usuario que compra PRO en Android (Play Store) vera su estado PRO reflejado en iOS al consultar `/users/me`, porque el backend centraliza el tier. RevenueCat sincroniza entitlements cross-platform.

**RevenueCat como cache local:**

El `SubscriptionClient` ahora usa RevenueCat SDK v5+:
- `RevenueCat.shared.entitlements` para verificacion rapida offline
- `configure()` y `logIn(userId)` para user identification (integrado con Sign in with Apple)
- Grace period: automáticamente manejado por RevenueCat según configuración en App Store Connect
- Se sincroniza con el backend para paridad cross-platform y entitlements verificados por servidor

### 18.5 Perfil de Usuario

El perfil de usuario combina datos de autenticacion, estadisticas y suscripcion.

#### Modelo de Datos del Perfil

| Campo | Origen | Descripcion |
|-------|--------|-------------|
| `name` | Backend (`User.Name`) | Nombre para mostrar (de Apple/Google o manual) |
| `email` | Backend (`User.Email`) | Email de la cuenta |
| `avatarUrl` | Backend (`User.ImageURL`) | Foto de perfil (URL de Apple/Google) |
| `subscriptionTier` | Backend (`User.SubscriptionTier`) | `"free"` o `"pro"` |
| `subscriptionExpiresAt` | Backend | Fecha de vencimiento de suscripcion PRO |
| `linkedAccounts` | Backend | Proveedores vinculados: Apple, Google, email |
| `emailVerified` | Backend (`User.EmailVerified`) | Si el email esta verificado |
| `memberSince` | Backend (`User.CreatedAt`) | Fecha de registro |

#### Estadisticas del Perfil (calculadas)

| Estadistica | Calculo | Fuente |
|-------------|---------|--------|
| **Racha actual** | Dias consecutivos con al menos una sesion | `PersistenceClient` → `DailyStats.hadFocusSession` |
| **Horas totales de enfoque** | Suma de `totalFocusSeconds` de todos los `DailyStats` | SwiftData local |
| **Sesiones completadas** | Suma de `sessionsCompleted` de todos los `DailyStats` | SwiftData local |
| **Tareas completadas** | Conteo de `TaskItem` con `isCompleted = true` | SwiftData local |
| **Modo dominante** | Modo con mas segundos totales | Calculo sobre `DailyStats` |

#### Implementacion con TCA

El perfil se implementa como un feature TCA:

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var userName: String
        var userEmail: String
        var avatarURL: URL?
        var subscriptionTier: String       // "free" | "pro"
        var linkedAccounts: [String]       // ["apple", "google", "email"]
        var memberSince: Date
        // Stats
        var currentStreak: Int
        var totalFocusHours: Double
        var totalSessions: Int
        var totalTasksCompleted: Int
    }

    enum Action {
        case onAppear
        case profileLoaded(UserProfile)
        case statsLoaded(ProfileStats)
        case logoutTapped
        case deleteAccountTapped
        case manageSubscriptionTapped
    }
}
```

#### Pantalla de Perfil

La `ProfileView` (SwiftUI) muestra:

- **Header:** Avatar, nombre, email, badge PRO/FREE
- **Estadisticas:** Racha, horas totales, sesiones, tareas completadas, miembro desde
- **Cuenta:** Cuentas vinculadas (Apple, Google, email), opcion de vincular/desvincular
- **Suscripcion:** Estado actual, fecha de vencimiento, boton de gestionar/upgrade
- **Acciones:** Cerrar sesion, eliminar cuenta
