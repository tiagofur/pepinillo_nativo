# Microsoft Store screenshots

Store listing images for **Pepinillo** (desktop). Replace placeholders with real app captures before public submission.

## Required sizes (desktop / PC)

| Size | Use | Status |
| ---- | --- | ------ |
| **1366 × 768** | Minimum common Store desktop screenshot | Placeholder PNG present |
| **1920 × 1080** | Preferred high-res desktop screenshot | Placeholder PNG present |

Microsoft may also accept other 16:9 desktop sizes; check Partner Center → Product page → Store listings for the current matrix.

## Optional / nice-to-have

| Asset | Guidance |
| ----- | -------- |
| Light theme + dark theme | At least one of each if UI differs |
| Feature callouts | Focus timer, tasks, tray mini-timer, analytics |
| ARM64 device shot | Optional if hardware available |
| Store logo / tile icons | Generated under `windows/Pepinillo.WinUI/Assets/` (not this folder) |

## Content guidance

1. **No fake metrics** — show real UI; placeholders here are brand frames only.
2. **Age-appropriate** — productivity app, Everyone / 3+; no violence, gambling, or adult content.
3. **No misleading paywall** — free tier must be honest; IAP callouts must match live products.
4. **Privacy** — do not show real user emails or private task content in marketing shots.
5. **Captions** (optional in Partner Center) — short benefit lines, e.g. “Stay in deep work with Pomodoro & Flowtime”.

## Placeholders in this folder

| File | Notes |
| ---- | ----- |
| `desktop-1366x768-placeholder.png` | Solid brand frame + title — **replace before Store** |
| `desktop-1920x1080-placeholder.png` | Same — **replace before Store** |

## How to capture real screenshots

1. Run a Release build on Windows 11 (x64 or ARM64).
2. Set scale to 100% for crisp text.
3. Capture Focus, Tasks, Analytics, Settings (privacy links), Paywall (with D1 prices once final).
4. Export lossless PNG; avoid heavy compression artifacts.
5. Drop files here and update the Store listing via Partner Center (see `../RELEASE_RUNBOOK.md`).
