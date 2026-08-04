# Pepinillo Windows — Excellence Plan (Perfect Product)

**Version:** 1.0  
**Date:** 2026-08-04  
**Status:** Active backlog — plan + GitHub issues  
**Audience:** Humans and AI agents implementing Windows  
**Depends on:** [11](11_WINDOWS_APP_PRD_AND_ROADMAP.md) · [12](12_WINDOWS_EXECUTION_PLAN.md) · [02](02_FEATURES.md) · [04](04_MONETIZATION.md) · [09](09_CURRENT_STATUS.md)  
**Launch ops:** [windows/store/LAUNCH_CHECKLIST.md](../windows/store/LAUNCH_CHECKLIST.md) · issue **#568**

---

## 1. Outcome first

Ship a **Microsoft Store–ready Windows app** that:

1. Matches **every phone-relevant feature** from iOS + Android (pillars Execute / Plan / Reflect / Admin).
2. **Improves** on mobile where desktop can (tray, Compact Overlay, global hotkeys, multi-monitor, keyboard-first, calendar grid).
3. Feels **visually and interaction-perfect** under Fluent Design 2 (Mica, density, motion, empty states, focus rings).
4. Is documented so **any agent** can implement one issue without re-discovering product truth.

**Not the goal:** Clone phone chrome pixel-for-pixel. Goal is **functional + emotional parity**, native Windows craft.

---

## 2. Baseline (already coded — do not re-build)

P0–P2 + packaging kit exist under `windows/`:

| Band | Content | Status |
| ---- | ------- | ------ |
| P0 | DI, nav, Focus (Pomodoro/Stopwatch), Tasks, Settings, SQLite | Coded |
| P1 | Tray, mini-timer, hotkeys, toasts, Focus Assist stub | Coded |
| P2 | Flowtime/TimeBlock, journal, analytics, soundscapes player, auth, sync, StoreContext, paywall, partial i18n | Coded |
| P3 packaging | Logos, MSIX scripts/CI, store docs | In-repo ready |
| Post-merge | Auth gates (#570), EF migrations (#571), Flowtime soft + partial Pomodoro (#572) | Merged |

**Remaining is excellence + parity depth + Store proof**, not greenfield.

---

## 3. Definition of Perfect

### 3.1 Product perfect

| Pillar | Perfect means |
| ------ | ------------- |
| **Execute** | 4 modes correct; Mode Intelligence; soundscapes auto-play with fades; journal; timer never “dies” when window minimized (tray + mini + toasts) |
| **Plan** | Inbox/Today/Upcoming/All; free cap 3; paid subtasks/recurrence; priority/energy/pomodoro estimates; keyboard-first create/complete; excellent empty states |
| **Reflect** | Free 7-day + streaks + achievements; paid Weekly/Monthly Review; local Mode Intelligence / template AI; Everywhere path for cloud AI when product says so |
| **Admin** | Account auth, restore purchases, paywall v3.1 copy, settings, export, Privacy/Terms, language EN/ES/PT, onboarding |

### 3.2 Design perfect

- Fluent + Mica (or Acrylic where appropriate) with Light / Dark / System.
- Named themes: **Classic (free), Forest / Ocean / Sunset (paid)** — same commercial gate as mobile.
- Focus mode colors: Pomodoro red, Time Block purple, Stopwatch green, Flowtime teal (document in theme tokens).
- Spacing scale, type scale, corner radius, elevation consistent across all pages.
- Empty, loading, error, offline states for every primary surface.
- Keyboard: Tab order, accelerators, Escape, Enter defaults.
- Accessibility: Narrator names, contrast, 200% text scale, high-contrast theme smoke.

### 3.3 Desktop-superior (welcome improvements over mobile)

| Improvement | Why Windows wins |
| ----------- | ---------------- |
| System tray + tray menu | True background companion |
| Compact Overlay mini-timer | Always-on-top while coding |
| Global hotkeys + rebind UI | Hands never leave keyboard |
| Multi-monitor mini placement | Pro multi-display setups |
| Jump List / startup with Windows | OS-native entry points |
| Calendar time-block grid | Visual planning at desktop width |
| Toast actions + tray | Faster than phone notification drawers |
| Dense but calm data tables for analytics | Desktop real estate |

### 3.4 Explicit N/A (do not implement as phone clones)

| Mobile | Windows decision |
| ------ | ---------------- |
| watchOS / Wear | N/A |
| Live Activity / FGS | Substitute: tray + mini + toasts |
| Home/Lock widgets | Optional post-GA Windows Widgets |
| HealthKit / Health Connect | N/A until product says otherwise |
| Siri / Google Assistant | Optional later |
| CloudKit | N/A — use Go backend Everywhere |
| StoreKit / Play Billing | Microsoft Store |

---

## 4. Free / Pepinillo+ / Everywhere (must match monétization)

Authoritative: [04_MONETIZATION.md](04_MONETIZATION.md). Windows prices: D1 in [LAUNCH_CHECKLIST](../windows/store/LAUNCH_CHECKLIST.md).

| Capability | Free | Pepinillo+ Windows | Everywhere |
| ---------- | ---- | ------------------ | ---------- |
| Modes | Pomodoro, Stopwatch | + Flowtime, Time Block | same |
| Tasks | 3 incomplete root | Unlimited + subtasks + recurrence | same |
| Analytics | Today + 7 days | 30d/1y + Weekly/Monthly Review | + cloud AI when shipped |
| Soundscapes | 4 basics | All premium | same |
| Themes | Classic / system | Forest, Ocean, Sunset | same |
| Export | No | CSV/PDF | same |
| Sync | Local only | Local (+ iCloud N/A) | Cross-device backend |
| Desktop power (tray/hotkeys/mini) | Available (habit surface) | same | same |

Code gate owner: `windows/Pepinillo.Core/Services/EntitlementService.cs`.

---

## 5. Workstreams & GitHub issues

> Issue numbers are filled when created. Epic tracks the whole program.

| ID | Workstream | Issue | Priority | Depends on |
| -- | ---------- | ----- | -------- | ---------- |
| **E** | Epic: Windows excellence | **[#573](https://github.com/tiagofur/pepinillo_nativo/issues/573)** | P0 | — |
| **W0** | Docs truth + agent contract (this file maintained) | **[#574](https://github.com/tiagofur/pepinillo_nativo/issues/574)** | P0 | — |
| **W1** | Hardware smoke gate + quality bar | **[#575](https://github.com/tiagofur/pepinillo_nativo/issues/575)** | **P0** | — |
| **W2** | Fluent design system + visual excellence | **[#576](https://github.com/tiagofur/pepinillo_nativo/issues/576)** | **P0** | W1 preferred |
| **W3** | Soundscapes complete (assets + session audio) | **[#577](https://github.com/tiagofur/pepinillo_nativo/issues/577)** | P0 | W2 tokens optional |
| **W4** | Reflect parity (Weekly/Monthly + achievements) | **[#578](https://github.com/tiagofur/pepinillo_nativo/issues/578)** | P0 | — |
| **W5** | Mode Intelligence | **[#579](https://github.com/tiagofur/pepinillo_nativo/issues/579)** | P1 | W4 data helpful |
| **W6** | Export CSV/PDF + streak protection | **[#580](https://github.com/tiagofur/pepinillo_nativo/issues/580)** | P1 | Entitlements |
| **W7** | First-run onboarding | **[#581](https://github.com/tiagofur/pepinillo_nativo/issues/581)** | P1 | W2 |
| **W8** | Full EN/ES/PT localization | **[#582](https://github.com/tiagofur/pepinillo_nativo/issues/582)** | P1 | — |
| **W9** | Desktop power v2 (Focus Assist, toast actions, startup, hotkey rebind) | **[#583](https://github.com/tiagofur/pepinillo_nativo/issues/583)** | P0 | W1 |
| **W10** | Auth + Everywhere sync depth | **[#584](https://github.com/tiagofur/pepinillo_nativo/issues/584)** | P0 | API |
| **W11** | Paywall + commerce excellence | **[#585](https://github.com/tiagofur/pepinillo_nativo/issues/585)** | P0 | #568 SKUs |
| **W12** | Tasks/Plan excellence | **[#586](https://github.com/tiagofur/pepinillo_nativo/issues/586)** | P1 | W2 |
| **W13** | Calendar time-block grid (desktop advantage) | **[#587](https://github.com/tiagofur/pepinillo_nativo/issues/587)** | P2 | W12 |
| **W14** | Multi-monitor + shell excellence | **[#588](https://github.com/tiagofur/pepinillo_nativo/issues/588)** | P2 | W9 |
| **W15** | Accessibility + keyboard-first | **[#589](https://github.com/tiagofur/pepinillo_nativo/issues/589)** | P1 | W2 |
| **W16** | Microsoft Store launch (ops) | **[#568](https://github.com/tiagofur/pepinillo_nativo/issues/568)** | P0 | W1 smoke |

### Recommended implementation order (agents)

```
W0/W1 (truth + smoke)
  → W2 (design system)
  → W3 + W4 + W9 + W10 + W11 in parallel slices
  → W5 + W6 + W7 + W8 + W12 + W15
  → W13 + W14
  → #568 Internal flight
```

---

## 6. Agent contract (every Windows issue)

Any human or AI implementing a Windows issue **MUST**:

1. Read **this file** §3–4 + the linked issue body end-to-end.
2. Read PRD slices linked in the issue (never invent free/paid rules).
3. Keep **Core** (`Pepinillo.Core`) platform-agnostic; put OS code in `Pepinillo.WinUI`.
4. UI strings in **English** by default; wire through localization keys when touching user-visible text.
5. Add/extend **Core unit tests** for logic; note WinUI manual smoke steps in the PR.
6. Update **this plan** matrix + [09_CURRENT_STATUS.md](09_CURRENT_STATUS.md) §3b when status changes.
7. Update [02_FEATURES.md](02_FEATURES.md) Windows notes when a mobile-parity feature ships.
8. One PR ≈ one issue; Conventional Commits: `feat(windows):` / `fix(windows):` / `docs(windows):`.
9. Do **not** claim Focus Assist, AI, or soundscapes “done” if still stub/placeholder/missing assets.
10. Cross-platform rule: if you discover a **mobile** bug while porting, open a separate iOS/Android issue — do not silently diverge.

### Issue body template (copy for new issues)

```markdown
## Context
<link to PRD/13 workstream Wx>

## Goal
<user-visible outcome>

## Scope
- Paths: `windows/...`
- PRD: ...

## Acceptance criteria
- [ ] ...
- [ ] Core tests green
- [ ] Manual smoke steps listed

## Out of scope
- ...

## Agent notes
- Entitlements: ...
- Do not: ...

## Delivery
- Priority / Size / Depends on
```

---

## 7. Parity matrix — perfect target

Legend: **Done** · **Partial** · **Missing** · **N/A** · **Stretch**

| Feature | Mobile phone | Windows now | Perfect target | Workstream |
| ------- | ------------ | ----------- | -------------- | ---------- |
| Pomodoro / Stopwatch | Done | Done | Done | — |
| Flowtime soft / Time Block | Done | Done | Done + polish | W2 |
| Mode Intelligence | iOS done / Android partial | Missing | Done (local) | W5 |
| Journal + energy | Done | Done | Done + polish | W2 |
| Tasks CRUD + filters | Done | Done | Done + keyboard excellence | W12 |
| Subtasks / recurrence gates | Done | Done | Done | — |
| Weekly / Monthly Review | Done | Missing | Done | W4 |
| Achievements (6) | Done | Missing | Done | W4 |
| Streaks + protection | Done | Streaks only | +1 skip/week paid | W6 |
| Soundscapes player + assets | iOS strong | Player only | Full + auto-play + fade | W3 |
| Themes 4 named | Done | **Improved (W2):** System/Light/Dark free + Forest/Ocean/Sunset gated via `CanUseTheme`; DesignTokens + Mica; OLEDBlack aliases Dark | Full + gate | W2 |
| Onboarding | Done | Missing | Done | W7 |
| EN/ES/PT | Done | Partial | Full .resw | W8 |
| Auth email/password | Done | Done | + verify UX, merge | W10 |
| Everywhere sync | Done | Partial | Full session/tasks/settings | W10 |
| Paywall + restore | Done | Partial | Perfect copy + restore | W11 |
| Export CSV/PDF | Partial/Done | Missing | Done | W6 |
| Phase notifications | Done | Toasts | + actions | W9 |
| Live Activity | Done | N/A → tray/mini | Excellent tray/mini | W9/W14 |
| Focus Assist / DND | Mobile APIs | Stub | Best-effort real | W9 |
| Startup with OS | N/A phone | Missing | Done | W9 |
| Hotkey rebind | N/A | Missing | Done | W9 |
| Calendar grid | Partial | Missing | Desktop advantage | W13 |
| Multi-monitor mini | N/A | Missing | Stretch excellence | W14 |
| A11y / keyboard | Varies | Partial | Excellent | W15 |
| Store ship | Live | Not submitted | Internal→Public | #568 |
| Watch / Health / Widgets phone | Done | N/A | N/A | — |

---

## 8. Design excellence checklist (W2 owner)

Use as acceptance for design-system work:

- [ ] Token file (colors, type, spacing, radius, elevation) shared by all pages
- [ ] NavigationView + content density tuned for 1280×720 and 1920×1080
- [ ] Focus page: large timer readable at a glance; mode chips; clear primary CTA
- [ ] Tasks: scannable rows, priority/energy affordances, empty states with one action
- [ ] Analytics: streak hero, charts readable in dark/light
- [ ] Paywall: “Not a subscription” for Pepinillo+ crystal clear (04 monétization)
- [ ] Mini timer: minimal chrome, high contrast elapsed time
- [ ] Motion: subtle, 150–250ms, no gratuitous bounce
- [ ] High contrast + text scale smoke documented

---

## 9. Quality gates before “perfect” claim

| Gate | Proof |
| ---- | ----- |
| G1 Core tests | `dotnet test windows/Pepinillo.Core.Tests` green |
| G2 WinUI smoke | `LAUNCH_CHECKLIST` Phase B on real Windows hardware |
| G3 Parity matrix | No **Missing** for P0 phone features in Windows scope (this file §7) |
| G4 Entitlements | Free user cannot access paid modes/tasks/export; Plus/Everywhere unlock correctly |
| G5 Audio | Free 4 tracks play; premium gated; session auto-play optional setting works |
| G6 Commerce | Sandbox purchase + restore + backend Everywhere grant |
| G7 Store | #568 Internal flight installable |
| G8 A11y | Narrator pass on Focus + Tasks + Paywall |

---

## 10. Non-goals (protect scope)

- Replacing WinUI with Electron/MAUI/WebView shell.
- Full cloud AI Coach/Scheduler as “shipped” before backend product is ready (paywall may say Próximamente).
- Pixel-cloning iOS Liquid Glass or Material You — use Fluent equivalents.
- Implementing watch companions on Windows.

---

## 11. Document maintenance

| When | Update |
| ----- | ------ |
| Issue created/closed | §5 table issue numbers / status |
| Feature ships | §7 matrix + `09` §3b + `02` Windows notes |
| Pricing/SKU change | `04`, `ProductCatalog`, `LAUNCH_CHECKLIST`, #568 |
| Design tokens change | §8 + architecture note in `11` |

**Changelog**

| Date | Change |
| ---- | ------ |
| 2026-08-04 | v1.0 — Excellence plan from parity audit; backlog W0–W16 + epic **#573** (children #574–#589, Store #568) |

---

## 12. Quick path for a new agent

1. Read this file §1–4 and §6.
2. Open epic **[#573](https://github.com/tiagofur/pepinillo_nativo/issues/573)**; pick the highest-priority open child with no unfinished dependency (start with **#575** smoke if not done).
3. Implement only that issue’s scope.
4. Tests + PR linking `Fixes #N`.
5. Update §7 / `09` in the same PR when behavior changes.
