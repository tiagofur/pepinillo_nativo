# android/AGENTS.md — Android y Wear OS Nativo

Mapa rápido para agentes que tocan `android/**`. Arquitectura completa:
[`../docs/architecture.md`](../docs/architecture.md) §4.

---

## Proyecto Gradle

- Módulos: `:app` (phone/tablet/foldable — `applicationId
  dev.creapolis.pepinillo`, `compileSdk 37`, `minSdk 29`, `targetSdk 36`,
  `versionName 3.1.0`, `versionCode 29`) y `:wear` (Wear OS — `minSdk 26`,
  `targetSdk 36`, `versionCode 10029`).
- Catálogo de versiones: `gradle/libs.versions.toml` (AGP, Kotlin, Compose BOM,
  Hilt, Room, Ktor, RevenueCat, Wear Compose/Tiles, Glance, WorkManager,
  Play Review). Gradle 9.6.1, toolchain JVM 21, target JVM 17.
- `google-services.json` y firma release (`key.properties` + `pepinillo.jks`)
  son locales/gitignoreados; los plugins Firebase se aplican condicionalmente.
- Room: version 14, `exportSchema = true` (schemas en `app/schemas/`),
  migraciones `MIGRATION_1_2..MIGRATION_13_14` — toda nueva migración añade
  schema JSON exportado.

## Arquitectura `:app`

Paquete base `dev.creapolis.pepinillo`:

- `core/`: `auth/` (EncryptedSharedPreferences, `SessionManager`),
  `billing/` (`SubscriptionManager`, `SubscriptionMapper` con gracia 3 días,
  `SubscriptionState`, `FeatureGate` con `FREE_TASK_LIMIT=3`),
  `identity/`, `network/` (Ktor+OkHttp, refresh automático), `result/`.
- `data/`: Room (7 entidades: Task, FocusSession, DailyStats, Subtask,
  ProductivityReport, User, PreferenceSync), DataStore, `sync/` (`SyncEngine`
  serializado con `SyncLock`, `SettingsSyncEngine` (17 claves),
  `InitialSyncManager` download-then-swap, `SyncWebSocketClient`
  (`Sec-WebSocket-Protocol: bearer, <jwt>`), `SyncWorker` 15 min).
- `domain/`: `timer/FocusEngine` (4 Hz, estados `Idle/Running/Paused/
  WaitingForNext`), `report/` (remote → on-device stub → template),
  `soundscape/` (8 paisajes), `streak/`, `tasks/`.
- `feature/`: shell `Focus / Plan / Dashboard / More`
  (`NavigationSuiteScaffold`, `ListDetailPaneScaffold` adaptativo en Tasks y
  Dashboard), `FocusMode` = `Pomodoro`/`Flow`/`Blocks`/`Chrono`, paywall,
  auth (merge vs wipe), onboarding, `InAppReviewManager` (3 sesiones).
- `widget/`: Glance (FocusTimer, Tasks, DailyStats) + `FocusTimerRecovery`.
- `service/`: `FocusTimerService` (FGS `specialUse` + recovery prefs),
  recordatorios diarios, BootCompletedReceiver.
- PiP automático en `onUserLeaveHint` con timer `Running`.

## Arquitectura `:wear` (Wear OS)

- `presentation/`: `HorizontalPager` 4 páginas (Stats/Timer/Tasks/
  Diagnostics) + ambiente dimming.
- `data/`: `WearDataStore` (flows en memoria), `WearSnapshotStore`
  (SharedPrefs), `WearPendingCommandQueue` (máx 40, coalescida),
  `WearCommandWatchdog` (5 s revert de updates optimistas).
- `service/`: `WearSyncListenerService` (DataItems
  `/pepinillo/{timer,tasks,stats,user,theme}`, evento
  `/pepinillo/event/phase_complete`, cola al reconectar),
  `WearFocusService` (FGS + OngoingActivity).
- `tile/` + `complication/`: `FocusTileService` (freshness 30/60 s),
  `TasksTileService` (Pro, máx 4), `FocusComplicationDataSource`
  (SHORT_TEXT/LONG_TEXT/RANGED_VALUE, recalc por epoch).

## Verificación

```bash
cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest
cd android && ./gradlew :app:assembleDebug :wear:assembleDebug
./gradlew :app:connectedDebugAndroidTest   # MigrationTest (instrumentado)
```

CI: `.github/workflows/android-test.yml` corre subconjunto focalizado;
`SyncEngineTest` excluido hasta #281/#282 (timeout GHA).
