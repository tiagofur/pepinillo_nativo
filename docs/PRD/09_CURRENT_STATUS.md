# Pepinillo — Current Implementation Status

**Date:** 2026-03-24  
**Version:** 1.3  
**Status:** Active Development  
**Last Updated:** 2026-04-21  
**Update Cadence:** Per sprint

---

## 1. Overall Status

| Platform        | Status                                                              | % Complete | Files           | Approx. Lines | Build                |
| --------------- | ------------------------------------------------------------------- | ---------- | --------------- | ------------- | -------------------- |
| iOS (iPhone)    | **Code complete + audit fixes applied; waiting on RevenueCat config** | 95%        | ~143 Swift      | ~30K          | BUILD SUCCESSFUL (Pepinillo Dev, iPhone 17 Pro simulator) |
| watchOS         | Implemented (timer, tasks, dashboard, enhanced Smart Stack widgets) | 100%       | Included in iOS | Included      | BUILD SUCCESSFUL     |
| Android (phone) | Sprints 1-4 complete (Foundation + Ecosystem + Polish)              | 85%        | ~97 Kotlin      | ~20K          | BUILD SUCCESSFUL     |
| Wear OS         | Implemented (timer, tasks, stats, tile, complication)               | 95%        | ~18 Kotlin      | ~5K           | BUILD SUCCESSFUL     |
| Backend (Go)    | Complete REST API with auth + sync (local deployment ready)         | 90%        | ~50 Go          | ~8K           | Functional locally   |

### Monetization Direction (2026-04-22, v3.1) — Status: Code Complete, Config Pending

- **Approved commercial model:** Pepinillo+ (one-time, NOT a subscription) + Everywhere/AI+ (recurring sync + Advanced AI).
- **Naming finalized (v3.1):** "Pepinillo+" for the one-time purchase, "Everywhere/AI+" for the subscription. Entitlement IDs: `pepinillo_plus` + `everywhere_plus`.
- **Product ID reuse:** Existing `pro.lifetime` → Pepinillo+, `pro.monthly`/`pro.annual` → Everywhere/AI+. No new SKUs needed.
- **Apple Intelligence as hero:** On-device AI Reports (Foundation Models + template fallback) is the primary differentiator.
- **Próximamente strategy:** Everywhere/AI+ features (Backend Sync, AI Coach, Task Scheduling, Subtask Gen) shown only in paywall with subtle badge.
- **Transparency principle:** Pepinillo+ is explicitly "One purchase. Yours forever. Not a subscription."
- **Prices (global):** Pepinillo+ $19.99 one-time · Everywhere/AI+ $4.99/month · $34.99/year.
- **Prices (LATAM):** Pepinillo+ $9.99 · Everywhere/AI+ $2.49/month · $17.99/year.
- **Implementation status (code — ✅ DONE):**
  - [x] `AppConfig.aiInsightsEnabled = true`
  - [x] `PaywallView.swift` — two-tier design, "NOT a subscription" badge, Apple Intelligence as hero
  - [x] `SubscriptionClient.swift` — `pepinillo_plus`/`everywhere_plus` entitlements, legacy `premium`/`pro` fallback
  - [x] `UserCapabilities.swift` — granular capability model
  - [x] `Pepinillo.storekit` — renamed to "Pepinillo+" / "Everywhere/AI+ Monthly" / "Everywhere/AI+ Annual", prices $19.99/$4.99/$34.99
  - [x] Mock display names and prices aligned to v3.1
- **Implementation status (external — ⚠️ BLOCKING v1.0):**
  - [ ] **[CRITICAL BLOCKER]** Update revoked API keys in RevenueCat (App Store Connect API: `22YZT9D55J` · In-App Purchase: `Z95PS2LD73`)
  - [ ] Complete metadata + rename products in App Store Connect (pending API key fix)
  - [ ] Create `pepinillo_plus` + `everywhere_plus` entitlements in RevenueCat (pending API key fix)
  - [ ] Create new RevenueCat offerings with canonical naming (pending API key fix)
  - [ ] Configure S2S Notifications webhook in App Store Connect (pending deployment URL)

### Product Reset Direction (2026-04-21) — In Flight

- **Hero user:** knowledge worker / creative doing deep work daily.
- **Canonical product pillars:** `Execute`, `Plan`, `Reflect`, and `Admin`.
- **Canonical phone surfaces:** `Focus`, `Plan`, and `Dashboard` as primary destinations; `Account / Admin` lives outside the main productivity axis.
- **Current runtime baseline during transition:** iPhone ships `Focus / Plan / Dashboard / More`; Android phone is actively converging to the same model.
- **Current product gaps:** task depth is still too light, Dashboard/reviews are not yet a unified reflection engine, and AI positioning is more defined in strategy than in product behavior.
- **Immediate product priority (post-v1.0):** stop accumulating disconnected surfaces and redesign screen ownership before major new feature expansion.
- **v1.0 focus:** ship monetized, platform-complete app with multi-mode execution engine, basic task planning, and foundational analytics.

---

## 1.5 Blockers for v1.0 Release

**These items must be complete before submission to App Store / Play Store.**

### Critical Blockers (Stop-Ship if not resolved)

| Item | Platform | Current Status | Owner | Impact | Target Date |
| ---- | -------- | -------------- | ----- | ------ | ----------- |
| RevenueCat API key reconfiguration (v3.1 rename) | iOS + Android | Awaiting action | Manual config | Cannot deploy; paywall will fail | 2026-04-28 |
| App Store Connect product metadata update | iOS | Blocked on API key | Manual config | Cannot upload build | 2026-04-28 |
| Go backend deployment + SSL certificate | Both | Local-only functional | Deployment | Backend unavailable in production | 2026-04-30 |
| Play Store Console setup (Android) | Android | Not yet started | Manual config | Cannot publish Android app | 2026-05-05 |

### High-Priority (Ship-Blocking if missed)

| Item | Platform | Current Status | Owner | Impact | Target Date |
| ---- | -------- | -------------- | ----- | ------ | ----------- |
| Demo data verification (full flow) | iOS | Code ready | Manual QA | App Store reviewers will test; if demo crashes, rejection | 2026-04-27 |
| Xcode setup finalization (Info.plist, targets, signing) | iOS | 95% complete | Manual setup | Build may fail during archival | 2026-04-28 |
| Android R8 minification verification | Android | Code ready | Manual build/test | Release APK may crash without proper ProGuard rules | 2026-04-29 |
| Network requests over HTTPS + certificate pinning | Both | iOS done, Android hardened | Code | HTTP requests will fail in production | Already done ✅ |

### Medium-Priority (Would be nice, not stop-ship)

| Item | Platform | Current Status | Owner | Impact | Target Date |
| ---- | -------- | -------------- | ----- | ------ | ----------- |
| Localization completeness check (EN, ES, PT) | Both | ~95% complete | Manual review | Missing strings fall back to EN; bad UX but not rejection | 2026-05-01 |
| Marketing screenshots + app preview | iOS + Android | Not yet started | Design | Store listing quality but not technical blocker | 2026-05-10 |
| Release notes preparation | Both | Not yet started | Docs | Store metadata but not blocker | 2026-05-10 |

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

- **watchOS app:** timer with 4 modes, task list, dashboard, enhanced Smart Stack widgets (rectangular with live countdown + phase + linked task, circular with actual progress, corner with live countdown), smart relevance scoring (100 active / 10 idle), 5-minute refresh when active, Tasks complication (accessoryRectangular, accessoryCircular, accessoryCorner)
- **Watch-Phone connectivity:** bidirectional state sync via WatchConnectivity
- **Widgets:** Home Screen (S/M/L) + Lock Screen, all mode-aware
- **Live Activity + Dynamic Island:** 4 distinct UIs per active mode
- **Siri / App Intents:** multi-mode commands in 3 languages (EN, ES, PT)
- **Control Center widget:** quick session toggle (iOS 18+)
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

- **RevenueCat iOS:** fully configured
  - SDK v5+ (wrapping StoreKit 2) with legacy 3-product setup (monthly, annual, lifetime)
  - iOS Public API Key: `appl_xnChlVXXtUFhusIfJyNrNDcMGLj` (configured in code)
  - Entitlement: `pro` via RevenueCat Offerings/Packages (legacy single-flag model)
  - User identification integrated with Sign in with Apple flow
  - Grace period support via RevenueCat entitlements
  - Paywall implemented
  - **Target packaging:** Pepinillo+ + Everywhere/AI+ Monthly + Everywhere/AI+ Annual

### RevenueCat Backend: Secret API key configured

- Secret API Key (V2): `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (label: "Pepinillo Backend")
- Environment variable: `REVENUECAT_SECRET_KEY` (loaded via `backend/internal/config/config.go`)
- Webhook handler: `POST /api/v1/webhooks/revenuecat` (implemented and tested)
- Webhook URL (pending deployment): `https://{YOUR_DOMAIN}/api/v1/webhooks/revenuecat`
- **Authoritative billing endpoint:** `POST /api/v1/billing/verify` (use instead of legacy verification paths)
- **RevenueCat dashboard:** products and entitlements
  - iOS products imported (monthly, annual, lifetime)
  - Entitlements linked (premium/pro)
  - S2S notifications configured

### Auth Hardening — P0 + P1 Complete (2026-04-20) ✅

**P0 — Apple Sign-In hardening (all platforms):**
- Backend now requires `APPLE_BUNDLE_ID` in production (`backend/internal/config/config.go`).
- Backend `/api/v1/auth/apple` now requires `nonce` in request payload (`backend/internal/adapters/handlers/oauth_handler.go`).
- Apple token verification hardened in backend with:
  - retry/backoff when fetching Apple JWKS,
  - strict `iat` validation (missing, too old, or future tokens rejected),
  - existing issuer/audience/expiration/nonce checks preserved (`backend/internal/services/oauth_service.go`).
- iOS Apple login request now requires non-optional nonce in DTO and guarded flow before backend exchange (`ios/Domain/Models/APIDTOs.swift`, `ios/Features/Auth/AuthView.swift`, `ios/App/AppFeature.swift`).
- Added focused backend tests for production config and Apple token validation branches (`backend/internal/config/config_test.go`, `backend/internal/services/oauth_service_validation_test.go`, `backend/internal/adapters/handlers/oauth_handler_test.go`).

**P1.1 — Email verification gate (backend + iOS + Android):**
- Backend embeds `emailVerified` in JWT access/refresh claims (`backend/internal/adapters/middleware/jwt_middleware.go`, `backend/internal/services/auth_service.go`, `backend/internal/services/oauth_service.go`).
- New `RequireEmailVerified()` middleware blocks unverified users from all data endpoints with `403 email_not_verified` (`backend/internal/adapters/middleware/email_verification.go`).
- Route restructure: all data routes (tasks, focus, pomodoro, AI, analytics, sync, preferences, push) moved under `verified` group; auth routes + `GET /users/me` + billing remain accessible to unverified users (`backend/internal/adapters/handlers/routes.go`).
- `VerifyEmail` backend endpoint now returns fresh tokens with `emailVerified: true` so clients update Keychain/EncryptedSharedPreferences atomically on success (`backend/internal/services/auth_service.go`, `backend/internal/adapters/handlers/auth_handler.go`).
- iOS: `EmailVerificationFeature` + `EmailVerificationView` added; `AuthFeature` sends `.emailVerificationRequired` delegate when backend returns unverified user; `AppFeature` shows non-dismissible verification sheet (`ios/Features/Auth/EmailVerificationFeature.swift`, `ios/Features/Auth/EmailVerificationView.swift`, `ios/App/AppFeature.swift`, `ios/App/AppView.swift`).
- Android: `handleAuthSuccess` in `AuthViewModel` gates on `emailVerified`; new `EmailVerificationScreen` composable added; route `email-verification/{email}` wired in `MainActivity` (`android/app/.../feature/auth/EmailVerificationScreen.kt`, `AuthViewModel.kt`, `MainActivity.kt`).

**P1.2 — deviceId Keychain migration (iOS):**
- `getOrCreateDeviceId` migrated from `UserDefaults` to iOS Keychain (`kSecAttrAccessibleAfterFirstUnlock`) with transparent legacy migration path (`ios/Domain/Clients/KeychainClient.swift`).

### Navigation Parity R1 Progress (2026-04-20) ✅ / Transitional

- The current runtime phone baseline is `Focus`, `Plan`, `Dashboard`, and `More`.
- `More` is the current shipping label for the Account / Admin surface, and owns profile, auth, subscription, settings, export, and support on iPhone.
- Android phone is actively converging toward the same shell and ownership model.
- That 4-surface baseline is still considered **transitional** under the product reset.
- Next IA target: `Focus`, `Plan`, and `Dashboard` as primary productivity destinations, with `Account / Admin` holding Settings, Profile, Subscription, and support outside the main productivity axis.
- Reviews and calendar entry points should consolidate under `Dashboard` or `Plan`, instead of remaining scattered across drawers and duplicated shortcuts.

### Widget/Build Stabilization (2026-04-20) ✅

- Fixed multiple Swift syntax and state-construction errors in widget providers (`ios/PepinilloWidget/DashboardWidgetProvider.swift`, `ios/PepinilloWidget/FocusWidgetProvider.swift`, `ios/PepinilloWidget/DashboardWidget.swift`).
- Removed duplicated `isProUser` declaration causing compile failure (`ios/Shared/Persistence/AppGroupContainer.swift`).
- Fixed SwiftUI style API mismatch in email verification view (`ios/Features/Auth/EmailVerificationView.swift`).
- Addressed Swift concurrency capture violations in `AppFeature` async effects (`ios/App/AppFeature.swift`).
- Regenerated Xcode project from `project.yml` to ensure source inclusion consistency (`ios/Pepinillo.xcodeproj`).

### Pending iOS

| Item                                | Priority | Notes                                                                                                  |
| ----------------------------------- | -------- | ------------------------------------------------------------------------------------------------------ |
| ✅ Product reset IA + screen ownership | DONE     | 4-tab runtime baseline: Focus / Plan / Dashboard / More, with More owning account/admin surfaces |
| ✅ Account tab full-screen navigation | DONE     | Profile, Subscription, Export, Help all push as NavigationLink (Phase 5 complete) |
| Enable Apple Intelligence (AI Reports) | P0    | Code is ready, just needs `AppConfig.aiInsightsEnabled = true` + paywall redesign |
| Paywall redesign for Pepinillo+ / Everywhere/AI+ | P0 | Two-tier paywall: one-time vs subscription, Próximamente section |
| RevenueCat entitlement reconfiguration | P0     | Map `pro.lifetime` → `pepinillo_plus`, `pro.monthly`/`pro.annual` → `everywhere_plus` |
| App Store Connect metadata update | P0       | New names, descriptions, and screenshots for the 3 products |
| Demo data verification | P0       | Run `-seedDemoData` and verify Dashboard, AI Reports, charts all display correctly |
| Feature gating enforcement | ✅ Done   | Legacy single-pro gating is in place; entitlement names updated for new tiers |
| Xcode setup (non-code)              | P0       | App Group, CloudKit container, StoreKit config, targets, SPM, Info.plist, audio assets, localization |
| macOS target                        | P2       | Included in roadmap but not implemented                                                                |
| iPad layouts                        | ✅ Done  | Full parity with iPhone: landscape uses NavigationSplitView (sidebar + detail), portrait uses top-menu Picker; same 4 tabs as iPhone (Focus/Plan/Dashboard/Account). Responsive Dashboard (1-col compact, 2-col regular). Task detail always in sheet. Stage Manager + keyboard shortcuts remain. |

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
- Mode breakdown (by focus mode)
- AI Reports (on-device + template fallback)
- Weekly Review (weekly comparison)
- Monthly Review (monthly review)
- Achievements with visual progress

### Android Ecosystem ✅

- **Wear OS app:** timer, task list, stats, diagnostics
- **Wear Focus Timer Tile:** enhanced `FocusTileService` with progress arc (colored by mode), timer display, phase label, session counter, linked task name. Distinct idle/running/paused states. Built with Tiles 1.4.1 + ProtoLayout Material 1.2.1.
- **Wear Tasks Tile:** `TasksTileService` showing top 4 tasks with energy emoji, truncated title, pomodoro progress, and completed/total header.
- **WearSnapshotStore extended:** now persists linkedTaskId, linkedTaskName, completedSessions, and theme colors for tile access.
- **Wear Complication:** `FocusComplicationDataSource` (SHORT_TEXT + LONG_TEXT)
- **Wear Data Layer sync:** bidirectional (phone-watch) with local fallback
- **Glance widgets:** FocusTimerWidget, DailyStatsWidget (Home Screen)
- **Lock Screen widget:** LockScreenTimerWidget (Android 14+, category KEYGUARD)
- **Quick Settings Tile:** FocusTileService (Android 7+)
- **Google Assistant App Actions:** 3 BIIs + 4 shortcuts + deep links `pepinillo://focus/`
- **Ongoing notification:** with Pause/Resume/Stop actions
- **Adaptive layouts:** WindowSizeClass, NavigationRail (medium), PermanentNavigationDrawer (expanded)
- **Two-pane layouts:** FocusScreen, TaskListScreen master-detail, DashboardScreen multi-column, SettingsScreen two-column
- **Foldable:** hinge avoidance via `androidx.window` 1.3.0

### Integrations ✅

- **Google Calendar UI:** runtime permissions, toggle in Settings, time blocking when WORK sessions are completed
- **Health Connect:** Mindful Sessions (experimental API)
- **JWT auth + Go backend:** login/register via Ktor
- **Room + Sync Engine:** dirty-flag strategy, last-write-wins by `updatedAt`, WorkManager periodic sync every 15 min
- **DND / Focus Mode:** `DndManager` activates Do Not Disturb during sessions

### Design ✅

- **Unified theme system:** 4 named themes (Classic, Forest, Ocean, Sunset) + Material You dynamic colors
- **Theme picker:** horizontal scroll cards with per-theme preview
- **Focus mode colors:** consistent per mode (Pomodoro=red, TimeBlock=purple, Chrono=green)
- **PRO gating:** Forest, Ocean, Sunset require PRO subscription
- **Wear OS theme sync:** selected phone theme syncs to watch via Data Layer API
- Material 3 + Material You (dynamic color)
- Adaptive layouts (phone, tablet, foldable with hinge avoidance)
- Shimmer loading placeholders
- 3 languages: English, Spanish, Portuguese
- Adaptive app icon with monochrome support (Android 13+)

### Billing ✅

- **RevenueCat Android:** fully configured
  - SDK v8.10.0 (Purchases SDK) integrated
  - Android Public API Key: `goog_ITPYSPEdubAzAeoNGxezZuZJELT` (configured in code)
  - Legacy Product IDs: com.pepinillo.app.pro.monthly, com.pepinillo.app.pro.annual, com.pepinillo.app.pro.lifetime
  - Entitlement: `premium` (legacy naming drift from iOS `pro`)
  - User identification integrated with auth flow
  - Grace period support via RevenueCat entitlements
  - Paywall implemented
- **Cross-platform billing stack parity:** iOS and Android both use RevenueCat (core setup completed)
  - iOS uses RevenueCat SDK v5+ (wrapping StoreKit 2)
  - Android uses RevenueCat Purchases SDK v8.10.0
  - Packaging still needs migration to Pepinillo+ + Everywhere/AI+ (external RevenueCat + App Store Connect config pending)
- **RevenueCat Backend:** Secret API key configured
  - Secret API Key (V2): `sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ` (label: "Pepinillo Backend")
  - Webhook handler: `POST /api/v1/webhooks/revenuecat` (implemented)
- Feature gating for subtasks and recurrence is implemented (PRO badges, disabled inputs for free users)

### Production Hardening (Completed 2026-04-02)

| Fix | Status | Details |
| --- | ------ | ------- |
| Ktor logging restricted in release | ✅ | `LogLevel.NONE` for release, `LogLevel.BODY` for debug only |
| RevenueCat API key moved to BuildConfig | ✅ | Removed hardcoded constant, uses `BuildConfig.REVENUECAT_API_KEY` |
| Wear OS R8 minification enabled | ✅ | `isMinifyEnabled = true` with dedicated ProGuard rules |
| Network security config added | ✅ | Cleartext disabled, `api.ppn.creapolis.dev` domain pinned, debug overrides for user certs |
| WebSocket heartbeat/ping | ✅ | 30s ping interval, 10s pong timeout, auto-reconnect on timeout |
| Backup rules configured | ✅ | Encrypted prefs and Room DB excluded from cloud backup and device transfer |
| Unused imports cleaned | ✅ | Removed `runBlocking` import from MainActivity |
| Full sync pagination | ✅ | Already implemented in `InitialSyncManager` with cursor-based loops |

### Android/Wear Build Stabilization (2026-04-20) ✅

- Fixed unresolved DI import for `SubscriptionManager` in `MainActivity` (`android/app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt`).
- Fixed WorkManager network constraint compile issue by restoring `NetworkType` import (`android/app/src/main/java/dev/creapolis/pepinillo/data/sync/SyncWorker.kt`).
- Fixed timer service widget timestamp calculation using `remainingMillis` derived from state (`android/app/src/main/java/dev/creapolis/pepinillo/service/FocusTimerService.kt`).
- Fixed Glance widget compilation issues in focus widget (misplaced imports, key conflict, invalid countdown API usage, color type mismatch) (`android/app/src/main/java/dev/creapolis/pepinillo/widget/FocusTimerWidget.kt`).
- Fixed Wear presentation compile blockers (`Alignment`/`height` imports in stats screen; `Stop` icon import in timer screen) (`android/wear/src/main/java/dev/creapolis/pepinillo/presentation/StatsScreen.kt`, `android/wear/src/main/java/dev/creapolis/pepinillo/presentation/TimerScreen.kt`).
- Validation: `:app:assembleDebug` and `:wear:assembleDebug` both successful.

### Pending Android

| Item                           | Priority | Notes                                                                        |
| ------------------------------ | -------- | ---------------------------------------------------------------------------- |
| Product reset IA + screen ownership | P0    | Active runtime parity phase uses `Focus / Plan / Dashboard / More`; final 3-surface IA remains target-state |
| More hub parity closures       | P0       | ✅ Help/Support, About, Export, Profile all have dedicated screens wired in nav |
| Feature gating enforcement     | P0       | ✅ All features gated: modes, tasks, subtasks, recurrence, export, themes, analytics (periods/reviews/AI), widgets (focus+stats), Wear tiles/complications, task analytics |
| Complete paywall UI            | P0       | ✅ v3.1 two-tier design: Pepinillo+ (one-time) + Everywhere/AI+ (subscription) cards, dynamic CTA |
| Firebase Analytics/Crashlytics | P1       | Plugins commented out; missing `google-services.json`                        |
| CI/CD pipeline                 | P1       | GitHub Actions (build + lint + tests)                                        |
| Play Store listing             | P1       | Screenshots, ASO, description                                                |
| Test coverage                  | P1       | 16 test files, ~200+ tests across phone and wear                            |
| OEM testing                    | P2       | Samsung, Pixel, Xiaomi, OnePlus                                              |
| Release keystore               | P1       | Generate and store in secure vault                                           |

---

## 4. Detailed Parity Matrix

### Focus Engine

| Feature                            | iOS              | Android               | Notes                                  |
| ---------------------------------- | ---------------- | --------------------- | -------------------------------------- |
| FocusEngine (core engine)          | ✅               | ✅                    | Swift Actor vs Kotlin coroutines       |
| Pomodoro Strategy                  | ✅               | ✅                    |                                        |
| Flowtime Strategy                  | ✅               | ✅                    |                                        |
| TimeBlock Strategy                 | ✅               | ✅                    |                                        |
| Stopwatch Strategy                 | ✅               | ✅                    |                                        |
| Session journaling                 | ✅               | ✅                    |                                        |
| Task linking                       | ✅               | ✅                    |                                        |
| ADHD-friendly breaks               | ✅               | ✅                    |                                        |
| Foreground Service / Live Activity | ✅ Live Activity | ✅ Foreground Service | Different mechanisms, same user outcome |
| Dynamic Island                     | ✅               | N/A                   | iOS only                               |

### Tasks

| Feature                            | iOS           | Android | Notes                                           |
| ---------------------------------- | ------------- | ------- | ----------------------------------------------- |
| Basic CRUD                         | ✅            | ✅      |                                                 |
| Drag-to-reorder                    | ✅            | ⬜      | Android reorder is not implemented              |
| Subtasks                           | ✅            | ✅      |                                                 |
| Priority levels                    | ✅            | ✅      |                                                 |
| Energy levels (deep/shallow/admin) | ✅            | ✅      |                                                 |
| Energy batching UI                 | ⬜            | ✅      | Android has energy grouping; iOS does not       |
| Recurring tasks                    | ✅ iCal RRULE | ✅      | iOS uses iCalendar format                        |
| Estimated/completed pomodoros      | ✅            | ✅      |                                                 |
| Apple Reminders import             | ✅            | N/A     | iOS only                                        |
| Google Tasks import                | N/A           | ✅      | Android only                                    |

### Analytics

| Feature                       | iOS                    | Android                 | Notes                                    |
| ----------------------------- | ---------------------- | ----------------------- | ---------------------------------------- |
| Dashboard with charts         | ✅ SwiftCharts         | ✅ Vico                 |                                          |
| 7-day / 30-day / 1-year views | ✅                     | ✅                      |                                          |
| Mode breakdown                | ✅                     | ✅                      |                                          |
| Achievements                  | ✅ 6 types             | ✅                      |                                          |
| Weekly Review                 | ✅                     | ✅                      |                                          |
| Monthly Review                | ✅                     | ✅                      |                                          |
| AI Reports                    | ✅ Apple FM + fallback | ✅ On-device + fallback |                                          |
| Per-task drill-down           | ✅                     | ⬜                      | Android does not have per-task drill-down |

### Ecosystem

| Feature                              | iOS                                               | Android                 | Notes                                                    |
| ------------------------------------ | ------------------------------------------------- | ----------------------- | -------------------------------------------------------- |
| Watch/Wear app (timer)               | ✅ watchOS                                        | ✅ Wear OS              |                                                          |
| Watch/Wear tasks                     | ✅                                                | ✅                      |                                                          |
| Watch/Wear dashboard/stats           | ✅                                                | ✅                      |                                                          |
| Watch/Wear complications (enhanced)  | ✅ Enhanced (live countdown, progress, relevance) | ✅                      | Both platforms have rich complications                   |
| Wear Focus Timer Tile (enhanced)     | N/A                                               | ✅                      | Progress arc, phase label, session counter, linked task |
| Wear Tasks Tile                      | N/A                                               | ✅                      | Top 4 tasks with energy emoji + pomodoro progress       |
| watchOS Tasks Complication           | ✅                                                | N/A                     | accessoryRectangular, accessoryCircular, accessoryCorner |
| watchOS Smart Stack widgets          | ✅ Enhanced (live countdown, relevance scoring)   | N/A                     | Rectangular, circular, corner complications              |
| Watch-Phone sync                     | ✅ WatchConnectivity                              | ✅ Data Layer           |                                                          |
| Home Screen widgets                  | ✅                                                | ✅ Glance               |                                                          |
| Lock Screen widget                   | ✅                                                | ✅ Android 14+          |                                                          |
| Live Activity / Ongoing notification | ✅ Live Activity + DI                             | ✅ Foreground Service   |                                                          |
| Quick Settings Tile                  | N/A                                               | ✅                      | Android only                                             |
| Control Center widget                | ✅ iOS 18+                                        | N/A                     | iOS only                                                 |
| Siri / Google Assistant              | ✅ App Intents (3 langs)                          | ✅ App Actions (3 BIIs) |                                                          |
| Spotlight / Search indexing          | ✅                                                | ⬜                      | Android does not have search indexing                    |
| iPad layouts                         | ⬜                                                | N/A                     | Planned but not implemented                              |
| Tablet/foldable layouts              | N/A                                               | ✅                      | WindowSizeClass + hinge avoidance                        |
| macOS target                         | ⬜                                                | N/A                     | Planned but not implemented                              |

### Integrations

| Feature                           | iOS                              | Android            | Notes                                  |
| --------------------------------- | -------------------------------- | ------------------ | -------------------------------------- |
| Health (Mindful Minutes/Sessions) | ✅ HealthKit                     | ✅ Health Connect  |                                        |
| Calendar integration              | ⬜                               | ✅ Google Calendar | iOS does not have calendar integration |
| System Focus Mode / DND           | ✅ FocusFilterIntent             | ✅ DndManager      |                                        |
| Soundscapes                       | ✅ AVAudioPlayer (4 soundscapes) | ⬜ Not implemented | Android missing; iOS has 4 functional  |
| Mode Intelligence                 | ✅                               | ✅                 |                                        |

### Auth and Sync

| Feature                   | iOS                   | Android                                           | Notes                                                  |
| ------------------------- | --------------------- | ------------------------------------------------- | ------------------------------------------------------ |
| Auth                      | ✅ Sign in with Apple | ✅ JWT + Go backend                              |                                                        |
| Anonymous user support    | ✅ IdentityClient     | ✅ IdentityManager state machine                 | Both: full offline use without account                 |
| Sync                      | ✅ CloudKit + Backend | ✅ Room + SyncEngine + WorkManager + WebSocket   | Commercial split now distinguishes Apple-local sync from Everywhere backend sync |
| Settings sync             | ✅ PreferenceDirtyTracker (17 keys, per-key LWW) | ✅ SettingsSyncEngine (17 keys, per-key LWW)     | Both: bidirectional via user_preferences table |
| Batch session sync        | ✅ SyncClient.syncSessions() | ✅ POST /sync/sessions                       | Both: replaces individual POSTs                        |
| Initial upload            | ✅ SyncClient.initialUpload() | ✅ POST /sync/initial-upload                    | Both: atomic upload on anonymous-to-registered         |
| New device full sync      | ✅ SyncClient.performInitialSync() (cursor) | ✅ GET /sync/full (cursor pagination)  | Both: cursor-based pagination                          |
| Real-time WebSocket sync  | ✅ WebSocketClient (URLSessionWebSocketTask) | ✅ SyncWebSocketClient + SyncLifecycleObserver | Both: notification-only, triggers HTTP sync        |
| Data merge dialog         | ✅ DataMergeView (SwiftUI sheet) | ✅ DataMergeDialog composable            | Both: upload local vs download cloud choice            |
| Offline support           | ✅                    | ✅ dirty-flag + last-write-wins                   |                                                        |

### Billing

| Feature                             | iOS                                | Android                                 | Notes                                                    |
| ----------------------------------- | ---------------------------------- | --------------------------------------- | -------------------------------------------------------- |
| Billing SDK                         | ✅ RevenueCat SDK v5+ (StoreKit 2) | ✅ RevenueCat SDK v8.10.0 (Purchases)   | Core cross-platform billing parity established           |
| Paywall UI                          | ✅                                 | ✅                                      | Available on both platforms                              |
| Feature gating                      | ✅ Legacy gating enforced          | ⚠️ Partial                              | Next step is capability-based gating for Pepinillo+ vs Everywhere/AI+ |
| Products (current runtime)          | ✅ monthly/annual/lifetime         | ✅ monthly/annual/lifetime              | Legacy single-tier model still configured                |
| Products (target rollout)           | 📋 Pepinillo+ + Everywhere/AI+     | 📋 Everywhere/AI+ monthly/annual        | Approved commercial direction (v3.1, 2026-04-22). iOS code aligned; RC + ASC config pending |
| Entitlements verification           | ✅ RevenueCat entitlements (`pro`) | ✅ RevenueCat entitlements (`premium`)  | Naming drift still needs harmonization and capability split |
| AI credit ledger                    | ⬜                                  | ⬜                                       | Backend work not started                                 |

### Design and Accessibility

| Feature                                 | iOS                       | Android                   | Notes                                         |
| --------------------------------------- | ------------------------- | ------------------------- | --------------------------------------------- |
| Theming                                 | ✅ 4 themes + Liquid Glass | ✅ 4 themes + Material You | Strong parity baseline                        |
| Theme picker (horizontal scroll)        | ✅                        | ✅                        | Available on both platforms                   |
| Appearance selector (Light/Dark/System) | ✅                        | ✅                        |                                               |
| Focus mode colors (red/purple/green)    | ✅                        | ✅                        | Consistent on both platforms                  |
| Wear OS / watchOS theme sync            | ✅ WatchConnectivity      | ✅ Data Layer             | Phone -> watch                                |
| Glassmorphism                           | ✅                        | ⬜                        | iOS only                                      |
| Haptic feedback                         | ✅                        | ⬜                        | Android haptics not fully implemented         |
| Reduce Motion                           | ✅                        | ⬜                        |                                               |
| VoiceOver / TalkBack                    | ✅                        | ✅                        |                                               |
| Dynamic Type / Font scaling             | ✅                        | ✅                        |                                               |
| Shimmer loading                         | ⬜                        | ✅                        | Android only                                  |
| Localization (EN, ES, PT)               | ✅                        | ✅                        |                                               |

---

## 5. Current Stack

### iOS

| Layer           | Technology                        | Version   | Notes                                             |
| --------------- | --------------------------------- | --------- | ------------------------------------------------- |
| Language        | Swift                             | 6         |                                                   |
| Architecture    | TCA (The Composable Architecture) | >= 1.17   |                                                   |
| Persistence     | SwiftData                         | iOS 17+   |                                                   |
| Sync            | CloudKit                          | native    | Free, transparent                                 |
| UI              | SwiftUI                           | iOS 17+   |                                                   |
| Widgets         | WidgetKit                         | iOS 17+   | Home + Lock Screen                                |
| Live Activities | ActivityKit                       | iOS 16.1+ | + Dynamic Island                                  |
| Watch           | WatchConnectivity                 | watchOS 10+ |                                                 |
| Intents         | App Intents                       | iOS 17+   | 3 languages                                       |
| Health          | HealthKit                         | iOS 17+   | Mindful Minutes                                   |
| Billing         | RevenueCat SDK v5+                | iOS 17+   | Wraps StoreKit 2, 3 products, entitlement: `pro`  |
| Audio           | AVAudioPlayer                     | native    | Soundscapes                                       |

### Android

| Layer              | Technology                               | Version        | Notes                                                          |
| ------------------ | ---------------------------------------- | -------------- | -------------------------------------------------------------- |
| Language           | Kotlin                                   | 2.0.21         | Limited by Hilt 2.52 (no Kotlin 2.1.x metadata support)       |
| KSP                | ksp                                      | 2.0.21-1.0.28  | Must match Kotlin                                              |
| Build              | AGP                                      | 8.10.0         | Gradle 8.14.3                                                  |
| UI                 | Jetpack Compose + Material 3             | BOM 2025.03.00 |                                                                |
| Architecture       | Circuit (MVI)                            | 0.24.0         | Manual wiring in AppModule (without `@CircuitInject` KSP)     |
| DI                 | Hilt                                     | 2.52           | `@AssistedInject` for Circuit Presenters                       |
| Persistence        | Room                                     | 2.7.0          | KSP, exportSchema=true                                         |
| Networking         | Ktor                                     | 3.1.0          | OkHttp engine                                                  |
| Widgets            | Glance                                   | 1.1.1          | PreferencesGlanceStateDefinition                               |
| Sync               | WorkManager                              | 2.10.0         | hilt-work 1.2.0                                                |
| Charts             | Vico                                     | 1.14.0         | compose-m3                                                     |
| Audio              | Media3/ExoPlayer                         | 1.5.0          | Soundscapes                                                    |
| Billing            | RevenueCat Purchases SDK                 | v8.10.0        | Fully integrated with shared `premium` entitlement             |
| Health             | Health Connect                           | 1.1.0-rc01     | Experimental API                                               |
| Adaptive           | material3-window-size-class              | via BOM        | WindowWidthSizeClass                                           |
| Foldable           | androidx.window                          | 1.3.0          | FoldingFeature + hinge avoidance                               |
| Wear Tiles         | Tiles 1.4.1 + ProtoLayout Material 1.2.1 | 1.4.1          | Enhanced FocusTileService + TasksTileService                  |
| Wear Complications | watchface-complications                  | 1.2.1          | SuspendingComplicationDataSourceService                        |
| Wear Data Layer    | play-services-wearable                   | 18.2.0         | DataClient + MessageClient                                     |
| Firebase           | --                                       | --             | Plugins commented out; enable with `google-services.json`      |

---

## 6. Backend (Go)

### Architecture

- **Pattern:** Hexagonal (ports and adapters)
- **Language:** Go 1.24
- **HTTP Framework:** Fiber v2
- **ORM / DB:** GORM + PostgreSQL
- **Directory:** `backend/`

### Backend Status

| Component                           | Status             | Detail                                                                          |
| ----------------------------------- | ------------------ | ------------------------------------------------------------------------------- |
| Complete REST API                   | ✅ Implemented     | Auth (email/password), tasks CRUD + sync, sessions, stats, user profile        |
| Billing verification (both stores)  | ✅ Implemented     | App Store and Google Play receipt verification via RevenueCat                   |
| RevenueCat webhook endpoint         | ✅ Implemented     | `POST /api/v1/webhooks/revenuecat` for subscription lifecycle events            |
| RevenueCat REST API client          | ✅ Implemented     | Server-side client for entitlement verification                                 |
| Direct App Store/Play verification  | ✅ Implemented     | Fallback verification when RevenueCat is unavailable                            |
| Subscription lifecycle events       | ✅ Implemented     | purchase, renewal, cancellation, expiration, billing issues                     |
| Push notifications                  | ✅ Implemented     | APNS (iOS) + FCM (Android)                                                      |
| WebSocket                           | ✅ Implemented     | Real-time communication channel                                                 |
| AI Insights                         | ✅ Implemented     | Gemini integration for productivity reports                                     |
| OAuth social login                  | 🔄 Partial         | Sign in with Apple is implemented on iOS + backend; Android Google Sign-In/provider linking rollout is still pending |
| Real-time multi-device coordination | ❌ Not implemented | WebSocket exists but cross-device coordination logic is still missing           |
| Deployment                          | ❌ Not deployed    | Needs cloud hosting (Railway/Fly.io/VPS) + PostgreSQL + Redis                  |

### Implemented Endpoints

| Endpoint                         | Method     | Description                                              |
| -------------------------------- | ---------- | -------------------------------------------------------- |
| `/api/v1/auth/register`          | POST       | User registration (email/password)                       |
| `/api/v1/auth/login`             | POST       | JWT login                                                |
| `/api/v1/tasks`                  | GET/POST   | List and create tasks                                    |
| `/api/v1/tasks/:id`              | PUT/DELETE | Update and delete tasks                                  |
| `/api/v1/tasks/sync`             | POST       | Task synchronization with dirty flags                    |
| `/api/v1/sessions`               | GET/POST   | List and create focus sessions                           |
| `/api/v1/stats`                  | GET        | Productivity stats                                       |
| `/api/v1/user`                   | GET/PUT    | User profile                                             |
| `/api/v1/billing/verify`         | POST       | Receipt verification (App Store + Google Play)           |
| `/api/v1/notifications/register` | POST       | Device token registration (APNS/FCM)                     |
| `/ws`                            | WebSocket  | Real-time communication channel                          |

### Client Integration

| Platform | Status         | Detail                                                             |
| -------- | -------------- | ------------------------------------------------------------------ |
| Android  | 🔄 Partial     | Auth client + SyncEngine exist and connect to backend endpoints    |
| iOS      | ✅ Implemented | SyncClient + IdentityClient + WebSocketClient + APIClient (TCA)   |
| Wear OS  | 🔄 Partial     | Inherits Android phone sync via Data Layer                         |
| watchOS  | 🔄 Partial     | Inherits iOS phone state via WatchConnectivity (sync via phone)    |

### Applied Migrations

| Migration | Description                                       |
| --------- | ------------------------------------------------- |
| 000001    | Initial tables (users, tasks, sessions)          |
| 000002    | Base fields                                       |
| 000003    | `energy_level` + recurrence fields in tasks       |
| 000004    | Device tokens for push notifications              |

### Pending Backend Work (priority order)

| #   | Task                                                                  | Priority | Dependencies       | Estimate |
| --- | --------------------------------------------------------------------- | -------- | ------------------ | -------- |
| 1   | Deploy backend to cloud hosting                                       | P0       | None               | 4-8h     |
| 2   | Complete remaining OAuth rollout (Google provider, account linking hardening) | P0 | #1 (deployment) | 8-12h |
| 3   | Android: add Google Sign-In via Credential Manager                    | P0       | #2 (OAuth rollout) | 6-8h     |
| 4   | ~~iOS: create API client, connect auth + sync to backend~~            | ✅ DONE  | #2 (OAuth backend) | Done     |
| 5   | Improve sync engine (WebSocket real-time, bidirectional multi-device) | P1       | #1 (deployment)    | 12-16h   |
| 6   | Monetization v2 capability split (`local_premium`, sync, AI credits)  | P0       | #1                 | 8-12h    |
| 7   | AI credit ledger + monthly reset policy                               | P1       | #1, #6             | 10-14h   |
| 8   | Cross-platform subscription verification                              | P1       | #1, #4, #6         | 8-12h    |
| 9   | Account/profile parity refinement (both platforms)                    | P1       | #2, #3, #4, #8     | 8-12h    |

---

## 7. Production Audit Fixes (2026-03-20)

The following issues were identified during a production readiness audit and have been fixed:

### Monetization Fixes

| Fix                               | Platform | Details                                                                                                     |
| --------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------- |
| Subtasks & recurrence PRO gating  | Android  | `FeatureGate` injected into `TaskDetailViewModel`; UI shows PRO badges and disables inputs for free users |
| `acknowledgePurchase` retry logic | Android  | Exponential backoff (3 retries), persistent fallback to SharedPreferences, retry on next app launch       |
| Subscription grace period buffer  | iOS      | 3-day buffer added before revoking access after subscription expiry                                         |

### Stability Fixes

| Fix                                   | Platform | Details                                                                                 |
| ------------------------------------- | -------- | --------------------------------------------------------------------------------------- |
| Timer crash recovery for Paused state | Android  | Timer now saves `Paused` state (previously only saved `Running`/`WaitingForNext`)      |
| POST_NOTIFICATIONS permission check   | Android  | `FocusTimerService` checks permission before calling `notify()` on Android 13+ (API 33) |

### Quality Fixes

| Fix                              | Platform | Details                                                                                     |
| -------------------------------- | -------- | ------------------------------------------------------------------------------------------- |
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

| Fix                       | Details                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| Subtasks in sync DTOs     | Subtasks now included in task sync payloads (previously omitted, breaking subtask sync)         |
| PomodoroSessionDto userId | Now populates `userId` from AuthStore (previously empty/null)                                   |
| PomodoroSessionDto taskId | Now resolves `linkedTaskId` -> `serverId` before sending (previously empty/null)                |
| Task soft-delete for sync | Changed `deleteTaskById` (hard-delete) to `softDelete` in TaskRepository for sync compatibility |

### iOS SyncClient Fixes

| Fix                   | Details                                                        |
| --------------------- | -------------------------------------------------------------- |
| Subtasks in sync DTOs | Subtask inclusion fixed for cross-platform parity with Android |
| userId population     | Session sync now properly populates `userId` field            |

### Remaining Sync Gaps

| Gap               | Platform(s) | Impact                                                      | Priority |
| ----------------- | ----------- | ----------------------------------------------------------- | -------- |
| ~~Session sync stub~~ | ~~iOS~~ | ~~Session data not synced to backend~~ (FIXED: SyncClient.syncSessions) | ✅ Done  |
| Focus config sync | Both        | Focus configs (`GET/PUT /pomodoro/config`) not implemented | P2       |
| Daily stats sync  | Both        | No sync fields defined on DailyStats entity                 | P2       |

---

## 9. Watch Complication Fixes & Task Parity (2026-03-24)

### Pomodoro Live Countdown Fixes

| Fix                                  | Platform | Details                                                                                  |
| ------------------------------------ | -------- | ---------------------------------------------------------------------------------------- |
| Tile countdown updates live          | Wear OS  | Pomodoro timer tile was stuck/static; now updates countdown in real time                 |
| Complication countdown at progress=0 | watchOS  | Pomodoro complication now shows live countdown even when progress=0 (timer just started) |

### watchOS Tasks Complication (New)

| Complication Family  | Content                               |
| -------------------- | ------------------------------------- |
| accessoryRectangular | Top task list with completion status  |
| accessoryCircular    | Completed tasks count                 |
| accessoryCorner      | Task count badge                      |

**Cross-platform parity update:** task complication/tile is now available on both Wear OS (`TasksTileService`) and watchOS (`TasksComplication`). Pomodoro live countdown is verified on both platforms.

---

## 10. Summary of Critical Gaps

### Both Platforms

| Gap                          | iOS                 | Android                    | Impact                                                                               |
| ---------------------------- | ------------------- | -------------------------- | ------------------------------------------------------------------------------------ |
| Sync engine gaps             | ✅ Full sync impl   | ⚠️ Partial                 | iOS: full sync architecture implemented; Android: subtasks/sessions improved; daily stats sync still pending on both |
| Feature gating not enforced  | ⚠️                  | ⚠️ Partial                 | Android: subtasks/recurrence gated. iOS + other Android features still need gating |
| Missing backend endpoints    | Low (uses CloudKit) | High (depends on backend)  | Stats and billing verification                                                       |

### iOS Only

| Gap                               | Impact                     | Effort               |
| --------------------------------- | -------------------------- | -------------------- |
| Xcode setup (non-code)            | Blocks any build           | 2-4h manual          |
| Outdated StoreKit prices          | Suboptimal revenue         | 1h                   |
| iPad/macOS not implemented        | Reduces TAM                | 48h (Phase 2 roadmap) |

### Android Only

| Gap                           | Impact                           | Effort                    |
| ----------------------------- | -------------------------------- | ------------------------- |
| Firebase not configured       | No analytics or crash reporting  | 2h + `google-services.json` |
| No CI/CD                      | No automated build               | 4-6h                      |
| Minimal test coverage (~20)   | Regression risk                  | 15-20h                    |
| Release keystore not generated| Blocks release                   | 1h                        |
| OEM testing pending           | Bugs on Samsung/Xiaomi           | 20h                       |
| Paywall UI incomplete         | Lower paid conversion            | 8-10h                     |