# Design: Android Judgment Day Test Coverage Batch (Lote G)

## Technical Approach

Test-only change: add new test files to close 7 coverage gaps across Room, Focus, ViewModels, Auth, RevenueCat, Wear OS, and Compose layers. No production code changes. All tests follow existing project conventions (JUnit4, MockK, Turbine, `Dispatchers.setMain`).

## Architecture Decisions

### Decision: Test Framework Stack

**Choice**: JUnit4 + MockK + Turbine + coroutines-test (existing stack)
**Alternatives considered**: JUnit5, Mockito
**Rationale**: Project already uses JUnit4/MockK/Turbine consistently across 45+ test files. Introducing JUnit5 or Mockito would create a mixed stack. Turbine is already a dependency for Flow testing.

### Decision: Room Migration Test Location

**Choice**: Extend existing `androidTest/.../MigrationTest.kt` for MIGRATION_10_11
**Alternatives considered**: New separate test class
**Rationale**: MigrationTest already has the `MigrationTestHelper` rule, schema asset paths, and correct package. Adding 10→11 tests here keeps migration coverage centralized. Follows the existing pattern (8→9, 9→10 tests in same class).

### Decision: RevenueCat Mocking Strategy

**Choice**: Mock `SubscriptionManager` at the boundary, not RevenueCat SDK internals
**Alternatives considered**: Mock `Purchases` SDK directly, use RevenueCat test fakes
**Rationale**: `PaywallViewModel` takes `SubscriptionManager` as constructor param. MockK mocks it cleanly. The existing `PaywallViewModelTest` already proves this pattern works. No RevenueCat SDK mock dependency needed.

### Decision: Wear OS Test Approach

**Choice**: JVM unit tests with MockK (same as existing `WearFocusServiceTest`)
**Alternatives considered**: Robolectric, instrumented tests
**Rationale**: Wear module already has 12 unit test files using plain JUnit4 + MockK. No Robolectric dependency exists. Adding it for 4-5 tests isn't justified. Focus on testing pure logic (data mapping, state transitions) not Android framework.

### Decision: Compose Smoke Test Approach

**Choice**: Instrumented `createComposeRule` tests under `androidTest`
**Alternatives considered**: Robolectric Compose tests
**Rationale**: `androidTestImplementation(libs.androidx.compose.ui.test.junit4)` is already a dependency. Compose smoke tests need real Android context for navigation graph and touch target measurement. Robolectric isn't configured for Compose.

### Decision: PR Split Strategy

**Choice**: Single PR under 400 lines (test-only, no production code)
**Alternatives considered**: Chained PRs
**Rationale**: Test files are additive and independent. No cross-file dependencies. Review budget is achievable with focused test files (~30-60 lines each, 7-8 files).

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `android/app/src/androidTest/.../MigrationTest.kt` | Modify | Add MIGRATION_10_11 tests, serverId preservation, dirty session |
| `android/app/src/test/.../service/FocusTimerServiceRecoveryTest.kt` | Modify | Add pause-death restore, start-stop race tests |
| `android/app/src/test/.../domain/timer/FocusEngineTest.kt` | Modify | Add silent completion (no notification permission) |
| `android/app/src/test/.../feature/tasks/TaskPlanFilterTest.kt` | Modify | Add far-future due date, undo window timing |
| `android/app/src/test/.../feature/tasks/TaskDetailViewModelTest.kt` | Create | Update/complete race, recurrence complete |
| `android/app/src/test/.../feature/auth/AuthViewModelTest.kt` | Modify | Add merge pipeline, logout wipe isolation |
| `android/app/src/test/.../feature/paywall/PaywallViewModelTest.kt` | Modify | Add purchase success, restore, offerings empty/error |
| `android/wear/src/test/.../service/WearFocusServiceTest.kt` | Modify | Add disconnect, Pro gate, phase_complete |
| `android/app/src/androidTest/.../compose/OnboardingSmokeTest.kt` | Create | Navigation destination, touch target, string locale |

## Dependencies and Mocking Strategy

| Dependency | Mocking | Notes |
|------------|---------|-------|
| `SessionRepository` | MockK `mockk(relaxed = true)` | Existing pattern in FocusEngineTest |
| `TaskRepository` | MockK `mockk(relaxed = true)` | Existing pattern |
| `UserPreferencesRepository` | MockK + `MutableStateFlow<UserPreferences>` | Existing pattern |
| `SubscriptionManager` | MockK `mockk(relaxed = true)` | Existing pattern in PaywallViewModelTest |
| `AuthStore` | MockK `mockk(relaxed = true)` | Existing pattern in AuthViewModelTest |
| `PepinilloApiClient` | MockK `mockk(relaxed = true)` | Existing pattern |
| `SessionManager` | MockK `mockk(relaxed = true)` | Existing pattern |
| `IdentityManager` | MockK `mockk(relaxed = true)` | Existing pattern |
| `FeedbackManager` | MockK `mockk(relaxed = true)` | Existing pattern |
| `SharedPreferences` | FakeSharedPreferences inner class | Existing pattern in FocusTimerServiceRecoveryTest |
| Room `MigrationTestHelper` | Already configured | Schema assets in `app/schemas/` |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Room Migration | MIGRATION_10_11 forward/downgrade, serverId preservation, dirty session | `MigrationTestHelper` + `androidTest`, extend existing class |
| Focus Lifecycle | Pause-death restore, start-stop race, silent completion | Unit tests with `TestScope`, mockk, existing FocusEngineTest pattern |
| Task Filters | Far-future due date, undo window timing | Extend TaskPlanFilterTest, unit assertions |
| Task Detail | Update/complete race, recurrence complete | New TaskDetailViewModelTest with MockK |
| Auth | Merge pipeline, logout wipe isolation | Extend AuthViewModelTest, mockk `coEvery`/`coVerify` |
| Paywall | Purchase success/restore/offerings/cancel | Extend PaywallViewModelTest, MockK `SubscriptionManager` |
| Wear OS | Disconnect, Pro gate, phase_complete, FGS death | Extend WearFocusServiceTest, pure unit tests |
| Compose | Onboarding navigation, touch target, string locale | `createComposeRule` instrumented tests |

## CI Integration

- **Unit tests** (`androidTest` excluded): Run on every PR via `./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest`
- **Instrumented tests** (`androidTest`): Run on device/emulator in CI pipeline. Room migration tests require device.
- **Compose smoke tests**: Part of instrumented tests, require `createComposeRule`
- **No new CI configuration needed** — existing pipeline already runs both unit and instrumented tests

## Migration / Rollout

No migration required. Test-only change. CI returns to previous coverage baseline automatically on revert.

## Open Questions

- [ ] Should `TaskDetailViewModelTest` be a new file or extend existing `TaskDetailDatePickerTest`? (Recommend new file for clarity)
- [ ] Far-future due date test: use 365 days or configurable threshold? (Recommend 365 days per spec)
- [ ] Touch-target assertion: skip in CI env due to Compose measurement flakiness? (Recommend skip with `@LargeTest` annotation)
