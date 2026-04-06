# Pepinillo Project Instructions

## Scope

These instructions apply to the entire repository.

## Communication

- Default language: English for responses, documentation updates, and collaboration artifacts unless the user explicitly asks for another language.
- Be direct, practical, and explain technical reasoning when proposing changes.

## Engineering Priorities

- Preserve cross-platform parity across Android, Wear OS, iOS, and watchOS.
- For any feature or bug fix on one platform, verify equivalent functional behavior on the other platforms.
- Enforce functional parity as a strict rule; platform-specific UI can follow native Apple/Google patterns but must remain behaviorally aligned.
- Prefer native-first UX conventions so each app feels OS-integrated instead of a generic cross-platform UI.
- Prefer architecture clarity over quick patches.

## Change Management

- Keep diffs minimal and avoid unrelated refactors.
- Do not revert unrelated user changes.
- Do not add AI attribution lines in commits.

## Validation

- Build validation is allowed and encouraged when it helps detect integration issues early.
- Run focused checks first (lint, targeted tests, static checks), then run builds for touched platforms before handoff when practical.
- For expensive full-repo validation, confirm first unless the user explicitly requested comprehensive validation.

## Platform Validation Matrix

- Always validate only what was touched first, then expand if integration risk is high.
- If a change touches multiple platforms, run the matching checks for each touched platform.

| Touched area        | Focused checks first                                                                                   | Build check before handoff                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `backend/`          | `cd backend && go test ./...` (or package-scoped tests when possible)                                  | `cd backend && go test ./...`                                                                           |
| `android/app`       | `cd android && .\\gradlew :app:testDebugUnitTest --console=plain`                                      | `cd android && .\\gradlew :app:assembleDebug --console=plain`                                           |
| `android/wear`      | `cd android && .\\gradlew :wear:testDebugUnitTest --console=plain`                                     | `cd android && .\\gradlew :wear:assembleDebug --console=plain`                                          |
| Android + Wear sync | `powershell -ExecutionPolicy Bypass -File scripts/validate_wear_sync.ps1`                              | `cd android && .\\gradlew :wear:assembleDebug :app:assembleDebug --console=plain`                       |
| `ios/` iOS app      | `cd ios && xcodebuild -scheme Pepinillo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` | `cd ios && xcodebuild -scheme Pepinillo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` |
| `ios/` watch app    | `cd ios && xcodebuild -scheme PepinilloWatch -destination 'generic/platform=watchOS Simulator' build`  | `cd ios && xcodebuild -scheme PepinilloWatch -destination 'generic/platform=watchOS Simulator' build`   |

- If simulator/device-specific commands fail because of environment constraints, run the closest equivalent command and report the limitation clearly.

## Product Documentation Sync

- Update PRD/ for new features and meaningful changes to existing features.
- Do not update PRD/ for minor bug-fix-only changes unless they alter architecture, functionality scope, or product design direction.
- Keep feature parity tables and current-status notes aligned with implemented functionality and structural decisions.

## Git Workflow

- Create automatic commits at logical checkpoints, grouping related changes by intent and impact.
- Use commit granularity at agent discretion, prioritizing recoverability and traceability over arbitrary micro-commits.
- After local commit checkpoints, ensure changes are pushed so GitHub reflects progress and rollback points are preserved.
- Never add AI attribution lines in commits.

## Pull Request Checklist

- Every pull request must include explicit parity impact: Android, Wear OS, iOS, watchOS.
- If a platform is marked as not impacted, include a short justification.
- Every pull request must include validation evidence for touched areas using the Platform Validation Matrix.
- Every pull request must include PRD impact classification: `No PRD update required` or `PRD update required`.
- If PRD update is required, list the exact PRD files changed.
- Every pull request must include a short risk assessment and rollback note.

Use this minimum PR structure:

```md
## Summary

## Platform Parity

- Android:
- Wear OS:
- iOS:
- watchOS:

## Validation Evidence

- Command:
- Result:

## PRD Impact

- Classification: No PRD update required | PRD update required
- Files:

## Risk and Rollback

- Risk:
- Rollback:
```

## Review Mode

- If the user asks for a review, report findings first (severity-ordered), then risks/gaps, then summary.

## Mobile Conventions

- iOS/watchOS: follow TCA patterns and strict concurrency expectations documented in ios/CLAUDE.md.
- Android/Wear: keep shared behavior and sync flows consistent between phone and watch modules.
