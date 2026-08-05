# Monetization — Pepinillo (Apple-First Rollout)

**Version:** 3.1  
**Last Updated:** 2026-04-21  
**Scope:** Canonical packaging, pricing, rollout, and entitlement architecture  
**Authoritative Source for Packaging and Pricing:** This document  
**Update Cadence:** Per commercial model change

> **Changelog v3.1 (2026-04-21):** Renamed entitlement IDs `apple_unlock` → `pepinillo_plus` and `everywhere` → `everywhere_plus` for marketing-code alignment. No functional change.

---

## 1. Business Model

**Freemium with two paid layers.** Pepinillo separates local premium value from recurring-cost value.

- **Pepinillo+:** one-time purchase for the full Apple experience with Apple Intelligence.
- **Everywhere/AI+:** monthly or annual subscription for cross-platform sync and advanced AI capabilities.

This split exists because local premium features can be sold once, but multi-platform backend sync and cloud AI create ongoing cost. The commercial model reflects that cost structure.

**Positioning:** Pepinillo is not monetizing cosmetic access. Users pay to get better at deep work and to keep one reliable system across their devices.

**Transparency principle:** Pepinillo+ is explicitly **not a subscription**. One purchase, forever. This must be crystal clear in all user-facing copy. Users who buy Pepinillo+ own it — no recurring charges, no surprises.

**Rollout principle:** do not market value that is not yet shipped. `Everywhere/AI+` features listed as "Próximamente" are communicated only in the paywall to set expectations, not promoted elsewhere in the app.

---

## 2. Canonical Commercial Vocabulary

| Term | Meaning | Operational note |
| ---- | ------- | ---------------- |
| **Free** | Core Pepinillo experience | Must be strong enough to create habit before monetization pressure appears |
| **Pepinillo+** | One-time Apple-only premium purchase | Not a subscription. Funds local premium value + Apple Intelligence, not recurring backend or cloud AI cost |
| **Everywhere/AI+** | Recurring monthly/annual subscription | Funds cross-platform sync, advanced cloud AI (Coach, Scheduling, Subtask Gen), and monthly AI credits |
| **Apple Intelligence** | On-device AI via Apple Foundation Models + template fallback | Included in Pepinillo+ on Apple platforms. Always works — template fallback when Foundation Models unavailable |
| **AI+ (Advanced AI)** | Cloud-powered AI features: Coach, Task Scheduling, Subtask Generation, Advanced Insights | Included only in Everywhere/AI+ |
| **Local Intelligence** | Mode Intelligence, on-device/template AI Reports | Included in Pepinillo+ |
| **Legacy `pro` / `premium`** | Transitional runtime shorthand | Mapping: `pro.lifetime` → Pepinillo+, `pro.monthly`/`pro.annual` → Everywhere/AI+ |

---

## 3. Offer Structure

### 3.1 Free

| Feature | Free limit | Why it stays free |
| ------- | ---------- | ----------------- |
| Focus modes | Pomodoro + Stopwatch | Enough to prove the core workflow |
| Tasks | Up to 3 active tasks | Lets users form a habit before paying |
| Subtasks / recurrence | Not available | High perceived value for serious planners |
| Analytics | Today + last 7 days | Demonstrates value, preserves upgrade trigger |
| Widgets | One basic timer widget | Good trial surface without giving away the full ecosystem |
| Themes | Default / system only | Simple aesthetic gate |
| Soundscapes | 4 basics | Enough to feel product quality |
| Apple Watch / Wear OS | No full companion experience | Companion apps remain a premium differentiator |
| Sync | Device-local only | No cross-device promise in Free |
| Export | Not available | Professional workflow feature |
| AI Reports | Not available | Premium reflection feature |

### 3.2 Pepinillo+ (One-Time Purchase)

Pepinillo+ is the one-time premium purchase for iPhone, iPad, macOS, and watchOS.

**Explicitly NOT a subscription.** Users own it forever after a single purchase.

| Feature | Included in Pepinillo+ |
| ------- | ---------------------- |
| Focus modes | Flowtime + Time Block in addition to Free modes |
| Tasks | Unlimited tasks, subtasks, recurrence |
| Analytics | 30-day + 1-year history, Weekly Review, Monthly Review |
| Apple Intelligence | On-device AI Reports via Apple Foundation Models (iOS 26+) with template fallback for all devices |
| Mode Intelligence | Smart mode suggestions based on historical session data |
| Themes and soundscapes | All premium themes (Forest, Ocean, Sunset) and premium soundscapes |
| Apple ecosystem surfaces | All widgets (S/M/L + Lock Screen), full watchOS companion, Live Activity, Dynamic Island |
| Export | CSV / PDF export |
| Apple sync | iCloud / CloudKit sync between Apple devices |
| Streak protection | 1 free skip per week |
| Calendar integration | Apple Calendar time blocking |
| Health integration | Apple Health Mindful Minutes |
| Reminders import | Apple Reminders one-way import |
| System Focus Modes | Auto DND during sessions via FocusFilterIntent |

Pepinillo+ **does not** include cross-platform backend sync, cloud AI features, or monthly AI credits.

**Paywall copy emphasis:**
- "One purchase. Yours forever."
- "Not a subscription — pay once, own Pepinillo+ for life."
- Apple Intelligence as headline differentiator

### 3.3 Everywhere/AI+ (Subscription)

Everywhere/AI+ is the recurring plan for cross-platform power users who want the deepest AI assistance.

| Feature | Included in Everywhere/AI+ |
| ------- | -------------------------------- |
| **Everything in Pepinillo+** | Full Apple premium experience included |
| Cross-platform backend sync | Go-backend account sync across iOS + Android + Web (when available) |
| Advanced AI Insights | Cloud-powered predictive insights: productive windows, burnout detection, trend forecasting |
| AI Coach | Personalized productivity coaching with actionable weekly recommendations |
| AI Task Scheduling | Smart task scheduling based on energy patterns, calendar availability, and historical productivity |
| AI Subtask Generation | Automatically break complex tasks into actionable subtasks |
| 100 AI Credits / month | Monthly allowance for cloud AI workflows (no rollover) |
| Cross-device recovery | Restore and migrate data through account-based identity |
| Android / Wear OS | When available, includes full premium experience on those platforms |

Everywhere/AI+ never offers lifetime access. Recurring infrastructure and recurring AI must remain on recurring billing.

**Próximamente note:** Backend Sync, AI Coach, Task Scheduling, and Subtask Generation features are displayed in the paywall as "Próximamente" to set expectations. They are NOT promoted elsewhere in the app until shipped.

---

## 4. Pricing (AUTHORITATIVE)

**Effective Date:** 2026-04-21  
**These prices supersede the former single-tier Pro model for planning and rollout.**

### Global Market (US/EU/Tier 1)

| Offer | Price | Equivalent Monthly | Notes |
| ----- | ----- | ------------------ | ----- |
| **Pepinillo+** | **$19.99 one-time** | — | One purchase, forever. Not a subscription |
| **Everywhere/AI+ Monthly** | **$4.99/month** | $4.99 | Cross-platform sync + Advanced AI |
| **Everywhere/AI+ Annual** | **$34.99/year** | $2.92 | 42% lower than monthly |

### LATAM (MX/CO/AR/BR/CL/PE)

| Offer | Price | Equivalent Monthly | Notes |
| ----- | ----- | ------------------ | ----- |
| **Pepinillo+** | **$9.99 one-time** | — | One purchase, forever. Not a subscription |
| **Everywhere/AI+ Monthly** | **$2.49/month** | $2.49 | Cross-platform sync + Advanced AI |
| **Everywhere/AI+ Annual** | **$17.99/year** | $1.50 | 40% lower than monthly |

### Pricing rationale

- **Pepinillo+ stays below the annual subscription** so users can afford a one-time upgrade without undermining recurring economics.
- **Everywhere/AI+ Annual** is the default value plan because it funds infrastructure more predictably and lowers churn risk.
- **LATAM pricing stays materially below Tier 1 pricing** to preserve Pepinillo's regional advantage.
- **No lifetime recurring offer** because sync and AI costs do not disappear.

---

## 5. Apple Intelligence Strategy

### Why This Wins Apple Design Awards

Pepinillo's Apple Intelligence integration is the **primary differentiator** against every other focus/productivity app:

1. **On-device AI Reports** — Uses Apple Foundation Models (iOS 26+) to generate personalized productivity reports without any API call. Zero latency, zero cost, zero privacy concerns.
2. **Template Fallback** — When Foundation Models are unavailable (older devices, first-gen implementation), deterministic template-based reports provide the same structured experience.
3. **Mode Intelligence** — Local ML that learns which focus technique works best for each task type. Pure on-device, no cloud dependency.
4. **Siri Integration** — 9 intents across 3 languages for hands-free productivity. "How's my focus today?" is magical.
5. **Interactive Widgets** — Full session control from Home Screen, Lock Screen, and Control Center.
6. **Live Activity + Dynamic Island** — Always-visible session state during deep work.

### AI+ (Everywhere/AI+ Cloud Features)

These features require cloud AI (Gemini/OpenAI) and backend infrastructure:

| Feature | Description | Why it needs cloud |
| ------- | ----------- | ------------------ |
| **Advanced AI Insights** | Predictive productive windows, burnout detection, long-term trend forecasting | Requires large context window + historical pattern analysis beyond on-device capability |
| **AI Coach** | Personalized weekly coaching with habit recommendations, motivation, and accountability | Requires nuanced natural language generation beyond template scope |
| **AI Task Scheduling** | Smart scheduling based on energy patterns, calendar, and historical data | Requires multi-factor optimization across calendar + health + historical data |
| **AI Subtask Generation** | Automatically decompose complex tasks into actionable subtasks | Requires task understanding + decomposition reasoning |

### Implementation Architecture

```
AI Report Generation Pipeline:
  ┌──────────────────────────────────────────────┐
  │  AIReportClient.liveValue                     │
  │  ┌──────────────────────────────────────────┐ │
  │  │ 1. OnDeviceReportGenerator               │ │
  │  │    (Apple Foundation Models, iOS 26+)     │ │
  │  │    ↓ unavailable/error?                   │ │
  │  │ 2. TemplateReportGenerator                │ │
  │  │    (deterministic, ALWAYS works)           │ │
  │  └──────────────────────────────────────────┘ │
  └──────────────────────────────────────────────┘

AI+ Features (future, Everywhere/AI+):
  ┌──────────────────────────────────────────────┐
  │  Cloud AI Client                              │
  │  → Gemini / OpenAI API                        │
  │  → Monthly AI credits (100/month)             │
  │  → Requires backend + billing verification    │
  └──────────────────────────────────────────────┘
```

---

## 6. Platform Packaging

### 6.1 iOS / watchOS / Apple ecosystem

| Aspect | Detail |
| ------ | ------ |
| Billing framework | RevenueCat SDK v5+ wrapping StoreKit 2 |
| Primary offers | Pepinillo+ (one-time), Everywhere/AI+ Monthly, Everywhere/AI+ Annual |
| Apple sync | CloudKit / iCloud unlocked by Pepinillo+ or Everywhere/AI+ |
| Backend sync | Requires Everywhere/AI+ (Próximamente) |
| Watch behavior | watchOS inherits entitlement state from the iPhone companion |
| Restore behavior | RevenueCat restore + backend reconciliation |

### 6.2 Android / Wear OS

| Aspect | Detail |
| ------ | ------ |
| Billing framework | RevenueCat / Google Play Billing |
| Primary offers during rollout | Everywhere/AI+ Monthly, Everywhere/AI+ Annual |
| Local premium | Included inside Everywhere/AI+ during rollout |
| Backend sync | Requires Everywhere/AI+ |
| Wear behavior | Wear OS inherits entitlement state from the Android companion |

### 6.3 Web (companion client)

**Product decision approved:** [PRD/14](14_WEB_CLIENT_DECISION_BRIEF.md). Client not shipped; do not market until live (NG6).

| Aspect | Detail |
| ------ | ------ |
| Role | Companion extra — large screen without install; not a native OS replacement |
| Free | Browser-local storage only; **same Free limits** as §3.1 (Pomodoro + Stopwatch, 3 active tasks, 7-day analytics, etc.) |
| Primary paid offer | **Everywhere/AI+** Monthly / Annual only |
| Pepinillo+ (one-time) | **Not offered on web** (Apple-ecosystem purchase) |
| Local premium on web | Included inside Everywhere/AI+ (same pattern as Android rollout) for web-capable features |
| Backend sync | Requires Everywhere/AI+; Free web never promises multi-device |
| Billing channel | TBD at design (Stripe/web checkout vs. subscribe/restore via store apps + account) |
| Restore | Account + backend entitlement (`everywhere_plus`); cross-device recovery when subscribed |

### 6.4 Product IDs (Reusing Existing SKUs)

**We reuse the 3 existing product IDs in App Store Connect.** Only the metadata (name, description, price) changes.

**iOS (StoreKit / RevenueCat):**

| Product ID | Previous Name | New Name | Type |
| ---------- | ------------- | -------- | ---- |
| `com.pepinillo.app.pro.lifetime` | Pro Lifetime | **Pepinillo+** | Non-consumable (one-time) |
| `com.pepinillo.app.pro.monthly` | Pro Monthly | **Everywhere/AI+ Monthly** | Auto-renewable subscription |
| `com.pepinillo.app.pro.annual` | Pro Annual | **Everywhere/AI+ Annual** | Auto-renewable subscription |

**Android (Google Play / RevenueCat):**

| Product ID | Name | Type |
| ---------- | ---- | ---- |
| `com.pepinillo.app.pro.monthly` | Everywhere/AI+ Monthly | Auto-renewable subscription |
| `com.pepinillo.app.pro.annual` | Everywhere/AI+ Annual | Auto-renewable subscription |

### 6.5 RevenueCat Entitlement Configuration

| Entitlement Name | Products | Capabilities Unlocked |
| ---------------- | -------- | --------------------- |
| `pepinillo_plus` | `pro.lifetime` | `localPremium`, `appleCloudSync`, `localAI`, `exportAccess` |
| `everywhere_plus` | `pro.monthly`, `pro.annual` | All `pepinillo_plus` + `backendSync`, `aiCreditsMonthly: 100`, `crossDeviceRestore` |
| `premium` (legacy) | — | Grandfathered → `pepinillo_plus` if lifetime, `everywhere_plus` if subscription |
| `pro` (legacy) | — | Same mapping as `premium` |

**Migration:** Existing `premium`/`pro` entitlement holders are grandfathered. Lifetime → `pepinillo_plus` capabilities. Subscription → `everywhere_plus` capabilities. No user loses access.

---

## 7. Backend And Entitlement Architecture

### Target capabilities

| Capability | Pepinillo+ | Everywhere/AI+ | Purpose |
| ---------- | ---------- | -------------- | ------- |
| `local_premium` | ✅ | ✅ | Unlock local premium features on the current platform |
| `apple_cloud_sync` | ✅ | ✅ | Allow Apple-only iCloud / CloudKit sync |
| `local_ai` | ✅ | ✅ | Apple Intelligence on-device reports + Mode Intelligence |
| `export_access` | ✅ | ✅ | CSV / PDF data export |
| `backend_sync` | — | ✅ | Go-backend sync across supported clients |
| `ai_credits_monthly` | — | 100/month | Cloud AI credit allowance |
| `cross_device_restore` | — | ✅ | Account-based entitlement portability |

### Rules

1. **Store purchase or RevenueCat event** identifies the source product.
2. **RevenueCat entitlement resolution** maps product to capability set (client-side).
3. **Backend** derives capabilities from that product for server-side enforcement.
4. **Clients** adapt UX locally, but backend remains authoritative for protected operations.
5. **Lifetime (Pepinillo+)** grants `local_premium`, `apple_cloud_sync`, `local_ai`, `export_access` but must never grant perpetual `backend_sync` or perpetual AI credits.

**Billing verification endpoint remains authoritative:** `POST /api/v1/billing/verify`

---

## 8. Gating And Paywall Rules

| Trigger | Recommended offer | Why |
| ------- | ----------------- | --- |
| User taps Flowtime / Time Block | Pepinillo+ or Everywhere/AI+ | Premium local value |
| User opens AI Report | Pepinillo+ or Everywhere/AI+ | Apple Intelligence included in both paid tiers |
| User wants iCloud sync | Pepinillo+ or Everywhere/AI+ | Apple-local continuity |
| User wants advanced AI features | Everywhere/AI+ (Próximamente) | Cloud AI features |
| User wants cross-platform sync | Everywhere/AI+ (Próximamente) | Backend infrastructure required |

### Paywall Design Principles

1. **Transparency first:** Pepinillo+ is clearly labeled "One purchase. Yours forever. Not a subscription."
2. **Apple Intelligence as hero:** The AI Reports feature is the headline differentiator
3. **Próximamente section:** Everywhere/AI+ features not yet shipped appear with a subtle badge
4. **Value anchoring:** Annual subscription shows per-month savings

---

## 9. Rollout Plan

| Phase | Goal | Status |
| ----- | ---- | ------ |
| **Phase 0** | Documentation alignment | ✅ This document (v3.0) |
| **Phase 1** | Enable Apple Intelligence + redesign Paywall | 🔄 In progress |
| **Phase 2** | Submit to App Store with Pepinillo+ as primary offer | ⬜ Next |
| **Phase 3** | Backend Sync + AI+ implementation for Everywhere/AI+ | ⬜ Future |
| **Phase 4** | Android migration to Everywhere/AI+ | ⬜ Future |
| **Phase 5** | Marketing expansion (macOS when shipped; **Web companion** only after client live — model approved in PRD/14) | ⬜ Future |

---

## 10. Success Metrics

| Metric | Target |
| ------ | ------ |
| Free → Pepinillo+ conversion | ≥ 4% on Apple platforms |
| Free → Everywhere/AI+ conversion | ≥ 3% in first 90 days (post-launch) |
| Pepinillo+ → Everywhere/AI+ attach rate | ≥ 15% |
| AI Report activation | ≥ 50% of paid users generate at least 1 report/month |
| AI credit activation (future) | ≥ 40% of Everywhere/AI+ subscribers use credits monthly |

---

## Appendix: Changes from v2.0 → v3.0

| Change | v2.0 | v3.0 |
| ------ | ---- | ---- |
| One-time purchase name | "Apple Unlock" | **Pepinillo+** |
| Subscription name | "Pepinillo Everywhere" | **Everywhere/AI+** |
| Product IDs | New IDs (not yet created) | **Reusing existing** `pro.lifetime`, `pro.monthly`, `pro.annual` |
| RevenueCat entitlements | `apple_unlock`, `everywhere` (new) | Same products, renamed to `pepinillo_plus`, `everywhere_plus` in v3.1 |
| Apple Intelligence | Mentioned as "Local Intelligence" | **Full section** with implementation architecture |
| AI+ features | "Monthly AI credits" | **Detailed:** Advanced Insights, AI Coach, Task Scheduling, Subtask Gen |
| Próximamente strategy | Not defined | **Defined:** Only in paywall, not promoted elsewhere |
| Transparency | Generic | **Explicit:** "Not a subscription" messaging throughout |

---

## Appendix: Changes from v3.0 → v3.1

| Change | v3.0 | v3.1 |
| ------ | ---- | ---- |
| RC entitlement (one-time) | `apple_unlock` | **`pepinillo_plus`** |
| RC entitlement (subscription) | `everywhere` | **`everywhere_plus`** |
| Swift enum (SubscriptionState) | `.appleUnlock` / `.everywhere` | **`.pepinilloPlus`** / **`.everywherePlus`** |
| Swift static (UserCapabilities) | `.appleUnlock` / `.everywhere` | **`.pepinilloPlus`** / **`.everywherePlus`** |
| tierIdentifier string | `"apple_unlock"` / `"everywhere"` | **`"pepinillo_plus"`** / **`"everywhere_plus"`** |

No product IDs or backend tier strings were changed. No functional behavior changed.

---

## Appendix: Strategic Notes

- The old one-tier Pro model was simple, but it mixed local premium, backend cost, and AI cost into one offer.
- Pepinillo+ gives a safer one-time entry point for users who mostly live inside the Apple ecosystem.
- Everywhere/AI+ is the recurring business layer that can sustainably fund sync, identity, server operations, and cloud AI.
- Reusing existing product IDs eliminates App Store Connect migration risk and RevenueCat reconfiguration complexity.
- Apple Intelligence is our competitive moat. No other focus app has this level of on-device AI integration with template fallback.
