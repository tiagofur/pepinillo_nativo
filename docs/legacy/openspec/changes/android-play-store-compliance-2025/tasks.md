# Tasks: Android Compliance 2025

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 150-250 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Foundation
- [ ] 1.1 Update `android/app/build.gradle.kts` with `targetSdk = 35` and update dependencies in `libs.versions.toml`.
- [ ] 1.2 Add `android:supportsPictureInPicture="true"` and `configChanges` to `MainActivity` in `AndroidManifest.xml`.

## Phase 2: Core Implementation (PiP & Insets)
- [ ] 2.1 Implement `onPictureInPictureModeChanged` in `MainActivity.kt` to toggle `isPipMode` state.
- [ ] 2.2 Implement `enterPictureInPictureMode()` trigger in `MainActivity.kt` on `onUserLeaveHint`.
- [ ] 2.3 Refactor `MainActivity.kt` to pass `isPipMode` to `PepinilloApp`.

## Phase 3: UI Modernization
- [ ] 3.1 Update `android/app/src/main/res/values/themes.xml` parent to `Theme.Material3.DayNight.NoActionBar`.
- [ ] 3.2 Adjust `FocusScreen.kt` to hide non-essential elements (navbar, more icon) when `isPipMode` is true.
- [ ] 3.3 Ensure `Scaffold` in `MainActivity.kt` correctly uses `WindowInsets.systemBars` for Edge-to-Edge.

## Phase 4: Verification
- [ ] 4.1 Verify Edge-to-Edge behavior (no overlaps) on Android 15 emulator.
- [ ] 4.2 Verify PiP entry/exit and UI display.
- [ ] 4.3 Run `./gradlew test` to ensure no regressions.
