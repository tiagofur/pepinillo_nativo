# Pepinillo Windows — Execution Plan

**Version:** 1.2  
**Date:** 2026-08-04  
**Status:** P1 coded — tray/mini/hotkeys/toasts/Focus Assist; WinUI manual smoke pending on Windows; next is P2  

**Branch:** `feat/windows-native-app`  
**Canonical product PRD:** [11_WINDOWS_APP_PRD_AND_ROADMAP.md](11_WINDOWS_APP_PRD_AND_ROADMAP.md)  
**Parity source of truth (mobile):** [02_FEATURES.md](02_FEATURES.md)  
**Live status tracker:** [09_CURRENT_STATUS.md](09_CURRENT_STATUS.md)

---

## 1. Goal

Ship a **native Windows** app (WinUI 3 / C# / Microsoft Store) with **functional parity** to Android phone and iOS phone for all features that make sense on desktop, plus **Windows-native power features** (tray, Compact Overlay, global hotkeys, Focus Assist).

### Success criteria (product)

| Criterion | Definition |
| --------- | ---------- |
| **MVP usable** | User can run focus sessions, manage tasks offline, see basic history, change settings — without crashes |
| **Feature parity** | Every mobile feature marked `[All]` or with a Windows desktop substitute is **Done** or **N/A (platform)** with documented substitute |
| **Store-ready** | Signed MSIX, Partner Center listing, IAP live, privacy/terms, certification pass |

### Explicit non-goals (platform N/A)

| Mobile feature | Windows substitute / decision |
| -------------- | ----------------------------- |
| watchOS / Wear OS companion | **N/A** — no companion watch on Windows |
| Live Activity / Dynamic Island / Foreground Service notif | **System Tray + Compact Overlay mini-timer** |
| Home/Lock widgets (phone) | Deferred; optional Windows Widgets later (P3+) |
| HealthKit / Health Connect | **N/A** unless product later defines desktop health |
| Siri / Google Assistant | Optional later: Windows voice access — not MVP |
| Apple Reminders / Google Tasks import | Deferred; use backend sync + manual entry first |
| StoreKit / Play Billing | **Microsoft Store** `Windows.Services.Store` |

---

## 2. Baseline (2026-08-03 audit)

### Maturity

| Level | Status |
| ----- | ------ |
| Scaffolding | **Yes** (superseded by P0 shell) |
| MVP usable (local focus + tasks) | **Coded** — Core verified; WinUI manual smoke pending on Windows |
| Feature parity with mobile | **No** |
| Microsoft Store ready | **No** |

**Phase mapping to PRD 11 (post-P0 code):** Phase 1 largely complete in code; Phase 2 tasks UX partial; Phase 3–6 mostly stubs or absent.

### Stack (confirmed in repo)

```
windows/
  Pepinillo.slnx
  Pepinillo.Core/          # net9.0 — models, EF Core SQLite, services, ViewModels
  Pepinillo.WinUI/         # net9.0-windows10.0.19041.0 — WinUI 3, MSIX tooling
  Pepinillo.Core.Tests/    # xUnit
```

| Layer | Choice |
| ----- | ------ |
| UI | WinUI 3, Windows App SDK 1.6, Fluent / NavigationView |
| Pattern | MVVM (`CommunityToolkit.Mvvm`) — **DI not wired** |
| Data | EF Core SQLite (`FocusSessions`, `TaskItems`) |
| Packaging | `EnableMsixTooling`; identity placeholder |
| CI | `.github/workflows/windows-build.yml` (build + Core tests; **no pack/sign**) |
| Approx size | ~50–55 source files, ~1.9k lines (early skeleton) |

### What works today (partial)

- `FocusEngineService` — basic Idle/Running/Paused/Completed tick
- `FocusViewModel` — exists, **no Focus page**
- `TaskService` + `TasksPage` shell — CRUD/list filters incomplete in UI
- Analytics / Settings shells — mostly static or no-op save
- `MiniTimerWindow` Compact Overlay — productized (Focus / tray / hotkey)
- System tray (`H.NotifyIcon`), global hotkeys, AppNotification toasts
- Focus Assist best-effort service (graceful no-op when OS API unavailable)
- `BackendApiClient` skeleton → `https://api.pepinillo.app/v1`
- Commerce constants + free-default tests; purchase APIs stubbed
- Unit tests for engine / tasks / free commerce default

### Critical blockers for “runnable product”

1. ~~No DI / navigation / Focus page~~ — **done (P0)**  
2. **Assets/** still incomplete for Store logos (MSIX pack may fail)  
3. Package identity `CN=PepinilloDev` not Partner Center–aligned  
4. Soundscapes audio / auth / real Store IAP still stubs (**P2**)  
5. WinUI **manual smoke on Windows** still pending  


---

## 3. Priority bands (how we execute)

Maps engineering priorities to PRD 11 phases. **Do not start P1 until P0 Definition of Done is met.**

| Band | Intent | PRD 11 phases | Exit gate |
| ---- | ------ | ------------- | --------- |
| **P0** | Runnable local MVP shell | Phase 1 + partial Phase 2 | Focus + Tasks + Settings persist offline; nav works; Core tests green |
| **P1** | Desktop power features | Phase 3 | Tray, mini-timer, hotkeys, toasts, Focus Assist toggle real |
| **P2** | Parity depth + commerce path | Phase 4–5 | Real analytics, soundscapes, auth/sync, StoreContext + paywall design |
| **P3** | Ship Microsoft Store | Phase 6 + polish | Signed MSIX, listing, beta track, cert checklist |

Estimated remaining effort (order of magnitude, after existing skeleton): **~280–320h** toward Store GA (PRD 11 total ~340h).

---

## 4. P0 — Core Foundation (next implementation)

**Objective:** A developer (and then a tester) can launch the app on Windows 10/11, navigate Focus / Plan / Reflect / Settings, run a Pomodoro or Stopwatch, create tasks, and persist data across restarts.

### 4.1 Work units (ordered)

| ID | Work unit | Primary paths | Depends on | DoD |
| -- | --------- | ------------- | ---------- | --- |
| **P0.1** | App host + DI | `App.xaml.cs`, service registration | — | `IServiceProvider` registers `DbContext`, services, VMs; single composition root |
| **P0.2** | Navigation shell | `MainWindow.xaml(.cs)` | P0.1 | `NavigationView` → `Frame` routes: Focus, Tasks, Analytics, Settings; Soundscapes can stub-route to “Coming soon” |
| **P0.3** | SQLite lifecycle | `PepinilloDbContext`, App launch | P0.1 | DB created under local app data; migrations or `EnsureCreated` documented; survives restart |
| **P0.4** | FocusPage + engine completion | `Views/FocusPage.xaml`, `FocusEngineService`, `FocusViewModel` | P0.1–0.3 | Pomodoro work/break cycle; Stopwatch; pause/resume/skip; session row written on complete; link optional task id |
| **P0.5** | Settings persistence | `SettingsViewModel`, settings store | P0.1, P0.3 | Durations, auto-start flags, theme preference, DND/tray *intent flags* persist (OS hooks can no-op until P1) |
| **P0.6** | Tasks UX completion | `TasksPage`, `TasksViewModel`, `TaskService` | P0.1–0.3 | Today/Upcoming/Inbox filters bound; add/complete/delete; subtasks create/toggle; no crash on empty state |
| **P0.7** | Theme apply (basic) | App resources / Settings | P0.5 | Light / Dark / System applies to shell |
| **P0.8** | Smoke + tests | Core tests + manual checklist | P0.4–0.6 | `dotnet test` green; manual smoke script below passes |

### 4.2 P0 out of scope (explicit)

- System tray, global hotkeys, real Focus Assist API  
- Real Store IAP / paywall enforcement  
- Full auth + sync worker  
- Soundscapes audio assets / player  
- Charts library / AI reports  
- Partner Center submission  
- Full EN/ES/PT resource files (Spanish hardcode acceptable in P0 if consistent; i18n is P2)

### 4.3 P0 manual smoke checklist

```
[ ] App launches without exception
[ ] Nav: Focus, Tasks, Analytics, Settings all open
[ ] Start Pomodoro → Running → Pause → Resume → Complete
[ ] Start Stopwatch → stop → session recorded
[ ] Create task in Inbox → appears in Today when dated
[ ] Complete task → list updates
[ ] Kill app → relaunch → tasks and last settings still present
[ ] Mini timer may remain unlinked (OK in P0)
```

### 4.4 P0 Definition of Done

- [x] All P0.1–P0.8 complete (code)  
- [x] Core unit tests pass locally (**16/16**; CI via `windows-build.yml`)  
- [ ] No unhandled exceptions on smoke checklist (**requires Windows machine**)  
- [x] `09_CURRENT_STATUS.md` Windows section updated  
- [x] Conventional commit(s) on `feat/windows-native-app`  

**After Windows smoke passes → start P1.**

---

## 5. P1 — Desktop power features

| ID | Work unit | Notes | Status |
| -- | --------- | ----- | ------ |
| **P1.1** | System tray (`H.NotifyIcon`) | Context menu Start/Pause, Skip, Show, Mini timer, Exit; minimize-to-tray when setting on | **Coded** |
| **P1.2** | Productize MiniTimer | Focus page + tray + hotkey; Compact Overlay; sync time/status/task; AlwaysOnTop setting | **Coded** |
| **P1.3** | Global hotkeys | Defaults `Win+Shift+P/S/M` via RegisterHotKey; conflicts documented; rebind UI deferred | **Coded** |
| **P1.4** | Toast notifications | AppNotification phase complete / break start/end; gated on `EnableToastNotifications` | **Coded** |
| **P1.5** | Focus Assist / Focus Sessions | `IFocusAssistService` + WinUI best-effort; silent no-op when OS API unavailable | **Coded** (best-effort) |

**P1 DoD:** User can leave timer in tray + floating mini window while coding; hotkeys work when app is backgrounded (within OS limits).

- [x] Tray + close-to-tray + Exit path coded  
- [x] Mini timer open/close + state sync coded  
- [x] Global hotkeys registered (process-level; conflict-tolerant)  
- [x] Toasts implement `INotificationService` (gated)  
- [x] Focus Assist wiring + graceful no-op  
- [ ] Manual verification on Windows 10/11 machine  


---

## 6. P2 — Parity depth, backend, commerce path

| ID | Work unit | Parity notes |
| -- | --------- | ------------ |
| **P2.1** | Full focus modes | Flowtime + Time Block complete behavior + auto-start gates |
| **P2.2** | Session journaling UI | Post-session reflection entry (parity with mobile) |
| **P2.3** | Tasks depth | Priority, energy, recurrence (RRULE or simplified), pomodoro estimates |
| **P2.4** | Analytics real data | Aggregate from SQLite; charts (OxyPlot or WinUI charts); streaks |
| **P2.5** | Soundscapes | MediaPlayer, loop catalog, volume, premium gating hooks |
| **P2.6** | Auth UI + secure token store | Login/register/email verify gate aligned with Go backend |
| **P2.7** | Sync worker | Local-first; background reconcile with `backend/` APIs |
| **P2.8** | StoreContext IAP | Durable + subscription SKUs; entitlement cache; offline free tier |
| **P2.9** | Paywall UI | Two-tier Pepinillo+ / Everywhere/AI+ (copy aligned with mobile v3.1 intent) |
| **P2.10** | Localization | EN / ES / PT resource dictionaries |
| **P2.11** | Privacy & Terms surfaces | In-app links to https://creapolis.dev/privacy-policy/ and terms |

**P2 DoD:** Feature parity matrix (section 8) has no **Missing** for P0/P1 mobile must-haves that are in Windows scope; commerce works in sandbox.

---

## 7. P3 — Microsoft Store ship

| ID | Work unit | Notes |
| -- | --------- | ----- |
| **P3.1** | Visual assets | Logos, splash, Store screenshots (light/dark), age-appropriate |
| **P3.2** | Package identity | Reserved name in Partner Center; real publisher cert; version scheme |
| **P3.3** | Capabilities | `internetClient`, background/toast as required; minimal privilege |
| **P3.4** | MSIX pack + sign | CI artifact; optional Partner Center upload |
| **P3.5** | Listing metadata | Description, keywords, support URL, privacy URL, categories |
| **P3.6** | IAP in Partner Center | `pepinillo_plus_windows`, `everywhere_plus_monthly`, `everywhere_plus_annual` (names from PRD 11 — confirm before create) |
| **P3.7** | Certification pass | Startup, accessibility basics, crash-free paths, offline free tier |
| **P3.8** | Beta track | Package flight / internal testers → public |

**P3 DoD:** App installable from Microsoft Store (or private flight) on x64 + ARM64; purchases resolve entitlements with backend when account linked.

### Store packaging checklist (living)

- [ ] Partner Center app reserved  
- [ ] Publisher certificate not `CN=PepinilloDev`  
- [ ] Assets folder complete per `Package.appxmanifest`  
- [ ] Privacy policy URL on listing + in app  
- [ ] Age rating questionnaire  
- [ ] IAP products created and linked  
- [ ] CI packs MSIX for `win-x64` and `win-arm64`  
- [ ] Manual cert dry-run on clean Windows 11 VM  

---

## 8. Feature parity matrix (Windows tracking)

Legend: **Done** · **Partial** · **Missing** · **N/A** · **Planned (band)**

| Feature area | Mobile | Windows now | Target band |
| ------------ | ------ | ----------- | ----------- |
| Pomodoro / Stopwatch | Done | Partial | **P0** |
| Flowtime / Time Block | Done | Partial | **P2** |
| Auto-start work/break | Done | Missing | **P0** (flags) / **P2** (full) |
| Session journaling | Done | Missing | **P2** |
| Task CRUD + lists | Done | Partial | **P0** |
| Subtasks / priority / energy / recurring | Done | Partial | **P0** subtasks · **P2** rest |
| Link task ↔ session | Done | Partial | **P0** |
| Dashboard analytics | Done | Partial (fake) | **P2** |
| AI reports | Partial/Done | Missing | **P2** (Everywhere) |
| Themes | Done | Partial | **P0** basic · **P2** named themes |
| Soundscapes | Done | Missing | **P2** |
| Phase notifications | Done | **Coded** (toasts) | **P1** |
| Live Activity / ongoing | Done | N/A → tray + mini **Coded** | **P1** |
| Widgets | Done | N/A / later | P3+ optional |
| Watch / Wear | Done | **N/A** | — |
| Health | Partial | **N/A** | — |
| Backend auth + sync | Done | Partial skeleton | **P2** |
| Billing / paywall | Done | Stub | **P2–P3** |
| System tray | N/A mobile | **Coded** | **P1** |
| Compact Overlay | N/A mobile | **Coded** | **P1** |
| Global hotkeys | N/A mobile | **Coded** | **P1** |
| Focus Assist / DND | Mobile APIs | **Coded** (best-effort no-op) | **P1** |
| Onboarding | Done | Missing | **P2** |
| Localization EN/ES/PT | Done | Partial hardcode | **P2** |
| CSV export | Partial | Missing | **P2** (Pepinillo+) |
| Offline-first local DB | Done | Partial | **P0** |

---

## 9. Open decisions (resolve before or during P2/P3)

| # | Decision | Options / note | Owner |
| - | -------- | -------------- | ----- |
| D1 | **Windows price alignment** | PRD 11: + $9.99 / Everywhere $2.99·$19.99 vs global mobile $19.99 / $4.99·$34.99 (LATAM closer to PRD 11). **Must pick Store prices before Partner Center SKUs.** | Product |
| D2 | **SKU IDs** | Confirm `pepinillo_plus_windows` vs shared entitlement `pepinillo_plus` via backend only | Product + Backend |
| D3 | **Auth providers on Windows** | Email/password first; Microsoft account OAuth later? | Product |
| D4 | **Windows Widgets** | In 1.0 or post-GA | Product |
| D5 | **Minimum OS** | Keep Win10 19041+ or Win11-only for Focus Sessions | Eng |

Until D1 is decided, implement commerce **behind interfaces** and keep product IDs in one constants file (already started).

---

## 10. Engineering conventions (Windows)

| Topic | Convention |
| ----- | ---------- |
| Solution root | `windows/` |
| UI strings in code (P0) | English preferred for new strings; avoid Rioplatense slang in UI |
| Commits | Conventional Commits, e.g. `feat(windows): wire DI and navigation` |
| Tests | Unit tests in `Pepinillo.Core.Tests`; UI automation deferred |
| DI | Prefer `Microsoft.Extensions.DependencyInjection` host in App |
| Navigation | Tag-based `NavigationView` → typed page map |
| Secrets | No API keys in repo; use build config / user secrets for dev endpoints if needed |
| Cross-platform rule | Feature complete on Windows → update `02_FEATURES` / `09_CURRENT_STATUS`; if mobile gap appears, track issues on mobile too |

### Suggested commit slices for P0 (work-unit commits)

1. `feat(windows): add DI composition root`  
2. `feat(windows): wire NavigationView frame routes`  
3. `feat(windows): ensure SQLite lifecycle on launch`  
4. `feat(windows): add FocusPage and complete focus engine cycles`  
5. `feat(windows): persist settings`  
6. `feat(windows): complete tasks list filters and actions`  
7. `feat(windows): apply light/dark/system theme`  
8. `test(windows): extend Core coverage for session persist`  
9. `docs(windows): update status after P0`  

---

## 11. Risk register

| Risk | Impact | Mitigation |
| ---- | ------ | ---------- |
| Focus engine diverges from mobile semantics | Parity bugs | Mirror mobile phase rules; shared acceptance scenarios in tests |
| Store certification rejects fullTrust / capabilities | Block ship | Prefer least privilege; document why fullTrust if required |
| Hotkeys conflict with other apps | UX | Document defaults; settings to disable/rebind (P2) |
| Pricing mismatch across stores | Support burden | Resolve D1; backend is source of Everywhere entitlement |
| Scope creep into P1 during P0 | Delay MVP | Enforce section 4.2 out of scope |
| Audio/licensing for soundscapes | Legal | Use owned or licensed assets before Store |

---

## 12. Next action

1. **On Windows:** build WinUI, run P0 smoke §4.3 + P1 tray/mini/hotkey/toast checks.  
2. **Start P2** (analytics depth, soundscapes audio, auth/sync path, IAP sandbox).  
3. Do not open Partner Center SKUs until **D1** pricing is confirmed.

---

## 13. Document maintenance

| When | Update |
| ---- | ------ |
| End of each P-band | This file §2 baseline + §8 matrix + `09_CURRENT_STATUS` Windows section |
| Feature shipped | `02_FEATURES` Windows notes / labels |
| Architecture change | `11_WINDOWS_APP_PRD_AND_ROADMAP` |
| Store listing live | `09_CURRENT_STATUS` build + store row |

**Change log**

| Date | Change |
| ---- | ------ |
| 2026-08-03 | v1.0 — Initial execution plan from code/docs audit; P0 ready |
| 2026-08-03 | v1.1 — P0 implemented in code; Core tests 16/16; WinUI smoke pending |
| 2026-08-04 | v1.2 — P1 coded (tray, mini-timer, hotkeys, toasts, Focus Assist best-effort); Core 16/16 |
