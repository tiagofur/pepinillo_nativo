# Final Polish - Eliminating All Remaining Warnings and Build Errors

I will perform a final, meticulous cleanup of the project to resolve the remaining lint warnings, Gradle alerts, and the SDK 37 `jlink` build error.

## User Review Required

> [!IMPORTANT]
> I am reverting the SDK version from **37** back to **36**. SDK 37 is currently causing a `jlink` error in the environment's JDK which prevents the project from compiling Java sources. SDK 36 is fully stable and supports all modern features.

## Proposed Changes

### [Component: Build Configuration]

#### [MODIFY] [build.gradle.kts (:app)](file:///Users/tiagofur/dev/pepinillo_nativo/android/app/build.gradle.kts) & [:wear](file:///Users/tiagofur/dev/pepinillo_nativo/android/wear/build.gradle.kts)
- Downgrade `compileSdk` and `targetSdk` to **36** to resolve the `jlink` transformation error.
- Replace `apply(plugin = ...)` with `pluginManager.apply(...)` to resolve the legacy syntax warning.
- Fix all missing trailing commas in dependency lists and configuration blocks.
- Remove redundant `@Suppress("DEPRECATION")` if the underlying issue is resolved by using the correct API.

### [Component: Code Quality]

#### [MODIFY] [MainActivity.kt](file:///Users/tiagofur/dev/pepinillo_nativo/android/app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt)
- Move trailing lambdas out of parentheses for `FocusScreen` and `TasksAdaptiveLayout`.
- Add clarifying parentheses where requested by the IDE.
- Ensure all imports are clean and necessary.

### [Component: Dependencies]

#### [MODIFY] [libs.versions.toml](file:///Users/tiagofur/dev/pepinillo_nativo/android/gradle/libs.versions.toml)
- Update all libraries to the absolute latest versions reported by the IDE (Kotlin 2.4.10, etc.) to eliminate "version available" alerts.

## Verification Plan

### Automated Tests
- Run `./gradlew clean :app:assembleDebug :wear:assembleDebug` and ensure it passes.
- Run `analyze_file` on all three key files to confirm zero warnings.

### Manual Verification
- Deploy to the Pixel 10 Pro emulator to verify the app is functional and immersive.
