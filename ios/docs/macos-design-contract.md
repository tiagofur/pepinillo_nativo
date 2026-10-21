# Pepinillo for Mac — macOS Design Contract

**Status:** v1 (Focus-first + Plan)
**Target:** `PepinilloMac` (macOS 15+, SwiftUI + AppKit)
**Shared core:** `AppFeature`, `FocusFeature`, `TaskListFeature`, `AnalyticsFeature`, `PersistenceClient`
**Related:** `.impeccable.md`, `PRD/05_TECHNICAL_ARCHITECTURE_IOS.md`, `PRD/09_CURRENT_STATUS.md`

---

## 1. Purpose

Pepinillo for Mac is not the iPad app stretched to a window. It keeps the brand's visual language and re-expresses it with macOS grammar: menu bar presence, sidebar + detail + inspector, toolbar, menus, keyboard, pointer, materials, and window management.

The test: a Mac user should recognize Pepinillo, but never feel they are using an iOS app in a window.

---

## 2. Non-negotiables (shared with iOS / iPad)

| Invariant | Source of truth |
| --- | --- |
| Mode accents: Pomodoro red, Flowtime blue, Time Block purple, Stopwatch green, Streak amber | `ios/Shared/Design/AppTheme.swift` |
| Break variants derived by hue shift + desaturation + lightening | `ios/Shared/Design/PhaseColors.swift` |
| Glass radii: tile 12, card 20, hero 28 | `ios/Shared/Design/GlassTokens.swift` |
| Motion presets: snappy, bouncy, smooth, heroEntrance, pressScale | `ios/Shared/Design/MotionTokens.swift` |
| Ambient mesh: 60 s drift, 2 s timeline beats, 0.12 light / 0.22 dark opacity | `ios/Shared/Design/GlassModifier.swift` |
| Celebration vocabulary | `ios/Shared/Design/CelebrationView.swift` |
| Product voice and copy | `Localizable.xcstrings` (EN/ES/PT) |

Coherence means the same palette, ring geometry, glass language, motion feel, and copy. It does **not** mean the same layout.

---

## 3. Platform expression

| Dimension | iPad | macOS |
| --- | --- | --- |
| Navigation | tabs + split view | sidebar + detail + inspector |
| Density | regular | compact |
| Type | Dynamic Type | semantic macOS text styles |
| Materials | glass + ambient | materials in chrome; ambient only in the Focus stage |
| Primary actions | prominent buttons | toolbar + menus + keyboard shortcuts |
| Plan | list + sheet | table + inspector |
| Pointer | touch | hover, context menus, drag & drop |
| Windows | one scene | main window + menu bar + settings + statistics |

---

## 4. Scenes and window

- `Window("Pepinillo", id: "main")` — single main window, default 1120×760, minimum 960×640.
- `MenuBarExtra("Pepinillo", systemImage: "timer")` with `.menuBarExtraStyle(.window)`.
- `Settings` scene, opened with `⌘,`.
- `Window("Statistics", id: "statistics")` — F4, not v1.
- Closing the main window must not stop the timer. Set `applicationShouldTerminateAfterLastWindowClosed = false`.
- Restore the selected sidebar section, window frame, and inspector visibility.
- The timer lives in the app-level `StoreOf<AppFeature>`, not in a view's lifecycle.

---

## 5. Information architecture

Sidebar (`List(selection:)`, `.listStyle(.sidebar)`, width 200–280, ideal 220):

| Section | Symbol | Content |
| --- | --- | --- |
| Focus | `timer` | Timer stage, mode switcher, linked task, session journal |
| Plan | `checklist` | Task table, filters, search, inspector |
| Today | `chart.bar` | Today KPIs, recent sessions, start next focus |

Bottom of the sidebar: Pepinillo+ entitlement status or app version. No account section in v1.

---

## 6. Menu bar

- Label while running: `Image(systemName: phaseSymbol)` + `Text(mm:ss)` with `.monospacedDigit()`. Idle: icon only.
- Do not rely on color in the menu bar; it renders as a template.
- Popover width: 320 pt.
- Content: mode + phase, large time, primary Start/Pause, Skip/Stop, Link task (recent 5), today stats (sessions / minutes), Open Pepinillo, Settings…, Quit.
- Global shortcut: `⌃⌥Space` toggles start/pause. Never bare `Space`; never `⌘Space`.
- Update the label once per second only while a session is running. Idle label is static.
- Menu bar actions send the same `FocusFeature` actions as the window. No parallel timer logic.

---

## 7. Focus

- Centered stage; ring max 420 pt; timer numerals 64–96 pt, `.rounded`, `.monospacedDigit()`.
- Mode switcher: segmented control in the toolbar (Pomodoro / Flowtime / Time Block / Stopwatch). Existing Pro gate unchanged.
- Primary action: Start/Pause, `.borderedProminent`, minimum height 32, default keyboard action.
- Secondary actions: Skip, Reset, Stop in the toolbar or Focus menu.
- Linked task: optional chip; picker over active tasks; never required to start.
- Session journal after completion: inspector or compact sheet. It must not block returning to the timer.
- Ambient background is clipped to the Focus detail pane. Sidebar, toolbar, Plan, Today, and Settings use system backgrounds.

---

## 8. Plan

- `Table` columns: Done, Title, Priority, Energy, Pomodoros, Due.
- Row height 30; header 28. Inline title edit; double-click opens the inspector.
- Multi-select; context menu: Start Focus, Complete, Priority, Energy, Move to Today, Delete.
- Drag to reorder. If `Table` reordering proves fragile, use `List` with `.onMove` — nativeness beats dogma.
- Toolbar: search field, filter menu (All / Today / Upcoming / Completed), new task (`⌘N`), inspector toggle.
- Inspector: title, notes, priority, energy, estimate, subtasks, linked sessions.
- Empty state: `PepinilloEmptyState` adapted, CTA "New task".
- Undo for delete and complete.

---

## 9. Today

- Header: date, streak, total focus time.
- KPI grid: focus time, sessions, streak, tasks completed.
- Recent sessions list (last 5) and "Start next focus".
- No weekly/monthly review, AI reports, or calendar in v1.

---

## 10. Settings

`Settings` scene, `⌘,`, tabs:

| Tab | Contents |
| --- | --- |
| General | Launch at login, Show in Dock, default section |
| Focus | Durations, default mode, linked-task behavior |
| Notifications | Session end, break end, sound |
| Appearance | Theme (Classic/Forest/Ocean/Sunset), light/dark/system |

No account, auth, or sync UI in v1.

---

## 11. Typography

Use semantic macOS text styles, not hardcoded Dynamic Type sizes:

| Role | Style |
| --- | --- |
| Window / section title | `.title2` or `.title` |
| Card title | `.headline` |
| Body | `.body` (13 pt) |
| Secondary | `.callout` / `.subheadline` |
| Caption | `.caption` (11 pt) |
| Timer | `.system(size: 84, weight: .medium, design: .rounded).monospacedDigit()` |
| Menu bar | `.system(size: 12, design: .rounded).monospacedDigit()` |

SF Pro is the default. Rounded is reserved for numerals and celebration. Do not use `.navigationBarTitleDisplayMode` or `.largeTitle` in window chrome.

---

## 12. Spacing, radii, materials

- 4 pt base grid; use 8 / 12 / 16 / 24 / 32.
- Sidebar row 28; table row 30; card padding 16 (compact) or 24 (hero).
- Radii: `GlassCornerRadius.tile` 12, `.card` 20, `.hero` 28.
- Chrome: `NSColor.windowBackgroundColor`; popover: `.regularMaterial`.
- Cards: `.pepinilloGlass(cornerRadius: GlassCornerRadius.card)`.
- No full-window mesh gradient behind Plan, Today, or Settings.

---

## 13. Motion

- `MotionTokens.snappy` for control state; `.smooth` for layout; `heroEntrance` for celebration.
- Ring progress: smooth, no bounce.
- Reduce Motion: static background, crossfade transitions, no celebration stagger.
- Reduce Transparency: opaque surfaces, no materials.

---

## 14. Keyboard and commands

| Shortcut | Action |
| --- | --- |
| `⌘,` | Settings |
| `⌘N` | New task |
| `⌘F` | Search |
| `⌘1` / `⌘2` / `⌘3` | Focus / Plan / Today |
| `⌘↩` | Start / Pause |
| `⌘.` | Stop |
| `⌃⌥Space` | Global start / pause |

Menus: App, File, Edit (undo/redo), View, Focus, Plan, Window, Help. No bare `Space` or single-letter menu equivalents. Icon-only toolbar buttons get tooltips.

---

## 15. Accessibility

- Timer: `.accessibilityLabel("25 minutes remaining")` and an `.accessibilityValue` that updates with the phase.
- Ring progress is exposed as a value; never color alone.
- Minimum hit target 28×28; primary action at least 32 pt high.
- Contrast: 4.5:1 body, 3:1 large text. Mode and priority pair color with an icon or label.
- Full Keyboard Access and a visible focus ring.
- VoiceOver reads the menu bar popover controls.

---

## 16. Localization

- All new strings go through `Localizable.xcstrings` (EN/ES/PT).
- No hardcoded Spanish in code.
- Dates and numbers use `FormatStyle`, not manual string building.

---

## 17. Anti-patterns

- Stretching iPhone or iPad views to fill a Mac window.
- Sheets for primary flows.
- Full-window ambient gradient behind tables.
- iOS hit targets, nav bars, or tab bars on macOS.
- Bare `Space` shortcuts.
- Auto-hiding the Dock without an explicit preference.
- Forking the TCA domain or adding a second timer engine.

---

## 18. Open decisions (resolve in F1)

1. Global shortcut dependency: `KeyboardShortcuts` package vs in-house Carbon wrapper.
2. Pro entitlement on macOS: existing gate with a clear state vs free modes only in v1.
3. Mac test target: add `PepinilloMacTests` or run shared tests with a macOS destination.
4. App-usage insights (F4): opt-in `NSWorkspace` foreground sampling; not v1.
