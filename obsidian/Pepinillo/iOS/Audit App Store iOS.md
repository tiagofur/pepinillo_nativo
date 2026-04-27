# iOS Audit — App Store Production Review Readiness

**Date:** 2026-04-07
**Target:** App Store Production Review submission
**Platform audited:** iOS + watchOS (Swift + SwiftUI + TCA + SwiftData)
**Verdict:** ❌ **NOT READY** — 5 P0 blockers, 5 P1 majors, 3 P2 minors. Estimated fix time: **2–3 hours**.

---

## Executive Summary

Pepinillo iOS is a **well-architected offline-first deep work platform** with strong foundations in accessibility, networking, and timer mechanics. The codebase is close to submission-ready, but has **5 blocking issues** that will trigger automatic App Store rejection if submitted as-is. All issues are configuration fixes or defensive-programming patches — **no architectural changes required**.

### Findings Summary

| Priority | Count | Fix Time |
|----------|-------|----------|
| P0 (Blocking) | 5 | 30–45 min |
| P1 (Major) | 5 | 45 min – 1 hr |
| P2 (Minor) | 3 | 15–30 min |
| P3 (Nice-to-have) | 1 | — |
| **Total** | **14** | **2–3 hrs** |

### Readiness Verdict

- **Status as-is:** ❌ NOT READY — guaranteed rejection
- **Status after P0 + P1 fixes:** ✅ READY — routine approval expected
- **Architectural risk:** NONE — all fixes are localized

---

## P0 — Blocking Issues (App Store Rejection Risk)

### P0-1. Missing `NSCalendarsUsageDescription`

- **File:** `ios/project.yml` (lines 90–105) + `ios/App/Info.plist`
- **Impact:** Calendar integration (`createFocusEvent`) is actively used but the permission string is NOT declared. App Store privacy validation will reject automatically.
- **Fix:** Add to `project.yml`:
  ```yaml
  NSCalendarsUsageDescription: "Pepinillo creates calendar events for Time Block sessions to sync with your schedule."
  ```
  Ensure it propagates to `Info.plist`.
- **Effort:** < 5 min

### P0-2. `fatalError` in `PepinilloApp.init()`

- **File:** `ios/App/PepinilloApp.swift:55`
- **Impact:** If `makeSharedModelContainer` throws (disk full, corrupted store, first-launch race, sandbox edge case), the app terminates on launch. App Review runs on simulators with unusual filesystem states — this **will** get caught.
- **Fix:** Replace `fatalError` with graceful handling. Catch the error, send an `.initializationFailed` action into the TCA store, and present a retry/fallback UI.
- **Effort:** 15–20 min

### P0-3. Force unwrap in `FocusWidgetProvider`

- **File:** `ios/PepinilloWidget/FocusWidgetProvider.swift:42, 137`
- **Impact:** `Calendar.current.date(byAdding:)!` can return nil in edge cases (calendar boundary, DST transitions). Widget timeline refresh will crash silently → user sees a stale/blank widget.
- **Fix:**
  ```swift
  guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else { return .idle }
  ```
- **Effort:** 5 min

### P0-4. Force unwraps in `DashboardWidgetProvider`

- **File:** `ios/PepinilloWidget/DashboardWidgetProvider.swift:38, 39, 125`
- **Impact:** Three force unwraps in the streak calculation path. Same crash risk as P0-3, same silent widget failure.
- **Fix:** Apply the same `guard let` pattern to all three lines.
- **Effort:** 10 min

### P0-5. Force unwrap in Siri Intent

- **File:** `ios/PepinilloIntents/GetModeSuggestionIntent.swift:53`
- **Impact:** `task!` force unwrap after an optional binding (logic error). If `task` is nil the Siri Intent crashes → poor voice UX, potential rejection if a reviewer tests Siri.
- **Fix:**
  ```swift
  "\(task?.title ?? "this task")"
  ```
- **Effort:** 5 min

---

## P1 — Major Issues (HIG / Compliance / UX Violations)

### P1-1. Unused `NSRemindersUsageDescription`

- **File:** `ios/project.yml` (lines 100–102) + `ios/App/Info.plist`
- **Impact:** Reminders import is documented in PRD but **not implemented**. Declaring a permission you don't use is flagged by App Review as misleading.
- **Fix:** Remove the key from both files. Defer Reminders import to v1.1, or implement it fully before submission.
- **Effort:** < 5 min

### P1-2. Incomplete app icon asset catalog

- **File:** `ios/Shared/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- **Impact:** Only a single 1024×1024 icon is declared. App Store submission expects proper sizes (120, 152, 167, 180 for iPhone; 1024 for Marketing). Missing sizes may trigger submission errors or weak presentation.
- **Fix:** Regenerate the icon set with all required sizes. Either manually populate `Contents.json` or use Xcode's Image Asset catalog UI to auto-generate from the 1024 source.
- **Effort:** 15–30 min

### P1-3. Hard-coded font sizes (Dynamic Type violation)

- **File:** `ios/Features/Focus/FocusView.swift:217, 221`
- **Impact:** `.font(.system(size: 28))` and `.font(.system(size: 64, weight: .light))` do NOT scale with Dynamic Type. Users at AX5+ text sizes will see truncation or overflow. Accessibility violation.
- **Fix:** Replace with named fonts:
  ```swift
  .font(.title)   // instead of size: 28
  .font(.system(.largeTitle, design: .rounded)) // instead of size: 64
  ```
  Or use `@ScaledMetric(relativeTo: .largeTitle)` for custom scaling.
- **Effort:** 15 min (including layout verification at AX sizes)

### P1-4. Force unwrap in `AppGroupContainer`

- **File:** `ios/Shared/Persistence/AppGroupContainer.swift:34`
- **Impact:** `FileManager.default.urls(...).first!` crashes if Documents directory is inaccessible (jailbroken devices, sandbox permission changes). Offline-first means this path must always work.
- **Fix:**
  ```swift
  guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      // handle gracefully
  }
  ```
- **Effort:** 10 min

### P1-5. Reduce Motion not respected on transitions

- **File:** `ios/Features/Focus/FocusView.swift:26` (and other `.transition()` call sites)
- **Impact:** `@Environment(\.accessibilityReduceMotion)` is declared but only used in `AudioBarsView`. Other transitions (`.move(edge: .top)`, etc.) ignore Reduce Motion, violating accessibility intent.
- **Fix:** Wrap transitions in a helper that respects `reduceMotion`:
  ```swift
  .transition(reduceMotion ? .identity : .move(edge: .top))
  ```
- **Effort:** 15 min

---

## P2 — Minor Issues (Polish & Consistency)

### P2-1. Empty `UILaunchScreen` dict

- **File:** `ios/App/Info.plist:56–57` + `ios/project.yml:79`
- **Impact:** `UILaunchScreen: {}` is an empty legacy config. May show a blank screen for 1–2s on launch. Reviewers may request clarity.
- **Fix:** Create a SwiftUI launch screen or add a proper `LaunchScreen.storyboard` with branding.
- **Effort:** 20 min

### P2-2. Inconsistent `ConditionalAnimation` usage

- **File:** `ios/Features/Focus/FocusView.swift` and related views
- **Impact:** `ConditionalAnimation` helper exists but is inconsistently applied. Some animations bypass it.
- **Fix:** Audit all `.animation()` and `.transition()` calls in Focus/Tasks/Analytics views and wrap consistently.
- **Effort:** 15 min

### P2-3. Entitlements XML formatting inconsistency

- **File:** `ios/App/Pepinillo.entitlements:19`
- **Impact:** `com.apple.security.application-groups` has inconsistent line breaks vs. other keys. Cosmetic only.
- **Fix:** Reformat for consistency.
- **Effort:** 2 min

---

## P3 — Nice-to-have

### P3-1. Silent data gaps in `DashboardWidgetProvider`

- **File:** `ios/PepinilloWidget/DashboardWidgetProvider.swift:66`
- **Impact:** Missing `DailyStats` for past dates produces empty data silently. No user-visible error, but debugging is harder.
- **Fix:** Add a debug log when stats are missing.
- **Effort:** 5 min

---

## Offline-First Compliance Report

### Verdict: ✅ **COMPLIANT**

**Strengths verified in the audit:**

- ✅ SwiftData is the **single source of truth** for tasks, sessions, stats
- ✅ Backend sync is **explicitly non-blocking**: `try? await syncClient.syncAll()` on app launch with silent error handling (`AppFeature.swift:253`)
- ✅ Focus sessions work 100% offline — timer uses `Date`-based arithmetic, no network
- ✅ Widgets read from local SwiftData, not network
- ✅ HealthKit writes, Calendar events, notifications — all local-first
- ✅ App launch does **not** block on network calls
- ✅ Backend down → app continues normally with silent fallback

**Minor concerns:**

- ⚠️ No explicit "syncing…" UI indicator. Acceptable per offline-first design, but could be enhanced.
- ⚠️ Sync conflicts rely on SwiftData/CloudKit defaults. No explicit conflict resolution strategy documented.

**Conclusion:** Production-ready for offline scenarios. No work required for this dimension.

---

## Backend Status (for sync testing)

### iOS Backend URL

- **File:** `ios/Domain/Clients/APIClient.swift:96`
- **Current:** `https://api.ppn.creapolis.dev/api/v1`
- **ATS safe?** ✅ YES — HTTPS, real domain, App Store compliant
- **Concern:** Hard-coded, not scheme-aware. No Debug-vs-Release override, no Info.plist configuration. Cannot point at `localhost` without editing source.
- **Blocking for submission?** NO — the VPS URL is production-ready

### Local Docker Backend

- **Conflict root cause:** Port 80 (Caddy) vs Windows HTTP.sys / IIS. The `docker-compose.yml` maps Caddy to `80:80` and `443:443`, which Windows reserves by default.
- **Secondary risk:** `backend/.env` does **not exist** — only `.env.example`. The `api` service requires `.env` to start.
- **Blocking for submission?** NO — iOS already targets the VPS over HTTPS

### Recommended local fix (non-blocking)

1. Create `backend/docker-compose.override.yml` (gitignored):
   ```yaml
   services:
     caddy:
       profiles: ["disabled"]
     postgres:
       ports: ["55432:5432"]
     redis:
       ports: ["56379:6379"]
   ```
2. Copy `.env.example` → `.env` and fill in values
3. `docker compose up -d --build` from `backend/`
4. Verify: `curl http://localhost:8080/api/v1/health`

**Note:** To point iOS at a local backend, `APIClient.swift` needs a `#if DEBUG` override + ATS exception. Deferred — not required for submission.

---

## Positive Findings (Already Solid — Do Not Break)

1. ✅ **Timer accuracy** — `Date`-based arithmetic, immune to drift and background suspension
2. ✅ **Accessibility foundation** — `.accessibilityLabel`, `.accessibilityValue`, `.accessibilityHint` present on key controls
3. ✅ **Network resilience** — 401 → refresh → retry logic in APIClient; all errors caught silently
4. ✅ **Offline-first genuinely implemented** — SwiftData is truth, backend is sync layer
5. ✅ **Hit targets exceed HIG** — 56×56 and 72×72 buttons (min is 44×44)
6. ✅ **Dark mode complete** — theme colors use adaptive Color with light/dark variants
7. ✅ **No placeholder/debug strings** — no TODOs, FIXMEs, or Lorem Ipsum in user-facing code
8. ✅ **Entitlements aligned** — HealthKit, CloudKit, Siri, App Groups declared and used correctly
9. ✅ **All 4 focus modes implemented** — Pomodoro, Flowtime, Time Block, Stopwatch
10. ✅ **watchOS target clean** — separate target, shared models, no code duplication
11. ✅ **Mac Catalyst keyboard shortcuts** — Space to start/pause, Cmd+. to stop
12. ✅ **No hardcoded secrets or API keys**
13. ✅ **ATS configured correctly** — HTTPS only, `ITSAppUsesNonExemptEncryption: false`

---

## Files Requiring Changes

### Quick (config only, < 5 min each)

- `ios/project.yml` — add `NSCalendarsUsageDescription`, remove `NSRemindersUsageDescription`
- `ios/App/Info.plist` — sync from `project.yml`
- `ios/App/Pepinillo.entitlements` — cosmetic formatting

### Medium (code changes, 5–10 lines each)

- `ios/App/PepinilloApp.swift:55` — remove `fatalError`
- `ios/PepinilloWidget/FocusWidgetProvider.swift:42, 137` — guard let
- `ios/PepinilloWidget/DashboardWidgetProvider.swift:38, 39, 125` — guard let
- `ios/PepinilloIntents/GetModeSuggestionIntent.swift:53` — optional coalescing
- `ios/Shared/Persistence/AppGroupContainer.swift:34` — guard let
- `ios/Features/Focus/FocusView.swift:26, 217, 221` — Dynamic Type + Reduce Motion

### Large (asset / design work)

- `ios/Shared/Resources/Assets.xcassets/AppIcon.appiconset/` — complete icon set
- Launch screen (SwiftUI or storyboard)

---

## Recommended Execution Plan

### Wave 1 — P0 Fixes (~45 min) — ZERO RISK

All defensive programming + config. Cannot break existing behavior.

1. Add `NSCalendarsUsageDescription`
2. Remove `NSRemindersUsageDescription`
3. Replace `fatalError` in `PepinilloApp.init()` with graceful handling
4. Replace all force unwraps (widgets + Siri intent + AppGroupContainer)

### Wave 2 — P1 Fixes (~1 hr)

1. Complete app icon asset catalog
2. Replace hard-coded font sizes with Dynamic Type
3. Apply Reduce Motion to all transitions
4. Audit `ConditionalAnimation` consistency

### Wave 3 — Verification (~30 min)

1. Re-audit modified files
2. **Cross-platform parity check** — verify the same bugs (force unwraps, hard-coded sizes, missing permission strings) do NOT exist in Android. Mandated by `CLAUDE.md`.
3. Clean build + archive dry-run
4. Update `09_CURRENT_STATUS.md` in PRD

### Wave 4 — Submission

1. Archive → Validate → Upload to App Store Connect
2. Fill metadata, screenshots, review notes
3. Submit for review

---

## Cross-Platform Parity Reminder

Per `CLAUDE.md`, every fix on iOS **must** be checked on Android:

| iOS fix | Android equivalent to verify |
|---------|------------------------------|
| Force unwraps in widgets | `!!` operators in Glance widgets |
| `fatalError` in init | `error("...")` or unchecked `Result` in Android app init |
| Missing calendar permission | `READ_CALENDAR` / `WRITE_CALENDAR` in `AndroidManifest.xml` |
| Unused Reminders permission | Equivalent Google Tasks permission audit |
| Hard-coded font sizes | `sp` vs `dp` audit in Compose |
| Reduce Motion | `LocalAccessibilityManager` / animation scale settings |

This audit does **not** cover Android. A parallel Android audit is recommended before any cross-platform submission.

---

## Bottom Line

> **None of these issues require architectural changes.**
> iOS is 2–3 hours of disciplined fixes away from App Store Production Review readiness.
> The hard work (offline-first, accessibility foundation, native architecture) is already done.
