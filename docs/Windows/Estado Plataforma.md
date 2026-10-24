---
tags:
  - windows
  - status
aliases:
  - Estado Windows
platform: windows
type: status
doc_role: status
status: active
date: 2026-08-05
updated: 2026-08-05
---

# Platform status — Windows

> [!abstract] Canonical ops note
> Aligns with [PRD/09](../../PRD/09_CURRENT_STATUS.md). Does **not** claim Microsoft Store published until #568 succeeds.

## Current status

| Item | State |
| ---- | ----- |
| Stack | C# / WinUI 3 / Windows App SDK / .NET / EF Core SQLite / MSIX |
| Excellence **W0–W15** | **Code complete / merged** |
| CI | Core tests + x64/ARM64 build + MSIX pack |
| Store published | **Not claimed** — flight pending |

## Remaining ops

| Work | Tracking | Action |
| ---- | -------- | ------ |
| WinUI hardware smoke | **#575** | `windows/store/LAUNCH_CHECKLIST.md` Phase B + `A11Y_SMOKE.md` on Windows 10/11 |
| Partner Center / Store | **#568** | Screenshots, publisher CN, IAP SKUs, Internal flight |

## What is in code (summary)

Focus (4 modes), tasks, calendar/day planner, analytics/reviews, soundscapes, auth/sync paths, Store commerce service + paywall, a11y/keyboard excellence, desktop power (toasts, startup, hotkeys). Residuals (no full Outlook/Google calendar sync, Partner Center sandbox proof, etc.) are listed in PRD/09 §3b — do not invent completion beyond that.

## Pricing (D1)

- Pepinillo+ Windows: **$9.99** durable (platform-scoped)
- Everywhere: **$4.99/mo · $34.99/yr** (match global mobile)

## References

- [[Windows MOC]]
- [PRD/11](../../PRD/11_WINDOWS_APP_PRD_AND_ROADMAP.md) · [12](../../PRD/12_WINDOWS_EXECUTION_PLAN.md) · [13](../../PRD/13_WINDOWS_EXCELLENCE_PLAN.md)
- [[../Cross-Platform/Parity Matrix|Parity Matrix]]
