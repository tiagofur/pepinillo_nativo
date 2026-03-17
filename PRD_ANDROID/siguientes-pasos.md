# Siguientes Pasos — Android Nativo

**Última actualización:** 2026-03-13

---

## Estado Actual

🟢 **Phases 1–3 completas** — Scaffolding y código fuente implementados, `./gradlew assembleDebug` retorna **BUILD SUCCESSFUL**.

🟢 **Sprint 1 completado** — Bugs críticos corregidos, localización extraída, lock screen widget creado.

🟢 **Sprint 2 completado** — Wear OS: Data Layer sync bidireccional, Tile, Complication.

🟢 **Sprint 3 completado** — Google Assistant App Actions, Calendar UI, energy batching, domain model consolidation.

🟢 **Sprint 4 completado** — Adaptive layouts: WindowSizeClass, NavigationRail/Drawer, two-pane en FocusScreen, master-detail en TaskList, multi-column en Dashboard, two-column en Settings, foldable hinge avoidance.

⏸ **Sprint 5 pendiente** — Launch prep (Firebase, CI/CD, tests, Play Store) — se hará más adelante.

> **Prerequisito original:** iOS launch (Q3 2026) antes de empezar Android. El desarrollo se adelantó para tener paridad de funcionalidad.

---

## Auditoría PRD vs Realidad (actualizado 2026-03-13)

### Brechas Corregidas (Sprint 1)

| Brecha | Estado | Detalle |
|--------|--------|---------|
| BUG: Streak count incorrecto | ✅ Corregido | `StatsDao.getStreakCount()` ahora usa CTE recursivo para contar días consecutivos |
| BUG: Auth gate ausente | ✅ Corregido | `MainActivity` verifica token de auth además de onboarding |
| GAP P0: Localización incompleta | ✅ Corregido | ~100+ strings extraídos de hardcoded Kotlin a `strings.xml` (EN/ES/PT) |
| GAP P0: Lock screen widget | ✅ Implementado | `LockScreenTimerWidget` con categoría KEYGUARD para Android 14+ |

### Brechas Corregidas (Sprint 2)

| Brecha | Estado | Detalle |
|--------|--------|---------|
| Wear OS: Data Layer sync | ✅ Implementado | `PhoneDataLayerManager` + `PhoneMessageListenerService` (phone); `WearDataRepository` + `WearDataLayerListener` + `WearMessageSender` (watch). Bidireccional con fallback local |
| Wear OS: TileService | ✅ Implementado | `FocusTileService` via Horologist `SuspendingTileService` — muestra idle/active timer layouts |
| Wear OS: ComplicationDataSourceService | ✅ Implementado | `FocusComplicationDataSource` — SHORT_TEXT y LONG_TEXT (tiempo/streak) |

### Brechas Corregidas (Sprint 3)

| Brecha | Estado | Detalle |
|--------|--------|---------|
| Google Assistant App Actions | ✅ Implementado | `actions.xml` (3 BIIs), `shortcuts.xml` (4 shortcuts), deep links `pepinillo://focus/`, intent handling en MainActivity |
| Google Calendar UI integration | ✅ Implementado | Permisos READ/WRITE_CALENDAR, toggle en Settings con runtime permissions, `blockFocusTime()` al completar sesión WORK |
| Task energy batching UI | ✅ Implementado | Energy view en TaskListScreen: agrupación por DEEP/SHALLOW/ADMIN, sugerencias por hora del día via ModeIntelligenceService |
| Domain models duplicados | ✅ Consolidado | `FocusSession`, `Task`, `Subtask` convertidos a typealias; `shared/` es fuente canónica |

### Brechas Corregidas (Sprint 4)

| Brecha | Estado | Detalle |
|--------|--------|---------|
| WindowSizeClass + adaptive nav | ✅ Implementado | NavigationBar (compact), NavigationRail (medium), PermanentNavigationDrawer (expanded) |
| FocusScreen responsive | ✅ Implementado | Two-pane en >= 600dp: timer 320dp izquierda (60%), controles derecha (40%) + hinge avoidance |
| TaskListScreen master-detail | ✅ Implementado | Left pane (40%): task list, Right pane (60%): task detail o placeholder. Selection local sin navegación |
| DashboardScreen multi-column | ✅ Implementado | WeeklyChart (60%) + ModeBreakdown (40%) side-by-side; AchievementsGridSection con FlowRow |
| SettingsScreen two-column | ✅ Implementado | Left: focus config/durations, Right: sound/calendar/import/logout + hinge spacer |
| Foldable hinge avoidance | ✅ Implementado | `androidx.window` 1.3.0 + `FoldableUtils.kt` con `rememberFoldingFeature()`. Spacer dinámico entre panes |

### Brechas Pendientes (Sprint 5 — Diferido)

| Brecha | Prioridad | Sprint |
|--------|-----------|--------|
| Test coverage (actualmente 3 archivos, ~20 tests) | P1 | Sprint 5 |
| Firebase Analytics/Crashlytics | P1 | Sprint 5 |
| CI/CD pipeline | P1 | Sprint 5 |
| Play Store listing + release signing | P1 | Sprint 5 |
| Performance optimization + R8/ProGuard | P2 | Sprint 5 |

---

## Decisiones de Stack Implementadas

| Capa | Tecnología | Versión | Notas |
|------|-----------|---------|-------|
| Lenguaje | Kotlin | **2.0.21** | ⚠️ Hilt 2.52 no puede leer metadata de Kotlin 2.1.x (APT limitation). Usar 2.0.21 hasta Hilt 2.53+ |
| KSP | `ksp` | **2.0.21-1.0.28** | Debe coincidir exactamente con Kotlin 2.0.21 |
| Build | AGP | 8.10.0 | |
| UI | Jetpack Compose + Material 3 | BOM 2025.03.00 | |
| MVI | Circuit | 0.24.0 | Circuit registrado manualmente en `AppModule` (sin `@CircuitInject` KSP) |
| DI | Hilt | 2.52 | `@AssistedInject` + `@AssistedFactory` para Circuit Presenters |
| DB | Room | 2.7.0 | KSP; exportSchema=true; schemas en `app/schemas/` |
| Networking | Ktor | 3.1.0 | OkHttp engine; DTOs alineados con backend Go |
| Widgets | Glance | 1.1.1 | Estado via `PreferencesGlanceStateDefinition` |
| Sync | WorkManager | 2.10.0 | `hilt-work 1.2.0`; `PepinilloApp implements Configuration.Provider` |
| Charts | Vico | 1.14.0 | `compose-m3` |
| Audio | Media3/ExoPlayer | 1.5.0 | Soundscapes |
| Billing | Play Billing | 7.1.1 | |
| Health | Health Connect | 1.1.0-rc01 | Mindful Sessions (experimental API) |
| Adaptive | material3-window-size-class | via BOM | `WindowWidthSizeClass` para responsive layouts |
| Foldable | androidx.window | 1.3.0 | `FoldingFeature` + `rememberFoldingFeature()` para hinge avoidance |
| Wear Tiles | Horologist | 0.6.20 | `SuspendingTileService` para Wear OS Tile |
| Wear Complications | watchface-complications | 1.2.1 | `SuspendingComplicationDataSourceService` |
| Wear Data Layer | play-services-wearable | 18.2.0 | `DataClient` + `MessageClient` para sync phone↔watch |
| Firebase | — | — | Plugins comentados; activar al agregar `google-services.json` |

---

## Roadmap por Sprints

### Sprint 1: Bugs Críticos + Localización ✅ (Completado 2026-03-13)

```
✅ 1.1 Fix streak calculation — CTE recursivo en StatsDao
✅ 1.2 Wire auth gate — MainActivity verifica token + redirige a AuthScreen
✅ 1.3 Extraer ALL hardcoded strings — ~100+ strings EN/ES/PT
   → DashboardScreen, WeeklyReviewScreen, AchievementsSection, AuthScreen,
     FocusScreen, OnboardingScreen, SettingsScreen, SoundscapeScreen,
     TaskListScreen, TaskDetailScreen, MainScaffold (bottom nav),
     DailyStatsWidget, FocusTimerWidget
✅ 1.4 Lock screen widget — LockScreenTimerWidget (KEYGUARD category)
```

### Sprint 2: Wear OS ✅ (Completado 2026-03-13)

```
✅ 2.1 Data Layer Sync — PhoneDataLayerManager + PhoneMessageListenerService (phone)
      → WearDataRepository + WearDataLayerListener + WearMessageSender (watch)
      → WearFocusViewModel reescrito: usa datos sincronizados con fallback local
      → Sincroniza: timer state, task list, daily stats
✅ 2.2 Wear Tile — FocusTileService (SuspendingTileService via Horologist)
      → Layout idle (quick-start) y active (timer + controles)
      → Dependencias: wear-tiles 1.4.1 + horologist-tiles 0.6.20
✅ 2.3 Wear Complication — FocusComplicationDataSource
      → SHORT_TEXT (tiempo activo o streak) y LONG_TEXT
      → Dependencias: wear-watchface-complications-data-source 1.2.1
```

### Sprint 3: Features P1 + Assistant ✅ (Completado 2026-03-13)

```
✅ 3.1 Google Assistant App Actions
      → actions.xml (BII: START_EXERCISE, STOP_EXERCISE, GET_EXERCISE_OBSERVATION)
      → shortcuts.xml (4 shortcuts: Pomodoro, Flow, Stopwatch, Tasks)
      → Deep links pepinillo://focus/{start|stop|status}
      → Intent handling + onNewIntent en MainActivity
✅ 3.2 Google Calendar UI
      → Permisos READ/WRITE_CALENDAR en manifest
      → Toggle en SettingsScreen con runtime permission flow
      → Wire GoogleCalendarManager.blockFocusTime() al completar sesión WORK
      → Preferencia calendarSyncEnabled en UserPreferencesRepository
✅ 3.3 Task energy batching
      → Energy view toggle en TaskListScreen (agrupa por DEEP/SHALLOW/ADMIN)
      → Sugerencias basadas en hora via ModeIntelligenceService.suggestEnergyLevel()
      → Banner de sugerencia + grupo recomendado resaltado
✅ 3.4 Consolidar domain models duplicados
      → FocusSession, Task, Subtask → typealias a shared/
      → Imports normalizados en FocusEngine, MainActivity
```

### Sprint 4: Adaptive Layouts ✅ (Completado 2026-03-13)

```
✅ 4.1a WindowSizeClass + MainScaffold adaptive navigation
      → material3-window-size-class agregado al BOM
      → Compact: NavigationBar (bottom) — sin cambios
      → Medium: NavigationRail (lateral izquierdo)
      → Expanded: PermanentNavigationDrawer (240dp)
      → NavTab data class reutilizable para las 3 variantes
✅ 4.1b FocusScreen two-pane layout
      → BoxWithConstraints branching en 600dp
      → Compact: layout original sin cambios
      → Expanded: Row — timer 320dp izquierda (60%), controles/stats derecha (40%)
      → TimerRing acepta size: Dp parametrizable
      → 3 composables compartidos extraídos (SuggestedModeChip, SessionCounter, LinkedTaskSection)
      → Hinge avoidance: hingePadding.coerceAtLeast(24.dp) entre panes
✅ 4.1c TaskListScreen master-detail
      → Tablet: Row — task list izquierda (40%), detail/placeholder derecha (60%)
      → Selection local via selectedTaskId (sin navegación en tablet)
      → TaskDetailPane con título, notas, prioridad, energía, pomodoros, modo, botones
      → TaskDetailPlaceholder con icono centrado + "Select a task"
      → Composables compartidos: TaskListTopBar, TaskListLoadingIndicator
✅ 4.1d DashboardScreen multi-column grid
      → Tablet: WeeklyChart (60%) + ModeBreakdown (40%) side-by-side
      → AchievementsGridSection con FlowRow responsive (cards 160dp)
      → Phone: layout original sin cambios
✅ 4.1e SettingsScreen two-column
      → Tablet: Left (focus config, durations, auto-start) + Right (sound, calendar, import, logout)
      → Hinge avoidance spacer entre columnas
✅ 4.1f Foldable hinge avoidance
      → androidx.window 1.3.0 + window-core
      → core/ui/FoldableUtils.kt con rememberFoldingFeature()
      → Integrado en FocusScreen y SettingsScreen expanded layouts
```

### Sprint 5: Launch Prep ⏸ (Pendiente — no se implementará aún)

```
⬜ 5.1 Firebase — agregar google-services.json + descomentar plugins
⬜ 5.2 CI/CD — GitHub Actions (build + lint + tests)
⬜ 5.3 Release keystore — generar y guardar en vault seguro
⬜ 5.4 Más tests — FocusEngine, SyncEngine, presenters, UI tests
⬜ 5.5 Play Store listing — screenshots, ASO, descripción
⬜ 5.6 OEM testing — Samsung, Pixel, Xiaomi, OnePlus
```

---

## Lo Que Se Implementó (Phases 1-3)

### Phase 1: Foundation ✅

```
✅ Proyecto Android creado (app ID: dev.creapolis.pepinillo)
✅ Gradle 8.14.3 + Version Catalog (libs.versions.toml)
✅ Room database + 4 entidades (TaskEntity, SubtaskEntity, FocusSessionEntity, DailyStatsEntity)
✅ Domain models: FocusMode, FocusPhase, FocusConfig, Task, Subtask, FocusSession, EnergyLevel, DailyStats
✅ Strategy pattern: PomodoroStrategy, FlowtimeStrategy, TimeBlockStrategy, StopwatchStrategy
✅ FocusEngine (Coroutines + StateFlow, @Singleton)
✅ FocusPresenter + FocusScreen (Compose, Circuit MVI)
✅ TaskListPresenter + TaskListScreen + TaskDetailScreen
✅ AuthPresenter + AuthScreen (JWT via Ktor + backend Go)
✅ OnboardingPresenter + OnboardingScreen (5 pantallas)
✅ Ktor API client (RemoteTask alineado con backend: syncId, isFinished, description)
✅ SyncEngine (dirty-flag strategy, last-write-wins por updatedAt)
✅ SyncWorker (@HiltWorker, periódico 15 min + OneTime expedited)
✅ UserPreferencesRepository (DataStore)
✅ RepositoryModule, DatabaseModule, NetworkModule, AppModule (Circuit)
✅ Material You theme (PepinilloTheme, Color.kt, Type.kt)
```

### Phase 2: Ecosystem ✅

```
✅ FocusForegroundService (FOREGROUND_SERVICE_SPECIAL_USE, notificación persistente)
✅ FocusNotificationManager (canal IMPORTANCE_LOW, sin sonido, acciones Pause/Resume/Stop)
✅ FocusTimerWidget (Glance, Home Screen — muestra tiempo restante y modo)
✅ DailyStatsWidget (Glance, Home Screen — muestra sesiones del día)
✅ LockScreenTimerWidget (Glance, KEYGUARD — Android 14+)
✅ WidgetStateStore (updateAppWidgetState via PreferencesGlanceStateDefinition)
✅ FocusTileService (Quick Settings Tile, Android 7+)
✅ Wear OS completo (Data Layer sync bidireccional, TileService, ComplicationDataSource)
✅ Google Assistant App Actions (actions.xml, shortcuts.xml, deep links, intent handling)
✅ Tablet/Foldable adaptive layouts (WindowSizeClass, NavigationRail/Drawer, two-pane, master-detail, hinge avoidance)
✅ Unit tests (FocusStateTest, GoogleTaskDtoTest, GoogleImportStateTest — 20 tests, 0 failures)
```

### Phase 3: Polish ✅

```
✅ DashboardPresenter + DashboardScreen (Vico charts, modo breakdown, streaks)
✅ WeeklyReviewPresenter + WeeklyReviewScreen
✅ AchievementsSection (logros con progreso)
✅ SettingsPresenter + SettingsScreen (FocusConfig sliders, default mode, logout)
✅ ModeIntelligenceService (suggestMode basado en historial de sesiones)
✅ SoundscapePlayer (ExoPlayer) + SoundscapeScreen (6 tracks)
✅ HealthConnectManager (writeMindfulSession para sesiones WORK completadas)
✅ BillingManager (Play Billing 7.1.1, SubscriptionTier FREE/PRO)
✅ RecurringTaskEngine (genera próxima tarea recurrente al completar)
✅ DndManager (Do Not Disturb durante sesiones de focus)
✅ MainActivity con 4 tabs (Focus, Tasks, Stats, Settings) + back stacks independientes
✅ Onboarding condicional (sin bottom nav)
✅ Auth gate: redirige a AuthScreen si no hay token válido
✅ Google Tasks import (OAuth + REST via play-services-auth 21.3.0; Settings → Import section)
✅ Accessibility (TalkBack + font scaling — 9 screens)
✅ Localización completa: EN, ES, PT (~100+ strings en resources)
⬜ Performance optimization + R8/ProGuard tuning
```

### Phase 4: Launch ⬜

```
✅ App icon: pepinillo adaptativo (fondo #2E7D32, pepinillo blanco con stripes)
    → res/drawable/ic_launcher_foreground.xml + mipmap-anydpi-v26/ic_launcher.xml
    → Incluye monochrome para Android 13+ themed icons
⬜ Registrar app en Google Play Console (app ID: dev.creapolis.pepinillo)
⬜ Agregar google-services.json → descomentar Firebase plugins en build.gradle.kts
⬜ Generar release keystore (guardar en vault seguro, NUNCA en el repo)
⬜ Configurar CI/CD (GitHub Actions: build + lint + unit tests)
⬜ Internal testing track (Play Store)
✅ Audio assets: 6 archivos MP3 en app/src/main/assets/sounds/
    rain (216K CC-BY), forest (656K PD), white_noise (376K CC-BY),
    cafe (296K PD), ocean (540K CC-BY), fire (324K PD)
    → Creditos en ATTRIBUTION.txt (CC-BY: Mark DiAngelo, Caroline Ford, Mike Koenig)
⬜ OEM testing (Samsung, Pixel, Xiaomi, OnePlus)
⬜ Play Store listing (screenshots, ASO, descripción)
⬜ Open beta
⬜ Staged rollout (10% → 50% → 100%)
```

---

## Blockers y Dependencias

| Blocker | Afecta | Resolución |
|---------|--------|------------|
| No `google-services.json` | Firebase Analytics/Crashlytics | Crear proyecto Firebase (Sprint 5) |
| Wear OS emulator | Testing de Tile, Complication, Data Layer | ✅ Sprint 2 implementado; verificar en emulator |
| Play Console developer account | Store listing, signing | Debe existir antes de Sprint 5 |
| Backend: endpoints `stats/daily`, `stats/weekly`, `subscriptions/verify` | Stats sync, billing verification | Trabajo en Go backend (paralelo) |
| Backend: campo `mode` en FocusSession | Mode breakdown en servidor | Expandir modelo en Go backend |

---

## Estructura del Proyecto

```
apps/android_native/
├── gradle/libs.versions.toml         ← Version catalog
├── settings.gradle.kts
├── build.gradle.kts                  ← Root (plugins apply false)
├── gradle.properties                 ← JVM 4GB, configuration cache
└── app/src/main/kotlin/dev/creapolis/pepinillo/
    ├── PepinilloApp.kt               ← @HiltAndroidApp + WorkManager config
    ├── MainActivity.kt               ← Adaptive nav (BottomBar/Rail/Drawer) + onboarding + auth gate + App Actions
    ├── core/
    │   ├── di/                       ← AppModule, DatabaseModule, NetworkModule, RepositoryModule
    │   ├── navigation/               ← PepinilloNavGraph.kt (9 screens)
    │   ├── network/                  ← PepinilloApiClient (Ktor)
    │   └── theme/                    ← Material You: Color, Theme, Type
    ├── domain/
    │   ├── model/                    ← FocusMode, FocusPhase, Task, FocusSession, etc.
    │   ├── repository/               ← Interfaces: TaskRepository, SessionRepository, StatsRepository
    │   └── service/                  ← FocusModeStrategy, ModeIntelligenceService
    ├── data/
    │   ├── local/                    ← PepinilloDatabase, 4 entidades, 3 DAOs
    │   ├── datastore/                ← UserPreferencesRepository
    │   ├── repository/               ← Impl: Task, Session, Stats
    │   └── sync/                     ← SyncEngine, SyncWorker, RecurringTaskEngine
    ├── feature/
    │   ├── focus/                    ← FocusEngine, FocusScreen, FocusForegroundService
    │   │   └── strategy/             ← Pomodoro, Flowtime, TimeBlock, Stopwatch
    │   ├── tasks/                    ← TaskListScreen, TaskDetailScreen
    │   ├── auth/                     ← AuthScreen
    │   ├── onboarding/               ← OnboardingScreen
    │   ├── analytics/                ← DashboardScreen, WeeklyReviewScreen, AchievementsSection
    │   ├── settings/                 ← SettingsScreen
    │   └── soundscape/               ← SoundscapePlayer, SoundscapeScreen
    └── platform/
        ├── billing/                  ← BillingManager (Play Billing)
        ├── calendar/                 ← GoogleCalendarManager
        ├── focusmode/                ← DndManager
        ├── googletasks/              ← GoogleTasksImportManager
        ├── health/                   ← HealthConnectManager
        ├── notification/             ← FocusNotificationManager
        ├── datalayer/                ← PhoneDataLayerManager, PhoneMessageListenerService
        ├── tile/                     ← FocusTileService
        └── widget/                   ← FocusTimerWidget, DailyStatsWidget, LockScreenTimerWidget, WidgetStateStore
```

```
wear/src/main/kotlin/dev/creapolis/pepinillo/wear/
    ├── data/
    │   ├── WearDataRepository.kt    ← StateFlows for synced data from phone
    │   ├── WearDataLayerListener.kt ← WearableListenerService receiving phone updates
    │   └── WearMessageSender.kt     ← Sends commands to phone via MessageClient
    ├── presentation/
    │   └── WearFocusViewModel.kt    ← Uses synced data + local engine fallback
    ├── tile/
    │   └── FocusTileService.kt      ← SuspendingTileService (idle/active layouts)
    └── complication/
        └── FocusComplicationDataSource.kt ← SHORT_TEXT + LONG_TEXT
```

---

## Backend Updates Implementados

Los siguientes campos ya están en el backend Go:

- `energy_level` en el modelo de tarea ✅ (ver `apps/backend/internal/domain/task.go`)
- Recurrence fields en tarea ✅ (migración `000003_add_task_energy_recurrence`)
- Device tokens para push notifications ✅ (migración `000004_add_device_tokens`)

Pendientes de backend:

```
⬜ Endpoint GET /api/v1/stats/daily
⬜ Endpoint GET /api/v1/stats/weekly
⬜ Endpoint POST /api/v1/subscriptions/verify (Play receipt verification)
⬜ Expandir modelo sesión: agregar campo `mode`
```

---

## Gotchas y Decisiones Técnicas Clave

| Problema | Solución |
|----------|----------|
| SoundscapePlayer crashea con assets faltantes | `Player.Listener.onPlayerError` → emite `ERROR` en StateFlow; UI muestra mensaje y spinner en lugar de crashear |
| Hilt 2.52 no puede leer Kotlin 2.1.0 metadata | Usar Kotlin **2.0.21** + KSP **2.0.21-1.0.28** |
| Circuit `@CircuitInject` KSP genera warnings | Wiring manual en `AppModule.provideCircuit()` |
| Glance: `currentState<T>()` con custom class falla | Usar `PreferencesGlanceStateDefinition` + `Preferences` |
| Glance widgets no usan stringResource() | Usar `context.getString(R.string.xxx)` en su lugar |
| `libs.versions.toml` cargado dos veces | Gradle 8 lo auto-descubre; NO usar `from()` en `settings.gradle.kts` |
| `kotlin-parcelize` conflicto de versión | `id("kotlin-parcelize")` sin versión (bundled con Kotlin) |
| Destructuring con >5 componentes en Kotlin | Usar `when(state)` + asignaciones explícitas |
| `android:roundIcon` sin mipmap → AAPT fail | Removido de `<application>` tag |
| Firebase sin `google-services.json` → build fail | Plugins comentados; activar manualmente |
| Health Connect API experimental | `@OptIn(ExperimentalMindfulnessSessionApi, ExperimentalDeduplicationApi)` |
| Foreground Service en Android 14+ | `FOREGROUND_SERVICE_SPECIAL_USE` + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` en Manifest |
| Google Tasks import sin OAuth Client ID | `GoogleTasksImportManager.getSignInIntent()` lanza el flujo estándar de GMS; para producción se necesita crear un OAuth 2.0 Client ID en Google Cloud Console (tipo Android) y agregar el SHA-1 del keystore |
| Lock screen widget Android 14+ | `widgetCategory="home_screen|keyguard"` en widget info XML |
| Adaptive layouts en Circuit screens | `BoxWithConstraints` local (no threadear WindowSizeClass por Circuit); branching en `maxWidth >= 600.dp` |
| NavigationRail vs BottomBar | `calculateWindowSizeClass(activity)` en `setContent{}`, pasar `widthSizeClass` a `MainScaffold` |
| App Actions deep links | Scheme `pepinillo://focus/{start\|stop\|status}` + `android:launchMode="singleTask"` para `onNewIntent` |

---

## Documentos del PRD

| # | Documento | Descripción |
|---|-----------|-------------|
| 01 | `01_PRD_PEPINILLO_ANDROID.md` | PRD principal: visión, features, monetización, métricas |
| 02 | `02_COMPETITIVE_ANALYSIS.md` | Análisis competitivo Android |
| 03 | `03_TECHNICAL_ARCHITECTURE.md` | Stack, estructura, código de ejemplo |
| 04 | `04_EFFORT_ESTIMATION_ROADMAP.md` | Estimación de horas y roadmap por fases |
| 05 | `05_CLAUDE_CODE_COLLABORATION_GUIDE.md` | Cómo usar Claude Code efectivamente |
| 06 | `06_FLUTTER_TO_ANDROID_MIGRATION.md` | Mapeo técnico Flutter → Android nativo |
| 07 | `siguientes-pasos.md` | Este archivo — tracking de progreso |
