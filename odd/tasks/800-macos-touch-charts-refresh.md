# 800 — macOS touch: chart scrubbing and pull-to-refresh
Objective: Let a finger (or pointer) read exact values off the focus charts in `MacTodayView` / `MacStatisticsView`, and reload Today and Plan with the system pull-to-refresh on touch Macs.
Branch: `feat/macos-touch-charts-refresh` | Delivery: `complete` | Test runners: `xcodebuild build -scheme "PepinilloMac Dev"`

## Specs

- **S1**: Sliding a finger or pointer over the bars of `weeklyChart` (Today) and `chart` (Statistics) shows a callout with the exact date/week, focus minutes and sessions via `.chartXSelection`; it hides on release.
- **S2**: `MacTodayView` and `MacPlanView` adopt `.refreshable` (`onRefresh()` / task reload) without breaking the toolbar `Refresh` button.
- **S3**: Compatible with macOS 15+.

## UX Brief

- **Visitor mode / goal**: reviewing, not acting. "How much was Tuesday?" should be answerable by touching Tuesday.
- **Composition thesis**: the chart stays the picture; the callout is a transient annotation on it, never a new permanent row. A hairline rule marks the bar, a small material chip above it carries date → focus time → sessions, in that reading order. Same chip in both charts.
- **Content**: title is the full weekday + day + month (7D/30D) or the week's date range (Year); value uses the same duration formatting as the summaries; sessions reuse the existing `%lld sessions` string. No new copy.
- **States**: no selection = chart exactly as before. Empty periods keep their existing empty text (no chart, no callout). Callout is clamped inside the chart horizontally so edge bars never clip.
- **Refresh**: the pull is the touch twin of the toolbar Refresh button, not a replacement. No custom indicator — the system control only.
- **Accessibility**: callout text is one combined element; the charts keep their existing summary label/value. Pointer users get the same callout on hover-scrub, so nothing is touch-only.
- **Memorable moment**: dragging a finger along the week and watching the numbers follow.

### Assumptions

- A1: Hover-scrubbing with the pointer showing the same callout is desirable (S1 says "dedo o puntero").
- A2: Today's `.refreshable` cannot await completion (`onRefresh` is a synchronous closure from `MacAppView`, outside the edit surfaces), so the system indicator dismisses immediately there; Plan awaits the real fetch.
- A3: `.refreshable` on a macOS `ScrollView`/`Table` only becomes interactive on macOS 27 (`NSRefreshController`); not exercised here.

## Allowed edit surfaces

- `ios/Mac/MacTodayView.swift`
- `ios/Mac/MacStatisticsView.swift`
- `ios/Mac/MacPlanView.swift`
- `ios/Shared/Resources/Localizable.xcstrings` (not needed — no new strings)
- `odd/tasks/800-macos-touch-charts-refresh.md`

## Log

- **L1 (2026-11-16)**: User request verbatim: `PR verde... continue con las mejoras y pruebas`.
- **L2 (2026-11-16)**: Verified by `PepinilloMac Dev` build on Xcode 27.3 beta (`BUILD SUCCEEDED`, no warnings in the touched files). Not exercised on screen: the callout needs real pointer/finger movement, and `.refreshable` only becomes interactive on macOS 27 (this machine runs 27.2.1 without touch).
