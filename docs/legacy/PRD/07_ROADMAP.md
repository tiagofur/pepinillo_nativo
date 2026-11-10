# Unified Roadmap — Pepinillo

**Date:** 2026-08-05  
**Version:** 3.0  
**Status:** Active (source of truth)  
**Live status detail:** [09_CURRENT_STATUS.md](09_CURRENT_STATUS.md)

---

## 1. Answer first

| Platform | Product readiness | What remains |
| -------- | ----------------- | ------------ |
| **iOS** | App Store ready (code + audit fixes) | External: RevenueCat/ASC v3.1 config; submission when store ops ready |
| **watchOS** | Companion shipped | Entitlement propagation polish; simplified journal UX |
| **Android** | Production ready (v3.0.0) | Play Console naming/catalog; billing v3.1 external config |
| **Wear OS** | Production ready | Companion entitlement propagation closure |
| **Windows** | **W0–W15 excellence code complete** | **#575** WinUI hardware smoke · **#568** Partner Center / Store flight |
| **Web (companion)** | **Product approved** ([PRD/14](14_WEB_CLIENT_DECISION_BRIEF.md)) | Spec/design/tasks next; **not marketed** until shipped; Free local + Everywhere sync |
| **Backend (Go)** | API complete locally (migrations through 000014) | VPS deploy (see root `DEPLOYMENT.md`); store webhook live endpoint |

Do **not** treat fake percentage bars as status. For implementation truth, use **PRD/09**.

---

## 2. Platforms & doc map

| Area | Canonical docs |
| ---- | -------------- |
| Product vision / features / monetization | `PRD/01`–`04` |
| Architecture iOS / Android | `PRD/05`, `PRD/06` |
| **This roadmap** | `PRD/07` (this file) |
| Live implementation status | `PRD/09` |
| Windows product + execution + excellence | `PRD/11`, `PRD/12`, `PRD/13` |
| Web companion decision + Free/Everywhere matrix | `PRD/14` |
| Windows Store ops | `windows/store/*` (launch checklist, IAP, a11y smoke) |
| Deploy (IONOS VPS) | root `DEPLOYMENT.md`, `VPS_SETUP_CHECKLIST.md` |
| Operational vault (MOCs, runbooks, status notes) | `docs/` — **not** a second PRD |

---

## 3. Development context

- **Solo developer:** Tiago + AI-assisted sessions  
- **Stack:** Native iOS (Swift + TCA), Android (Kotlin), Windows (WinUI 3 / C#), planned web companion (lightweight SPA), shared Go backend  
- **Data:** iOS may use CloudKit for Apple-local sync; cross-platform sync is Go backend (web Free stays browser-local until Everywhere)  
- **Commercial model (v3.1):** Pepinillo+ (one-time) + Everywhere/AI+ (subscription) — see `PRD/04`; web paid path is Everywhere-only

---

## 4. Active tracks (2026-08)

### 4.1 Mobile launch readiness

| Track | Status | Notes |
| ----- | ------ | ----- |
| Core product (Focus 4 modes, Tasks, Analytics) | Done on iOS + Android phones | Watches: companion surfaces |
| Monetization code | Done (entitlements/paywall wiring) | **External** RevenueCat + ASC / Play config still open |
| Auth hardening (Apple nonce, etc.) | Done (backend P0/P1) | Deploy + live webhooks pending |
| Localization EN/ES/PT | Largely done | Minor string fallbacks possible |

### 4.2 Windows track

| Slice | Status |
| ----- | ------ |
| Packaging P0–P3 + excellence **W0–W15** | **Code complete / merged** (see PRD/09 §3b, PRD/13) |
| WinUI hardware smoke | **Open** — GitHub **#575** · `windows/store/LAUNCH_CHECKLIST.md` Phase B + `A11Y_SMOKE.md` |
| Microsoft Store / Partner Center | **Open** — GitHub **#568** · screenshots, publisher CN, IAP SKUs, Internal flight |

**Windows pricing (D1):** Pepinillo+ Windows **$9.99** durable (platform-scoped); Everywhere **$4.99/mo · $34.99/yr** (align global mobile). Durable product ID details: store docs under `windows/store/`.

Detail: [11_WINDOWS_APP_PRD_AND_ROADMAP.md](11_WINDOWS_APP_PRD_AND_ROADMAP.md) · [12_WINDOWS_EXECUTION_PLAN.md](12_WINDOWS_EXECUTION_PLAN.md) · [13_WINDOWS_EXCELLENCE_PLAN.md](13_WINDOWS_EXCELLENCE_PLAN.md)

### 4.3 Backend / ops

| Item | Status |
| ---- | ------ |
| REST API, auth, sync, billing verify, webhooks (code) | Implemented |
| Migrations `000013` tier capabilities + `000014` AI credits | Present in repo |
| Production deploy on IONOS VPS | Ops — follow `DEPLOYMENT.md` |

### 4.4 Web companion track

| Slice | Status |
| ----- | ------ |
| Decision brief + Free / Everywhere / N/A matrix | **Approved** — [PRD/14](14_WEB_CLIENT_DECISION_BRIEF.md) |
| W1 Free local shell (Focus / Plan / Dashboard / Account) | Not started |
| W2 Auth + Everywhere sync (needs backend prod) | Not started |
| W3–W5 Premium web depth + AI+ surfaces | Not started |

**Model:** Free = browser-local + Free caps; Everywhere = web-capable premium + multi-device sync. Do **not** market web until a client ships (NG6).

Detail: [14_WEB_CLIENT_DECISION_BRIEF.md](14_WEB_CLIENT_DECISION_BRIEF.md)

---

## 5. Near-term priority order

1. **Windows ops:** #575 smoke on real Windows 10/11 → #568 Store flight (does not invent “published” until flight succeeds).  
2. **Billing external config:** RevenueCat entitlements `pepinillo_plus` / `everywhere_plus`, offerings rename, ASC keys rotation (dashboard only — never commit secrets).  
3. **Backend deploy:** live API + RevenueCat webhook URL.  
4. **Store submissions:** iOS / Android when external blockers clear.  
5. **Parity polish:** watch entitlement propagation; residual mobile gaps listed in PRD/09 and `docs/Cross-Platform/Parity Matrix.md`.  
6. **Web planning (non-blocking ops):** SDD spec → design → tasks for `web-client` when ready to schedule engineering; Free W1 can proceed without prod backend, W2+ needs deploy.

---

## 6. Post-launch / later (not blocking current ops)

Historical effort estimates and phase hour tables from v1–v2 roadmaps are archived conceptually here as **completed foundation work**. Future opportunities (not commitments):

| Band | Ideas |
| ---- | ----- |
| P1 post-store | AI Coach (cloud), deeper sync realtime, Android/iOS paywall naming cleanup in stores |
| P2 | Smarter scheduling, subtask AI decomposition, stronger tablet layouts |
| P3 | Broader ecosystem (standalone watch depth, family/team, export integrations) |

**macOS** remains out of commercial promise until a real client exists.  
**Web** product model is **approved** (companion; Free local + Everywhere sync) but stays **out of commercial promise** until W1+ ships — then market only what is live (NG6 / ADR-001 amendment spirit).

---

## 7. Historical note (v1–v2)

Versions **1.0** (2026-03) and **2.0** (2026-04) tracked hour estimates and May 2026 mobile v1.0 critical path. Mobile product surfaces are largely implemented; remaining work is **ops, store config, Windows smoke/Store, and deploy** — tracked in PRD/09, not in stale percentage tables.

---

## 8. Maintenance rule

After significant work:

1. Update **PRD/09** first.  
2. Adjust this roadmap only when tracks or remaining ops change.  
3. Keep `docs/` operational notes in sync; never re-fork full PRD bodies under `docs/PRD/`.
