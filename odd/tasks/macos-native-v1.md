# macOS Native v1 — Focus-first + Plan

Native macOS app (`PepinilloMac`) with a macOS-first shell: menu bar presence, Focus timer, Plan table, Today. Shared TCA/SwiftData core; new Mac presentation layer. No auth, AI, or paywall redesign in v1.

- Branch: `feat/macos-native-v1` (worktree: `pepinillo_nativo-worktrees/macos-native-v1`, based on `main` @ `52a8069b`)
- Delivery: `stacked-to-main` (chosen 2026-10-21; forecast is well over 400 authored lines)
- Test runner: `xcodebuild -scheme "PepinilloMac Dev" -destination 'platform=macOS' build`; `xcodebuild -scheme "Pepinillo Dev" -destination 'generic/platform=iOS Simulator' build`; UI tests pending

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
| T1 | S1, S10 | F0: design contract + `.impeccable.md` + PRD updates | inline | 6cc09447 |
| T2 | S4 | F1: app lifecycle — `Window`, `Settings`, launch at login, Dock policy | inline | 0977c09a |
| T3 | S4 | F1: `MenuBarExtra` countdown + quick controls + today stats | inline | 0977c09a |
| T4 | S4 | F1: global shortcut (`⌃⌥Space`) + commands + notification actions | inline | 09fff0b4 |
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
- L6 (2026-10-21): F0 artifacts written and read back. Local `main` fast-forwarded to `origin/main` (`52a8069b`, 0/0) and worktree `pepinillo_nativo-worktrees/macos-native-v1` created on `feat/macos-native-v1`. F0 committed as `6cc09447` (T1).
- L7 (2026-10-21): F1 T2/T3 implemented and committed as `0977c09a`. Replaced `WindowGroup` with `Window("Pepinillo", id: "main")`; added `Settings` scene and `MenuBarExtra` with `.menuBarExtraStyle(.window)`. Moved `.appLaunched` into `MacAppBootstrap.apply` so the launch contract runs even when the main window never appears. Added `MacPreferences` (`SMAppService.mainApp` launch-at-login, Dock policy via `setActivationPolicy`) and a General/Appearance settings window. Menu bar shows live countdown, Start/Pause/Resume/Skip/Stop, today stats, Open Pepinillo, Settings, Quit. Replaced the bare `Space` command key with `⌘↩`; Account menu renamed from Settings.
- L8 (2026-10-21): Verification. `xcodebuild -scheme "PepinilloMac Dev" -destination 'platform=macOS' -derivedDataPath build/macos-f1 CODE_SIGNING_ALLOWED=NO build` → BUILD SUCCEEDED. `xcodebuild -scheme "Pepinillo Dev" -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios-f1 CODE_SIGNING_ALLOWED=NO build` → BUILD SUCCEEDED. The built Mac app launched and stayed running; menu bar contents could not be inspected through System Events because `osascript` lacks Accessibility permission, so UI interaction remains manual.
- L9 (2026-10-21): Platform gates required to make the shared Mac target compile: iOS-26 scroll/tab APIs in `GlassModifier`, `ControlCenter` in `WidgetSurfaceReload`, `UNAuthorizationStatus.ephemeral`, `Color(uiColor:)` in `TaskRow`, and the UIKit export files. Export (`ExportView`/`ExportService`/`ExportReportView`) is excluded from the Mac target and its Account entry is iOS-only until a native macOS export task exists. T4 remains pending: global shortcut (KeyboardShortcuts vs Carbon) and notification action routing. Next: F2 shell (T5).
- L10 (2026-10-21): Delivery decision: `stacked-to-main`. Each work unit lands as a small PR to main in order; after the parent PR merges, rebase/retarget the next PR. F1 is the first slice.
- L11 (2026-10-21): F1 T4 implemented and committed as `09fff0b4`. Chose Carbon `RegisterEventHotKey` for `⌃⌥Space` (no new dependency; global key monitors would require Accessibility permission). Added `MacGlobalHotKey`, unified the menu command, menu bar primary action, and global shortcut behind `FocusToggleCommand`, and documented the shortcut in Settings. Notification action routing was already present in `AppFeature`; it now starts from the bootstrap `.appLaunched` effect. Verification: Mac build → BUILD SUCCEEDED; iOS build → BUILD SUCCEEDED; `FocusToggleCommandTests` 4/4 passed on iPhone 17 Pro (iOS 26.5); built Mac app launched and stayed running. The global keypress itself remains manual because `osascript` lacks Accessibility permission.

## Close-out

Pending.
