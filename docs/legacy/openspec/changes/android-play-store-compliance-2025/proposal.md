# Proposal: Android Compliance 2025

## Intent
Update the native Android rewrite to meet Google Play 2025 requirements and establish a modern foundation for Android 15+.

## Scope

### In Scope
- Update `targetSdk` to 35 (Stable).
- Implement Picture-in-Picture (PiP) for the Focus Timer.
- Modernize `Theme.Pepinillo` to support Android 15 Edge-to-Edge enforcement.
- Audit and update core dependencies (Compose, Hilt, Room).
- Add PiP entry/exit logic and UI adjustments.

### Out of Scope
- Adding reCAPTCHA (not found in current native code; will ignore unless user requests).
- UI redesign of screens beyond Edge-to-Edge fixes.

## Capabilities

### New Capabilities
- `picture-in-picture`: Allow users to track their focus timer while using other apps.

### Modified Capabilities
- `edge-to-edge-display`: Ensure the app correctly handles system bars and cutouts on Android 15.

## Approach
Implement PiP using `enterPictureInPictureMode()` in `MainActivity`. Update `Scaffold` and `PepinilloTheme` to handle window insets following the latest Android 15 guidelines. Update `libs.versions.toml` to stable 2025 versions.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `android/app/build.gradle.kts` | Modified | Update SDK versions and dependencies. |
| `android/app/src/main/AndroidManifest.xml` | Modified | Register PiP support. |
| `android/app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt` | Modified | PiP and Insets handling. |
| `android/app/src/main/res/values/themes.xml` | Modified | Modernize theme parent. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| PiP Glitches | Med | Test with `onPictureInPictureModeChanged`. |
| SDK 35 Breaks | Low | Regression test core features (Sync, Auth). |

## Rollback Plan
Revert Gradle changes and manifest edits. The code changes are additive and can be toggled or reverted via Git.

## Dependencies
- Android Studio Ladybug+ (for API 35 testing).

## Success Criteria
- [ ] App targets API 35.
- [ ] Timer continues in PiP when app is backgrounded during Focus.
- [ ] Content is not obscured by system bars or notches on Android 15.
