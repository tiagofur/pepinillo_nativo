# Arquitectura de Pepinillo

**Reconciliada**: 2026-11-10 con el código ejecutable. ADRs vinculantes:
[`docs/architecture/adr/README.md`](architecture/adr/README.md). Contrato HTTP:
[`contracts/openapi.yaml`](../contracts/openapi.yaml).

---

## 1. Visión general

```text
┌─────────────── Clientes nativos (offline-first) ───────────────┐
│  iOS/iPadOS + watchOS (Swift6·TCA·SwiftData SchemaV6)          │
│  macOS PepinilloMac (SwiftUI + AppKit)                          │
│  Android + Wear OS (Kotlin·Compose·Hilt·Room v14·Glance)        │
│  Base local: SwiftData (App Group) / Room v14                   │
└────────────┬───────────────────────────────┬───────────────────┘
             │ opcional Everywhere/AI+       │ CloudKit (Pepinillo+)
             ▼                               ▼
   Backend Go `/api/v1` (LWW autoritativo)   iCloud privado (dual-store)
   Fiber v2 + GORM + PostgreSQL 16 + Redis 7
   + sidecar opcional ml_service (FastAPI)
```

- Los clientes son **100% offline-first**: el foco, tareas y analíticas
  funcionan sin red y sin cuenta. La sync es opcional y premium.
- El backend es la **autoridad LWW** para sync cloud (reloj del servidor,
  `ResolveSyncTimestamp` con clamp de futuro).

---

## 2. Backend Go (`backend/`)

Layout hexagonal (`ADR-0001`): `cmd/api/main.go` (composition root) →
`internal/domain` (puro) → `internal/ports` (interfaces) → `internal/services`
(casos de uso) → `internal/adapters` (handlers Fiber, middleware, repos
GORM/Postgres, stores redis/memory, llm gemini/noop, push apns/fcm/mux, storage
minio/noop, notifier sendgrid, websocket hub).

- **Migraciones**: `backend/migrations/000001..000015` ejecutadas al boot con
  `golang-migrate`. Toda nueva tabla/columna añade par `up`/`down` numerado.
- **Auth**: JWT HS256 (access 15 min, refresh 30 d rotado con detección de
  robo), claims `userId/email/tier/tokenType/emailVerified`. OAuth Google
  (tokeninfo) y Apple (JWKS + nonce obligatorio + revocación al borrar cuenta).
  Códigos temporales y refresh tokens HMAC-hashed (`REFRESH_TOKEN_HASH_KEY`)
  en Redis (fallback memoria en dev).
- **Compuertas de rutas** (`routes.go`): público → `JWT` → `RequireEmailVerified`
  (403 `email_not_verified`) → `SubscriptionMiddleware` (tiers) →
  `RequireBackendSync` (402 `ERR_TIER_INSUFFICIENT`) o
  `RequireProFeatureMiddleware` (403 `feature_not_available`).
  ⚠️ En Fiber v2 los webhooks sin JWT y `/auth` público se registran **antes**
  del grupo `protected` con prefijo vacío `""`.
- **Tiers**: `free`, `pepinillo_plus` (sticky lifetime vía
  `pepinilloPlusEntitlementAt`), `everywhere_monthly`, `everywhere_annual`
  (`EffectiveTierAt`). IA cloud: 100 créditos/mes con deduct atómico y refund.
- **Sync LWW**: `ON CONFLICT (id) DO UPDATE ... WHERE EXCLUDED.updated_at > ...`,
  `ended_at` monotónico (NULL→set nunca revierte), IDOR guard reescribiendo IDs
  ajenos, stats diarias recomputadas en UTC, paginado cursor `updatedAt|id`
  (límite 1..500).
- **Webhooks RevenueCat**: dedupe `webhook_events(event_id, source)`, claims
  `purchase_claims(platform, purchase_token)` (409 si ya reclamado), ACK 200 a
  IDs anónimos no-UUID.
- **Errores**: envolvente real `ErrorEnvelope` (`{"error": ...}`) y
  `BackendSyncRequiredError` (`402 ERR_TIER_INSUFFICIENT`); RFC 9457
  `ProblemDetails` es el objetivo para endpoints nuevos (`ADR-0003`).
- **Observabilidad**: `log/slog` JSON, Sentry (Fiber middleware), `/health/*`
  (deps, metrics, prometheus, alerts, alertmanager, slo). Workers: generador de
  recurrencias 24 h y reconciliador de sesiones stale (TTL default 168 h).

---

## 3. Apple (`ios/`)

**Targets** (`ios/project.yml`, XcodeGen → `Pepinillo.xcodeproj` generado):
`Pepinillo` (iOS 17+), `PepinilloMac` (macOS 15+), `PepinilloWidgetExtension`,
`PepinilloWidgetMacExtension`, `PepinilloWatch` (watchOS 10+),
`PepinilloWatchWidgetExtension`, `PepinilloControlCenter` (iOS 18+),
`PepinilloTests`. Schemes: `Pepinillo Dev/Staging/Production` (con
`PepinilloTests`) y `PepinilloMac Dev/Staging/Production` (sin target de tests;
la lógica Mac se prueba en el simulador iOS).

- **TCA**: `AppFeature` compone `FocusFeature`, `TaskListFeature`,
  `AnalyticsFeature`, `SettingsFeature`, `PaywallFeature` + sheets
  (`Calendar`, `Auth`, `Profile`, `EmailVerification`) y tabs
  `.focus/.plan/.dashboard/.account`.
- **Persistencia** (`Shared/Persistence/`): `PepinilloMigrationPlan` con
  `SchemaV1..V6` (V6 añade `AchievementRecord`), 8 `@Model` en `Domain/Models/`.
  `AppGroupContainer` administra 3 SQLite en el App Group
  `group.com.pepinillo.app`: `PepinilloLocal.sqlite` (launch-critical),
  `PepinilloAppleCloud.sqlite` (CloudKit privado) y legacy de recuperación.
  `BackgroundPersistenceActor` (`@ModelActor`) ejecuta lecturas/escrituras
  off-main.
- **Router de stores** (`PersistenceStoreRouter.reconcile(capabilities:)`):
  `.backend` (everywhere_plus) con `SyncClient` + WebSocket; `.appleCloud`
  (pepinillo_plus) vía `LocalToCloudStoreMigrator`; `.local` (free). Widgets/
  intents leen el store según `activeSyncMode`.
  ⚠️ Gap actual: `MacAppBootstrap` no cablea `syncModeClient.reconcile` (Mac
  opera `.local`).
- **Puente entre procesos**: `AppGroupDefaults` (`userCapabilities`,
  `activeSyncMode`, comandos `external*Requested`) + notificación Darwin
  `com.pepinillo.app.externalCommand`.
- **macOS** (`Mac/`): sidebar+detail+inspector, `NSStatusItem`+`NSPopover`
  (`MacStatusBarController`, pulso 1 Hz), `MacDockTileView` (arc + badge),
  panel Notch (`MacNotchPanelController`, aparece en hold de fase), Quick
  Capture `⌃⌥T` (NSPanel no activante), Spotlight (`MacSpotlightIndexer`,
  fingerprint 10 s), sampler opt-in de app foreground (`MacActivitySampler` →
  JSON local). Atajos: `⌃⌥Space`, `⌃⌥T`, `⌃⌥→`, `⌃⌥X`, `⌃⌥P`. Contrato de
  diseño: `ios/docs/macos-design-contract.md`.
- **Monetización**: `SubscriptionClient` + `SubscriptionCapabilityResolver`
  (`everywhere_plus` → `pepinillo_plus` → legacy `premium`/`pro`), gracia
  offline 7 días para everywhere_plus, `UserCapabilities` en App Group.
  `AIReportClient` (on-device Foundation Models iOS/macOS 26+ → plantilla).
- **watchOS**: `WatchAppFeature`/`WatchTimerFeature`/`WatchTasksFeature`/
  `WatchDashboardFeature`; sync con el phone vía `WatchConnectivityClient`
  (ticks throttle 1 Hz, tareas/stats/tema) y `WatchStatsKeys` para
  complications.

---

## 4. Android (`android/`)

**Módulos**: `:app` (phone/tablet, `minSdk 29`, `targetSdk 36`, `compileSdk 37`)
y `:wear` (Wear OS, `minSdk 26`), ambos `applicationId dev.creapolis.pepinillo`.

- **Shell**: `NavigationSuiteScaffold` con 4 tabs `Focus / Plan / Dashboard /
  More`; layout adaptativo `ListDetailPaneScaffold` (MEDIUM/EXPANDED) en Tasks
  y Dashboard; PiP en `onUserLeaveHint` con timer corriendo.
- **Capas**: `core/` (auth EncryptedSharedPreferences, billing RevenueCat con
  `SubscriptionMapper` y gracia 3 días, `FeatureGate` con `FREE_TASK_LIMIT=3`),
  `data/` (Room v14: `TaskEntity`, `FocusSessionEntity`, `DailyStatsEntity`,
  `SubtaskEntity`, `ProductivityReportEntity`, `UserEntity`,
  `PreferenceSyncEntity`; DataStore; `SyncEngine` serializado con `SyncLock`,
  `InitialSyncManager` download-then-swap, `SyncWebSocketClient` con
  `Sec-WebSocket-Protocol: bearer`), `domain/` (`FocusEngine` 4 Hz,
  reportes remote→on-device stub→template, soundscapes 8), `feature/`
  (`FocusMode`: Pomodoro/Flow/Blocks/Chrono), `widget/` (Glance x3 +
  recovery), `service/` (`FocusTimerService` FGS `specialUse`, recordatorios
  diarios).
- **Wear OS** (`:wear`): `HorizontalPager` 4 páginas (Stats/Timer/Tasks/
  Diagnostics), `WearViewModel` con updates optimistas + `WearCommandWatchdog`
  (5 s) y cola offline (40 comandos coalescidos), `WearSyncListenerService`
  (DataItems `/pepinillo/{timer,tasks,stats,user,theme}` + eventos
  `/pepinillo/event/phase_complete`), `FocusTileService` (freshness 30/60 s),
  `TasksTileService` (Pro, máx 4), `FocusComplicationDataSource`,
  `WearFocusService` (FGS + OngoingActivity).
- **Monetización**: `SubscriptionManager` + `SubscriptionState` (tiers FREE /
  PEPINILLO_PLUS / EVERYWHERE_MONTHLY / EVERYWHERE_ANNUAL), `FeatureGate`
  (sync y IA cloud gated en `canSync`), In-App Review tras 3 sesiones.

---

## 5. Sincronización multi-dispositivo (flujos)

1. **First login con Everywhere+**: `POST /sync/initial-upload` (deviceId +
   tasks + sessions + settings) → respuesta merge-back aplica el estado del
   servidor (hasExistingData).
2. **Pull**: `GET /sync/full` paginado (cursors `taskCursor`/`sessionCursor`
   formato `RFC3339Nano|id`, límite ≤500) con download-then-swap local.
3. **Push incremental**: `POST /tasks/sync` (delta + `deletedSyncIds` +
   `lastSyncAt`) y `POST /sync/sessions` (lote LWW). Respuestas traen
   `appliedSyncIds`/`rejectedSyncIds`/`syncTimestamp`.
4. **Preferencias**: `GET/PUT /preferences` (17 claves Android en
   `SettingsSyncEngine`, excluye device-local).
5. **Invalidación en vivo**: WebSocket `/api/v1/ws` (auth Bearer o
   `Sec-WebSocket-Protocol: bearer, <jwt>`, ping/pong 54/60 s, máx 8
   conexiones/usuario) con eventos `task_updated`, `task_deleted`,
   `focus_*_updated/created`, `pomodoro_*`, `settings_updated`,
   `sessions_synced`, `initial_upload_completed`, `user_updated`. El emisor se
   auto-excluye con `X-Device-ID`.

---

## 6. Decisiones abiertas (no reinventar sin issue)

- Migrar errores HTTP a RFC 9457 solo en endpoints nuevos o `/api/v2`.
- Codegen de DTOs desde `contracts/openapi.yaml` (Swift/Kotlin) pendiente de
  issue dedicada; hoy los modelos se validan manualmente contra el contrato.
- Cablear `syncModeClient.reconcile` en `PepinilloMac` antes de habilitar sync
  backend en Mac.
