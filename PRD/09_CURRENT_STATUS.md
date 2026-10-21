# Pepinillo — Current Implementation Status

**Last Updated:** 2026-08-23
**Version:** 3.x  
**Status:** Production + Growth Validation Phase

---

## 1. Overall Status

| Platform        | Status                                                              | Files           | Approx. Lines | Build                |
| --------------- | ------------------------------------------------------------------- | --------------- | ------------- | -------------------- |
| iOS (iPhone)    | App Store Ready (Sprints 1-5: session/sync/correctness/surfaces/resume; achievements persisted in SwiftData (SchemaV6, #642); suite 870/0 on Xcode 27; stacked PRs #636-642) | ~180 Swift      | ~44K          | BUILD SUCCESSFUL (Pepinillo Dev, iPhone 17 simulator, Xcode 27) |
| watchOS         | Implemented (timer, tasks, dashboard, enhanced Smart Stack widgets) | Included in iOS | Included      | Requires Xcode setup |
| Android (phone) | Production Ready (Natively rewritten, signing configured)           | ~97 Kotlin      | ~20K          | BUILD SUCCESSFUL (v3.0.0, build 18) |
| Wear OS         | Production Ready (Timer, tasks, stats, tile, complications, theme sync) | ~18 Kotlin      | ~5K           | BUILD SUCCESSFUL (v3.0.0, build 10018) |
| Windows (desktop) | **Excellence W0–W15 code merged** (parity depth + desktop craft + Store kit); **ops left:** WinUI smoke (#575) + Partner Center (#568) | ~100+ C#/XAML | ~6K+ | CI: Core tests + x64/ARM64 build + MSIX pack |
| Web (companion) | **W1 Free shell** + polish; **W2 auth + bidirectional sync** (email login, entitlement, initial-upload round-trip with merge-back, full-pull, auto-sync on mutation + refocus; needs API URL + Everywhere) | Svelte/TS | greenfield | `pnpm test` + `pnpm test:e2e` + `pnpm build` |
| Backend (Go)    | Complete REST API (not deployed)                                    | ~50 Go          | ~8K           | Functional locally   |

**Windows tracking docs:** product PRD [11_WINDOWS_APP_PRD_AND_ROADMAP.md](11_WINDOWS_APP_PRD_AND_ROADMAP.md) · execution plan [12_WINDOWS_EXECUTION_PLAN.md](12_WINDOWS_EXECUTION_PLAN.md)

**Web companion:** Decision [PRD/14](14_WEB_CLIENT_DECISION_BRIEF.md) approved · SDD `web-client` · path `web/` · **W1 Free offline shell** + polish (e2e, wake lock, export, prefs) · **W2**: email register/login, token refresh, `/users/me` entitlement, `POST /sync/initial-upload` when Everywhere (configure `PUBLIC_API_BASE_URL` + CORS), **bidirectional sync** — initial-upload round-trip applies the merged server state back to IndexedDB (LWW merge of tasks/sessions/prefs), `GET /sync/full` paginated pull, auto-sync on local mutations (debounced) and on tab refocus (throttled 60s). Residual: WS live invalidation (backend does not yet emit `sync_required`), Google OAuth web, fine-grained dirty-tracking. Marketing NG6: keep noindex until verified live.

### Monetization Direction (2026-04-22, v3.1)

- **Approved commercial model:** Pepinillo+ (one-time, NOT a subscription) + Everywhere/AI+ (recurring sync + Advanced AI).
- **Naming finalized (v3.1):** "Pepinillo+" for the one-time purchase, "Everywhere/AI+" for the subscription. Entitlement IDs: `pepinillo_plus` + `everywhere_plus`.
- **Product ID reuse:** Existing `pro.lifetime` → Pepinillo+, `pro.monthly`/`pro.annual` → Everywhere/AI+. No new SKUs needed.
- **Apple Intelligence as hero:** On-device AI Reports (Foundation Models + template fallback) is the primary differentiator.
- **Próximamente strategy:** Everywhere/AI+ features (Backend Sync, AI Coach, Task Scheduling, Subtask Gen) shown only in paywall with subtle badge.
- **Transparency principle:** Pepinillo+ is explicitly "One purchase. Yours forever. Not a subscription."
- **Prices (global):** Pepinillo+ $19.99 one-time · Everywhere/AI+ $4.99/month · $34.99/year.
- **Prices (LATAM):** Pepinillo+ $9.99 · Everywhere/AI+ $2.49/month · $17.99/year.
- **Implementation status (code — done):**
  - [x] `AppConfig.aiInsightsEnabled = true`
  - [x] `PaywallView.swift` — two-tier design, "NOT a subscription" badge, Apple Intelligence as hero
  - [x] `SubscriptionClient.swift` — `pepinillo_plus`/`everywhere_plus` entitlements, legacy `premium`/`pro` fallback
  - [x] `UserCapabilities.swift` — granular capability model
  - [x] `Pepinillo.storekit` — renamed to "Pepinillo+" / "Everywhere/AI+ Monthly" / "Everywhere/AI+ Annual", prices $19.99/$4.99/$34.99
  - [x] Mock display names and prices aligned to v3.1
- **Implementation status (external — manual tasks remaining):**
  - [x] Repository secret hardening: current tracked credentials/tokens sanitized; redacted CI scanner added (#613)
  - [ ] **[BLOCKER]** Revoke/rotate the exposed RevenueCat server key and update the production runtime (#613)
  - [ ] Enable GitHub Secret Protection/push protection and decide coordinated history remediation (#613)
  - [ ] **[BLOCKER]** Update revoked API keys in RevenueCat (App Store Connect API: `22YZT9D55J` · In-App Purchase: `Z95PS2LD73`)
  - [ ] Complete metadata + rename products in App Store Connect
  - [ ] Create `pepinillo_plus` + `everywhere_plus` entitlements in RevenueCat
  - [ ] Create new RevenueCat offerings with canonical naming
  - [ ] Configure S2S Notifications webhook in App Store Connect

### Product Reset Direction (2026-04-21)

- **Hero user:** knowledge worker / creative doing deep work daily.
- **Canonical product pillars:** `Execute`, `Plan`, `Reflect`, and `Admin`.
- **Canonical phone surfaces:** `Focus`, `Plan`, and `Dashboard` as primary destinations; `Account / Admin` lives outside the main productivity axis.
- **Current runtime baseline during transition:** iPhone ships `Focus / Plan / Dashboard / More`; Android phone is converging to the same shell while ownership is consolidated.
- **Current product gaps:** task depth is still too light, Dashboard/reviews are not yet a unified reflection engine, and AI positioning is more defined in strategy than in product behavior.
- **Immediate product priority:** stop accumulating disconnected surfaces and redesign screen ownership before major new feature expansion.
# 1. Product Phase

Pepinillo has moved from a product construction phase into a **growth validation phase**.

The main objective is no longer maximizing feature count. The objective is validating that real users:

1. Discover Pepinillo.
2. Understand its value.
3. Complete focus sessions.
4. Build a recurring habit.
5. Are willing to pay for premium features.

See:

- `docs/strategy/PRODUCT_DIRECTION.md`
- `docs/strategy/GROWTH_VALIDATION_PLAN.md`

---

# 2. Platform Status

| Platform | Status | Notes |
| --- | --- | --- |
| Android | Active Production Platform | Native Android app released and available. Current focus: stability, acquisition and retention. |
| iOS | Active Production Platform | Native iOS app released and available. Current focus: stability, acquisition and retention. |
| watchOS | Active Companion Platform | Supports Apple ecosystem experience. Maintained as part of iOS strategy. |
| macOS | Active Development (v1: Focus-first + Plan) | Native `PepinilloMac` target; menu bar + Focus/Plan/Today; no auth/AI in v1. Contract: `ios/docs/macos-design-contract.md`. |
| Wear OS | Active Companion Platform | Supports Android ecosystem experience. Maintained as part of Android strategy. |
| Backend | Active Infrastructure | Required services and infrastructure should prioritize current mobile needs. |
| Windows | Paused Experiment | Technical feasibility validated. Not an active roadmap commitment. |
| Web Companion | Paused Experiment | Technical feasibility explored. Not an active roadmap commitment. |

---

# 3. Active Product Priorities

Current priorities:

## User Growth

- Improve onboarding.
- Improve store conversion.
- Acquire first meaningful group of real users.
- Collect qualitative feedback.

## Retention

- Improve the Focus → Complete → Return loop.
- Understand which focus modes create the most value.
- Improve daily and weekly engagement.

## Reliability

- Maintain Android and iOS production quality.
- Resolve critical bugs quickly.
- Improve automated confidence.

## Monetization

- Validate premium positioning.
- Measure conversion.
- Improve paywall clarity.

---

# 4. Product Direction

Pepinillo is a native deep-work companion.

The core experience is:

```
Plan → Focus → Complete → Reflect
```

Primary pillars:

## Focus

Helping users enter meaningful work sessions with minimal friction.

Supported methods:

- Pomodoro
- Flowtime
- Time Block
- Stopwatch

## Plan

Tasks exist to support focused execution.

Pepinillo is not intended to become a complete project management platform.

## Reflect

Analytics and reviews help users understand their work patterns.

---

# 5. Platform Decisions

## Active

- Android
- iOS
- watchOS
- Wear OS
- Backend services required for production functionality

## Paused

### Windows

Status: Archived exploration.

Reason:

The implementation validated technical feasibility, but current business validation must happen on mobile first.

Resume criteria:

- Proven mobile traction.
- User demand.
- Clear business justification.

### Web Companion

Status: Archived exploration.

Reason:

The companion experience was technically explored, but browser access is not a current growth priority.

Resume criteria:

- User demand.
- Sync maturity.
- Clear acquisition or retention benefit.

---

# 6. Monetization Direction

Current model:

## Pepinillo+

One-time purchase.

Provides premium local capabilities.

## Everywhere / AI+

Subscription model for recurring-cost capabilities such as:

- cloud features;
- advanced AI capabilities;
- future cross-device services.

The monetization strategy should be validated through real user behavior before expanding complexity.

---

# 7. Important Product Rules

Before implementing major features, evaluate:

- Does this improve activation?
- Does this improve retention?
- Does this improve monetization?
- Is there evidence users need it?

If the answer is unclear, document the idea but avoid prioritizing implementation.

---

# 8. Documentation Rules

Source of truth:

- `PRD/` → product requirements, roadmap and official status.
- `docs/strategy/` → strategic context and decision reasoning.
- `docs/` → technical documentation, guides and operational notes.

Avoid duplicated product status documents.

---

# 9. Current Strategic Statement

Pepinillo already has a strong technical foundation.

The next challenge is not building more software. The next challenge is proving product value with real users.

Technology enables the experience.

Focused work is the product.
