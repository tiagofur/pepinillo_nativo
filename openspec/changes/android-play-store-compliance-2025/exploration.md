## Exploration: Android Compliance 2025

### Current State
The native Android app targets API 36 and uses modern APIs like `enableEdgeToEdge()`. However, Google Play reports issues likely stemming from the transition of the Flutter version to Native, and potential deprecations in the theme configuration for Android 15. Picture-in-Picture is currently unimplemented.

### Affected Areas
- `android/app/build.gradle.kts` — SDK versions and dependency updates.
- `android/app/src/main/AndroidManifest.xml` — PiP registration.
- `android/app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt` — PiP lifecycle and Edge-to-Edge refinements.
- `android/app/src/main/res/values/themes.xml` — Theme parent update for M3/Android 15 compliance.
- `android/app/src/main/java/dev/creapolis/pepinillo/feature/focus/FocusScreen.kt` — PiP UI mode.

### Approaches
1. **Minimum Compliance** — Update targetSdk to 35, fix Theme parent, and add PiP support to Manifest.
   - Pros: Fast, meets Google requirements.
   - Cons: Misses opportunities for UX improvement.
   - Effort: Low

2. **Full Premium Update** — Update to SDK 35 (stable), refactor Theme for M3/Android 15, implement PiP for Focus Timer with custom UI, and audit all dependencies.
   - Pros: Premium feel, future-proof, addresses user request for "without bugs".
   - Cons: More complex implementation.
   - Effort: Medium

### Recommendation
Approach 2 is recommended. Since we are moving from a Flutter version to a Native rewrite, we should ensure the native foundations are state-of-the-art.

### Risks
- PiP lifecycle: entering/exiting PiP must be smooth to avoid UI glitches.
- SDK 36: While 36 is in the code, 35 is the stable requirement. We should verify if 36 has any breaking changes for current dependencies.

### Ready for Proposal
Yes
