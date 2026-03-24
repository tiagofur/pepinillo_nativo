# Pepinillo — Current Implementation Status

**Date:** 2026-03-24  
**Version:** 1.0  
**Status:** Active Development  
**Last Updated:** 2026-03-24  
**Update Cadence:** Per-sprint

---

## 1. General Status

| Platform        | Status                                                              | Files           | Lines Approx | Build                |
| --------------- | ------------------------------------------------------------------- | --------------- | ------------ | -------------------- |
| iOS (iPhone)    | Phases 1-3 complete (all P0 + P1)                                   | ~143 Swift      | ~30K         | Requires Xcode setup |
| watchOS         | Implemented (timer, tasks, dashboard, enhanced Smart Stack widgets) | Included in iOS | Included     | Requires Xcode setup |
| Android (phone) | Sprints 1-4 complete (Foundation + Ecosystem + Polish)              | ~97 Kotlin      | ~20K         | BUILD SUCCESSFUL     |
| Wear OS         | Implemented (timer, tasks, stats, tile, complication)               | ~18 Kotlin      | ~5K          | BUILD SUCCESSFUL     |
| Backend (Go)    | Complete REST API (not deployed)                                    | ~50 Go          | ~8K          | Functional locally   |

---

## 2. iOS — Implemented

### Focus Engine ✅

- **FocusEngine** (Swift Actor) with 4 strategies: Pomodoro, Flowtime, TimeBlock, Stopwatch
- Strategy pattern via `FocusModeProtocol` — all 4 modes share ~80% of code
- Session journaling (detailed record per session)
- Task linking (link active task to focus session)
- Soundscape picker integrated in focus view
- Mode Intelligence banner (suggests optimal mode based on history)
- ADHD-friendly breaks (configurable per mode)

### Tasks ✅

- Full CRUD with drag-to-reorder
- Subtasks (nested tasks)
- Priority + energy levels (deep/shallow/admin)
- Recurring tasks (iCalendar RRULE format: daily, weekly, monthly, custom)
- Estimated and completed pomodoros per task
- Import from Apple Reminders (one-way, via EventKit)

### Analytics ✅

- 7-day, 30-day, and 1-year views
- Breakdown by focus mode
- Achievements (6 types)
- Weekly Review (current week vs. previous week comparison, trends, dominant mode)
- Monthly Review (monthly review with aggregated metrics)
- AI Reports (Apple Foundation Models + template fallback when model unavailable)
- Per-task analytics drill-down

### Apple Ecosystem ✅

- **watchOS app:** timer with 4 modes, task list, dashboard, enhanced Smart Stack widgets (rectangular with live countdown + phase + linked task, circular with actual progress, corner with live countdown), smart relevance scoring (100 active / 10 idle), 5-min refresh when active, Tasks complication (accessoryRectangular, accessoryCircular, accessoryCorner)
- **Watch-Phone connectivity:** bidirectional state sync via WatchConnectivity
- **Widgets:** Home Screen (S/M/L) + Lock Screen, all mode-aware
- **Live Activity + Dynamic Island:** 4 distinct UIs per active mode
- **Siri / App Intents:** multi-mode commands in 3 languages (EN, ES, PT)
- **Control Center widget:** quick toggle for session (iOS 18+)
- **Spotlight indexing:** tasks indexed for system search

### Integrations ✅

- **Apple Health:** Mindful Minutes (logs sessions as `HKCategorySample.mindfulSession`)
- **Apple Focus Modes:** `FocusFilterIntent` to auto-activate/deactivate DND
- **Apple Reminders import:** one-way import via EventKit
- **Sign in with Apple:** native authentication
- **CloudKit sync:** transparent sync via iCloud

### Design ✅

- 4 named themes (Classic, Forest, Ocean, Sunset) + Liquid Glass
- **Theme picker:** horizontal scroll cards with preview
- **Appearance selector:** Light / Dark / System
- **Focus mode colors:** consistent colors per mode (Pomodoro=red, TimeBlock=purple, Chrono=green)
- **PRO gating:** Forest, Ocean, Sunset require PRO subscription
- Glassmorphism in key components
- Contextual haptic feedback
- Reduce Motion support (accessibility)
- 3 languages: English, Spanish, Portuguese

### Billing ✅

- **RevenueCat iOS:** Fully configured
  - SDK v5+ (wrapping StoreKit 2) with 3 products (monthly, annual, lifetime)
  - iOS Public API Key: `appl_xnChlVXXtUFhusIfJyNrNDcMGLj` (configured in code)
  - Entitlement: `pro` via RevenueCat Offerings/Packages
  - User identification integrated with Sign in with Apple flow
  - Grace period support via RevenueCat entitlements
  - Paywall implemented

### RevenueCat Backend:\*\* Secret API key configured

- Secret API Key (V2): `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (label: "Pepinillo Backend")
- Environment variable: `REVENUECAT_SECRET_KEY` (loaded via `backend/internal/config/config.go`)
- Webhook handler: `POST /api/v1/webhooks/revenuecat` (implemented and tested)
- Webhook URL (pending deployment): `https://{YOUR_DOMAIN}/api/v1/webhooks/revenuecat`
- **Authoritative Billing Endpoint:** `POST /api/v1/billing/verify` (use instead of legacy `POST /billing/verify-receipt`)
- **RevenueCat Dashboard:** Products and entitlements
  - iOS products imported (monthly, annual, lifetime)
  - Entitlements linked (premium/pro)
  - S2S notifications configured

### Pending iOS

| Item                                | Priority | Notes                                                                                                |
| ----------------------------------- | -------- | ---------------------------------------------------------------------------------------------------- |
| Feature gating enforcement          | P0       | Analytics, sync, widgets, themes are NOT actually blocked for free users                             |
| Price update to $3.99/$24.99/$49.99 | P0       | Update via RevenueCat Offerings (PRIORITY)                                                           |
| Xcode setup (non-code)              | P0       | App Group, CloudKit container, StoreKit config, targets, SPM, Info.plist, audio assets, localization |
| macOS target                        | P2       | Contemplated in roadmap but not implemented                                                          |
| iPad layouts                        | P2       | NavigationSplitView, Stage Manager, keyboard shortcuts                                               |

---

## 3. Android — Implemented

### Focus Engine ✅

- **FocusEngine** (`@Singleton`, based on coroutines + StateFlow)
- 4 modes with strategies: Pomodoro, Flowtime, TimeBlock, Stopwatch
- Foreground Service (`START_STICKY`, `FOREGROUND_SERVICE_SPECIAL_USE`)
- Persistent notification with actions (Pause/Resume/Stop)
- Session journaling and task linking

### Tasks ✅

- Full CRUD with subtasks
- Priority + energy levels (deep/shallow/admin)
- Energy batching UI (visual grouping by energy level + hourly suggestions)
- Recurring tasks (auto-generate next instance on completion)
- Google Tasks import (OAuth + REST via play-services-auth)

### Analytics ✅

- Dashboard with charts (Vico library)
- Mode breakdown (breakdown by focus mode)
- AI Reports (on-device + template fallback)
- Weekly Review (weekly comparison)
- Monthly Review (monthly review)
- Achievements with visual progress

### Android Ecosystem ✅

- **Wear OS app:** timer, task list, stats, diagnostics
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
  - Same `premium` entitlement on both platforms
- **RevenueCat Backend:** Secret API key configured
  - Secret API Key (V2): `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (label: "Pepinillo Backend")
  - Webhook handler: `POST /api/v1/webhooks/revenuecat` (implemented)
- Feature gating for subtasks & recurrence implemented (PRO badges, disabled inputs for free users)

### Pending Android

| Item                           | Priority | Notes                                                                     |
| ------------------------------ | -------- | ------------------------------------------------------------------------- |
| Feature gating enforcement     | P0       | Subtasks & recurrence gated; analytics, widgets, themes still need gating |
| Complete paywall UI            | P0       | Functional subscription screen                                            |
| Firebase Analytics/Crashlytics | P1       | Plugins commented out, missing `google-services.json`                     |
| CI/CD pipeline                 | P1       | GitHub Actions (build + lint + tests)                                     |
| Play Store listing             | P1       | Screenshots, ASO, description                                             |
| Test coverage                  | P1       | Only 3 test files, ~20 tests total                                        |
| Performance optimization       | P2       | R8/ProGuard tuning                                                        |
| OEM testing                    | P2       | Samsung, Pixel, Xiaomi, OnePlus                                           |
| Release keystore               | P1       | Generate and store in secure vault                                        |

---

## 4. Tabla de Paridad Detallada

### Motor de Enfoque

| Feature                            | iOS              | Android               | Notas                                  |
| ---------------------------------- | ---------------- | --------------------- | -------------------------------------- |
| FocusEngine (motor principal)      | ✅               | ✅                    | Swift Actor vs Kotlin coroutines       |
| Pomodoro Strategy                  | ✅               | ✅                    |                                        |
| Flowtime Strategy                  | ✅               | ✅                    |                                        |
| TimeBlock Strategy                 | ✅               | ✅                    |                                        |
| Stopwatch Strategy                 | ✅               | ✅                    |                                        |
| Session journaling                 | ✅               | ✅                    |                                        |
| Task linking                       | ✅               | ✅                    |                                        |
| ADHD-friendly breaks               | ✅               | ✅                    |                                        |
| Foreground Service / Live Activity | ✅ Live Activity | ✅ Foreground Service | Diferentes mecanismos, mismo resultado |
| Dynamic Island                     | ✅               | N/A                   | Solo iOS                               |

### Tareas

| Feature                            | iOS           | Android | Notas                                        |
| ---------------------------------- | ------------- | ------- | -------------------------------------------- |
| CRUD basico                        | ✅            | ✅      |                                              |
| Drag-to-reorder                    | ✅            | ⬜      | Android no tiene reorder implementado        |
| Subtasks                           | ✅            | ✅      |                                              |
| Priority levels                    | ✅            | ✅      |                                              |
| Energy levels (deep/shallow/admin) | ✅            | ✅      |                                              |
| Energy batching UI                 | ⬜            | ✅      | Android tiene agrupacion por energia; iOS no |
| Recurring tasks                    | ✅ iCal RRULE | ✅      | iOS usa formato iCalendar                    |
| Estimated/completed pomodoros      | ✅            | ✅      |                                              |
| Apple Reminders import             | ✅            | N/A     | Solo iOS                                     |
| Google Tasks import                | N/A           | ✅      | Solo Android                                 |

### Analytics

| Feature                       | iOS                    | Android                 | Notas                                 |
| ----------------------------- | ---------------------- | ----------------------- | ------------------------------------- |
| Dashboard con charts          | ✅ SwiftCharts         | ✅ Vico                 |                                       |
| 7-day / 30-day / 1-year views | ✅                     | ✅                      |                                       |
| Mode breakdown                | ✅                     | ✅                      |                                       |
| Achievements / logros         | ✅ 6 tipos             | ✅                      |                                       |
| Weekly Review                 | ✅                     | ✅                      |                                       |
| Monthly Review                | ✅                     | ✅                      |                                       |
| AI Reports                    | ✅ Apple FM + fallback | ✅ On-device + fallback |                                       |
| Per-task drill-down           | ✅                     | ⬜                      | Android no tiene drill-down por tarea |

### Ecosistema

| Feature                              | iOS                                               | Android                 | Notas                                                    |
| ------------------------------------ | ------------------------------------------------- | ----------------------- | -------------------------------------------------------- |
| Watch/Wear app (timer)               | ✅ watchOS                                        | ✅ Wear OS              |                                                          |
| Watch/Wear tasks                     | ✅                                                | ✅                      |                                                          |
| Watch/Wear dashboard/stats           | ✅                                                | ✅                      |                                                          |
| Watch/Wear complications (enhanced)  | ✅ Enhanced (live countdown, progress, relevance) | ✅                      | Both platforms have rich complications                   |
| Wear Focus Timer Tile (enhanced)     | N/A                                               | ✅                      | Progress arc, phase label, session counter, linked task  |
| Wear Tasks Tile                      | N/A                                               | ✅                      | Top 4 tasks with energy emoji + pomodoro progress        |
| watchOS Tasks Complication           | ✅                                                | N/A                     | accessoryRectangular, accessoryCircular, accessoryCorner |
| watchOS Smart Stack widgets          | ✅ Enhanced (live countdown, relevance scoring)   | N/A                     | Rectangular, circular, corner complications              |
| Watch-Phone sync                     | ✅ WatchConnectivity                              | ✅ Data Layer           |                                                          |
| Home Screen widgets                  | ✅                                                | ✅ Glance               |                                                          |
| Lock Screen widget                   | ✅                                                | ✅ Android 14+          |                                                          |
| Live Activity / Ongoing notification | ✅ Live Activity + DI                             | ✅ Foreground Service   |                                                          |
| Quick Settings Tile                  | N/A                                               | ✅                      | Solo Android                                             |
| Control Center widget                | ✅ iOS 18+                                        | N/A                     | Solo iOS                                                 |
| Siri / Google Assistant              | ✅ App Intents (3 langs)                          | ✅ App Actions (3 BIIs) |                                                          |
| Spotlight / Search indexing          | ✅                                                | ⬜                      | Android no tiene search indexing                         |
| iPad layouts                         | ⬜                                                | N/A                     | Contemplado pero no implementado                         |
| Tablet/foldable layouts              | N/A                                               | ✅                      | WindowSizeClass + hinge avoidance                        |
| macOS target                         | ⬜                                                | N/A                     | Contemplado pero no implementado                         |

### Integraciones

| Feature                           | iOS                              | Android            | Notas                                  |
| --------------------------------- | -------------------------------- | ------------------ | -------------------------------------- |
| Health (Mindful Minutes/Sessions) | ✅ HealthKit                     | ✅ Health Connect  |                                        |
| Calendar integration              | ⬜                               | ✅ Google Calendar | iOS no tiene integracion de calendario |
| System Focus Mode / DND           | ✅ FocusFilterIntent             | ✅ DndManager      |                                        |
| Soundscapes                       | ✅ AVAudioPlayer (4 soundscapes) | ⬜ Not implemented | Android missing; iOS has 4 functional  |
| Mode Intelligence                 | ✅                               | ✅                 |                                        |

### Auth y Sync

| Feature         | iOS                   | Android                            | Notas                           |
| --------------- | --------------------- | ---------------------------------- | ------------------------------- |
| Auth            | ✅ Sign in with Apple | ✅ JWT + Go backend                |                                 |
| Sync            | ✅ CloudKit           | ✅ Room + SyncEngine + WorkManager | Android requiere backend custom |
| Offline support | ✅                    | ✅ dirty-flag + last-write-wins    |                                 |

### Billing

| Feature                             | iOS                                | Android                                 | Notas                              |
| ----------------------------------- | ---------------------------------- | --------------------------------------- | ---------------------------------- |
| Billing SDK                         | ✅ RevenueCat SDK v5+ (StoreKit 2) | ✅ RevenueCat SDK v8.10.0 (Purchases)   | Cross-platform parity ACHIEVED     |
| Paywall UI                          | ✅                                 | ✅                                      | Ambas plataformas                  |
| Feature gating                      | ⚠️ No enforced                     | ✅ Subtasks/recurrence gated            | iOS: otros features aún sin gating |
| Productos (monthly/annual/lifetime) | ✅ 3 productos via RevenueCat      | ✅ 3 productos: monthly/annual/lifetime | Configurados en RevenueCat         |
| Entitlements verification           | ✅ RevenueCat entitlements (`pro`) | ✅ RevenueCat entitlements (`premium`)  | Entitlement unificado en backend   |

### Diseno y Accesibilidad

| Feature                                 | iOS                       | Android                   | Notas                                  |
| --------------------------------------- | ------------------------- | ------------------------- | -------------------------------------- |
| Theming                                 | ✅ 4 temas + Liquid Glass | ✅ 4 temas + Material You | Cross-platform parity achieved         |
| Theme picker (horizontal scroll)        | ✅                        | ✅                        | Ambas plataformas                      |
| Appearance selector (Light/Dark/System) | ✅                        | ✅                        |                                        |
| Focus mode colors (red/purple/green)    | ✅                        | ✅                        | Consistente en ambas plataformas       |
| Wear OS / watchOS theme sync            | ✅ WatchConnectivity      | ✅ Data Layer             | Phone -> watch                         |
| Glassmorphism                           | ✅                        | ⬜                        | Solo iOS                               |
| Haptic feedback                         | ✅                        | ⬜                        | Android no tiene haptics implementados |
| Reduce Motion                           | ✅                        | ⬜                        |                                        |
| VoiceOver / TalkBack                    | ✅                        | ✅                        |                                        |
| Dynamic Type / Font scaling             | ✅                        | ✅                        |                                        |
| Shimmer loading                         | ⬜                        | ✅                        | Solo Android                           |
| Localizacion (EN, ES, PT)               | ✅                        | ✅                        |                                        |

---

## 5. Stack Actual

### iOS

| Capa            | Tecnologia                        | Version     | Notas                                             |
| --------------- | --------------------------------- | ----------- | ------------------------------------------------- |
| Lenguaje        | Swift                             | 6           |                                                   |
| Arquitectura    | TCA (The Composable Architecture) | >= 1.17     |                                                   |
| Persistencia    | SwiftData                         | iOS 17+     |                                                   |
| Sync            | CloudKit                          | Nativo      | Gratis, transparente                              |
| UI              | SwiftUI                           | iOS 17+     |                                                   |
| Widgets         | WidgetKit                         | iOS 17+     | Home + Lock Screen                                |
| Live Activities | ActivityKit                       | iOS 16.1+   | + Dynamic Island                                  |
| Watch           | WatchConnectivity                 | watchOS 10+ |                                                   |
| Intents         | App Intents                       | iOS 17+     | 3 idiomas                                         |
| Health          | HealthKit                         | iOS 17+     | Mindful Minutes                                   |
| Billing         | RevenueCat SDK v5+                | iOS 17+     | Wraps StoreKit 2, 3 productos, entitlement: `pro` |
| Audio           | AVAudioPlayer                     | Nativo      | Soundscapes                                       |

### Android

| Capa               | Tecnologia                               | Version        | Notas                                                        |
| ------------------ | ---------------------------------------- | -------------- | ------------------------------------------------------------ |
| Lenguaje           | Kotlin                                   | 2.0.21         | Limitado por Hilt 2.52 (no soporta metadata de Kotlin 2.1.x) |
| KSP                | ksp                                      | 2.0.21-1.0.28  | Debe coincidir con Kotlin                                    |
| Build              | AGP                                      | 8.10.0         | Gradle 8.14.3                                                |
| UI                 | Jetpack Compose + Material 3             | BOM 2025.03.00 |                                                              |
| Arquitectura       | Circuit (MVI)                            | 0.24.0         | Wiring manual en AppModule (sin @CircuitInject KSP)          |
| DI                 | Hilt                                     | 2.52           | @AssistedInject para Circuit Presenters                      |
| Persistencia       | Room                                     | 2.7.0          | KSP, exportSchema=true                                       |
| Networking         | Ktor                                     | 3.1.0          | OkHttp engine                                                |
| Widgets            | Glance                                   | 1.1.1          | PreferencesGlanceStateDefinition                             |
| Sync               | WorkManager                              | 2.10.0         | hilt-work 1.2.0                                              |
| Charts             | Vico                                     | 1.14.0         | compose-m3                                                   |
| Audio              | Media3/ExoPlayer                         | 1.5.0          | Soundscapes                                                  |
| Billing            | RevenueCat Purchases SDK                 | v8.10.0        | Fully integrated with shared `premium` entitlement           |
| Health             | Health Connect                           | 1.1.0-rc01     | API experimental                                             |
| Adaptive           | material3-window-size-class              | via BOM        | WindowWidthSizeClass                                         |
| Foldable           | androidx.window                          | 1.3.0          | FoldingFeature + hinge avoidance                             |
| Wear Tiles         | Tiles 1.4.1 + ProtoLayout Material 1.2.1 | 1.4.1          | Enhanced FocusTileService + TasksTileService                 |
| Wear Complications | watchface-complications                  | 1.2.1          | SuspendingComplicationDataSourceService                      |
| Wear Data Layer    | play-services-wearable                   | 18.2.0         | DataClient + MessageClient                                   |
| Firebase           | --                                       | --             | Plugins comentados; activar con google-services.json         |

---

## 6. Backend (Go)

### Arquitectura

- **Patron:** Hexagonal (puertos y adaptadores)
- **Lenguaje:** Go 1.24
- **Framework HTTP:** Fiber v2
- **ORM / DB:** GORM + PostgreSQL
- **Directorio:** `backend/`

### Estado del Backend

| Componente                          | Estado             | Detalle                                                                         |
| ----------------------------------- | ------------------ | ------------------------------------------------------------------------------- |
| API REST completa                   | ✅ Implementado    | Auth (email/password), tasks CRUD + sync, sessions, stats, user profile         |
| Billing verify (ambas tiendas)      | ✅ Implementado    | Verificacion de recibos App Store y Google Play via RevenueCat                  |
| RevenueCat webhook endpoint         | ✅ Implementado    | `POST /api/v1/webhooks/revenuecat` para eventos de ciclo de vida de suscripcion |
| RevenueCat REST API client          | ✅ Implementado    | Client servidor para verificacion server-side de entitlements                   |
| Direct App Store/Play verification  | ✅ Implementado    | Fallback para verificacion si RevenueCat no disponible                          |
| Subscription lifecycle events       | ✅ Implementado    | purchase, renewal, cancellation, expiration, billing issues                     |
| Push notifications                  | ✅ Implementado    | APNS (iOS) + FCM (Android)                                                      |
| WebSocket                           | ✅ Implementado    | Canal de comunicacion en tiempo real                                            |
| AI Insights                         | ✅ Implementado    | Integracion con Gemini para reportes de productividad                           |
| OAuth social login                  | ❌ No implementado | Google Sign-In y Sign In with Apple faltan como providers                       |
| Coordinacion multi-device real-time | ❌ No implementado | WebSocket existe pero falta logica de coordinacion entre dispositivos           |
| Despliegue                          | ❌ No desplegado   | Necesita hosting (Railway/Fly.io/VPS) + PostgreSQL + Redis                      |

### Endpoints Implementados

| Endpoint                         | Metodo     | Descripcion                                       |
| -------------------------------- | ---------- | ------------------------------------------------- |
| `/api/v1/auth/register`          | POST       | Registro de usuario (email/password)              |
| `/api/v1/auth/login`             | POST       | Login con JWT                                     |
| `/api/v1/tasks`                  | GET/POST   | Listar y crear tareas                             |
| `/api/v1/tasks/:id`              | PUT/DELETE | Actualizar y eliminar tareas                      |
| `/api/v1/tasks/sync`             | POST       | Sincronizacion de tareas con dirty flags          |
| `/api/v1/sessions`               | GET/POST   | Listar y crear sesiones de enfoque                |
| `/api/v1/stats`                  | GET        | Estadisticas de productividad                     |
| `/api/v1/user`                   | GET/PUT    | Perfil de usuario                                 |
| `/api/v1/billing/verify`         | POST       | Verificacion de recibos (App Store + Google Play) |
| `/api/v1/notifications/register` | POST       | Registro de device token (APNS/FCM)               |
| `/ws`                            | WebSocket  | Canal de comunicacion en tiempo real              |

### Integracion con Clientes

| Plataforma | Estado         | Detalle                                                            |
| ---------- | -------------- | ------------------------------------------------------------------ |
| Android    | 🔄 Parcial     | Auth client + SyncEngine existen, conectan a endpoints del backend |
| iOS        | ❌ No iniciado | iOS actualmente usa CloudKit solamente; necesita API client nuevo  |
| Wear OS    | 🔄 Parcial     | Hereda sync de Android phone via Data Layer                        |
| watchOS    | ❌ No iniciado | Hereda de iOS phone via WatchConnectivity                          |

### Migraciones Aplicadas

| Migracion | Descripcion                                      |
| --------- | ------------------------------------------------ |
| 000001    | Tablas iniciales (users, tasks, sessions)        |
| 000002    | Campos base                                      |
| 000003    | `energy_level` + campos de recurrencia en tareas |
| 000004    | Device tokens para push notifications            |

### Trabajo Pendiente del Backend (ordenado por prioridad)

| #   | Tarea                                                                 | Prioridad | Dependencias       | Estimacion |
| --- | --------------------------------------------------------------------- | --------- | ------------------ | ---------- |
| 1   | Desplegar backend a hosting en la nube                                | P0        | Ninguna            | 4-8h       |
| 2   | Agregar OAuth providers (Google + Apple) al backend                   | P0        | #1 (despliegue)    | 8-12h      |
| 3   | Android: Agregar Google Sign-In via Credential Manager                | P0        | #2 (OAuth backend) | 6-8h       |
| 4   | iOS: Crear API client, conectar auth + sync al backend                | P0        | #2 (OAuth backend) | 16-24h     |
| 5   | Mejorar sync engine (WebSocket real-time, bidireccional multi-device) | P1        | #1 (despliegue)    | 12-16h     |
| 6   | Verificacion cross-platform de suscripciones                          | P1        | #1, #4             | 8-12h      |
| 7   | Pantalla de perfil de usuario (ambas plataformas)                     | P1        | #2, #3, #4         | 8-12h      |

---

## 7. Production Audit Fixes (2026-03-20)

The following issues were identified during a production readiness audit and have been fixed:

### Monetization Fixes

| Fix                               | Platform | Details                                                                                                   |
| --------------------------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| Subtasks & recurrence PRO gating  | Android  | `FeatureGate` injected into `TaskDetailViewModel`; UI shows PRO badges and disables inputs for free users |
| `acknowledgePurchase` retry logic | Android  | Exponential backoff (3 retries), persistent fallback to SharedPreferences, retry on next app launch       |
| Subscription grace period buffer  | iOS      | 3-day buffer added before revoking access after subscription expiry                                       |

### Stability Fixes

| Fix                                   | Platform | Details                                                                                 |
| ------------------------------------- | -------- | --------------------------------------------------------------------------------------- |
| Timer crash recovery for Paused state | Android  | Timer now saves `Paused` state (previously only saved `Running`/`WaitingForNext`)       |
| POST_NOTIFICATIONS permission check   | Android  | `FocusTimerService` checks permission before calling `notify()` on Android 13+ (API 33) |

### Quality Fixes

| Fix                              | Platform | Details                                                                                    |
| -------------------------------- | -------- | ------------------------------------------------------------------------------------------ |
| Notification string localization | iOS      | 12 notification strings now use `String(localized:)` instead of hardcoded English          |
| Notification string localization | Android  | 8 strings in `FocusTimerService` + `DailyReminderWorker` now use `getString(R.string.xxx)` |
| Wear OS data sync retry          | Wear OS  | Data layer sync now retries failed pushes up to 2 times with 1-second delay                |

### Remaining Items (Not Yet Fixed)

| Item                         | Platform | Details                                                 |
| ---------------------------- | -------- | ------------------------------------------------------- |
| Live Activity is a stub      | iOS      | Not wired to TCA; needs full integration                |
| SwiftData migration strategy | iOS      | No `ModelVersion`/`VersionedSchema` defined             |
| Soundscapes not implemented  | Android  | iOS has 4 functional soundscapes; Android still missing |
| Accessibility labels         | iOS      | 29 labels currently; could use more coverage            |

---

## 8. Sync Engine Fixes (2026-03-22)

Sync implementation enhancements to improve cross-platform reliability and data completeness.

### Android SyncEngine Fixes

| Fix                       | Details                                                                                         |
| ------------------------- | ----------------------------------------------------------------------------------------------- |
| Subtasks in sync DTOs     | Subtasks now included in task sync payloads (previously omitted, breaking subtask sync)         |
| PomodoroSessionDto userId | Now populates `userId` from AuthStore (previously empty/null)                                   |
| PomodoroSessionDto taskId | Now resolves `linkedTaskId` → `serverId` before sending (previously empty/null)                 |
| Task soft-delete for sync | Changed `deleteTaskById` (hard-delete) to `softDelete` in TaskRepository for sync compatibility |

### iOS SyncClient Fixes

| Fix                   | Details                                                        |
| --------------------- | -------------------------------------------------------------- |
| Subtasks in sync DTOs | Subtask inclusion fixed for cross-platform parity with Android |
| userId population     | Session sync now properly populates `userId` field             |

### Remaining Sync Gaps

| Gap               | Platform(s) | Impact                                                     | Priority |
| ----------------- | ----------- | ---------------------------------------------------------- | -------- |
| Session sync stub | iOS         | Session data not synced to backend                         | P1       |
| Focus config sync | Both        | Focus configs (`GET/PUT /pomodoro/config`) not implemented | P2       |
| Daily stats sync  | Both        | No sync fields defined on DailyStats entity                | P2       |

---

## 9. Watch Complication Fixes & Tasks Parity (2026-03-24)

### Pomodoro Live Countdown Fixes

| Fix                                  | Platform | Details                                                                                  |
| ------------------------------------ | -------- | ---------------------------------------------------------------------------------------- |
| Tile countdown updates live          | Wear OS  | Pomodoro timer tile was stuck/static; now updates countdown in real time                 |
| Complication countdown at progress=0 | watchOS  | Pomodoro complication now shows live countdown even when progress=0 (timer just started) |

### watchOS Tasks Complication (New)

| Complication Family  | Content                               |
| -------------------- | ------------------------------------- |
| accessoryRectangular | Top tasks list with completion status |
| accessoryCircular    | Completed tasks count                 |
| accessoryCorner      | Task count badge                      |

**Cross-platform parity:** Tasks complication/tile now available on BOTH Wear OS (TasksTileService) and watchOS (TasksComplication). Pomodoro live countdown verified working on both platforms.

---

## 10. Resumen de Brechas Criticas

### Ambas Plataformas

| Brecha                      | iOS                 | Android                    | Impacto                                                                            |
| --------------------------- | ------------------- | -------------------------- | ---------------------------------------------------------------------------------- |
| Sync engine gaps            | ⚠️ Parcial          | ⚠️ Parcial                 | Subtasks/sessions/configs sync now fixed; daily stats sync still pending           |
| Feature gating no enforced  | ⚠️                  | ⚠️ Partial                 | Android: subtasks/recurrence gated. iOS + other Android features still need gating |
| Backend endpoints faltantes | Bajo (usa CloudKit) | Alto (depende del backend) | Stats y billing verification                                                       |

### Solo iOS

| Brecha                              | Impacto                 | Esfuerzo             |
| ----------------------------------- | ----------------------- | -------------------- |
| Setup Xcode (no-codigo)             | Bloquea cualquier build | 2-4h manual          |
| Precios desactualizados en StoreKit | Revenue suboptimo       | 1h                   |
| iPad/macOS no implementados         | Reduce TAM              | 48h (roadmap Fase 2) |

### Solo Android

| Brecha                           | Impacto                          | Esfuerzo                  |
| -------------------------------- | -------------------------------- | ------------------------- |
| Firebase sin configurar          | Sin analytics ni crash reporting | 2h + google-services.json |
| CI/CD inexistente                | Sin build automatizado           | 4-6h                      |
| Test coverage minima (~20 tests) | Riesgo de regresiones            | 15-20h                    |
| Release keystore no generado     | Bloquea publicacion              | 1h                        |
| OEM testing pendiente            | Bugs en Samsung/Xiaomi           | 20h                       |
| Paywall UI incompleta            | Sin conversion a pago            | 8-10h                     |
