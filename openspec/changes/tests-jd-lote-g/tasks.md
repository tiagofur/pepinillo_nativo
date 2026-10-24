# Tasks: Android Judgment Day Test Coverage Batch (Lote G)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 350–400 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | All tests (unit + instrumented) | PR 1 | Test-only, no production code. ~9 files, ~40 lines each |

## Phase 1: Focus Timer Recovery Tests

- [x] 1.1 RED: Add pause-death test to `FocusTimerServiceRecoveryTest.kt` — session with 5:32 remaining survives process death, state restored on relaunch
- [x] 1.2 GREEN: Implement pause-death restore in `FocusTimerServiceRecoveryTest.kt` using `Dispatchers.setMain` + mockk `SharedPreferences`
- [x] 1.3 RED: Add start-stop race test — stop signal during start leaves no orphaned timer
- [x] 1.4 GREEN: Implement start-stop race assertion with concurrent coroutine signals
- [x] 1.5 RED: Add silent completion test to `FocusEngineTest.kt` — timer completes without notification permission, status = COMPLETED, no crash
- [x] 1.6 GREEN: Implement silent completion test with mocked permission denial

## Phase 2: Task Filter & ViewModel Tests

- [x] 2.1 RED: Add far-future due date test to `TaskPlanFilterTest.kt` — task with due date 365 days ahead appears in "Upcoming" filter
- [x] 2.2 GREEN: Implement filter assertion with mock TaskRepository
- [x] 2.3 RED: Add undo window timing test — completion 3s ago reverts on Undo; 10s ago is unavailable
- [x] 2.4 GREEN: Implement undo window test with time-based assertions
- [x] 2.5 RED: Create `TaskDetailViewModelTest.kt` — concurrent update/complete race produces deterministic final state
- [x] 2.6 GREEN: Implement update/complete race test with mockk TaskRepository
- [x] 2.7 RED: Add recurrence complete test — completing daily task creates tomorrow's instance, retains completion timestamp
- [x] 2.8 GREEN: Implement recurrence test with coEvery/coVerify assertions

## Phase 3: Auth & Paywall ViewModel Tests

- [x] 3.1 RED: Add merge pipeline test to `AuthViewModelTest.kt` — verify → merge flows correctly transitions state
- [x] 3.2 GREEN: Implement merge pipeline assertion with mocked AuthStore/IdentityManager
- [x] 3.3 RED: Add logout wipe isolation test — logout clears local data without affecting remote
- [x] 3.4 GREEN: Implement logout wipe test with coVerify on data store clear calls
- [x] 3.5 RED: Add purchase success test to `PaywallViewModelTest.kt` — purchase applies Pro from CustomerInfo
- [x] 3.6 GREEN: Implement purchase success assertion with mocked SubscriptionManager
- [x] 3.7 RED: Add restore test — restore awaits RevenueCat restore callback
- [x] 3.8 GREEN: Implement restore test with Turbine flow collection
- [x] 3.9 RED: Add offerings empty/error tests — empty list shows fallback, error shows retry
- [x] 3.10 GREEN: Implement offerings state tests with mockk

## Phase 4: Room Migration Tests (Instrumented)

- [x] 4.1 RED: Add MIGRATION_10_11 forward test to `MigrationTest.kt` — schema N+1 matches, no data loss
- [x] 4.2 GREEN: Implement migration test with MigrationTestHelper + schema assets
- [x] 4.3 RED: Add serverId preservation test — tasks retain serverId after migration
- [x] 4.4 GREEN: Implement serverId assertion post-migration
- [x] 4.5 RED: Add mode/phase mapping test — TIMER mode resolves correctly, phase states preserved
- [x] 4.6 GREEN: Implement mode/phase assertion with enum mapping
- [x] 4.7 RED: Add dirty session skip test — orphaned active session marked idle, no crash
- [x] 4.8 GREEN: Implement dirty session assertion with MigrationTestHelper

## Phase 5: Wear OS & Compose Smoke Tests

- [x] 5.1 RED: Add disconnect test to `WearFocusServiceTest.kt` — disconnect during active focus leaves status RUNNING
- [x] 5.2 GREEN: Implement disconnect assertion with mockk MessageClient
- [x] 5.3 RED: Add resume remaining time test — reconnect shows 7 min remaining on 10-min session
- [x] 5.4 GREEN: Implement resume time assertion with mockk DataClient
- [x] 5.5 RED: Add Pro gate test — free user start rejected, Pro user start succeeds
- [x] 5.6 GREEN: Implement Pro gate test with mockk SubscriptionManager
- [x] 5.7 RED: Add phase_complete call site test — phase transition triggers call with completed phase ID
- [x] 5.8 GREEN: Implement phase_complete assertion with coVerify
- [x] 5.9 RED: Create `OnboardingSmokeTest.kt` — fresh install routes to onboarding, completed routes to task list
- [x] 5.10 GREEN: Implement navigation destination assertion with createComposeRule
- [x] 5.11 RED: Add touch-target size assertion — primary button meets 48dp × 48dp minimum
- [x] 5.12 GREEN: Implement touch-target assertion with Compose measurement

## Phase 6: Verification

- [x] 6.1 Run `./gradlew :app:testDebugUnitTest` — all unit tests pass
- [x] 6.2 Run `./gradlew :wear:testDebugUnitTest` — Wear OS unit tests pass
- [x] 6.3 Run instrumented tests on emulator — Room migration + Compose smoke pass
- [x] 6.4 Verify no production code changes — `git diff` shows only test files
- [x] 6.5 Confirm all 22 success criteria from proposal are met
