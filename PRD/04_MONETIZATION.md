# Monetization — Pepinillo (iOS + Android)

**Version:** 1.0  
**Last Updated:** 2026-03-24  
**Scope:** Unified monetization document for both platforms  
**Authoritative Source for Pricing:** This document  
**Update Cadence:** Per pricing change

---

## 1. Business Model

**Freemium with subscription.** The same model applies on both platforms (iOS and Android).

Users get a functional and useful experience in the free tier — sufficient to validate the app's value — but with strategic limitations that motivate conversion to Pro. The goal is not to frustrate users, but to demonstrate premium value.

**Price Positioning:** Premium productivity tier ($25-50/year), not the free timer market ($2-5). We compete in the league of Things 3, Fantastical, and Craft.

---

## 2. FREE Tier (Free)

| Feature            | Free limit                                | Justification                                              |
| ------------------ | ----------------------------------------- | ---------------------------------------------------------- |
| Focus modes        | Pomodoro + Chrono/Stopwatch (2 of 4)      | The 2 most basic modes; they cover casual use cases        |
| Active tasks       | Maximum 3 tasks                            | Enough to test, not enough for active users                |
| Subtasks           | NOT available                              | High perceived value, low development cost                 |
| Recurring tasks    | NOT available                              | Pro only                                                   |
| Soundscapes        | 4 basics: Rain, Forest, Cafe, White Noise | Enough to experience the value                             |
| Analytics          | Today only + last 7 days                   | Motivates upgrade for full history                         |
| Widgets            | 1 basic widget (timer)                     | All others are Pro                                         |
| Themes             | Default theme only                         | Aesthetic limitation that motivates upgrade                |
| Daily sessions     | Unlimited                                  | Do NOT limit sessions — frustrates without converting      |
| History            | 7 days                                     | Data is lost afterward; motivates Pro for retention        |
| Sync/Cloud         | NOT available (local only)                 | Sync as a Pro differentiator                               |
| Watch/Wear OS      | NOT available                              | Strong differentiator for power users                      |
| Data export        | NOT available                              | Pro only                                                   |

---

## 3. PRO Tier

| Feature           | Pro                                                                                 |
| ----------------- | ----------------------------------------------------------------------------------- |
| Focus modes       | All modes: Pomodoro, Flowtime, Time Block, Chrono/Stopwatch                        |
| Tasks             | Unlimited + subtasks + recurrence                                                   |
| Soundscapes       | 8 total: Rain, Forest, Cafe, White Noise + Binaural Beats, Lo-fi, Ocean, Fireplace |
| Analytics         | Full history + Weekly Review + Monthly Review + AI Reports                          |
| Widgets           | All widgets (Timer, Stats, Tasks, Lock Screen, Quick Settings)                      |
| Themes            | All available themes (including Liquid Glass on iOS 26, Material You on Android)    |
| Sync/Cloud        | Full sync across devices (CloudKit on iOS, Go backend on Android)                   |
| Watch/Wear OS     | Full app on Apple Watch and Wear OS                                                 |
| Data export       | CSV and PDF                                                                          |
| Streak Protection | 1 free skip per week                                                                 |

---

## 4. Pricing (AUTHORITATIVE)

**Effective Date:** 2026-03-24  
**These prices supersede all prior references.**

### Global Market (US/EU/Tier 1)

| Plan     | Price           | Equivalent Monthly | Savings |
| -------- | --------------- | ------------------ | ------- |
| Monthly  | **$3.99/month** | $3.99              | —       |
| Annual   | **$24.99/year** | $2.08              | 48%     |
| Lifetime | **$49.99**      | —                  | —       |

### LATAM (MX/CO/AR/BR/CL/PE)

| Plan     | Price           | Equivalent Monthly | Savings |
| -------- | --------------- | ------------------ | ------- |
| Monthly  | **$1.99/month** | $1.99              | —       |
| Annual   | **$12.99/year** | $1.08              | 46%     |
| Lifetime | **$29.99**      | —                  | —       |

### Price justification

- **$3.99 vs $4.99**: Lower psychological barrier. $3.99 is in the sweet spot for productivity apps.
- **Annual at a 48% discount**: Strong incentive for annual subscriptions (higher LTV).
- **Lifetime at $49.99**: Reasonable for early adopters; not so low that it cannibalizes subscriptions.
- **LATAM at ~50% of global**: Purchasing power parity. Both stores support regionalized pricing.

### Price Update Action Items

| Platform       | Current (Live)                                | Target                                        | Status           | Action Required                             |
| -------------- | --------------------------------------------- | --------------------------------------------- | ---------------- | ------------------------------------------- |
| iOS (StoreKit) | Monthly $2.99, Annual $14.99, Lifetime $29.99 | Monthly $3.99, Annual $24.99, Lifetime $49.99 | ⚠️ LEGACY PRICES | Update via RevenueCat Offerings (PRIORITY) |
| Android        | Not yet implemented                           | Monthly $3.99, Annual $24.99, Lifetime $49.99 | 🔄 IN PROGRESS   | Configure via RevenueCat + Google Play      |

**Timeline:** These new prices are effective immediately for all new subscriptions. Legacy prices will expire on 2026-04-30.

---

## 5. Implementation by Platform

### 5.1 iOS

| Aspect       | Detail                                                                              |
| ------------ | ----------------------------------------------------------------------------------- |
| Framework    | RevenueCat SDK v5+ (wrapping native StoreKit 2)                                    |
| Products     | `monthly`, `annual`, `lifetime` via RevenueCat Offerings/Packages                  |
| Entitlement  | `pro` (unified in RevenueCat)                                                       |
| User ID      | Integrated with Sign in with Apple flow via `logIn(userId)`                        |
| Verification | Server-side via Go backend (`POST /api/v1/billing/verify` and RevenueCat REST API) |
| Restore      | RevenueCat `logIn()` + `entitlements` property                                     |
| Local cache  | RevenueCat SDK caches entitlements automatically                                    |
| Grace period | Automatically handled by RevenueCat according to App Store Connect configuration    |
| Webhooks     | Backend receives events via `POST /api/v1/webhooks/revenuecat`                     |

### 5.2 Android

| Aspect       | Detail                                                                                   |
| ------------ | ---------------------------------------------------------------------------------------- |
| Framework    | Google Play Billing Library 7 (BillingClient 7.x)                                       |
| Singleton    | `SubscriptionManager` with retry logic                                                   |
| Verification | Server-side via Go backend (`POST /api/v1/billing/verify`)                              |
| Restore      | `queryPurchases(BillingClient.ProductType.SUBS + INAPP)`                                |
| Local cache  | DataStore with `isPro`, `tier`, `expirationDate` (trust cache for 7 days offline)       |
| State        | Observable `StateFlow<SubscriptionState>`                                                |
| DI           | Hilt module (`@Singleton` scope)                                                         |

### 5.3 Product IDs

**iOS (StoreKit):**

```
com.pepinillo.app.pro.monthly
com.pepinillo.app.pro.annual
com.pepinillo.app.pro.lifetime
```

**Android (Google Play):**

```
com.pepinillo.app.pro.monthly    → $3.99/month
com.pepinillo.app.pro.annual     → $24.99/year
com.pepinillo.app.pro.lifetime   → $49.99 (in-app product, no subscription)
```

### 5.4 Backend

- **Billing Verification Endpoint (Authoritative):** `POST /api/v1/billing/verify`
  - Legacy paths are deprecated and must not be used
  - Supports verification of Google Play, App Store, and RevenueCat receipts
  - Tier mapping: `free`, `pro_monthly`, `pro_annual`, `lifetime`
  - Updates user tier in the database after successful verification
  - Returns: `{"tier": "pro_monthly", "expiresAt": "2026-04-24", "isActive": true}`

- **RevenueCat integration:**
  - Webhook endpoint: `POST /api/v1/webhooks/revenuecat` (receives subscription lifecycle events)
  - REST API client: verifies entitlements via the RevenueCat API
  - Supported events: purchase, renewal, cancellation, expiration, billing issues

- **Fallback:** Direct App Store/Google Play verification if RevenueCat is unavailable

---

## 6. Feature Gating (Enforcement)

### 6.1 Gating mechanisms

| Mechanism        | Description                                                                        |
| ---------------- | ---------------------------------------------------------------------------------- |
| Lock icons       | Lock icon on Pro features (Flowtime/Time Block modes, premium soundscapes)        |
| Task counter     | Visible counter "2/3 Tasks" for Free users; lock "+" button at 3                |
| Blur overlay     | Analytics data >7 days with blur/overlay and CTA "Unlock full history"           |
| Upgrade prompts  | Contextual prompts at natural friction points                                      |
| Free trial       | 7-day free Pro trial                                                               |

### 6.2 Gating by screen

| Screen              | Free restriction                                                                 |
| ------------------- | -------------------------------------------------------------------------------- |
| Focus Screen        | Lock on Flowtime and Time Block modes; lock on premium soundscapes              |
| Tasks Screen        | Maximum 3 tasks; no subtasks; no recurrence; contextual upgrade prompt           |
| Dashboard/Analytics | Last 7 days only; blur on older history; Weekly/Monthly Review blocked           |
| Settings            | Show current tier; "Upgrade to Pro" button; extra themes blocked                |
| Widgets             | Only timer widget available; others show "Upgrade to Pro"                       |
| Watch/Wear OS       | Upgrade message if a Free user opens the watch app                               |

### 6.3 Current gating issues (to be fixed)

**iOS — Features listed as Pro but NOT gated:**

| Feature             | Current status             | Required action                         |
| ------------------- | -------------------------- | --------------------------------------- |
| Analytics >7 days   | Accessible to everyone     | Add gate in `AnalyticsFeature`          |
| iCloud Sync         | Works for everyone         | Add gate in sync logic                  |
| Additional widgets  | Accessible without limits  | Add gate in widget configuration        |
| Themes              | All available              | Add gate in theme selector              |
| Subtasks            | Accessible to everyone     | Add gate in task creation               |
| Recurrence          | Accessible to everyone     | Add gate in task creation               |

**Android — No feature gating implemented:**

| Component             | Status     |
| --------------------- | ---------- |
| FeatureGate service   | Does not exist |
| Paywall screen        | Does not exist |
| SubscriptionManager   | Does not exist |
| UI locks/restrictions | Do not exist   |

---

## 7. Purchase Flows

### 7.1 Purchase flow (applies to both platforms)

```
 1. User taps a Pro feature or the "Upgrade" button
 2. Paywall is shown with a list of Pro benefits
 3. Paywall loads products from the store (StoreKit 2 / Google Play)
 4. User selects a plan (Monthly / Annual / Lifetime)
 5. "BEST VALUE" badge is highlighted on the Annual plan
 6. User confirms purchase
 7. Store shows native payment dialog
 8. App receives purchase confirmation
 9. App sends token/receipt to backend → POST /api/v1/billing/verify
10. Backend verifies with the corresponding store API
11. Feature unlocks immediately; UI updates
```

### 7.2 Restoration flow

```
1. User taps "Restore Purchases" in Paywall or Settings
2. App queries active purchases in the store
3. For each active purchase → verify with backend
4. Update local subscription status
```

### 7.3 Expiration flow

```
1. App starts → query active purchases in the store
2. If there are no active purchases AND local cache says isPro:
3.   Verify with backend
4.   If backend confirms expiration → downgrade to Free
5.   Grace period: 3 days after expiration before revoking access
```

### 7.4 Required Paywall elements

- List of 6+ Pro benefits
- Plan selector (Monthly / Annual / Lifetime)
- "BEST VALUE" badge on Annual plan
- Purchase button with loading state
- "Restore Purchases" link
- Links to Terms of Use and Privacy Policy (required by both stores)
  - Terms: https://creapolis.dev/terms-of-use/
  - Privacy: https://creapolis.dev/privacy-policy/

---

## 8. Conversion Hooks

Psychological triggers that motivate upgrades from Free to Pro:

| Hook                              | Mechanism                                                                        | Expected impact                                           |
| --------------------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **Only 2 of 4 free modes**        | "Unlock Flowtime and Time Block" is the primary conversion trigger             | High — Flowtime attracts users who bounced from Pomodoro |
| **3-task limit**                  | Natural upgrade pressure for active users who need more organization             | High — creates daily friction                             |
| **Basic vs full stats**           | Seeing only 7 days creates FOMO; blur older data with CTA                        | Medium-high — data-driven users want trends              |
| **Watch/Wear OS as aspiration**   | "Control your focus from your watch" — aspirational feature for power users    | Medium — niche audience but high purchase intent          |
| **Theme variety**                 | One free theme vs all themes (Liquid Glass, Material You, etc.)                 | Medium — aesthetic motivation                             |
| **No subtasks or recurrence**     | Users managing complex projects need structure                                  | Medium-high — functional differentiator                   |
| **No sync/cloud**                 | Risk of losing data motivates backup; multi-device use requires sync            | Medium — grows over time                                  |
| **No export**                     | Professional users need CSV/PDF reports                                         | Low-medium — niche but valuable                           |

### Prompt strategy

- **Non-intrusive**: Show upgrade prompts only when the user tries to use a Pro feature
- **Contextual**: The prompt explains the specific benefit being unlocked
- **Controlled frequency**: Maximum 1 prompt per session (no spam)
- **Free trial**: Offer 7 free Pro days on the first upgrade attempt

---

## 9. Monetization Metrics

### 9.1 Conversion objectives

| Metric                  | Target (30 days) | Target (90 days) | Stretch      |
| ----------------------- | ---------------- | ---------------- | ------------ |
| Free → Pro conversion   | >= 6%            | >= 8%            | >= 10%       |
| Trial-to-Paid           | —                | >= 40%           | >= 50%       |
| Monthly churn           | —                | < 8%             | < 5%         |
| ARPU (paying users)     | >= $3.50/month   | >= $3.50/month   | >= $4.50/month |

### 9.2 Revenue projections (conservative)

| Scenario         | MAU | Conversion | ARPU  | MRR     |
| ---------------- | --- | ---------- | ----- | ------- |
| Base (Month 6)   | 8K  | 6%         | $3.50 | $1,680  |
| Good (Month 6)   | 15K | 8%         | $3.80 | $4,560  |
| Stretch (Month 12) | 30K | 10%      | $4.00 | $12,000 |

### 9.3 Metrics to track

| Metric                                                       | Tool                                    |
| ------------------------------------------------------------ | --------------------------------------- |
| Conversion by plan (monthly/annual/lifetime)                | Backend analytics                       |
| Revenue by region (Global vs LATAM)                         | App Store Connect / Google Play Console |
| Paywall view-to-purchase rate                               | In-app analytics                        |
| Most attempted feature by Free users (conversion trigger)   | In-app analytics                        |
| Average time Free → Pro                                     | Backend analytics                       |
| Churn by cohort                                              | Backend analytics                       |
| LTV by plan                                                  | Calculated (ARPU / churn rate)          |

---

## Appendix: Competitor Comparison

| App            | Monthly      | Annual        | Lifetime         |
| -------------- | ------------ | ------------- | ---------------- |
| Forest         | —            | $19.99/yr     | $3.99 (one-time) |
| Focus Bear     | $4.99/mo     | $29.99/yr     | —                |
| Tide           | $2.99/mo     | $14.99/yr     | $49.99           |
| Be Focused Pro | —            | —             | $4.99            |
| Session        | $4.99/mo     | $29.99/yr     | $79.99           |
| **Pepinillo**  | **$3.99/mo** | **$24.99/yr** | **$49.99**       |

Pepinillo is competitively positioned: cheaper than Session and Focus Bear, while offering more features than Tide and Forest. LATAM pricing (~50% of global pricing) is a unique differentiator in the market.
