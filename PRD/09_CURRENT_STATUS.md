# Estado Actual del Proyecto — Pepinillo

**Fecha:** Marzo 2026
**Versión:** 1.0

---

## 1. Estado General

| Plataforma | Estado | Archivos | Lineas aprox | Build |
|------------|--------|----------|-------------|-------|
| iOS (iPhone) | Fases 1-3 completas (todos los P0 + P1) | ~143 Swift | ~30K | Requiere setup Xcode |
| watchOS | Implementado (timer, tasks, dashboard, enhanced Smart Stack widgets) | Incluido en iOS | Incluido | Requiere setup Xcode |
| Android (phone) | Sprints 1-4 completos (Foundation + Ecosystem + Polish) | ~97 Kotlin | ~20K | BUILD SUCCESSFUL |
| Wear OS | Implementado (timer, tasks, stats, tile, complication) | ~18 Kotlin | ~5K | BUILD SUCCESSFUL |
| Backend (Go) | API REST completa (no desplegado) | ~50 Go | ~8K | Funcional local |

---

## 2. iOS — Implementado

### Motor de Enfoque ✅
- **FocusEngine** (Swift Actor) con 4 estrategias: Pomodoro, Flowtime, TimeBlock, Stopwatch
- Strategy pattern via `FocusModeProtocol` — los 4 modos comparten ~80% del codigo
- Session journaling (registro detallado de cada sesion)
- Task linking (vincular tarea activa a sesion de enfoque)
- Soundscape picker integrado en la vista de enfoque
- Mode Intelligence banner (sugiere modo optimo basado en historial)
- Breaks ADHD-friendly (configurable por modo)

### Tareas ✅
- CRUD completo con drag-to-reorder
- Subtasks (sub-tareas dentro de cada tarea)
- Prioridad + energy levels (deep/shallow/admin)
- Tareas recurrentes (formato iCalendar RRULE: diaria, semanal, mensual, personalizada)
- Pomodoros estimados y completados por tarea
- Import desde Apple Reminders (one-way, via EventKit)

### Analytics ✅
- Vistas de 7 dias, 30 dias y 1 anio
- Breakdown por modo de enfoque
- Achievements / logros (6 tipos)
- Weekly Review (comparativa semana actual vs anterior, tendencias, modo dominante)
- Monthly Review (revision mensual con metricas agregadas)
- AI Reports (Apple Foundation Models + fallback a template cuando el modelo no esta disponible)
- Drill-down de analytics por tarea individual

### Ecosistema Apple ✅
- **watchOS app:** timer con 4 modos, lista de tareas, dashboard, enhanced Smart Stack widgets (rectangular with live countdown + phase + linked task, circular with actual progress, corner with live countdown), smart relevance scoring (100 active / 10 idle), 5-min refresh when active
- **Watch-Phone connectivity:** sync bidireccional de estado via WatchConnectivity
- **Widgets:** Home Screen (S/M/L) + Lock Screen, todos mode-aware
- **Live Activity + Dynamic Island:** 4 UIs distintas segun el modo activo
- **Siri / App Intents:** comandos multi-modo en 3 idiomas (EN, ES, PT)
- **Control Center widget:** toggle rapido de sesion (iOS 18+)
- **Spotlight indexing:** tareas indexadas para busqueda del sistema

### Integraciones ✅
- **Apple Health:** Mindful Minutes (registra sesiones como `HKCategorySample.mindfulSession`)
- **Apple Focus Modes:** `FocusFilterIntent` para activar/desactivar DND automaticamente
- **Apple Reminders import:** importacion one-way via EventKit
- **Sign in with Apple:** autenticacion nativa
- **CloudKit sync:** sincronizacion transparente via iCloud

### Diseno ✅
- 4 temas nombrados (Classic, Forest, Ocean, Sunset) + Liquid Glass
- **Theme picker:** horizontal scroll cards con preview
- **Appearance selector:** Light / Dark / System
- **Focus mode colors:** colores consistentes por modo (Pomodoro=rojo, TimeBlock=morado, Chrono=verde)
- **PRO gating:** Forest, Ocean, Sunset requieren suscripcion PRO
- Glassmorphism en componentes clave
- Haptic feedback contextual
- Soporte Reduce Motion (accesibilidad)
- 3 idiomas: Ingles, Espanol, Portugues

### Billing ✅
- **RevenueCat iOS:** Fully configured
  - SDK v5+ (wrapping StoreKit 2) con 3 productos (monthly, annual, lifetime)
  - iOS Public API Key: `appl_xnChlVXXtUFhusIfJyNrNDcMGLj` (configured in code)
  - Entitlement: `pro` via RevenueCat Offerings/Packages
  - User identification integrated with Sign in with Apple flow
  - Grace period support via RevenueCat entitlements
  - Paywall implementado
- **RevenueCat Backend:** Secret API key created
  - Secret API Key (V2): `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (label: "Pepinillo Backend")
  - Environment variable: `REVENUECAT_SECRET_KEY` (loaded in `backend/internal/config/config.go`)
  - Webhook handler: `POST /api/v1/webhooks/revenuecat` (implemented)
  - Webhook URL pending deployment: `https://{YOUR_DOMAIN}/api/v1/webhooks/revenuecat`
- **RevenueCat Dashboard:** Products and entitlements
  - iOS products imported (monthly, annual, lifetime)
  - Entitlements linked (premium/pro)
  - S2S notifications configured

### Pendiente iOS

| Item | Prioridad | Notas |
|------|-----------|-------|
| Feature gating enforcement | P0 | Analytics, sync, widgets, themes no estan realmente bloqueados para usuarios free |
| Actualizacion de precios | P1 | Cambiar de $2.99/$14.99/$29.99 a $3.99/$24.99/$49.99 |
| Setup Xcode (no-codigo) | P0 | App Group, CloudKit container, StoreKit config, targets, SPM, Info.plist, audio assets, localizacion |
| macOS target | P2 | Contemplado en roadmap pero no implementado |
| iPad layouts | P2 | NavigationSplitView, Stage Manager, keyboard shortcuts |

---

## 3. Android — Implementado

### Motor de Enfoque ✅
- **FocusEngine** (`@Singleton`, basado en coroutines + StateFlow)
- 4 modos con estrategias: Pomodoro, Flowtime, TimeBlock, Stopwatch
- Foreground Service (`START_STICKY`, `FOREGROUND_SERVICE_SPECIAL_USE`)
- Notificacion persistente con acciones (Pause/Resume/Stop)
- Session journaling y task linking

### Tareas ✅
- CRUD completo con subtasks
- Prioridad + energy levels (deep/shallow/admin)
- Energy batching UI (agrupacion visual por nivel de energia + sugerencias por hora del dia)
- Tareas recurrentes (generacion automatica de proxima instancia al completar)
- Google Tasks import (OAuth + REST via play-services-auth)

### Analytics ✅
- Dashboard con charts (Vico library)
- Mode breakdown (desglose por modo de enfoque)
- AI Reports (on-device + template fallback)
- Weekly Review (comparativa semanal)
- Monthly Review (revision mensual)
- Achievements / logros con progreso visual

### Ecosistema Android ✅
- **Wear OS app:** timer, lista de tareas, stats, diagnosticos
- **Wear Focus Timer Tile:** Enhanced `FocusTileService` with progress arc (colored by mode), timer display, phase label, session counter, linked task name. Distinct idle/running/paused states. Built with Tiles 1.4.1 + ProtoLayout Material 1.2.1.
- **Wear Tasks Tile:** New `TasksTileService` showing top 4 tasks with energy emoji, truncated title, pomodoro progress, and completed/total header.
- **WearSnapshotStore extended:** Now persists linkedTaskId, linkedTaskName, completedSessions, and theme colors for tile access.
- **Wear Complication:** `FocusComplicationDataSource` (SHORT_TEXT + LONG_TEXT)
- **Wear Data Layer sync:** bidireccional (phone-watch) con fallback local
- **Widgets Glance:** FocusTimerWidget, DailyStatsWidget (Home Screen)
- **Lock Screen widget:** LockScreenTimerWidget (Android 14+, categoria KEYGUARD)
- **Quick Settings Tile:** FocusTileService (Android 7+)
- **Google Assistant App Actions:** 3 BIIs + 4 shortcuts + deep links `pepinillo://focus/`
- **Ongoing notification:** con acciones Pause/Resume/Stop
- **Adaptive layouts:** WindowSizeClass, NavigationRail (medium), PermanentNavigationDrawer (expanded)
- **Two-pane layouts:** FocusScreen, TaskListScreen master-detail, DashboardScreen multi-column, SettingsScreen two-column
- **Foldable:** hinge avoidance via `androidx.window` 1.3.0

### Integraciones ✅
- **Google Calendar UI:** runtime permissions, toggle en Settings, bloqueo de tiempo al completar sesion WORK
- **Health Connect:** Mindful Sessions (API experimental)
- **Auth JWT + Go backend:** login/register via Ktor
- **Room + Sync Engine:** dirty-flag strategy, last-write-wins por `updatedAt`, WorkManager periodico 15 min
- **DND / Focus Mode:** `DndManager` activa Do Not Disturb durante sesiones

### Diseno ✅
- **Unified theme system:** 4 temas nombrados (Classic, Forest, Ocean, Sunset) + Material You dynamic colors
- **Theme picker:** horizontal scroll cards con preview de cada tema
- **Focus mode colors:** colores consistentes por modo (Pomodoro=rojo, TimeBlock=morado, Chrono=verde)
- **PRO gating:** Forest, Ocean, Sunset requieren suscripcion PRO
- **Wear OS theme sync:** el tema seleccionado en el phone se sincroniza al reloj via Data Layer API
- Material 3 + Material You (dynamic color)
- Adaptive layouts (phone, tablet, foldable con hinge avoidance)
- Shimmer loading placeholders
- 3 idiomas: Ingles, Espanol, Portugues
- App icon adaptativo con soporte monochrome (Android 13+)

### Billing ✅
- **RevenueCat Android:** Fully configured
  - SDK v8.10.0 (Purchases SDK) integrado
  - Android Public API Key: `goog_ITPYSPEdubAzAeoNGxezZuZJELT` (configured in code)
  - Product IDs: com.pepinillo.app.pro.monthly, com.pepinillo.app.pro.annual, com.pepinillo.app.pro.lifetime
  - Entitlement: `premium` (shared with iOS via RevenueCat)
  - User identification integrated with auth flow
  - Grace period support via RevenueCat entitlements
  - Paywall implementado
- **Cross-platform parity:** iOS y Android ahora ambas usan RevenueCat (LOGRADO)
  - iOS utiliza RevenueCat SDK v5+ (wrapping StoreKit 2)
  - Android utiliza RevenueCat Purchases SDK v8.10.0
  - Mismo entitlement `premium` en ambas plataformas
- **RevenueCat Backend:** Secret API key existente
  - Secret API Key (V2): `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (label: "Pepinillo Backend")
  - Webhook handler: `POST /api/v1/webhooks/revenuecat` (implementado)
- Feature gating for subtasks & recurrence implemented (PRO badges, disabled inputs for free users)

### Pendiente Android

| Item | Prioridad | Notas |
|------|-----------|-------|
| Feature gating enforcement | P0 | Subtasks & recurrence gated; other features still need gating |
| Paywall UI completa | P0 | Pantalla de suscripcion funcional |
| Firebase Analytics/Crashlytics | P1 | Plugins comentados, falta `google-services.json` |
| CI/CD pipeline | P1 | GitHub Actions (build + lint + tests) |
| Play Store listing | P1 | Screenshots, ASO, descripcion |
| Test coverage | P1 | Solo 3 archivos de test, ~20 tests |
| Performance optimization | P2 | R8/ProGuard tuning |
| OEM testing | P2 | Samsung, Pixel, Xiaomi, OnePlus |
| Release keystore | P1 | Generar y guardar en vault seguro |

---

## 4. Tabla de Paridad Detallada

### Motor de Enfoque

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| FocusEngine (motor principal) | ✅ | ✅ | Swift Actor vs Kotlin coroutines |
| Pomodoro Strategy | ✅ | ✅ | |
| Flowtime Strategy | ✅ | ✅ | |
| TimeBlock Strategy | ✅ | ✅ | |
| Stopwatch Strategy | ✅ | ✅ | |
| Session journaling | ✅ | ✅ | |
| Task linking | ✅ | ✅ | |
| ADHD-friendly breaks | ✅ | ✅ | |
| Foreground Service / Live Activity | ✅ Live Activity | ✅ Foreground Service | Diferentes mecanismos, mismo resultado |
| Dynamic Island | ✅ | N/A | Solo iOS |

### Tareas

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| CRUD basico | ✅ | ✅ | |
| Drag-to-reorder | ✅ | ⬜ | Android no tiene reorder implementado |
| Subtasks | ✅ | ✅ | |
| Priority levels | ✅ | ✅ | |
| Energy levels (deep/shallow/admin) | ✅ | ✅ | |
| Energy batching UI | ⬜ | ✅ | Android tiene agrupacion por energia; iOS no |
| Recurring tasks | ✅ iCal RRULE | ✅ | iOS usa formato iCalendar |
| Estimated/completed pomodoros | ✅ | ✅ | |
| Apple Reminders import | ✅ | N/A | Solo iOS |
| Google Tasks import | N/A | ✅ | Solo Android |

### Analytics

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| Dashboard con charts | ✅ SwiftCharts | ✅ Vico | |
| 7-day / 30-day / 1-year views | ✅ | ✅ | |
| Mode breakdown | ✅ | ✅ | |
| Achievements / logros | ✅ 6 tipos | ✅ | |
| Weekly Review | ✅ | ✅ | |
| Monthly Review | ✅ | ✅ | |
| AI Reports | ✅ Apple FM + fallback | ✅ On-device + fallback | |
| Per-task drill-down | ✅ | ⬜ | Android no tiene drill-down por tarea |

### Ecosistema

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| Watch/Wear app (timer) | ✅ watchOS | ✅ Wear OS | |
| Watch/Wear tasks | ✅ | ✅ | |
| Watch/Wear dashboard/stats | ✅ | ✅ | |
| Watch/Wear complications (enhanced) | ✅ Enhanced (live countdown, progress, relevance) | ✅ | Both platforms have rich complications |
| Wear Focus Timer Tile (enhanced) | N/A | ✅ | Progress arc, phase label, session counter, linked task |
| Wear Tasks Tile | N/A | ✅ | Top 4 tasks with energy emoji + pomodoro progress |
| watchOS Smart Stack widgets | ✅ Enhanced (live countdown, relevance scoring) | N/A | Rectangular, circular, corner complications |
| Watch-Phone sync | ✅ WatchConnectivity | ✅ Data Layer | |
| Home Screen widgets | ✅ | ✅ Glance | |
| Lock Screen widget | ✅ | ✅ Android 14+ | |
| Live Activity / Ongoing notification | ✅ Live Activity + DI | ✅ Foreground Service | |
| Quick Settings Tile | N/A | ✅ | Solo Android |
| Control Center widget | ✅ iOS 18+ | N/A | Solo iOS |
| Siri / Google Assistant | ✅ App Intents (3 langs) | ✅ App Actions (3 BIIs) | |
| Spotlight / Search indexing | ✅ | ⬜ | Android no tiene search indexing |
| iPad layouts | ⬜ | N/A | Contemplado pero no implementado |
| Tablet/foldable layouts | N/A | ✅ | WindowSizeClass + hinge avoidance |
| macOS target | ⬜ | N/A | Contemplado pero no implementado |

### Integraciones

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| Health (Mindful Minutes/Sessions) | ✅ HealthKit | ✅ Health Connect | |
| Calendar integration | ⬜ | ✅ Google Calendar | iOS no tiene integracion de calendario |
| System Focus Mode / DND | ✅ FocusFilterIntent | ✅ DndManager | |
| Soundscapes | ✅ AVAudioPlayer (4 soundscapes) | ⬜ Not implemented | Android missing; iOS has 4 functional |
| Mode Intelligence | ✅ | ✅ | |

### Auth y Sync

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| Auth | ✅ Sign in with Apple | ✅ JWT + Go backend | |
| Sync | ✅ CloudKit | ✅ Room + SyncEngine + WorkManager | Android requiere backend custom |
| Offline support | ✅ | ✅ dirty-flag + last-write-wins | |

### Billing

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| Billing SDK | ✅ RevenueCat SDK v5+ (StoreKit 2) | ✅ RevenueCat SDK v8.10.0 (Purchases) | Cross-platform parity ACHIEVED |
| Paywall UI | ✅ | ✅ | Ambas plataformas |
| Feature gating | ⚠️ No enforced | ✅ Subtasks/recurrence gated | iOS: otros features aún sin gating |
| Productos (monthly/annual/lifetime) | ✅ 3 productos via RevenueCat | ✅ 3 productos: monthly/annual/lifetime | Configurados en RevenueCat |
| Entitlements verification | ✅ RevenueCat entitlements (`pro`) | ✅ RevenueCat entitlements (`premium`) | Entitlement unificado en backend |

### Diseno y Accesibilidad

| Feature | iOS | Android | Notas |
|---------|-----|---------|-------|
| Theming | ✅ 4 temas + Liquid Glass | ✅ 4 temas + Material You | Cross-platform parity achieved |
| Theme picker (horizontal scroll) | ✅ | ✅ | Ambas plataformas |
| Appearance selector (Light/Dark/System) | ✅ | ✅ | |
| Focus mode colors (red/purple/green) | ✅ | ✅ | Consistente en ambas plataformas |
| Wear OS / watchOS theme sync | ✅ WatchConnectivity | ✅ Data Layer | Phone -> watch |
| Glassmorphism | ✅ | ⬜ | Solo iOS |
| Haptic feedback | ✅ | ⬜ | Android no tiene haptics implementados |
| Reduce Motion | ✅ | ⬜ | |
| VoiceOver / TalkBack | ✅ | ✅ | |
| Dynamic Type / Font scaling | ✅ | ✅ | |
| Shimmer loading | ⬜ | ✅ | Solo Android |
| Localizacion (EN, ES, PT) | ✅ | ✅ | |

---

## 5. Stack Actual

### iOS

| Capa | Tecnologia | Version | Notas |
|------|-----------|---------|-------|
| Lenguaje | Swift | 6 | |
| Arquitectura | TCA (The Composable Architecture) | >= 1.17 | |
| Persistencia | SwiftData | iOS 17+ | |
| Sync | CloudKit | Nativo | Gratis, transparente |
| UI | SwiftUI | iOS 17+ | |
| Widgets | WidgetKit | iOS 17+ | Home + Lock Screen |
| Live Activities | ActivityKit | iOS 16.1+ | + Dynamic Island |
| Watch | WatchConnectivity | watchOS 10+ | |
| Intents | App Intents | iOS 17+ | 3 idiomas |
| Health | HealthKit | iOS 17+ | Mindful Minutes |
| Billing | RevenueCat SDK v5+ | iOS 17+ | Wraps StoreKit 2, 3 productos, entitlement: `pro` |
| Audio | AVAudioPlayer | Nativo | Soundscapes |

### Android

| Capa | Tecnologia | Version | Notas |
|------|-----------|---------|-------|
| Lenguaje | Kotlin | 2.0.21 | Limitado por Hilt 2.52 (no soporta metadata de Kotlin 2.1.x) |
| KSP | ksp | 2.0.21-1.0.28 | Debe coincidir con Kotlin |
| Build | AGP | 8.10.0 | Gradle 8.14.3 |
| UI | Jetpack Compose + Material 3 | BOM 2025.03.00 | |
| Arquitectura | Circuit (MVI) | 0.24.0 | Wiring manual en AppModule (sin @CircuitInject KSP) |
| DI | Hilt | 2.52 | @AssistedInject para Circuit Presenters |
| Persistencia | Room | 2.7.0 | KSP, exportSchema=true |
| Networking | Ktor | 3.1.0 | OkHttp engine |
| Widgets | Glance | 1.1.1 | PreferencesGlanceStateDefinition |
| Sync | WorkManager | 2.10.0 | hilt-work 1.2.0 |
| Charts | Vico | 1.14.0 | compose-m3 |
| Audio | Media3/ExoPlayer | 1.5.0 | Soundscapes |
| Billing | RevenueCat Purchases SDK | v8.10.0 | Fully integrated with shared `premium` entitlement |
| Health | Health Connect | 1.1.0-rc01 | API experimental |
| Adaptive | material3-window-size-class | via BOM | WindowWidthSizeClass |
| Foldable | androidx.window | 1.3.0 | FoldingFeature + hinge avoidance |
| Wear Tiles | Tiles 1.4.1 + ProtoLayout Material 1.2.1 | 1.4.1 | Enhanced FocusTileService + TasksTileService |
| Wear Complications | watchface-complications | 1.2.1 | SuspendingComplicationDataSourceService |
| Wear Data Layer | play-services-wearable | 18.2.0 | DataClient + MessageClient |
| Firebase | -- | -- | Plugins comentados; activar con google-services.json |

---

## 6. Backend (Go)

### Arquitectura

- **Patron:** Hexagonal (puertos y adaptadores)
- **Lenguaje:** Go 1.24
- **Framework HTTP:** Fiber v2
- **ORM / DB:** GORM + PostgreSQL
- **Directorio:** `backend/`

### Estado del Backend

| Componente | Estado | Detalle |
|------------|--------|---------|
| API REST completa | ✅ Implementado | Auth (email/password), tasks CRUD + sync, sessions, stats, user profile |
| Billing verify (ambas tiendas) | ✅ Implementado | Verificacion de recibos App Store y Google Play via RevenueCat |
| RevenueCat webhook endpoint | ✅ Implementado | `POST /api/v1/webhooks/revenuecat` para eventos de ciclo de vida de suscripcion |
| RevenueCat REST API client | ✅ Implementado | Client servidor para verificacion server-side de entitlements |
| Direct App Store/Play verification | ✅ Implementado | Fallback para verificacion si RevenueCat no disponible |
| Subscription lifecycle events | ✅ Implementado | purchase, renewal, cancellation, expiration, billing issues |
| Push notifications | ✅ Implementado | APNS (iOS) + FCM (Android) |
| WebSocket | ✅ Implementado | Canal de comunicacion en tiempo real |
| AI Insights | ✅ Implementado | Integracion con Gemini para reportes de productividad |
| OAuth social login | ❌ No implementado | Google Sign-In y Sign In with Apple faltan como providers |
| Coordinacion multi-device real-time | ❌ No implementado | WebSocket existe pero falta logica de coordinacion entre dispositivos |
| Despliegue | ❌ No desplegado | Necesita hosting (Railway/Fly.io/VPS) + PostgreSQL + Redis |

### Endpoints Implementados

| Endpoint | Metodo | Descripcion |
|----------|--------|-------------|
| `/api/v1/auth/register` | POST | Registro de usuario (email/password) |
| `/api/v1/auth/login` | POST | Login con JWT |
| `/api/v1/tasks` | GET/POST | Listar y crear tareas |
| `/api/v1/tasks/:id` | PUT/DELETE | Actualizar y eliminar tareas |
| `/api/v1/tasks/sync` | POST | Sincronizacion de tareas con dirty flags |
| `/api/v1/sessions` | GET/POST | Listar y crear sesiones de enfoque |
| `/api/v1/stats` | GET | Estadisticas de productividad |
| `/api/v1/user` | GET/PUT | Perfil de usuario |
| `/api/v1/billing/verify` | POST | Verificacion de recibos (App Store + Google Play) |
| `/api/v1/notifications/register` | POST | Registro de device token (APNS/FCM) |
| `/ws` | WebSocket | Canal de comunicacion en tiempo real |

### Integracion con Clientes

| Plataforma | Estado | Detalle |
|------------|--------|---------|
| Android | 🔄 Parcial | Auth client + SyncEngine existen, conectan a endpoints del backend |
| iOS | ❌ No iniciado | iOS actualmente usa CloudKit solamente; necesita API client nuevo |
| Wear OS | 🔄 Parcial | Hereda sync de Android phone via Data Layer |
| watchOS | ❌ No iniciado | Hereda de iOS phone via WatchConnectivity |

### Migraciones Aplicadas

| Migracion | Descripcion |
|-----------|-------------|
| 000001 | Tablas iniciales (users, tasks, sessions) |
| 000002 | Campos base |
| 000003 | `energy_level` + campos de recurrencia en tareas |
| 000004 | Device tokens para push notifications |

### Trabajo Pendiente del Backend (ordenado por prioridad)

| # | Tarea | Prioridad | Dependencias | Estimacion |
|---|-------|-----------|-------------|------------|
| 1 | Desplegar backend a hosting en la nube | P0 | Ninguna | 4-8h |
| 2 | Agregar OAuth providers (Google + Apple) al backend | P0 | #1 (despliegue) | 8-12h |
| 3 | Android: Agregar Google Sign-In via Credential Manager | P0 | #2 (OAuth backend) | 6-8h |
| 4 | iOS: Crear API client, conectar auth + sync al backend | P0 | #2 (OAuth backend) | 16-24h |
| 5 | Mejorar sync engine (WebSocket real-time, bidireccional multi-device) | P1 | #1 (despliegue) | 12-16h |
| 6 | Verificacion cross-platform de suscripciones | P1 | #1, #4 | 8-12h |
| 7 | Pantalla de perfil de usuario (ambas plataformas) | P1 | #2, #3, #4 | 8-12h |

---

## 7. Production Audit Fixes (2026-03-20)

The following issues were identified during a production readiness audit and have been fixed:

### Monetization Fixes

| Fix | Platform | Details |
|-----|----------|---------|
| Subtasks & recurrence PRO gating | Android | `FeatureGate` injected into `TaskDetailViewModel`; UI shows PRO badges and disables inputs for free users |
| `acknowledgePurchase` retry logic | Android | Exponential backoff (3 retries), persistent fallback to SharedPreferences, retry on next app launch |
| Subscription grace period buffer | iOS | 3-day buffer added before revoking access after subscription expiry |

### Stability Fixes

| Fix | Platform | Details |
|-----|----------|---------|
| Timer crash recovery for Paused state | Android | Timer now saves `Paused` state (previously only saved `Running`/`WaitingForNext`) |
| POST_NOTIFICATIONS permission check | Android | `FocusTimerService` checks permission before calling `notify()` on Android 13+ (API 33) |

### Quality Fixes

| Fix | Platform | Details |
|-----|----------|---------|
| Notification string localization | iOS | 12 notification strings now use `String(localized:)` instead of hardcoded English |
| Notification string localization | Android | 8 strings in `FocusTimerService` + `DailyReminderWorker` now use `getString(R.string.xxx)` |
| Wear OS data sync retry | Wear OS | Data layer sync now retries failed pushes up to 2 times with 1-second delay |

### Remaining Items (Not Yet Fixed)

| Item | Platform | Details |
|------|----------|---------|
| Live Activity is a stub | iOS | Not wired to TCA; needs full integration |
| SwiftData migration strategy | iOS | No `ModelVersion`/`VersionedSchema` defined |
| Soundscapes not implemented | Android | iOS has 4 functional soundscapes; Android still missing |
| Accessibility labels | iOS | 29 labels currently; could use more coverage |

---

## 8. Resumen de Brechas Criticas

### Ambas Plataformas

| Brecha | iOS | Android | Impacto |
|--------|-----|---------|---------|
| Feature gating no enforced | ⚠️ | ⚠️ Partial | Android: subtasks/recurrence gated. iOS + other Android features still need gating |
| Backend endpoints faltantes | Bajo (usa CloudKit) | Alto (depende del backend) | Stats y billing verification |

### Solo iOS

| Brecha | Impacto | Esfuerzo |
|--------|---------|----------|
| Setup Xcode (no-codigo) | Bloquea cualquier build | 2-4h manual |
| Precios desactualizados en StoreKit | Revenue suboptimo | 1h |
| iPad/macOS no implementados | Reduce TAM | 48h (roadmap Fase 2) |

### Solo Android

| Brecha | Impacto | Esfuerzo |
|--------|---------|----------|
| Firebase sin configurar | Sin analytics ni crash reporting | 2h + google-services.json |
| CI/CD inexistente | Sin build automatizado | 4-6h |
| Test coverage minima (~20 tests) | Riesgo de regresiones | 15-20h |
| Release keystore no generado | Bloquea publicacion | 1h |
| OEM testing pendiente | Bugs en Samsung/Xiaomi | 20h |
| Paywall UI incompleta | Sin conversion a pago | 8-10h |
