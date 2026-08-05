# Pepinillo Web Client — Decision Brief & Feature Matrix

**Version:** 1.0  
**Date:** 2026-08-05  
**Status:** Draft for product approval (planning only — no implementation)  
**Related:** `PRD/01` vision (NG6), `PRD/02` features, `PRD/04` monetization, `PRD/07` roadmap, `PRD/09` status  
**Audience:** Product + engineering (pre-SDD spec/design)

---

## 1. Decision summary

| Question | Decision |
| -------- | -------- |
| Do we build a web client? | **Yes**, as a **companion extra**, not a fourth “native-class” OS. |
| Primary job | Let a mobile (or desktop-native) user work on a **larger screen without installing** anything. |
| Free tier | **Local-only** persistence in the browser; **same Free limits** as other platforms. |
| Paid tier on web | **Everywhere/AI+ only** (subscription). No Pepinillo+ one-time on web (Apple-ecosystem offer). |
| Everywhere unlocks | Entitled product features that work in a browser **+** account-based **backend sync** with iOS / Android / Windows. |
| Full OS parity day one? | **No.** Product parity where the browser is honest; platform-exclusive surfaces are **N/A**. |
| Commercial promise | Ship client first; **do not market web** until a real client exists (NG6 / roadmap). |

**One-line product definition:**

> Web = Everywhere companion client: Free is offline/local with Free caps; Everywhere unlocks full entitled web features and multi-device sync.

---

## 2. Why this is interesting

### Jobs to be done

1. **Big screen without install** — phone is home; browser on school/lab/shared PC for Plan + Dashboard + Focus while the tab is open.  
2. **Web-only Free trial** — try Pepinillo without App Store / Play / Microsoft Store friction.  
3. **Everywhere value proof** — cross-device continuity becomes tangible (phone session → web dashboard).  

### Why not a full “web OS” replacement

Pepinillo’s moat is **native depth** (widgets, watch, tray, hotkeys, Live Activity, OS Focus). The web client must **amplify** that ecosystem, not pretend to equal it.

### Preconditions (do not ignore)

| Precondition | Why |
| ------------ | --- |
| Backend API reachable in production | Free-local can ship without it; Everywhere **cannot**. |
| Free feature gates stable on mobile/Windows | Web must mirror the same Free limits (`PRD/04` §3.1). |
| Anonymous → account merge path | Free-local → login + Everywhere needs a clear merge/conflict UX (same class of problem as mobile). |
| Design tokens / calm UI language | Visual kinship with mobile + Windows without copying WinUI/Material pixel-for-pixel. |

---

## 3. Product model

### 3.1 Role

| Aspect | Web client |
| ------ | ---------- |
| Positioning | **Extra / companion**, not primary install target |
| Surfaces | Focus · Plan · Dashboard · Account (same mental model as phones) |
| Style | Calm, focused, large-screen friendly; shared mode colors and spacing tokens |
| Performance bar | Small JS payload, fast first paint, no heavy SPA bloat; Prefer progressive enhancement |

### 3.2 Tiers on web

| Tier | Storage | Sync | Feature access |
| ---- | ------- | ---- | -------------- |
| **Free** | Browser local only (IndexedDB or equivalent) | None | Free limits only (`PRD/04` §3.1) |
| **Everywhere/AI+** | Local cache + server | Bidirectional via Go backend (+ WS when entitled) | All **web-capable** premium features (see matrix) |

**Billing model (aligned with Android/Windows rollout):**

- Web offers **Everywhere/AI+** (monthly/annual) as the paid path.  
- **Pepinillo+** (one-time) remains **Apple platforms only**.  
- Entitlement source of truth for Everywhere remains **account + backend / RevenueCat cross-platform** (web purchase path TBD in design phase: Stripe web checkout vs. “subscribe in store app”).

### 3.3 Explicit non-goals (web)

| Non-goal | Reason |
| -------- | ------ |
| Tray / global hotkeys / Compact Overlay | OS shell — Windows native only |
| Widgets, Live Activity, Dynamic Island | OS surfaces |
| watchOS / Wear companions | Separate targets |
| Reliable timer with tab closed / browser killed | Browser lifecycle is hostile; document honestly |
| Team collaboration / notes editor | Product NG1 / NG2 |
| Electron/Tauri “web as desktop app” | Windows already native WinUI |
| Marketing web as shipped before launch | NG6 |

### 3.4 Honest browser limits (always document in UX)

Even on Everywhere:

- Timer runs while the **document is allowed to run** (visible tab preferred; background may throttle).  
- Notifications depend on browser permission + OS policy.  
- No guarantee equal to Android/iOS foreground services or Windows tray.  
- Copy should set expectation: *“Best experience: keep this tab open during a session.”*

---

## 4. Free limits (canonical — same as other apps)

Source: `PRD/04_MONETIZATION.md` §3.1. Web must enforce the same caps.

| Feature | Free limit |
| ------- | ---------- |
| Focus modes | Pomodoro + Stopwatch only |
| Tasks | Up to **3 active** tasks |
| Subtasks / recurrence | Not available |
| Analytics | Today + **last 7 days** |
| Themes | Default / system only |
| Soundscapes | **4** basics (when audio shipped on web) |
| Sync | **Device-local only** (this browser profile) |
| Export | Not available |
| AI Reports / cloud AI | Not available |

Widgets / watch “no full companion” Free rules do not apply as features on web (those surfaces are N/A).

---

## 5. Delivery slices (planning order)

Ship value early; do not wait for “everything possible”.

| Slice | Scope | Depends on backend? | User value |
| ----- | ----- | ------------------- | ---------- |
| **W0** | Decision brief + matrix (this doc); design tokens inventory | No | Alignment |
| **W1** | Shell: Focus / Plan / Dashboard / Account; Free local store; Free gates; EN/ES/PT | No | Usable Free web-only |
| **W2** | Auth (account); Everywhere entitlement check; upload/merge free-local → cloud; session/task/settings sync | **Yes** | Companion for mobile users |
| **W3** | Premium local features on web (Flowtime, Time Block, unlimited tasks, subtasks, recurrence, extended analytics, themes, Mode Intelligence where portable) | Yes (entitlement) | Paid without native install |
| **W4** | Soundscapes, export, streak protection, polish, PWA install optional | Partial | Depth |
| **W5** | Cloud AI+ surfaces when product-ready (Coach, credits, etc.) | Yes | Everywhere AI narrative |

**Tech direction (non-binding until design phase):** SvelteKit + TypeScript, CSS design tokens, Go REST (+ WS), local IndexedDB for Free; static/edge deploy. Optimize for small gzipped JS and calm UI.

---

## 6. Feature matrix

### Legend

| Cell | Meaning |
| ---- | ------- |
| **Free** | Available on Free web (local) with Free caps |
| **Everywhere** | Requires Everywhere/AI+ on web |
| **N/A** | Not applicable or not honest on web — stay native |
| **Later** | Web-capable but not first slices |
| **Adapted** | Same product intent; browser-specific implementation |

Platform columns: **Web Free** | **Web Everywhere** vs product intent on mobile/Windows.

### 6.1 Focus

| Feature | Mobile/Windows intent | Web Free | Web Everywhere | Notes |
| ------- | --------------------- | -------- | -------------- | ----- |
| Pomodoro | Free | Free | Free | Core |
| Stopwatch / Chrono | Free | Free | Free | Core |
| Flowtime | Paid | — (gate) | Everywhere | Same gate as local premium elsewhere |
| Time Block | Paid | — (gate) | Everywhere | |
| Pause / resume / skip | Free | Free | Free | |
| Session journaling | Free | Free | Free | |
| Link task to session | Free | Free | Free | Within task limits |
| Auto-start work/break settings | Free | Free | Free | |
| Background timer survival (OS) | Free (native) | **N/A** | **N/A** | Document “tab open” expectation |
| Mode Intelligence | Paid | — | Everywhere | Portable scoring if data local/synced |
| Mini timer / PiP / tray | Windows | **N/A** | **N/A** | |
| Global hotkeys | Windows | **N/A** | **N/A** | Optional in-page shortcuts only (Adapted) |
| Live Activity / persistent notif | iOS/Android | **N/A** / Adapted | Adapted | Browser Notification API only, best-effort |

### 6.2 Plan (tasks)

| Feature | Intent | Web Free | Web Everywhere | Notes |
| ------- | ------ | -------- | -------------- | ----- |
| Task CRUD | Free | Free (≤3 active) | Everywhere (unlimited) | Enforce Free cap strictly |
| Priority / energy / est. pomodoros | Free | Free | Free | |
| Drag reorder | Free | Free | Free | Desktop pointer UX |
| Subtasks | Paid | — | Everywhere | |
| Recurrence | Paid | — | Everywhere | |
| Today / Upcoming / Inbox filters | Free | Free | Free | Match product IA |
| Desktop day planner grid | Windows advantage | Later / Adapted | Later | Optional large-screen win; not required for W1 |

### 6.3 Dashboard / reflect

| Feature | Intent | Web Free | Web Everywhere | Notes |
| ------- | ------ | -------- | -------------- | ----- |
| Daily summary (7 days) | Free | Free | Free | |
| 30-day / 1-year views | Paid | — | Everywhere | |
| Mode breakdown charts | Paid | — | Everywhere | |
| Achievements / streaks | Free | Free | Free | |
| Streak protection | Paid | — | Everywhere | |
| Weekly / Monthly Review | Paid | — | Everywhere | |
| Local/template AI reports | Paid (Apple+/Everywhere) | — | Later | No Apple on-device models on web |
| Cloud AI Coach / scheduling / subtasks / credits | Everywhere | — | Later (W5) | After AI product ships |

### 6.4 Account, sync, billing

| Feature | Intent | Web Free | Web Everywhere | Notes |
| ------- | ------ | -------- | -------------- | ----- |
| Local persistence | Free | Free | Free | IndexedDB (or equivalent) |
| Create account / login | Free | Free | Free | Login without Everywhere still local-first until entitled |
| Backend bidirectional sync | Everywhere | — | Everywhere | Tasks, sessions, settings (product-defined set) |
| WebSocket invalidation | Everywhere | — | Everywhere | Same pattern as mobile |
| Cross-device restore / merge | Everywhere | — | Everywhere | Free-local merge dialog required |
| Pepinillo+ purchase | Apple only | **N/A** | **N/A** | |
| Everywhere subscribe / restore | Everywhere | — | Everywhere | Purchase channel TBD (web vs deep-link to stores) |
| Export CSV/PDF | Paid | — | Everywhere / Later | W4 |

### 6.5 Themes, audio, i18n, onboarding

| Feature | Intent | Web Free | Web Everywhere | Notes |
| ------- | ------ | -------- | -------------- | ----- |
| Classic + system light/dark | Free | Free | Free | |
| Forest / Ocean / Sunset | Paid | — | Everywhere | |
| Focus mode colors | Free | Free | Free | Shared tokens |
| Soundscapes (4 basic) | Free | Later | Later | Audio policy / autoplay constraints |
| Soundscapes (premium) | Paid | — | Later | |
| EN / ES / PT | Free | Free | Free | W1 |
| First-run onboarding | Free | Free | Free | Emphasize companion role + Free limits |

### 6.6 Explicit N/A (native-only)

Do **not** put these on the web roadmap as parity items:

- Home/Lock Screen widgets, Control Center, Quick Settings tiles  
- watchOS / Wear OS companions and complications  
- Siri / Google Assistant app actions  
- Apple Health / Health Connect  
- Apple Reminders import, system Focus Filters, DND APIs  
- Windows tray, Jump List, Compact Overlay, Focus Assist deep hooks  
- CloudKit (Apple-local); web uses **backend only** for cloud  

---

## 7. Free-local → Everywhere upgrade path

Critical product flow (must be designed before W2):

1. User uses Free web → data only in this browser.  
2. User creates account (optional on Free; required for Everywhere sync).  
3. User activates Everywhere (subscribe or restore from mobile purchase).  
4. Client offers **merge**: upload local → server, or pull server → local, or guided conflict resolution (mirror mobile anonymous→registered patterns).  
5. Ongoing LWW / entity rules same as mobile clients.  

**Risk:** data loss on browser clear / other device — Free UX must warn that Free web data is **this browser only**.

---

## 8. Success metrics (post-launch)

| Metric | Intent |
| ------ | ------ |
| Free web → session started in ≤ 30s | Companion is fast |
| Free web → Everywhere conversion | Web as funnel |
| Everywhere users with ≥1 web + ≥1 native session / week | Real companion usage |
| Bundle / LCP budgets (define in design) | Performance promise held |
| Support tickets about “timer stopped” | Honesty of browser limits |

---

## 9. Open questions (resolve before/at design)

1. **Web billing:** Stripe (or similar) on web vs. “Manage subscription in iOS/Android/Windows app” only?  
2. **Auth providers on web:** email magic link / Google / Apple — which for W2?  
3. **PWA:** installable icon in W1 or later?  
4. **Domain / branding:** `app.pepinillo…` vs marketing site separation.  
5. **Windows user without mobile:** is web still positioned as companion-only, or also primary for Chromebook-class users? (Recommended: allow web-primary Free + Everywhere; marketing still “extra”.)  

---

## 10. Recommendation & next steps

**Approve this brief** if product agrees:

1. Web is a **yes**.  
2. Free = local + Free caps.  
3. Everywhere = web-capable premium + sync.  
4. Matrix N/A rows stay native.  
5. Delivery is **sliced** (W1→W5), backend-prod gated for W2+.  

**After approval:**

1. Update `PRD/01` Platform Availability + NG6 note (web “planned companion”, not promised).  
2. Update `PRD/02` with a Web column or companion subsection.  
3. Update `PRD/04` § platform matrix with **§ Web** (Android-like Everywhere-only paid path).  
4. Update `PRD/07` / `PRD/09` status lines.  
5. Run SDD change `web-client` (spec → design → tasks) with artifact store of choice.  

**Do not start UI implementation** until W0 approval + at least W1 scope freeze.

---

## 11. Approval

| Role | Name | Date | Verdict |
| ---- | ---- | ---- | ------- |
| Product | | | ☐ Approve · ☐ Approve with changes · ☐ Reject |
| Notes | | | |

---

*End of decision brief v1.0*
