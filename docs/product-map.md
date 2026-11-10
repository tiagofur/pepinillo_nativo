# Mapa de producto — qué existe hoy

**Última reconciliación**: 2026-11-10 (fuente ejecutable: código + tests +
`contracts/openapi.yaml`). Distingue siempre **implemented today** de
**target/visión** (`docs/prd-v2.md`).

---

## Plataformas

| Plataforma | Estado | Base local | Build |
| :--- | :--- | :--- | :--- |
| **iOS (iPhone/iPad)** | Activa, App Store (`com.pepinillo.app`, v1.1.0 build 5) | SwiftData `SchemaV6` (`PepinilloLocal.sqlite` en App Group) | `xcodebuild -scheme "Pepinillo Dev"` |
| **watchOS** | Activa, companion completo (timer/tasks/dashboard) | Compartida con iOS vía `WatchConnectivityClient` (ticks 1 Hz) | scheme `Pepinillo Dev` (embed watch) |
| **macOS (`PepinilloMac`)** | Activa, App Store (menu bar + Notch + Quick Capture + Spotlight + Dock arc) | SwiftData `SchemaV6` compartido; **nota**: `syncModeClient.reconcile` aún no cableado en `MacAppBootstrap` | scheme `PepinilloMac Dev` |
| **Android (phone/tablet)** | Activa, Play Store (`dev.creapolis.pepinillo`, v3.1.0 build 29) | Room v14 (7 entidades, `schemas/` 8–14) | `./gradlew :app:assembleDebug` |
| **Wear OS** | Activa, companion (timer/tasks/stats, Tiles, Complications, FGS `specialUse`) | Snapshot + DataLayer (`/pepinillo/{timer,tasks,stats,theme,user}`) | `./gradlew :wear:assembleDebug` |
| **Backend Go** | Activa, producción `api.ppn.creapolis.dev` (VPS IONOS + Caddy) | PostgreSQL 16 + Redis 7 (`migrations/000001..000015`) | `go test ./...`, `deploy.yml` |
| **Web (`web/`)** | **EN PAUSA** (W1/W2 explorados: shell offline IndexedDB + auth/sync) | IndexedDB (`idb`) | `pnpm test` |
| **Windows (`windows/`)** | **EN PAUSA** (W0–W15 mergeados; falta smoke #575 + Partner Center #568) | — | `windows-build.yml` |

---

## Capacidades implementadas hoy

### Motor de foco (4 modos, paridad obligatoria)
- **Pomodoro** (free): 25/5/15 configurable, ciclo largo, auto-advance.
  iOS `PomodoroStrategy`; Android `FocusMode.Pomodoro` (25:00 free); backend
  `focus_mode.go` fases `work/short_break/long_break`.
- **Flowtime** (Pepinillo+): count-up, descansos sugeridos por fórmula
  (<25→5, <50→8, <90→10, ≥90→15). Android `FocusMode.Flow` (Pro).
- **Time Block** (Pepinillo+): duración planificada (60 min default) +
  midpoint check-in. Android `FocusMode.Blocks` (Pro).
- **Stopwatch** (free): count-up libre. Android `FocusMode.Chrono` (free).
- Anclaje a wall-clock, recuperación de sesiones huérfanas (ghost resume),
  hold de espera de fase, reconciliador backend `session_reconciler.go` (TTL
  `FOCUS_SESSION_STALE_TTL_HOURS`, default 168 h).

### Tareas
- CRUD + subtareas + prioridad + energía (`deep`/`shallow`/`admin`) + recurrencia
  con generación server-side (ventana 14 días, cron 24 h) y generación manual
  (`POST /api/v1/tasks/recurrences/generate`, máx. 370 días).
- Import desde **Apple Reminders** (iOS) y **EventKit Calendar** (iOS);
  **Calendar** propio multiplataforma (mes + detalle día).
- Límite free: **3 tareas activas** (`FREE_TASK_LIMIT` Android, cap iOS #216).
- Reordenamiento drag-and-drop (iOS/Mac sí; Android vía reorder en Plan).

### Ecosistema Apple
- Widgets Home/Lock (iOS), **Live Activity + Dynamic Island**, **Control Center**
  (iOS 18+), **App Intents/Siri** (start/pause/skip), Spotlight (iOS + macOS con
  deep-link `pepinillo://task/`), **HealthKit** (Mindful Minutes, write-only),
  Dashboard/Statistics macOS (⌘4, 7D/30D/Year).
- **macOS nativo**: `NSStatusItem` + `NSPopover` (1 Hz `MacPresencePulse`),
  estilos de menú (Countdown/Time only/Icon only), atajos globales
  (`⌃⌥Space`, `⌃⌥T` Quick Capture, `⌃⌥→`, `⌃⌥X`, `⌃⌥P`), Dock menu + badge +
  progress arc, panel Notch (v2.1, hold de fase), Services "Add Task to
  Pepinillo", muestreo opt-in de app en primer plano (`AppActivityUsageStore`).

### Ecosistema Android
- **Glance widgets** (Focus, Tasks, DailyStats), notificación persistente FGS
  con cronómetro, **Tiles** (Focus, Tasks Pro) y **Complications** (SHORT_TEXT,
  LONG_TEXT, RANGED_VALUE) en Wear OS, **Google Play In-App Review** tras 3
  sesiones con never-prompt-again, sonidos/paisajes (8 soundscapes), PiP
  automático al salir de la app con timer corriendo.

### Sincronización y cuentas
- **Offline-first**: todo funciona sin cuenta; sync es opcional y premium.
- **Apple CloudKit dual-store** (`PersistenceStoreRouter`): `.local` →
  `.appleCloud` (Pepinillo+) o `.backend` (Everywhere/AI+), migración y
  export-import entre stores.
- **Backend LWW** (Everywhere/AI+): `/sync/initial-upload`, `/sync/full`
  (paginado cursor `updatedAt|id`), `/sync/sessions`, `/tasks/sync`,
  `PUT /preferences`; WebSocket `/api/v1/ws` con eventos push server→client.
- **Auth**: email+password con verificación obligatoria para datos, Google y
  Sign in with Apple (nonce + revocación al borrar cuenta), refresh rotation
  con detección de robo, rate limiting por IP e identidad.
- **Wear/Watch companion sync**: DataLayer Android (cola offline 40 comandos +
  watchdog 5 s), `WatchConnectivityClient` iOS (1 Hz throttle).

### Monetización (v3.1)
- Productos: `com.pepinillo.app.pro.lifetime` ($19.99, **Pepinillo+**),
  `pro.monthly` ($4.99) y `pro.annual` ($34.99, **Everywhere/AI+**);
  precios LATAM $9.99/$2.49/$17.99.
- Tiers backend: `free`, `pepinillo_plus`, `everywhere_monthly`,
  `everywhere_annual` (`EffectiveTierAt` con lifetime sticky).
- **IA on-device** (Pepinillo+): Foundation Models (`iOS/macOS 26+`) con
  fallback de plantilla (`OnDeviceReportGenerator` → `TemplateReportGenerator`).
- **IA cloud** (Everywhere/AI+): `/api/v1/ai/*` con 100 créditos/mes, deduct
  atómico con refund, Gemini + fallback. `ml_service` FastAPI opcional.
- Webhook RevenueCat con dedupe `webhook_events` y claims `purchase_claims`.

### Seguridad y observabilidad backend
- JWT HS256 (access 15 min / refresh 30 d, HMAC-hashed en Redis), email
  verification gate, fail-closed en producción (`REFRESH_TOKEN_HASH_KEY` ≥32
  bytes, CORS sin `*`, `APPLE_BUNDLE_ID`), rate limiters duales, Sentry,
  `/health/*` con deps/metrics/prometheus/alerts/slo.

---

## Deuda y gaps conocidos (verificar en Issues antes de actuar)

- `PepinilloMac` no cablea `syncModeClient.reconcile` (solo `.local` hoy).
- `SyncEngineTest` Android excluido en CI hasta #281/#282; suite completa
  excede timeout de GHA.
- Test iOS en cuarentena: `spotlightTaskDeepLinkOpensTaskDetail`
  (`@Test(.disabled())`, TCA 1.26, issue #634).
- CI iOS ejecuta solo subconjuntos `-only-testing:` (fast/full); no toda la
  suite de 923 tests corre en cada PR.
- Widget iPad en macOS 27 crashea (issue #674, abierto).
- Errores HTTP aún no RFC 9457 (envolvente `{"error": ...}` vigente; objetivo
  en `ADR-0003` para endpoints nuevos).
