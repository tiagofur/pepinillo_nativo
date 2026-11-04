# ADR-0002: Client Surfaces Architecture (React+Vite, Tauri v2 Desktop) and 3-Tier Mobile Decision Matrix

- **Status**: Accepted
- **Date**: 2026-10-29
- **Deciders**: Software Factory Architecture Core

---

## 1. Context

Modern software products span Web browsers, Desktop operating systems (macOS, Windows, Linux), and Mobile devices (iOS, Android).
In an Agentic Software Factory, client architecture choices directly determine **token consumption**, **maintenance surface**, and **user experience quality**:
- Rebuilding identical CRUD screens three times (Web, iOS, Android) for an unvalidated MVP wastes substantial engineering time and LLM tokens.
- Conversely, shipping a flagship consumer mobile app or hardware-intensive mobile workflow inside a hybrid WebView wrapper creates jarring keyboard/scroll behavior, poor battery life, and restricted access to native OS APIs (Widgets, Live Activities, HealthKit, NFC, Bluetooth, background location).

We need a clear, deterministic architectural standard for Web and Desktop, paired with an objective **Mobile Decision Matrix** evaluated on Day 0 (`./scripts/init-project.sh`).

---

## 2. Decision

### 2.1 Web Frontend Standard: React + Vite + TypeScript (Strict)
For all browser-based applications (`apps/web`), we standardize on **React 19 + Vite + TypeScript (`strict: true`)**:
- **Routing**: **TanStack Router** (100% type-safe file/code routing and search-param validation).
- **Server State & Caching**: **TanStack Query v5** coupled with an OpenAPI-generated fetch client (`openapi-typescript` / `openapi-fetch`).
- **Styling & Primitives**: **Tailwind CSS** + accessible headless primitives (**Radix UI** / `shadcn/ui`).
- **Why Vite over Next.js/SSR by default**: Because our backend is already a high-performance **Go API (`ADR-0001`)**, introducing a Node.js SSR middle tier (Next.js App Router) duplicates backend routing, splits business logic across two runtimes, and increases agent context confusion. If a public marketing site requires SEO/SSR, it is deployed as a separate static/Astro surface without polluting the core web application.

### 2.2 Desktop Standard: Tauri v2 (`apps/desktop-tauri`)
For cross-platform desktop applications, we standardize on **Tauri v2**:
- Reuses the `apps/web` React + Vite frontend inside the native OS WebView (`WKWebView` on macOS, `WebView2` on Windows, `WebKitGTK` on Linux), producing **<15 MB binaries** with minimal RAM overhead compared to Electron (>150 MB).
- Native OS integrations, file-system access, local SQLite sidecars, and hardware bridges are implemented as explicit, typed **Rust `#[tauri::command]` functions** secured by fine-grained **Tauri v2 Capability files (`src-tauri/capabilities/*.json`)**.

### 2.3 The 3-Tier Mobile Decision Matrix
Before writing mobile code, the project selects its mobile tier based on **product maturity**, **UX requirements**, and **token/cost budget**:

| Tier | Surface Option | `./scripts/init-project.sh` Surface | When to Choose | Explicit Tradeoffs & Limitations |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1: Rapid MVP & Internal/B2B CRUD Validation** | **Tauri v2 Mobile** (iOS & Android targets sharing `apps/web`) | `mobile-tauri` | Validating product-market fit, internal operations tools, or B2B companion apps that reuse 95% of existing React + Vite screens and need basic camera/notification plugins. | **Lowest token & time cost** (single UI codebase). **Known WebView limitations**: virtual keyboard viewport resizing quirks, non-native scroll physics, no App Extensions (Widgets/Watch/Siri), and strict OS background task suspension. |
| **Tier 2: Cross-Platform Commercial App (Non-Native Bridge)** | **PWA** or dedicated cross-platform shell | Custom ADR required | Content/catalog apps that do not need native OS extensions but outgrow WebView forms. | Requires separate justification; rarely preferred over Tier 1 (for speed) or Tier 3 (for flagship quality). |
| **Tier 3: Flagship Consumer UX, Deep OS Integration & Long-Term Scale** | **Native iOS (`SwiftUI`) + Native Android (`Jetpack Compose`)** | `ios-native`, `android-native` | Products where tactile 120Hz fluidity, offline-first reliability, background sync, Widgets/Live Activities, Apple Pay/Google Pay, biometrics, BLE/NFC, or camera/audio pipelines are core differentiators. | **Highest UX ceiling and OS longevity**, at a higher initial token cost (~1.8x–2.2x UI tokens). We mitigate this token cost via **OpenAPI 3.1 code generation (`ADR-0003`)** and symmetrical `ViewModel` + Repository architecture across Swift and Kotlin. |

### 2.4 Graduation Path (Tier 1 -> Tier 3)
Because all business rules reside in the **Go Backend (`ADR-0001`)** and all network DTOs are defined in **`contracts/openapi.yaml` (`ADR-0003`)**, a product can launch its 2-week MVP on **Tier 1 (`mobile-tauri`)** and later graduate to **Tier 3 (`ios-native` + `android-native`)** with **zero backend rewrites**.

---

## 3. Consequences

### Positive
- Eliminates architectural debates at project start: Web is always React+Vite, Desktop is always Tauri v2, and Mobile is chosen consciously between Tier 1 (speed/token efficiency) and Tier 3 (native SwiftUI/Compose excellence).
- Contract-first codegen (`openapi.yaml` -> TypeScript, Swift, Kotlin) eliminates manual DTO translation across surfaces, cutting native mobile token overhead by ~40%.

### Negative / Tradeoffs
- Teams choosing Tier 1 (`mobile-tauri`) must respect WebView boundaries and avoid custom gesture-heavy animations that fight the mobile browser viewport.
- Teams choosing Tier 3 (`ios-native`, `android-native`) must run platform-specific verification (`xcodebuild test` / `./gradlew testDebugUnitTest`) in `V1`/`V2` checkpoints.
