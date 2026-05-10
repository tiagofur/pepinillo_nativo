# Proposal: App Release Review

## Intent
Ensure Android and iOS apps are release-ready by resolving functional parity gaps, fixing deprecated API usage in Android, and establishing a baseline for native UI/UX excellence on both platforms.

## Scope

### In Scope
- Migration of Android `PepinilloApiClient` from deprecated `pomodoro/` endpoints to `focus/` endpoints.
- Alignment of Android Task filters with iOS (`Today`, `Inbox`, `Upcoming`, `Completed`).
- Synchronization of Paywall product card features and descriptions between platforms.
- Implementation of Material 3 polish in Android (Edge-to-edge, spring animations).
- Verification of Soundscape parity (sounds availability and preview logic).

### Out of Scope
- Backend changes (endpoints already exist, just need to be used).
- Full redesign of either app (keeping native look but improving polish).

## Capabilities

### New Capabilities
- `upcoming-tasks`: Requirements for the 7-day upcoming task view and filtering logic.
- `android-native-polish`: UX requirements for Material 3 standard interactions (Haptics, predictive back, edge-to-edge).

### Modified Capabilities
- `task-management`: Update to include Inbox vs Active filter semantics.
- `monetization`: Alignment of feature tiers (Pepinillo+ vs Everywhere/AI+).

## Approach
We will first update the Android networking layer to use the correct endpoints. Then, we will modify the `TasksViewModel` and `TaskRepository` in Android to support the `Inbox` and `Upcoming` filters used in iOS. Finally, we will audit the UI components in Android to apply Material 3 polish (animations, spacing) to match the "feel" of the iOS version.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `android/.../network/` | Modified | Update to use `focus/` endpoints. |
| `android/.../feature/tasks/` | Modified | Add `Inbox` and `Upcoming` logic. |
| `android/.../feature/paywall/` | Modified | Align feature lists. |
| `android/.../ui/` | Modified | Global theme and animation improvements. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Endpoint mismatch | Low | Verified via backend alignment summary. |
| Filter logic bugs | Medium | Use unit tests to verify filter behavior. |
| Performance impact | Low | Compose animations are efficient. |

## Rollback Plan
Revert to previous git commit. All changes are client-side only.

## Dependencies
- Backend `focus/` endpoints must be stable (already verified).

## Success Criteria
- [ ] Android uses `focus/sessions` for all session operations.
- [ ] Android Task screen has Today, Inbox, Upcoming, and Completed filters.
- [ ] Paywall content is consistent across platforms.
- [ ] Android UI passes the "Senior Architect Polish" check.
