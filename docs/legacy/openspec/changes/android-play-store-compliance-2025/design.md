# Design: Android Compliance 2025

## Technical Approach
Implement compliance requirements using the latest AndroidX libraries. The Focus Timer will enter PiP mode automatically when the user leaves the app during an active session. Edge-to-edge support will be modernized by updating the theme parent and ensuring all composables respect window insets.

## Architecture Decisions

### Decision: PiP UI Handling
**Choice**: Use a boolean flag in `MainActivity` to toggle between full and PiP UI modes in Compose.
**Alternatives considered**: Multiple Activities (one for PiP).
**Rationale**: Simpler state management with a single Activity rewrite.

### Decision: SDK Targeting
**Choice**: Target SDK 35.
**Alternatives considered**: SDK 36.
**Rationale**: SDK 35 is the stable requirement for 2025. 36 is early/preview.

## Data Flow
`MainActivity` observes PiP mode changes via `onPictureInPictureModeChanged` and passes the state to the root composable.

    MainActivity ──→ onPictureInPictureModeChanged ──→ PepinilloApp (Compose)
         │                                               │
         └─────────────────── UI Mode State ──────────────┘

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `android/app/build.gradle.kts` | Modify | Update `targetSdk` to 35 and core deps. |
| `android/app/src/main/AndroidManifest.xml` | Modify | Add PiP support to `MainActivity`. |
| `android/app/src/main/java/dev/creapolis/pepinillo/MainActivity.kt` | Modify | Implement PiP callbacks and Insets. |
| `android/app/src/main/res/values/themes.xml` | Modify | Update theme parent to M3. |

## Interfaces / Contracts
New PiP state in `MainActivity`:
```kotlin
private var isPipMode by mutableStateOf(false)
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Inset handling logic | Local unit tests. |
| Integration | PiP entry/exit | Manual verification on Emulator. |
| Quality | Compliance check | Android Studio 'Layout Inspector'. |

## Migration / Rollout
No migration required. This is a platform update.

## Open Questions
- None.
