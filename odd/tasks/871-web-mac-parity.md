# 871 — Web visual parity with PepinilloMac

Objective: Make the web PWA (`web/` → app.pepinillo.app) visually and interactively match PepinilloMac (post glass-hybrid overhaul): mode colors, sidebar, per-pane toolbar, focus ring/stage, task table, dashboard, controls — with a Mac-grammar touch adaptation for mobile.
Branch: `feat/web-mac-parity` | Delivery: `complete` (chained PRs B1→B4) | Test runners: `pnpm test` + `pnpm build` (web/ and landing/)
UX Brief: https://github.com/tiagofur/pepinillo_nativo/issues/871#issuecomment-6958797986

## Specs (full Spanish text in issue #871)

- **S1**: Tokens = `AppTheme.classic` mode hexes (#E84D3D/#3387EB/#8F45DE/#2EB870/#FF991A); themes Forest/Ocean/Sunset swap the FULL mode palette (Mac behavior, gating unchanged); dark accent #3D9C5E; sidebar matte (glass only in Focus stage).
- **S2**: Desktop sidebar ≥1024px: 220px matte, Mac model (Foco → Plan section Todas/Hoy/Próximas/Completadas → Panel), 30px rows with radius-10 accent capsule (active = accent + white), account footer (avatar initial + name) + gear.
- **S3**: Per-pane Mac toolbar: Focus = centered mode segmented that empties while running; Plan = search + inspector toggle + New Task grouped; Panel = refresh + stats grouped; tooltips.
- **S4**: Focus stage: ambient mode-color mesh (60s stepped drift, 0.12 light/0.22 dark, static under reduced-motion); ring up to 360px stroke 13, track mode color 0.18, angular-gradient arc from 12 o'clock, dashed [4,10] idle overlay for count-up; digits 72/84 rounded semibold monospaced; breathing mode icon; − / tinted capsule primary / + glass circles; glass chips; Skip + destructive End with confirmation.
- **S5**: Break colors derived with `PhaseColors.swift` algorithm (short: hue+30 sat×0.75 light+0.15; long: hue+50 sat×0.60 light+0.20), unit-tested.
- **S6**: Plan: table rows 30/header 28 no zebra, circle checks, priority arrows, colored energy icons, pomodoro x/y, overdue red; fixed "New task" footer row; context menu (right-click / long-press) with Priority/Energy checkmarks + destructive role; undo banner material r12; inspector ideal 340.
- **S7**: Panel/Dashboard: max width 980, flat 4-column KPI row, weekly chart (bars r4, today full, past 0.35, right y-axis, scrub callout), Recent sessions + Next focus with green capsule CTA.
- **S8**: Mobile adapted: compact per-pane top bar, tabbar with new materials, same palette; no touch regressions (sheets, drag-reorder, 44px targets).
- **S9**: Landing lockstep: `landing/src/lib/design/` byte-identical to `web/src/lib/design/` after every batch; builds green.
- **S10**: Shortcuts: ⌘F search, ⌘N new task, ⌘⌥I inspector (⌘1/2/3 already exist).

## Exclusions

Menu bar, notch panel, dock (badge/arc/menu), separate Statistics window, Services/Spotlight, global ⌃⌥* shortcuts — browser cannot replicate them. ⌘K quick capture stays (Spotlight restyle only). No backend/API/contract changes. No i18n key changes.

## Allowed edit surfaces

- `web/src/lib/design/**` (tokens.css, base.css, components.css, Icon/Segmented/Sheet/Switch/Toasts.svelte, new ContextMenu.svelte)
- `web/src/routes/(app)/+layout.svelte`
- `web/src/routes/(app)/focus/+page.svelte`
- `web/src/routes/(app)/plan/+page.svelte`
- `web/src/routes/(app)/dashboard/+page.svelte`
- `web/src/routes/(app)/account/+page.svelte`
- `web/src/lib/features/focus/**`, `web/src/lib/features/plan/**`, `web/src/lib/features/dashboard/**`, `web/src/lib/features/shell/**` (new PaneToolbar)
- `web/src/lib/features/settings/**`, `web/src/lib/features/auth/**` (material re-tint only)
- `web/src/lib/stores/focus.svelte.ts` (phaseColor derivation only)
- `web/src/lib/domain/focus/phaseColors.ts` — **expansion (B3, leader-authorized)**: new pure module porting PhaseColors.swift (S5 requires its own unit-tested domain logic) + `web/tests/unit/phase-colors.test.ts`
- `web/src/lib/domain/tasks/plan.ts` — **expansion (B2, leader-authorized)**: add `'all'` to PlanFilter + filterTasks case for the Mac sidebar filters (Todas/Hoy/Próximas/Completadas)
- `web/src/lib/i18n/messages.ts` — **expansion (B2, leader-authorized)**: ADDITIVE keys only (`plan.search`, `plan.newTask`, `plan.empty.all`, `plan.search.empty`, `dashboard.refresh`, `focus.endConfirm` × es/en/pt); no existing key altered (exclusion intent preserved)
- `web/src/routes/+layout.svelte` — **expansion (B2 round 1, leader-authorized)**: SW registration gated to PROD builds (dev cache-first SW served stale modules and masked edits)
- `web/tests/unit/**` — **expansion (B2 round 1, leader-authorized)**: regression test for the new `all` filter case (reviewer P1)
- `landing/src/lib/design/**` (lockstep copies of `web/src/lib/design/`)
- `odd/tasks/871-web-mac-parity.md`

## Log

- **L1 (2026-11-17)**: Issue created from approved plan (AskUserQuestion decisions: desktop + mobile adapted; themes = Mac behavior). UX brief published; status:ready.
- **L2 (2026-11-17)**: B1 (tokens) merged via PR #872 (judgment-day dual APPROVED, 0 severe). B2 (shell) implemented on `feat/web-mac-shell`: Mac sidebar model (Foco → Plan filters → Panel, 30px rows, radius-10 accent capsule, account footer + gear), per-pane Mac toolbars via new `PaneToolbar` (Focus segmented empties while running; Plan search/inspector/new; Panel refresh), Plan filter `all` + toolbar search, shortcuts ⌘F/⌘N/⌘⌥I (browser-reserved caveat noted), Quick Capture restyled to the Spotlight panel. Surfaces expanded as noted above.
- **L3 (2026-11-17)**: B3 (focus stage) implemented on `feat/web-mac-focus`: PhaseColors.swift ported to pure domain module + tests (short hue+30/sat×0.75/light+0.15 → #E2C18F from pomodoro, long hue+50 → #E1DDAA); store `phaseColor` now derives break colors from the resolved mode hex (themes honored via getComputedStyle) instead of borrowing other modes' tokens; FocusRing rebuilt to Mac spec (CSS conic angular-gradient arc from 12 o'clock, stroke 13, track 0.18, dashed [4,10] idle overlay for count-up, digits 72/84 rounded semibold, breathing mode icon, phase label below with tracking 1.1, no card — floats on ambient); ambient mesh (4 mode-color blobs, 60s drift in 2s steps, 0.12 light/0.22 dark, static under reduced-motion); controls: − / mode-tinted glass capsule (0.72 + specular) / + 44px glass steppers, Skip bordered, End destructive with two-step confirm (`focus.endConfirm` additive key); task/soundscape chips become glass.
