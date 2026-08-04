# Windows accessibility smoke (W15 / #589)

Manual checks on a real Windows 10 19041+ or Windows 11 machine before claiming G8 (PRD/13).  
English automation names are intentional; Narrator speech language follows the OS.

## Prerequisites

- Pepinillo WinUI build installed or `dotnet run` from `windows/Pepinillo.WinUI`
- Narrator: `Win + Ctrl + Enter` (or Settings → Accessibility → Narrator)
- Optional: Settings → Accessibility → Text size → 200%
- Optional: Settings → Accessibility → Contrast themes → High contrast

## 1. Narrator — Focus primary flow

1. Open **Focus**.
2. Tab until mode chips; confirm Narrator announces **Select Pomodoro mode** (etc.).
3. Activate Pomodoro; Tab to **Start or resume focus session**; activate Start.
4. Confirm timer region has name **Session timer** and polite live updates (occasional announcements OK — not every second).
5. Activate **Pause focus session** (or use `Ctrl+Space` when the page has focus).
6. Resume with **Start** or `Ctrl+Enter`.
7. Optional: link a task via **Link focus session to task**, clear with **Clear linked task**.
8. Complete or stop; if journal appears, fill notes / energy and **Save session journal**.

**Pass:** Primary controls named; Start/Pause/Stop/Skip reachable by keyboard; no silent unlabeled icon-only CTAs on this path.

## 2. Narrator — Tasks

1. Open **Tasks**.
2. `Ctrl+N` focuses the new task title field (**New task title**).
3. Type a title, Tab to estimate / priority / energy, **Add task**.
4. Tab filter headers (Today / Upcoming / Inbox / All).
5. On a row: complete checkbox (**Complete task**), delete (**Delete task**).
6. Empty list: **Add your first task** CTA is announced.

## 3. Keyboard — Paywall CTAs

1. Open **Upgrade** / Paywall.
2. Tab through **Buy Pepinillo Plus**, **Subscribe monthly/annual**, **Restore purchases**, **Manage subscriptions in Microsoft Store**.
3. Confirm logical order (left product → right product → restore → manage).

## 4. Text scale 200%

1. Set Windows text size to **200%** (or display scaling that enlarges UI text).
2. Visit Focus, Tasks, Paywall, Settings.
3. Confirm primary CTAs remain clickable/visible; scrolling allowed — no permanently clipped Save / Start / Buy.

## 5. High contrast theme

1. Enable a Windows **High contrast** theme.
2. Focus timer card and mode chips remain readable (text uses theme brushes, not pure white-on-light).
3. Paywall and Settings cards: labels and buttons remain distinguishable.

## Page accelerators (in-app)

| Chord | Context | Action |
| ----- | ------- | ------ |
| `Ctrl+Enter` | Focus page | Start / resume session |
| `Ctrl+Space` | Focus page | Pause when available |
| `Ctrl+N` | Tasks page | Focus new task title field |

Global OS hotkeys (Play/Pause, Skip, Mini timer) remain rebindable in Settings.  
Caption in Settings: *Focus: Ctrl+Enter start/resume · Ctrl+Space pause when available. Tasks: Ctrl+N focus add field.*

## Sign-off

| Check | Build | Date | Tester | Pass? |
| ----- | ----- | ---- | ------ | ----- |
| Narrator Focus | | | | |
| Narrator Tasks | | | | |
| Keyboard Paywall | | | | |
| 200% text | | | | |
| High contrast | | | | |

Related: [CERTIFICATION_CHECKLIST.md](./CERTIFICATION_CHECKLIST.md) §7 · PRD/13 G8.
