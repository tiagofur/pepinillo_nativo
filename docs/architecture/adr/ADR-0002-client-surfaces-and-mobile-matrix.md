# ADR-0002: Superficies Cliente Nativas (Apple / Android) y Clientes en Pausa

- **Estado**: Accepted (reconciliado con el producto activo)
- **Fecha**: 2026-11-10 (original de plantilla: 2026-10-29)
- **Decisores**: Pepinillo Architecture Core

---

## 1. Contexto

Pepinillo nació en Flutter y evolucionó a implementaciones **100% nativas** para exprimir capacidades profundas de cada sistema operativo (Widgets, Live Activities, Dynamic Island, Control Center, App Intents/Siri, Apple Watch, Wear OS Tiles/Complications, `NSStatusItem` y panel de Notch en macOS). Además, existen dos experimentos previos (`web/` y `windows/`) que validaron viabilidad técnica pero quedaron pausados durante la fase de **Validación de Crecimiento**.

---

## 2. Decisión

### 2.1 Superficies Activas (Tier Nativo OS-First)
1. **Ecosistema Apple (`ios/`, XcodeGen `project.yml`)**:
   - **Plataformas**: **iOS 17+ / iPadOS 17+** (`Pepinillo`), **macOS 15+** (`PepinilloMac`), **watchOS 10+** (`PepinilloWatch`), **Widgets iOS/macOS**, **Control Center** (`iOS 18+`) y **Live Activities**.
   - **Stack**: Swift 6 (strict concurrency), SwiftUI (+ AppKit para `NSStatusItem`, `NSPopover`, `NSDockTile`, `NSPanel` de Quick Capture y Notch en `PepinilloMac`), **The Composable Architecture (TCA)**, **SwiftData (`SchemaV6`)**, StoreKit 2 + RevenueCat, Sentry.
   - **Almacenamiento**: Dual-store router (`PepinilloLocal.sqlite` / `PepinilloAppleCloud.sqlite`) + App Group `group.com.pepinillo.app`.
2. **Ecosistema Android (`android/`, Gradle `:app` + `:wear`)**:
   - **Plataformas**: **Android teléfono/tablet/foldable** (`minSdk 29`, `targetSdk 36`, `compileSdk 37`) y **Wear OS** (`minSdk 26`, `targetSdk 36`).
   - **Stack**: Kotlin, Jetpack Compose + Material 3 Expressive (`ListDetailPaneScaffold` adaptativo), Hilt DI, Coroutines/StateFlow, **Room (v14, 7 entidades)**, DataStore, WorkManager, **Jetpack Glance**, Wear Compose + Tiles + ProtoLayout + Complications, Ktor (OkHttp), RevenueCat, Google Play In-App Review.
   - **Comunicación reloj**: Wearable Data Layer (`WearDataLayerHelper` ↔ `WearSyncListenerService`) con cola offline de comandos y watchdog de 5 s.

### 2.2 Superficies en Pausa (No expandir sin autorización explícita)
- **`web/` (Web Companion)**: SvelteKit 2 + Svelte 5 + TypeScript + IndexedDB (`idb`) + Vitest + Playwright.
- **`windows/` (Windows Desktop)**: C# / .NET 9 / WinUI 3 (`Pepinillo.Core`, `Pepinillo.WinUI`).
- Ambos directorios permanecen como referencia técnica validada; **no forman parte de las entregas ni de la matriz obligatoria de paridad diaria** salvo autorización explícita en una issue.

### 2.3 Principio de Paridad
- **Paridad funcional obligatoria** entre superficies activas (iOS, iPadOS, watchOS, macOS, Android, Wear OS) en el motor de foco (4 modos: `Pomodoro`, `Flowtime`, `Time Block`, `Stopwatch`), reglas de negocio, estados de sesión y modelo de entitlements (`pepinillo_plus` / `everywhere_plus`).
- **Gramática visual nativa, nunca híbrida**: HIG-first en Apple (incluyendo arquitectura sidebar/tabla/inspector en macOS según `ios/docs/macos-design-contract.md`) y Material 3 Expressive en Android.

---

## 3. Consecuencias

- Cada superficie activa conserva su propio `AGENTS.md` (`ios/AGENTS.md`, `android/AGENTS.md`) con comandos exactos de compilación y prueba.
- Los clientes evitan lógica duplicada de sincronización LWW delegando la resolución autoritativa al backend Go (`contracts/openapi.yaml`) cuando el usuario tiene `everywhere_plus`.
- Las plantillas heredadas de `software-factory-base` que mencionaban Tauri o React+Vite no aplican a Pepinillo.
