# macOS Native v1 — Focus-first + Plan

Native macOS app (`PepinilloMac`) with a macOS-first shell: menu bar presence, Focus timer, Plan table, Today. Shared TCA/SwiftData core; new Mac presentation layer. No auth, AI, or paywall redesign in v1.

- Branch: `feat/macos-native-v1` (worktree: `pepinillo_nativo-worktrees/macos-native-v1`, based on `main` @ `52a8069b`)
- Delivery: `ask-on-risk` (forecast is well over 400 authored lines; decide chain strategy before F2)
- Test runner: `xcodebuild -scheme "PepinilloMac Dev" build`; test action to verify/add

## Specs

- S1: "quiero construir una app 100% nativa para MacOS y que tenga el diseño no adaptado, piensado para MacOS pero usando el mismo estilo y coherencia con la app de iOS y principalmente iPad".
- S2: "A" — approved v1 scope: Focus-first + Plan nativo (menu bar, full timer, tasks with Table, Today dashboard).
- S3: No auth, no AI reports, no new paywall design in v1. Existing entitlement gate stays as-is.
- S4: Presence: menu bar countdown + controls, global shortcut, launch at login, optional Dock icon.
- S5: One TCA/SwiftData core. No domain fork. macOS presentation lives in `ios/Mac/`.
- S6: No primary flow depends on a sheet. Sidebar + detail + inspector. Settings via `⌘,`.
- S7: Keyboard-first: menus, shortcuts, context menus, multi-select, drag & drop, undo/redo.
- S8: Accessibility: VoiceOver, Reduce Motion, Reduce Transparency, contrast, full keyboard access.
- S9: Tests: timer survives window close, menu bar action mapping, Plan CRUD/reorder.
- S10: Docs updated: `PRD/01`, `PRD/05`, `PRD/09`, `.impeccable.md`, `ios/docs/macos-design-contract.md`.
- S11: Out of scope: auth/account, sync UI, AI reports, weekly/monthly review, calendar, share cards, live cross-device timer, paywall redesign.

## Tasks

| ID | Spec | Task | Route | Commit |
| ---- | ---- | ---- | ---- | ------ |
| T1 | S1, S10 | F0: design contract + `.impeccable.md` + PRD updates | inline | — |
| T2 | S4 | F1: app lifecycle — `Window`, `Settings`, launch at login, Dock policy | inline | — |
| T3 | S4 | F1: `MenuBarExtra` countdown + quick controls + today stats | inline | — |
| T4 | S4 | F1: global shortcut + commands + notification actions | inline | — |
| T5 | S6, S7 | F2: main window shell — sidebar, toolbar, state restoration | inline | — |
| T6 | S2, S6 | F2: Focus stage + session journal + celebration | inline | — |
| T7 | S2 | F2: Today dashboard (subset of `AnalyticsFeature`) | inline | — |
| T8 | S2, S7 | F3: Plan table — filters, search, context menus, drag & drop | inline | — |
| T9 | S2, S7 | F3: task inspector + inline edit + undo | inline | — |
| T10 | S8, S9 | Tests + accessibility + localization pass | inline | — |
| T11 | S10 | F4: App Store packaging + TestFlight + docs | inline | — |

## Log

- L1 (2026-10-21): "encontre una app que recomendaron ne Topes de Gama + para MacOS que se llama Kofe Flow que es un pomodoro nada mas sin tareas y nada mas... puedes buscar sobre el en internet? de hecho lo tengo abierto ahora mismos aqui en esta macbook... lo que quiero es tomar ideas de mejoras en lo que ellos hacen mejor que nosotros. otro tema, quiero construir una app 100% nativa para MacOS y que tenga el diseño no adaptado, piensado para MacOS pero usando el mismo estilo y coherencia con la app de iOS y principalmente iPad... planea, puedes usar skills como de  @.agents/skills/teach-impeccable/ o alguna otra que veas util."
- L2: Scope answer: "A" — Focus-first + Plan native.
- L3: "arrancamos" — F0 authorized.
- L4: Evidence for the plan. `PepinilloMac` is already a native macOS target (macOS 15, `project.yml`, bundle `com.pepinillo.app`) sharing `AppFeature`/`Features`/`Domain`/`Shared`. `ios/Mac/MacAppView.swift` is iPad-adapted: `NavigationSplitView` 180 pt sidebar, 720×560 detail, 768 width breakpoint, sheets for every secondary flow. No `MenuBarExtra`, `LSUIElement`, or `SMAppService`. `ios/App/MacCommands.swift` uses bare `Space` as a menu key equivalent (risky while typing). PRD/05 says Catalyst and PRD/01 says Planned while the target is native — docs drift.
- L5: Competitive evidence. Kofe Flow installed bundle: universal arm64/x86_64, SwiftUI + AppKit, 7.4 MB, `LSMinimumSystemVersion` 14.0, `LSUIElement = true`; menu bar timer, global shortcuts, launch at login, hide Dock, local analytics, one-time Pro (kofeflow.com). Their wedge is presence, not features; we keep depth and adopt the presence.
- L6 (2026-10-21): F0 artifacts written and read back. Local `main` fast-forwarded to `origin/main` (`52a8069b`, 0/0) and worktree `pepinillo_nativo-worktrees/macos-native-v1` created on `feat/macos-native-v1`. F0 committed as T1.

## Close-out

Pending.
