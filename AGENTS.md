# AGENTS.md — Pepinillo monorepo

## What this repo is

Multi-platform **deep work / focus + tasks** product.

| Path | Stack |
| ---- | ----- |
| `ios/` | Swift, TCA, SwiftUI — iPhone + watchOS |
| `android/` | Kotlin, Compose — phone + Wear OS |
| `windows/` | C# / WinUI 3 / Windows App SDK — experimental desktop implementation (paused) |
| `backend/` | Go REST API |
| `PRD/` | **Product source of truth** (product decisions, features, roadmap, current status) |
| `docs/` | Operational documentation, guides, strategy context — **not** a second PRD |
| `docs/strategy/` | Product direction, growth validation, lessons learned |
| `DEPLOYMENT.md` | Backend deployment source of truth |

Live status: **`PRD/09_CURRENT_STATUS.md`**.

## Current product phase

Pepinillo is currently in **Growth Validation Phase**.

The product already has production-ready mobile foundations. The main objective is no longer expanding platforms or adding large feature surfaces. The priority is learning from real users and improving:

1. Activation — users understand the value and start focusing.
2. Retention — users return and build a focus habit.
3. Monetization — users perceive enough value to upgrade.
4. Reliability — users trust Pepinillo every day.

Before implementing large initiatives, ask:

- Does this improve activation?
- Does this improve retention?
- Does this improve monetization?
- Is there evidence users need it?

If the answer is no, prefer documenting the idea instead of expanding scope.

## Platform strategy

### Active platforms

- iOS
- Android
- watchOS
- Wear OS
- Backend services required by production features

### Paused experiments

Windows and Web are **not active roadmap work**.

They were valuable technical explorations and should be preserved, but agents should not continue implementing them unless there is a clear product/business reason approved through the roadmap.

Examples of valid reasons to resume:

- strong user demand;
- validated business opportunity;
- meaningful retention or revenue improvement.

## Agent rules (short)

1. **Docs SoT:** product truth lives in `PRD/`; operational context lives in `docs/`; deployment truth lives in root deployment docs. Never recreate PRD forks under `docs/PRD/`.
2. **Strategy context:** read `docs/strategy/` before proposing large product changes. It contains decisions about direction, validation and lessons learned.
3. **Secrets:** never commit API secrets. Use env/CI only (`REVENUECAT_SECRET_KEY`, etc.).
4. **Cross-platform parity:** fixes/features affecting shared product behavior should be reviewed across relevant platforms (iOS, Android, Wear, watchOS, backend).
5. **PRD maintenance:** after significant product work, update `PRD/09` and related feature documents when the product surface changes.
6. **Commits:** Conventional Commits in **English** (`feat:`, `fix:`, `docs:`, …). Platform scope when useful: `feat(android):`, `fix(ios):`. **No** AI co-author trailers.
7. **Scope discipline:** prefer existing architecture and dependencies. Do not invent unrelated scaffolding or workflows.
8. **User value first:** avoid feature expansion without validating that it improves user experience, retention or revenue.

## Tests (typical)

| Platform | Command (from relevant root) |
| -------- | ---------------------------- |
| Android | `cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest` |
| Backend | `cd backend && go test ./...` |
| Windows Core | `dotnet test windows/Pepinillo.Core.Tests/Pepinillo.Core.Tests.csproj -c Release` (use `DOTNET_ROLL_FORWARD=Major` if host SDK mismatch requires it) |
| iOS | Xcode / `xcodebuild` test schemes for Pepinillo targets (device/simulator as available) |

Prefer project checklists:

- `android/QA_RELEASE_CHECKLIST.md`
- `windows/store/LAUNCH_CHECKLIST.md`
- iOS App Store docs under `ios/docs/`

## Where to look

| Need | Location |
| ---- | -------- |
| Current implementation status | `PRD/09_CURRENT_STATUS.md` |
| Product direction | `docs/strategy/PRODUCT_DIRECTION.md` |
| Growth validation | `docs/strategy/GROWTH_VALIDATION_PLAN.md` |
| Platform decisions | `docs/strategy/PLATFORM_DECISIONS.md` |
| Lessons learned | `docs/strategy/LESSONS_LEARNED.md` |
| Roadmap | `PRD/07_ROADMAP.md` |
| Deploy backend | `DEPLOYMENT.md`, `VPS_SETUP_CHECKLIST.md` |
| Vault dashboard | `docs/00_DASHBOARD.md` |

Do not point agents at obsolete scaffold paths (`.context` generators, `dist/`, Jest).
