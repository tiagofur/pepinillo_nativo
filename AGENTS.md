# AGENTS.md — Pepinillo monorepo

## What this repo is

Multi-platform **deep work / focus + tasks** product:

| Path | Stack |
| ---- | ----- |
| `ios/` | Swift, TCA, SwiftUI — iPhone + watchOS |
| `android/` | Kotlin, Compose — phone + Wear OS |
| `windows/` | C# / WinUI 3 / Windows App SDK — desktop |
| `backend/` | Go REST API |
| `PRD/` | **Product source of truth** (01–14; web decision brief in 14) |
| `docs/` | Operational Obsidian-style vault (status, MOCs, runbooks) — **not** a second PRD |
| `windows/store/` | Microsoft Store launch / IAP / a11y checklists |
| `DEPLOYMENT.md` | Backend deploy SoT (IONOS VPS) |

Live status: **`PRD/09_CURRENT_STATUS.md`**. Windows depth: `PRD/11`–`13`. Web planning: `PRD/14`.

Legal: [Terms](https://creapolis.dev/terms-of-use/) · [Privacy](https://creapolis.dev/privacy-policy/)

## Agent rules (short)

1. **Docs SoT:** product truth in `PRD/`; ops in `docs/`; deploy in root `DEPLOYMENT.md`. Do not recreate PRD body forks under `docs/PRD/`.
2. **Secrets:** never commit API secrets. Use env/CI only (`REVENUECAT_SECRET_KEY`, etc.).
3. **Cross-platform parity:** a fix/feature on one platform should be reviewed on the others (iOS, Android, Wear, watchOS, Windows where applicable).
4. **PRD maintenance:** after significant work, update `PRD/09` (and `PRD/02` features/parity when product surface changes).
5. **Commits:** Conventional Commits in **English** (`feat:`, `fix:`, `docs:`, …). Platform scope when useful: `feat(android):`, `fix(ios):`, `feat(windows):`. **No** AI co-author trailers.
6. **Scope discipline:** prefer docs/code that matches existing stack; do not invent npm/Jest scaffold workflows for this monorepo.

## Tests (typical)

| Platform | Command (from relevant root) |
| -------- | ---------------------------- |
| Android | `cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest` |
| Backend | `cd backend && go test ./...` |
| Windows Core | `dotnet test windows/Pepinillo.Core.Tests/Pepinillo.Core.Tests.csproj -c Release` (use `DOTNET_ROLL_FORWARD=Major` if host SDK mismatch requires it) |
| iOS | Xcode / `xcodebuild` test schemes for Pepinillo targets (device/simulator as available) |

Prefer project checklists: `android/QA_RELEASE_CHECKLIST.md`, `windows/store/LAUNCH_CHECKLIST.md`, iOS App Store docs under `ios/docs/`.

## Where to look

| Need | Location |
| ---- | -------- |
| Current implementation status | `PRD/09_CURRENT_STATUS.md` |
| Roadmap | `PRD/07_ROADMAP.md` |
| Windows Store ops | `windows/store/` |
| Deploy backend | `DEPLOYMENT.md`, `VPS_SETUP_CHECKLIST.md` |
| Vault dashboard | `docs/00_DASHBOARD.md` |
| Orchestrator notes | `Claude.md` (project) |

Do not point agents at obsolete scaffold paths (`.context` generators, `dist/`, Jest).
