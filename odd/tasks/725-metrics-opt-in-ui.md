# 725 — Phase 2: Opt-in Consent UI for Aggregate Metrics Across iOS/macOS, watchOS, Android & Wear OS
Objective: Implement the "Compartir métricas anónimas" opt-in consent toggle (`metricsOptIn` via `GET /users/me` and `PUT /users/me`) across iOS/macOS, watchOS, Android, and Wear OS, plus dynamic toggle verification in `/internal/stats`.
Branch: `feat/metrics-opt-in-ui` | Delivery: `exception-ok` | Test runners: `go test ./...`, `./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest`, `xcodebuild test -scheme "Pepinillo Dev"`

## Specs

- **S1**: **Ajustes > Privacidad** (o sección equivalente): un toggle `"Compartir métricas anónimas"` en Ajustes de las 4 apps (iOS/macOS, Android, watchOS, Wear OS), default `OFF`, con el texto exacto del consentimiento:
  > Comparte métricas de uso anónimas y agregadas para mejorar Pepinillo: cuántas sesiones de enfoque se completan y en qué modos, minutos totales de enfoque y descanso, y tareas creadas y completadas. Nunca se comparte el contenido de tus tareas, tus horarios individuales ni ningún dato identificable. Puedes cambiarlo cuando quieras.
- **S2**: **Persistencia real + Optimista + error honesto**: el toggle refleja el valor real del servidor (`GET /users/me`) al abrir Ajustes; al cambiar el toggle envía `PUT /users/me` con `metricsOptIn`; si el `PUT` falla, revierte el valor optimista y avisa del error.
- **S3**: **Solo con cuenta activa**: si el usuario no está logueado con cuenta activa de sincronización (Free device-local), el toggle se muestra deshabilitado con `"Requiere cuenta con sincronización"` — no oculto de forma confusa ni simulado.
- **S4**: **El PUT de perfil rutinario NO envía el campo**: `PUT /users/me` envía `metricsOptIn` solo cuando el usuario cambia el toggle (nunca en un `PUT` rutinario de perfil — cubierto por test de regresión en iOS y Android).
- **S5**: **Verificación servidor-side**: con un usuario optado-in y sesiones sembradas, los agregados de `/internal/stats` lo cuentan; al desactivar (`metrics_opt_in = false`), deja de contarlos (reusando el test de integración gated por `STATS_TEST_DATABASE_URL`).
- **S6**: **App Store/Play y consistencia visual**: default `OFF`, sin pre-seleccionado en onboarding, sin dark patterns ni nagging; toggles nativos de cada plataforma (SwiftUI / Compose / watchOS / Wear OS).

## Allowed edit surfaces

- `backend/internal/adapters/repositories/postgres/internal_stats_repository_test.go`
- `ios/Domain/Models/APIDTOs.swift`
- `ios/Domain/Clients/PersistenceClient.swift`
- `ios/Domain/Clients/WatchConnectivityClient.swift`
- `ios/App/AppFeature.swift`
- `ios/Features/Profile/EditProfileFeature.swift`
- `ios/Features/Settings/SettingsFeature.swift`
- `ios/Features/Settings/SettingsView.swift`
- `ios/Mac/MacSettingsView.swift`
- `ios/PepinilloWatch/Features/WatchAppFeature.swift`
- `ios/PepinilloWatch/Views/WatchRootView.swift`
- `ios/PepinilloWatch/Views/WatchDashboardView.swift`
- `ios/Tests/SettingsFeatureTests/SettingsFeatureTests.swift`
- `ios/Tests/ProfileFeatureTests/EditProfileFeatureTests.swift`
- `ios/Tests/WatchFeatureTests/WatchAppFeatureTests.swift`
- `ios/Tests/WatchFeatureTests/WatchConnectivityEncodingTests.swift`
- `android/app/src/main/java/dev/creapolis/pepinillo/core/network/ApiModels.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/data/repository/UserRepository.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/feature/settings/SettingsViewModel.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/feature/settings/SettingsScreen.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/wear/WearDataLayerHelper.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/wear/PhoneWearListenerService.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt`
- `android/app/src/test/java/dev/creapolis/pepinillo/feature/settings/`
- `android/wear/src/main/java/dev/creapolis/pepinillo/data/WearDataStore.kt`
- `android/wear/src/main/java/dev/creapolis/pepinillo/data/WearDataFetcher.kt`
- `android/wear/src/main/java/dev/creapolis/pepinillo/data/WearMessageSender.kt`
- `android/wear/src/main/java/dev/creapolis/pepinillo/service/WearSyncListenerService.kt`
- `android/wear/src/main/java/dev/creapolis/pepinillo/presentation/MainActivity.kt`
- `android/wear/src/main/java/dev/creapolis/pepinillo/presentation/DiagnosticsScreen.kt`
- `android/wear/src/test/java/dev/creapolis/pepinillo/data/`
- `odd/tasks/725-metrics-opt-in-ui.md`

## Tasks

- [x] **T1** (`S5`, route: `inline`, trigger: small backend test unit, commit: `1ffe1c6e`, risk: `V1/V2`, checks: `STATS_TEST_DATABASE_URL=... go test -v ./internal/adapters/repositories/postgres -run TestInternalStatsRepository_ConsentAndAggregates` PASS): Extend `TestInternalStatsRepository_ConsentAndAggregates` in `backend/internal/adapters/repositories/postgres/internal_stats_repository_test.go` to verify dynamic opt-out (`metrics_opt_in = true -> false`) stops counting the user's sessions, focus/break minutes, and tasks, and re-enabling (`false -> true`) counts them again.
- [x] **T2** (`S1, S2, S3, S4, S6`, route: `delegated`, trigger: parallel disjoint surface `android/`, commit: `eebe202c`, risk: `V1`, checks: `./gradlew :app:testDebugUnitTest --tests "dev.creapolis.pepinillo.feature.settings.SettingsViewModelMetricsOptInTest" :wear:testDebugUnitTest` PASS): Implement `metricsOptIn` in Android phone (`ApiModels.kt`, `UserRepository.kt`, `SettingsViewModel.kt`, `SettingsScreen.kt`) and Wear OS (`WearDataLayerHelper.kt`, `PhoneWearListenerService.kt`, `WearDataStore.kt`, `WearSyncListenerService.kt`, `WearDataFetcher.kt`, `WearMessageSender.kt`, `DiagnosticsScreen.kt`, `MainActivity.kt`) with unit tests (`SettingsViewModelMetricsOptInTest.kt` and `WearDataStoreTest.kt`).
- [x] **T3** (`S1, S2, S3, S4, S6`, route: `delegated`, trigger: parallel disjoint surface `ios/`, commit: `5dff37fa`, risk: `V1`, checks: `xcodebuild test -scheme "Pepinillo Dev" ...` PASS, `xcodebuild build -scheme "PepinilloMac Dev"` PASS): Implement `metricsOptIn` in iOS/macOS (`APIDTOs.swift`, `PersistenceClient.swift`, `SettingsFeature.swift`, `SettingsView.swift`, `MacSettingsView.swift`, `AppFeature.swift`, `EditProfileFeature.swift`) and watchOS (`WatchConnectivityClient.swift`, `WatchAppFeature.swift`, `WatchRootView.swift`, `WatchDashboardView.swift`) with unit tests (`SettingsFeatureTests.swift`, `EditProfileFeatureTests.swift`, `WatchAppFeatureTests.swift`, `WatchConnectivityEncodingTests.swift`).

## Log

- **L1 (2026-11-11)**: User request verbatim:
  `# Fase 2: UI de consentimiento para métricas agregadas (opt-in) en las 4 apps`
  `Un toggle "Compartir métricas anónimas" en Ajustes de las 4 apps (iOS, Android, watchOS, Wear OS) que persista vía PUT /users/me enviando metricsOptIn solo cuando el usuario cambia el toggle (nunca en un PUT rutinario de perfil — evitaría sobrescribir el valor con nil/valor viejo por carreras).`
  `Texto exacto del consentimiento: Comparte métricas de uso anónimas y agregadas para mejorar Pepinillo: cuántas sesiones de enfoque se completan y en qué modos, minutos totales de enfoque y descanso, y tareas creadas y completadas. Nunca se comparte el contenido de tus tareas, tus horarios individuales ni ningún dato identificable. Puedes cambiarlo cuando quieras.`
  `Default: OFF. Solo con cuenta activa: si el usuario no está logueado (Free device-local), el toggle se muestra deshabilitado con "Requiere cuenta con sincronización". Optimista + error honesto: el toggle refleja el valor real del servidor al abrir Ajustes; si el PUT falla, revertir y avisar.`
