# Pepinillo — Technical Architecture & PRD: Native Windows Application

**Version:** 1.1  
**Date:** 2026-08-03  
**Status:** Planning complete — ready for P0 implementation  
**Author:** Tiago David + AI Pairing Assistant  
**Target Platform:** Windows 10 (19041+) & Windows 11 (x64 / ARM64) via Microsoft Store  
**Framework:** C# / WinUI 3 (Windows App SDK 1.6+)  
**Execution plan:** [12_WINDOWS_EXECUTION_PLAN.md](12_WINDOWS_EXECUTION_PLAN.md) (P0–P3 work units, parity matrix, Store checklist)  
**Live status:** [09_CURRENT_STATUS.md](09_CURRENT_STATUS.md) (Windows platform row)

---

## 1. Executive Summary & Vision

Pepinillo for Windows brings the **Deep Work Operating System** directly to knowledge workers, developers, and creators on desktop. It extends the core mobile experience (iOS SwiftUI / Android Jetpack Compose) to Windows as a **100% native WinUI 3 application**.

### Why Native Windows?
- **Seamless Desktop Workflow:** Knowledge workers spend hours at their PC. A native Windows app offers instant access, low RAM usage, and deep OS integration.
- **Unique Desktop Surfaces:** System Tray icon, Compact Overlay (Floating Always-On-Top Mini Timer), Global Keyboard Hotkeys (`Win + Shift + P`), and native Windows Focus Mode integration.
- **Unified Ecosystem:** Shares the existing **Go backend** (`backend/`) with iOS and Android for instant cross-device synchronization and shared subscription entitlements.

---

## 2. Product Architecture & Feature Scope

Pepinillo Windows mirrors the 4 core product pillars established in the mobile PRD:

### 2.1 Hero Execution Surface (Focus Engine)
- **Focus Modes:** Pomodoro, Stopwatch, Flowtime, and Time Blocking.
- **Compact Floating Window (Picture-in-Picture):** Sleek mini-timer that stays on top of code editors, browser tabs, or design software.
- **System Tray Mini-Timer:** Minimizes to system notification area with a quick-view timer popup.
- **Focus Mode Integration:** Auto-triggers Windows 11 Focus Sessions / Do Not Disturb via Windows Shell API.
- **Global Hotkeys:**
  - `Win + Shift + P`: Start / Pause session
  - `Win + Shift + S`: Skip break / Next session
  - `Win + Shift + M`: Toggle Compact Overlay Mode

### 2.2 Planning Surface (Task Management)
- **Views:** Inbox, Today, Upcoming, Projects / Areas.
- **Capabilities:** Unlimited tasks, subtask hierarchies, recurring tasks, priority tags, and time estimates.
- **Calendar & Time Blocking:** Grid view for visual scheduling directly from the desktop.

### 2.3 Reflective Surface (Dashboard & Analytics)
- **Charts:** Daily/Weekly/Monthly focus time breakdown, productivity distribution by hour/day.
- **Streak Tracker:** Session streaks with skip protection.
- **AI Reports:** Weekly/Monthly AI-generated productivity reflections (powered by Go backend AI services).

### 2.4 Audio & Soundscapes
- **Looping Ambient Audio:** Forest, Ocean, Rain, Cafe, White Noise, Deep Space.
- **Audio Engine:** Low-latency Windows Media Player pipeline with smooth fade-in / fade-out transitions.

---

## 3. Technology Stack & Architecture

```
+-------------------------------------------------------------------+
|                        Pepinillo Windows UI                       |
|           WinUI 3 (Windows App SDK) + Fluent Design 2             |
|          MVVM Pattern (CommunityToolkit.Mvvm / C# .NET 9)         |
+-------------------+---------------------------+-------------------+
                    |                           |
                    v                           v
+-------------------+-------+       +-----------+-------------------+
|   Local SQLite DB         |       |   Go Backend API Client       |
|   (EF Core / SQLite-net)  |       |   (HttpClient + JWT Auth)     |
+-------------------+-------+       +-----------+-------------------+
                    |                           |
                    +-------------+-------------+
                                  |
                                  v
+---------------------------------+---------------------------------+
|                       OS Integrations                             |
|  - System Tray (H.NotifyIcon)     - Windows Store Commerce API    |
|  - Windows Toast Notifications    - Focus Sessions (Do Not Disturb|
+-------------------------------------------------------------------+
```

| Layer | Component | Technology Selection |
| :--- | :--- | :--- |
| **UI Framework** | Desktop UI | C# / WinUI 3 (Windows App SDK 1.6+) |
| **Architecture** | Presentation Pattern | MVVM (`CommunityToolkit.Mvvm`) |
| **Local Persistence** | Database | SQLite with Entity Framework Core / SQLite-net |
| **Network & Sync** | Backend REST/gRPC | `HttpClient` connecting to Pepinillo Go Backend (`backend/`) |
| **Store & Commerce** | IAP & Subscriptions | `Windows.Services.Store` API + Stripe/RevenueCat Backend Sync |
| **Desktop Integrations** | System Tray & Hotkeys | `H.NotifyIcon.WinUI` + Windows App SDK AppNotificationManager |
| **Packaging** | Installer & Store Package | MSIX (x64 / ARM64) |

---

## 4. Canonical Monetization Model & Pricing

Pepinillo Windows enforces the exact same 3-tier commercial model defined in [04_MONETIZATION.md](file:///Users/tiagofur/dev/pepinillo_nativo/PRD/04_MONETIZATION.md).

| Tier | Format | Pricing (USD) | Included Features on Windows |
| :--- | :--- | :--- | :--- |
| **Free** | Freemium Core | $0 | Pomodoro & Stopwatch modes, max 3 active tasks, 7-day history, 4 basic soundscapes. |
| **Pepinillo+** | One-time purchase (Lifetime) | **$9.99** *(Pay once, own forever)* | All local Windows features: Flowtime + Time Block modes, unlimited tasks/subtasks, compact floating window, system tray popup, global hotkeys, CSV export, all premium themes & soundscapes. |
| **Everywhere / AI+** | Subscription | **$2.99 / mo** or **$19.99 / yr** | All Pepinillo+ features + Go backend cross-device sync (iOS, Android, Windows, Web), cloud AI reports, predictive insights, monthly AI credits. |

### Microsoft Store Commerce Integration:
1. **Pepinillo+:** Configured in Partner Center as a **Durable In-App Purchase** (`pepinillo_plus_windows`).
2. **Everywhere / AI+:** Configured in Partner Center as **Subscription In-App Purchases** (`everywhere_plus_monthly`, `everywhere_plus_annual`).
3. **Cross-Platform Entitlement:** When a user logs into their Pepinillo Account on Windows, the Go backend checks if they already have active `Everywhere/AI+` entitlements (purchased on iOS or Android). If verified, full features are instantly unlocked without extra charge.

---

## 5. Development Plan & Phase Breakdown

### Comparative Effort Estimate for Windows Development

| Component | Estimated Effort | Notes |
| :--- | :--- | :--- |
| **Project Setup & Base Architecture** | 25h | WinUI 3 solution structure, MVVM Toolkit, Dependency Injection, Navigation |
| **Focus Engine & Timer State Machine** | 45h | Timer logic, strategy pattern translation, precision tick handling |
| **Local Database & Domain Models** | 30h | SQLite schema, EF Core migrations, repository pattern |
| **Tasks & Planning UI** | 40h | Views for Inbox, Today, Upcoming, CRUD operations, subtasks |
| **System Tray & Compact Mini-Timer** | 35h | Always-on-top window, taskbar tray icon, popup UI, global hotkeys |
| **Windows OS Integration** | 25h | Toast notifications, Focus Mode (Do Not Disturb) sync, startup launch |
| **Backend REST Sync & Auth** | 40h | Auth client (Login/Register/JWT), sync engine integration with Go backend |
| **Analytics & Dashboard UI** | 25h | WinUI charts (OxyPlot / WinUI Chart controls), session history |
| **Soundscapes & Media Engine** | 20h | Background audio player, volume controls, seamless looping |
| **Monetization & Store Commerce** | 30h | Windows.Services.Store integration, paywall UI, entitlement verification |
| **Store Packaging, QA & CI/CD** | 25h | MSIX packaging, Partner Center store listing, GitHub Actions build pipeline |
| **Total Estimated Hours** | **~340h** | (~10-12 weeks at 30h/week) |

---

## 6. Implementation Roadmap (Milestones)

```
[Phase 1: Architecture & Focus Engine] ──► [Phase 2: Tasks & Desktop UI] ──► [Phase 3: Desktop Power Features]
                                                                                       │
[Phase 6: Store Release & QA] ◄── [Phase 5: Monetization & Polish] ◄── [Phase 4: Backend Sync & Auth]
```

### Phase 1: Core Foundation & Focus Engine (Weeks 1–2)
- Set up WinUI 3 C# solution with `CommunityToolkit.Mvvm`.
- Implement `FocusEngine` (Pomodoro & Stopwatch state machines).
- Create Main Window layout with Mica material styling and Dark/Light theme switching.
- Set up local SQLite database with EF Core.

### Phase 2: Tasks & Planning Surface (Weeks 3–4)
- Implement Task management views (Inbox, Today, Upcoming).
- Build subtask tree control and recurrence handling.
- Build Project & Area filtering.

### Phase 3: Windows Desktop Power Features (Weeks 5–6)
- Implement System Tray icon with quick action menu.
- Build Always-On-Top Compact Floating Mini-Timer window.
- Register Global Hotkeys (`Win + Shift + P`, `Win + Shift + S`).
- Implement Windows Toast Notifications with interactive buttons.

### Phase 4: Backend Sync & Auth (Weeks 7–8)
- Integrate Go backend auth client (JWT handling, login, sign up).
- Build background sync worker connecting WinUI local SQLite to Go backend endpoints.
- Build Dashboard & Analytics screen with interactive focus charts.

### Phase 5: Soundscapes & Monetization (Weeks 9–10)
- Implement background audio player with soundscape assets.
- Integrate `Windows.Services.Store` API for `Pepinillo+` and `Everywhere/AI+`.
- Build Paywall view and cross-platform entitlement checker.

### Phase 6: Microsoft Store Release & Testing (Weeks 11–12)
- Create MSIX packaging scripts & store certification compliance checks.
- Set up Microsoft Partner Center app submission listing, screenshots, and metadata.
- Launch Beta via Windows App Installer / Test Track.

---

## 7. Implementation Status & Next Step (2026-08-03)

| Item | State |
| ---- | ----- |
| Solution scaffold (`windows/`) | Present — Core + WinUI + tests + CI build |
| Phase 1 completion | ~15–25% (engine/tasks skeleton; no DI, no Focus page, incomplete wiring) |
| Microsoft Store readiness | Not ready (placeholder identity, missing Assets, no pack/sign) |
| Detailed execution | See **[12_WINDOWS_EXECUTION_PLAN.md](12_WINDOWS_EXECUTION_PLAN.md)** |

**Next engineering step:** execute **P0** (DI → navigation → SQLite lifecycle → FocusPage + engine cycles → settings persist → tasks UX → theme → smoke).
