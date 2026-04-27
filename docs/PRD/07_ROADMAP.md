# Unified Roadmap - Pepinillo (iOS + Android)

**Date:** 2026-04-27  
**Version:** 2.0 (Current Status + v1.0 Ship Plan)  
**Status:** Active Development  
**Target v1.0 Release:** Early May 2026

---

## 1. Development Context

- **Solo Developer:** Tiago + Claude Code Max (5x sessions/day capacity)
- **Hours/week:** 20-30 hours deep work
- **Architecture:** Native iOS (Swift + TCA) + Native Android (Kotlin + MVVM), shared Go backend
- **Data sync:** iOS (CloudKit + Go backend), Android (Go backend only)
- **Reuse rate:** ~40% of domain logic + business rules translate across platforms (FocusEngine strategy pattern, Task models, DailyStats)

---

## 2. Current Completion Status (2026-04-27)

| Phase | Area | iOS | Android | Wear/watchOS | Notes |
| ----- | ---- | --- | ------- | ------------ | ----- |
| **Foundation** | Focus Engine (4 modes) | ✅ 100% | ✅ 100% | ✅ 100% | Strategy pattern, all 4 modes (Pomodoro, Flowtime, TimeBlock, Stopwatch) |
| | Tasks (CRUD, subtasks, recurrence) | ✅ 100% | ✅ 100% | ✅ 100% | Full parity, recurring tasks auto-generate next instance |
| | Analytics (dashboard, reviews) | ✅ 100% | ✅ 100% | ✅ 100% | 7/30/365-day views, Weekly/Monthly reviews, AI Reports |
| **Apple Ecosystem** | Widgets (Home + Lock Screen) | ✅ 100% | — | ✅ 100% | Mode-aware, live countdown |
| | Live Activity + Dynamic Island | ✅ 100% | — | ⬜ N/A | 4 distinct UIs per mode |
| | Siri / App Intents | ✅ 100% (EN, ES, PT) | — | ⬜ N/A | 9 intents across 3 languages |
| | watchOS app | ✅ 100% | — | ✅ 100% | Timer, tasks, dashboard, complications, Smart Stack |
| | iPad adaptive layouts | ✅ 100% | — | ⬜ N/A | NavigationSplitView, Stage Manager, keyboard shortcuts |
| **Android Ecosystem** | Glance widgets (Home + Lock Screen) | — | ✅ 100% | — | Mode-aware, Compose-based |
| | Google Assistant (App Actions) | — | ✅ 100% | — | 3 BIIs + deep links |
| | Wear OS app | — | ✅ 100% | ✅ 100% | Timer tile, tasks tile, complications, hinge avoidance |
| | Adaptive layouts (phone/tablet/foldable) | — | ✅ 100% | — | WindowSizeClass, NavigationRail, PermanentDrawer |
| **Integrations** | Apple Health + Focus Modes (CloudKit sync) | ✅ 100% | — | ⬜ N/A | Mindful Minutes, FocusFilterIntent |
| | Health Connect + Google Calendar | — | ✅ 100% | — | Experimental Mindful Sessions, time-blocking |
| | JWT Auth + Go backend | ✅ 100% | ✅ 100% | ✅ 100% | Hardened (P0 + P1 complete), email verification gate |
| | RevenueCat (StoreKit 2 / Play Billing) | ✅ 100% | ✅ 100% | — | Code complete; awaiting v3.1 config (API key swap) |
| **Monetization** | Paywall (Pepinillo+ / Everywhere/AI+) | ✅ 100% | ✅ 95% | — | iOS ready; Android needs parity UI update |
| | Entitlements (pepinillo_plus / everywhere_plus) | ✅ Code done | ✅ Code done | — | **Config pending in RevenueCat + ASC** |
| **Design & UX** | Themes (4 themes + Liquid Glass) | ✅ 100% | ✅ 100% | ✅ 100% | Material You dynamic colors |
| | Glassmorphism + accessibility | ✅ 100% | ✅ 100% | ✅ 100% | VoiceOver/TalkBack, reduce motion support |
| | Localization (EN, ES, PT) | ✅ 95% | ✅ 95% | ✅ 95% | Minor strings may fall back to EN |
| **Testing** | Unit tests (strategies, engine, models) | ✅ 80% | ✅ 75% | — | TCA TestStore (iOS), JUnit 5 + Turbine (Android) |
| | Integration tests | ✅ 60% | ✅ 50% | — | Sync, auth, billing workflows |
| **Deployment** | Backend (Go REST API) | ✅ Functional locally | — | — | Auth, sync, billing endpoints; **not yet deployed** |
| | App Store submission readiness | 📋 90% | — | — | Awaiting RevenueCat config + metadata update |
| | Google Play submission readiness | — | 📋 85% | — | Awaiting Play Console setup + API key config |

**Conclusion:** Android takes ~8% fewer total hours, but the distribution is different. Areas where Android is more expensive:

1. Custom sync engine (+50h vs CloudKit)
2. JWT auth (+20h vs Sign in with Apple)
3. Play Billing (+15h vs StoreKit 2)
4. OEM testing (+10h due to fragmentation)

---

---

## 3. What's Left for v1.0 (May 2026 Target)

**Duration:** 2-3 weeks focused work  
**Team:** Tiago + Claude Code  
**Definition of Done:** Both apps buildable, signed, ready for store submission

### Critical Path to v1.0

| Task | Platform | Status | Effort | Blocker | Target |
| ---- | -------- | ------ | ------ | ------- | ------- |
| **Monetization Config** | Both | Pending | 4-6h | YES | 2026-04-28 |
| - Update RevenueCat API keys (v3.1) | — | Blocked | 2h | YES | 2026-04-28 |
| - Update ASC product metadata | iOS | Blocked | 2h | YES | 2026-04-28 |
| - Create RevenueCat entitlements (`pepinillo_plus`, `everywhere_plus`) | Both | Blocked | 1h | YES | 2026-04-28 |
| - Configure webhook in ASC | iOS | Blocked | 1h | YES | 2026-04-29 |
| **Demo Data Verification** | Both | Ready | 2-3h | YES | 2026-04-27 |
| - Run `-seedDemoData`, verify Dashboard/charts/AI Reports | iOS | Code ready | 1h | YES | 2026-04-27 |
| - Run demo in Android Dashboard | Android | Code ready | 1h | YES | 2026-04-27 |
| **Build & Signing** | Both | 95% | 4-5h | NO | 2026-04-29 |
| - Finalize Xcode setup (Info.plist, targets, signing) | iOS | 95% | 2h | NO | 2026-04-28 |
| - Finalize Android keystore + release config | Android | 95% | 2h | NO | 2026-04-28 |
| - Generate iOS archive + validate provisioning | iOS | Ready | 1h | NO | 2026-04-29 |
| - Generate Android AAB + validate Play Bundle | Android | Ready | 1h | NO | 2026-04-29 |
| **Store Submission Prep** | Both | 80% | 6-8h | NO | 2026-05-01 |
| - App Store Connect: screenshots + preview video | iOS | Not started | 4h | NO | 2026-04-30 |
| - Play Console: screenshots + feature graphic | Android | Not started | 3h | NO | 2026-04-30 |
| - Privacy Policy + Terms of Service | Both | Not started | 2h | NO | 2026-05-01 |
| - App Store Connect app review info | iOS | Not started | 1h | NO | 2026-05-01 |
| - Play Console privacy policy + content rating | Android | Not started | 1h | NO | 2026-05-01 |
| **Final QA** | Both | 70% | 4-5h | NO | 2026-05-02 |
| - End-to-end test (login → session → analytics) | Both | 70% | 2h | NO | 2026-05-02 |
| - Localization check (EN, ES, PT) | Both | Ready | 1h | NO | 2026-05-02 |
| - Accessibility audit (VoiceOver/TalkBack) | Both | 70% | 1h | NO | 2026-05-02 |
| **Submission** | Both | Ready | 1-2h | NO | 2026-05-03 |
| - Submit iOS build to App Store | iOS | Ready | 1h | NO | 2026-05-03 |
| - Submit Android to Play Console | Android | Ready | 1h | NO | 2026-05-03 |

**Total critical-path effort:** ~20-25h over 6 days (doable in 2-3 days with focused work)

---

## 4. Post-v1.0 Roadmap (Phase 2 Features)

### P1 — First 2-4 Weeks After Launch

| Feature | Platform | Effort | Notes |
| ------- | -------- | ------ | ----- |
| **Backend Deployment** | Both | 15-20h | Go API on Railway/Fly.io, PostgreSQL + Redis, SSL, monitoring |
| **Android Paywall Parity** | Android | 3-4h | Match iOS Pepinillo+ / Everywhere/AI+ two-tier UI |
| **Google Sign-In Integration** | Android | 12-15h | Credential Manager, connect to backend OAuth |
| **iOS Backend Integration** | iOS | 12-15h | Migrate CloudKit users to Go backend for sync |
| **Sync Engine v2** | Both | 25-30h | Real-time WebSocket sync for tasks/sessions/stats (not Pr\u00f3ximamente, shipped) |
| **AI Coach (Cloud)** | Both | 20-25h | Gemini/OpenAI API, weekly recommendations, requires Everywhere/AI+ |

### P2 — Weeks 4-8 Post-Launch

- Task Scheduling (smart scheduling based on energy + calendar)
- Subtask auto-generation (AI decomposition)
- macOS Catalyst target
- iPad pro layouts
- Web app (read-only dashboard, future feature)

### P3 — Beyond Launch (Seasonal/Opportunistic)

- Apple Watch Standalone (full experience without iPhone)
- Family Sharing tiers
- Team features (future, out of scope for v1.0)
- Export to Notion / Obsidian integrations

---

## 3. Phases - iOS

**Objective:** Multi-focus-mode app on iPhone with Task management and CloudKit.

| Task                                                          | hours | Claude Code |
| ------------------------------------------------------------- | ----- | ----------- |
| Set up Xcode, targets, App Groups, TCA                       | 4h    | High        |
| SwiftData models (TaskItem, SubTask, FocusSession, DailyStats) | 10h   | High        |
| FocusModeProtocol + Strategy pattern                          | 8h    | High        |
| 4 strategies (Pomodoro, Flowtime, TimeBlock, Stopwatch)      | 32h   | High        |
| FocusEngine Actor (unified engine)                            | 24h   | Medium      |
| FocusFeature TCA + FocusView SwiftUI                          | 36h   | High/Medium |
| Task List + Task Detail (CRUD, reorder, swipe, subtasks)     | 32h   | High        |
| Link tasks to focus sessions                                  | 8h    | High        |
| Analytics dashboard (SwiftCharts, mode breakdown)             | 24h   | Medium      |
| Settings, Navigation, Notifications                           | 32h   | High        |
| Themes (4 themes + Liquid Glass)                              | 16h   | Medium      |
| Onboarding with mode selector                                 | 10h   | Medium      |
| Localization (EN, ES, PT)                                     | 12h   | High        |
| Unit tests (4 strategies + FocusEngine + Tasks)               | 20h   | High        |

**Milestone:** Functional multi-mode app. 4 modes, linked tasks, analytics with mode breakdown. Internal TestFlight.

### Phase 2: Apple Ecosystem (Weeks 12-20, ~261h)

**Objective:** Widgets, Live Activities, Watch, Siri, iPad, Mac - all mode-aware.

| Task                                                          | hours | Claude Code |
| ------------------------------------------------------------- | ----- | ----------- |
| Home Screen Widgets (S/M/L, mode-aware)                      | 32h   | Medium      |
| Lock Screen Widget                                            | 10h   | High        |
| Live Activity + Dynamic Island (4 UIs per mode)              | 40h   | Medium      |
| Apple Watch app (mode picker + timer + tasks + complications) | 45h   | Medium      |
| Watch-Phone connectivity (mode sync)                         | 20h   | Low         |
| Siri / App Intents (multi-mode commands, 3 languages)        | 18h   | High        |
| iPad adaptive layouts (NavigationSplitView, Stage Manager)   | 16h   | High        |
| macOS target (menu bar + window + keyboard shortcuts)        | 32h   | Medium      |
| CloudKit sync setup + offline conflict resolution             | 32h   | Medium      |
| Integration tests                                             | 16h   | High        |

**Milestone:** Complete ecosystem. Every Apple surface understands the 4 modes.

### Phase 3: Polish & Premium (Weeks 21-27, ~196h)

**Objective:** Subscription-grade quality. The features that make users pay.

| Task                                                       | hours | Claude Code |
| ---------------------------------------------------------- | ----- | ----------- |
| System Focus Modes integration                             | 12h   | Medium      |
| Apple Health (Mindful Minutes)                            | 10h   | High        |
| Ambient soundscapes (rain, cafe, library, white noise)    | 16h   | Medium      |
| Recurring tasks (iCalendar RRULE)                         | 12h   | High        |
| Weekly Review (weekly comparison, trends)                 | 14h   | High        |
| Mode Intelligence (suggest optimal mode by task type)     | 16h   | Medium      |
| Streaks + milestones                                       | 10h   | High        |
| Energy levels in UI (deep/shallow/admin)                  | 6h    | High        |
| StoreKit 2 (paywall, tiers, LATAM prices, restore)        | 22h   | Medium      |
| Control Center widget                                      | 6h    | High        |
| Animations and micro-interactions                          | 20h   | Low         |
| Accessibility audit (VoiceOver, Dynamic Type)             | 12h   | High        |
| Performance optimization                                   | 12h   | Medium      |
| App Store screenshots + preview video + ASO               | 24h   | Medium/High |
| Privacy Policy + Terms                                     | 4h    | High        |

**Milestone:** Premium-ready. Soundscapes, Mode Intelligence, Weekly Review: the features worth $35/year.

### Phase 4: Launch (Weeks 28-31, ~89h)

| Task                                                         | hours | Claude Code |
| ------------------------------------------------------------ | ----- | ----------- |
| Public TestFlight beta (100+ users)                         | 8h    | N/A         |
| Beta bug fixes                                               | 35h   | High        |
| App Store submission                                         | 4h    | N/A         |
| Marketing site / landing page                                | 12h   | High        |
| Launch campaign (ProductHunt, Reddit, Twitter, LATAM blogs) | 10h   | Medium      |
| Post-launch monitoring + hot fixes                           | 20h   | High        |

---

## 4. Phases - Android

### Phase 1: Foundation (Weeks 1-10, ~250h)

**Objective:** Functional app with 4 modes, tasks, auth, and sync.

| Task                                               | hours | Claude Code |
| -------------------------------------------------- | ----- | ----------- |
| Android project + Gradle + Hilt + CI setup         | 20h   | 70%         |
| Room database + entities + DAOs + migrations       | 25h   | 80%         |
| Domain models (FocusMode, FocusPhase, FocusConfig) | 15h   | 90%         |
| Strategy pattern: 4 mode strategies                | 30h   | 70%         |
| FocusEngine (coroutines, StateFlow)                | 25h   | 50%         |
| FocusPresenter (Circuit) + FocusScreen (Compose)   | 30h   | 60%         |
| TaskListPresenter + TaskListScreen + TaskDetail    | 25h   | 70%         |
| Auth (JWT login/register via Go backend)           | 20h   | 60%         |
| Sync engine (Room - Backend, dirty flags)          | 35h   | 40%         |
| Onboarding flow (5 screens, mode test)             | 20h   | 80%         |
| Unit tests (domain, presenters, DAOs)              | 25h   | 70%         |

**Milestone:** Functional app with 4 modes, tasks, auth, and sync.

### Phase 2: Ecosystem (Weeks 11-18, ~220h)

**Objective:** Complete Android ecosystem: widgets, notification, Wear OS, Assistant.

| Task                                           | hours | Claude Code |
| ---------------------------------------------- | ----- | ----------- |
| Foreground Service + ongoing notification      | 30h   | 50%         |
| Home Screen widgets (Glance: timer + stats)   | 30h   | 60%         |
| Quick Settings Tile                            | 15h   | 80%         |
| Wear OS: timer screen + mode picker            | 35h   | 50%         |
| Wear OS: tile + complication + phone sync      | 25h   | 50%         |
| Google Assistant App Actions                   | 20h   | 70%         |
| Tablet/foldable adaptive layouts               | 20h   | 60%         |
| Material You dynamic color + theming           | 15h   | 80%         |
| Integration tests (sync, notification, widget) | 30h   | 60%         |

**Milestone:** Complete ecosystem: widgets, Wear OS, Assistant, adaptive layouts.

### Phase 3: Polish (Weeks 19-25, ~185h)

**Objective:** Feature-complete, ready for testing.

| Task                                   | hours | Claude Code |
| -------------------------------------- | ----- | ----------- |
| Dashboard + analytics charts (Vico)    | 20h   | 70%         |
| Weekly Review screen                   | 15h   | 80%         |
| Mode Intelligence service              | 15h   | 90%         |
| Soundscapes (ExoPlayer, 6 tracks)      | 20h   | 60%         |
| Google Health Connect integration      | 15h   | 60%         |
| Google Play Billing 7 (subscriptions)  | 30h   | 40%         |
| Recurring task generation engine       | 10h   | 90%         |
| Google Tasks import                    | 15h   | 60%         |
| Streaks + achievements                 | 10h   | 80%         |
| Android Focus Mode / DND integration   | 10h   | 60%         |
| Accessibility (TalkBack, font scaling) | 10h   | 50%         |
| Performance optimization + ProGuard    | 15h   | 40%         |

**Milestone:** Feature-complete, ready for testing.

### Phase 4: Launch (Weeks 26-29, ~95h)

| Task                                               | hours | Claude Code |
| -------------------------------------------------- | ----- | ----------- |
| Internal testing track in Play Store               | 15h   | 30%         |
| Testing bug fixes                                  | 25h   | 50%         |
| OEM testing (Samsung, Pixel, Xiaomi, OnePlus)      | 20h   | 20%         |
| Play Store listing (screenshots, description, ASO) | 15h   | 60%         |
| Beta (open testing track)                          | 10h   | 30%         |
| Launch (staged rollout 10% - 50% - 100%)           | 10h   | 30%         |

---

## 5. Timeline Visual

```
2026:
        Jan     Feb     Mar     Apr     May     Jun     Jul     Aug     Sep     Oct     Nov     Dec
iOS:    [========= Phase 1 =========][======= Phase 2 =======][===== Phase 3 =====][= P4 =]
        Foundation (268h)             Ecosystem (261h)         Polish (196h)        Launch
        Weeks 1-11                    Weeks 12-20              Weeks 21-27           W28-31

Android:                                [========= Phase 1 =========][======= Phase 2 =======][== Phase 3 ==][P4]
                                        Foundation (250h)             Ecosystem (220h)         Polish (185h)  Launch
                                        Weeks 1-10                    Weeks 11-18              W19-25         W26-29
```

**Timeline notes:**

- iOS starts in January 2026, launch target September 2026 (aligned with iOS 26)
- Android starts after iOS launch (Q3 2026), target Q4 2026 - Q1 2027
- Overlap between iOS Phase 4 and Android Phase 1 is possible: fixing iOS beta bugs while building Android foundation

---

## 6. Critical Path

### iOS - Critical Path

```
Project Setup --> SwiftData Models --> FocusModeProtocol
                                            |
                      PomodoroStrategy + FlowtimeStrategy
                      TimeBlockStrategy + StopwatchStrategy
                                            |
                                       FocusEngine (Actor)
                                            |
                                       FocusFeature (TCA)
                                            |
                                       Task Management
                                            |
                                      Link Tasks to Sessions
                                            |
                               Mode-Aware Analytics + Settings
                                            |
                                 CloudKit Sync ----> Widgets (mode-aware)
                                       |                    |
                                 Watch App          Live Activities (4 UIs)
                                 (mode picker)              |
                                       |              iPad / macOS
                                 Siri (multi-mode)
                                       |
                           Soundscapes + Mode Intelligence
                                       |
                              StoreKit 2 + Polish
                                       |
                                    LAUNCH
```

**Main risk:** FocusEngine Actor is the bottleneck. Everything depends on the engine working correctly with all 4 modes before building widgets, Watch, and Live Activities.

### Android - Critical Path

```
Gradle setup --> Room models --> Domain models
    |                              |
Hilt DI -----------> Strategy Pattern --> FocusEngine --> FocusPresenter --> FocusScreen
                                               |
                                    Foreground Service --> Ongoing Notification
                                               |
                                         Glance Widgets
                                               |
                                          Wear OS sync

Room models --> TaskPresenter --> TaskScreen
    |
Sync Engine (Requires Auth + Room + Ktor)
    |
Backend integration tests

Play Billing ----> Paywall UI ----> Feature gating
```

**Main risk:** Sync Engine is Android's bottleneck. Unlike iOS (automatic CloudKit), Android needs a complete custom sync engine before the app can be considered functional.

---

## 7. Claude Code Effectiveness

| Phase                | iOS %    | Android % | Best for                                           | Human-only                                      |
| -------------------- | -------- | --------- | -------------------------------------------------- | ----------------------------------------------- |
| Phase 1 (Foundation) | 65%      | 65%       | Models, Strategy boilerplate, Circuit/TCA          | Sync engine edge cases, auth flow               |
| Phase 2 (Ecosystem)  | 50%      | 55%       | Widget layouts, Tile service, App Actions/Intents  | Foreground Service lifecycle, Watch real-device |
| Phase 3 (Polish)     | 45%      | 60%       | Health, billing boilerplate, import logic          | Play Billing testing, soundscape mixing         |
| Phase 4 (Launch)     | 40%      | 35%       | Store descriptions, bug triage                     | OEM testing, staged rollout, beta management    |
| **Overall**          | **~50%** | **~55%**  |                                                    |                                                 |

**Estimated impact:** Claude Code saves ~400-450 total hours across both platforms, reducing the effective timeline from ~62 weeks to ~35-40 weeks.

---

## 8. Risks and Mitigations

### iOS

| Risk                                            | Impact       | Mitigation                                                                   |
| ----------------------------------------------- | ------------ | ---------------------------------------------------------------------------- |
| 4 mode strategies increase testing surface area | +1-2 weeks   | Strategy pattern keeps modes isolated. Test independently                    |
| Flowtime break calculation UX is unclear        | +1 week      | User test in beta. Simple formula first, then iterate                        |
| Audio engine complexity for soundscapes         | +1 week      | AVAudioPlayer for v1 (simple presets). AVAudioEngine only if needed          |
| Mode Intelligence needs 2+ weeks of data        | N/A          | Ship as fast-follow P1. Collect data from day 1                              |

### Android

| Risk                              | Impact       | Mitigation                                                    |
| --------------------------------- | ------------ | ------------------------------------------------------------- |
| Play Billing 7 complexity         | +1-2 weeks   | Start early, use billing-ktx samples                          |
| Wear OS DataLayer bugs            | +1 week      | Minimal Wear OS MVP first                                     |
| OEMs killing background processes | +1 week      | dontkillmyapp.com guide + user education                      |
| Sync engine conflicts             | +1 week      | Simple last-write-wins, no CRDT                               |
| Circuit learning curve            | +0.5 weeks   | Circuit docs are excellent; mental model similar to TCA       |

### Shared

| Risk                                    | Impact               | Mitigation                                                    |
| --------------------------------------- | -------------------- | ------------------------------------------------------------- |
| Go backend not ready on time            | Blocks Android sync  | Prioritize critical endpoints; iOS uses CloudKit              |
| One developer only = bus factor of 1    | High                 | Exhaustive documentation + Claude Code as knowledge base      |
| Burnout at 25h/week during 60+ weeks    | High                 | Clear phases with celebratory milestones. Breaks between phases |

**Total risk buffer:** +3-5 weeks per platform  
**Realistic timeline with risk:** iOS Sep-Nov 2026, Android Q1-Q2 2027

---

## 9. Unified Phase: Backend, Auth, Sync & User Profile

**Objective:** Unify both platforms (iOS + Android) under a single backend for authentication, cloud synchronization, multi-device support, cross-platform subscriptions, and user profiles.

**Prerequisite:** Both apps must be functional on their respective platforms (at least post-Phase 2 on each platform).

### Sub-phases (in order)

| #   | Sub-phase                        | Description                                                                                                                                                                                                                                                       | Dependencies                | Estimate |
| --- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | -------- |
| 1   | **Backend Deployment**           | Deploy Go backend on cloud hosting (Railway/Fly.io). Set up PostgreSQL + Redis. Configure domain, SSL, monitoring, and health checks.                                                                                                                           | None (phase start)          | 15-20h   |
| 2   | **OAuth Social Login (Backend)** | Add verification endpoints for Google Sign-In and Sign in with Apple. Migrate user model (google_id, apple_id). Support account linking.                                                                                                                       | Sub-phase 1 complete        | 25-30h   |
| 3   | **Google Sign-In on Android**    | Integrate Credential Manager for Google one-tap sign-in. Connect to backend OAuth endpoint. Update LoginScreen UI.                                                                                                                                               | Sub-phase 2 complete        | 20-25h   |
| 4   | **Backend Integration on iOS**   | Create API client (URLSession + JWT). Connect Sign in with Apple to backend (POST /auth/apple). Migration path for existing CloudKit users.                                                                                                                     | Sub-phase 2 complete        | 25-30h   |
| 5   | **Sync Engine v2**               | Real-time bidirectional synchronization via WebSocket (backend already has /ws). Improved conflict resolution. Both platforms synchronize Tasks, Sessions, stats, and preferences through the backend.                                                          | Sub-phases 3 and 4 complete | 40-50h   |
| 6   | **Cross-Platform Subscriptions** | Server-side receipt verification (both stores). Backend as source of truth for subscription status. User pays once and has Pro on all devices.                                                                                                                  | Sub-phase 5 complete        | 30-35h   |
| 7   | **User Profile**                 | Profile screen on iOS (SwiftUI) and Android (Compose). Shows avatar, name, email, subscription tier, linked accounts, stats (streak, hours, Sessions, Tasks, member since). Edit profile, manage subscription, sign out, and delete account.                 | Sub-phases 3 and 4 complete | 25-30h   |

**Total estimate:** ~180-220h

### Dependency Graph

```
Sub-phase 1: Backend Deployment
        |
Sub-phase 2: OAuth Social Login (Backend)
        |
   +---------+---------+
   |                   |
Sub-phase 3:         Sub-phase 4:
Google Sign-In      iOS Backend
(Android)           Integration
   |                   |
   +---+-------+-------+
       |               |
Sub-phase 5:         Sub-phase 7:
Sync Engine v2      User Profile
       |            (can start after 3+4)
Sub-phase 6:
Cross-Platform
Subscriptions
```

**Key notes:**

- Sub-phase 1 blocks all others (backend must be running)
- Sub-phase 2 blocks 3 and 4 (OAuth endpoints required)
- Sub-phases 3 and 4 can run in parallel after sub-phase 2
- Sub-phase 5 requires 3 and 4 complete (both platforms connected)
- Sub-phase 6 requires 5 complete (sync working)
- Sub-phase 7 can start after 3 and 4 (profile data available via /users/me)

### Specific Risks for This Phase

| Risk                                                  | Impact            | Mitigation                                                                               |
| ----------------------------------------------------- | ----------------- | ---------------------------------------------------------------------------------------- |
| Migration of existing CloudKit users on iOS           | +1-2 weeks        | Design a gradual migration path; keep CloudKit as temporary fallback                    |
| WebSocket latency in LATAM regions                    | UX degradation    | Choose nearby hosting region (Sao Paulo/Virginia); fallback to HTTP polling            |
| Cross-platform receipt verification (Apple + Google)  | +1 week           | Use proven server-side libraries; exhaustive sandbox testing with both stores           |
| Account linking with duplicate accounts               | Data loss risk    | Manual merge flow with user confirmation; never delete data automatically               |
| Cloud infrastructure costs                            | Operational       | Start with Railway free/low-cost tier; scale only after proven traction                |
