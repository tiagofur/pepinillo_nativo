# Proposal: Android Judgment Day Test Coverage Batch (Lote G)

## Intent

Consolidate 7 confirmed test coverage gaps from Judgment Day S1-S8 into a single test-only PR. All issues are MEDIUM priority, approved for implementation. No production code changes — only new or updated test files to close critical-path blind spots across Android (Room, ViewModels, Compose, RevenueCat) and Wear OS modules.

## Scope

### In Scope
- Room migration + sync critical-path tests (MIGRATION_10_11, serverId, mode/phase, dirty session)
- Focus recovery / pause-death / start-stop race / completion-feedback tests
- Task filter matrix, undo window, detail update races, recurrence complete tests
- AuthViewModel login/verify/merge/logout wipe tests
- RevenueCat purchase/restore/offerings/PaywallViewModel tests
- Wear OS peer-disconnect, FGS death, Pro gate, capability reconnect, phase_complete tests
- Compose smoke tests for onboarding gate, touch targets, theme strings

### Out of Scope
- Production code changes (zero tolerance for this change)
- Performance / load testing
- End-to-end UI automation
- iOS or web platform test coverage

## Capabilities

### New Capabilities
- `jd-test-coverage-room-migration`: Room migration and sync critical-path test coverage
- `jd-test-coverage-focus-recovery`: Focus lifecycle recovery, pause, death, and race-condition tests
- `jd-test-coverage-viewmodel-orchestration`: Task/Auth/Paywall ViewModel orchestration test coverage
- `jd-test-coverage-wear-os`: Wear OS peer-disconnect, FGS death, Pro gate, and phase_complete tests
- `jd-test-coverage-compose-smoke`: Compose UI smoke tests for onboarding, touch targets, theme

### Modified Capabilities
None — this change creates new test files only. Existing specs remain unchanged.

## Approach

| Layer | Technique | Module |
|-------|-----------|--------|
| Room | `MigrationTestHelper` + Robolectric for migration, unit for DAO assertions | `:android` |
| Focus | Unit tests with `Dispatchers.setMain`, fake lifecycle observers | `:android` |
| ViewModels | Fake repositories + `Turbine` for Flow collection | `:android` |
| Auth | Mocked AuthStore/IdentityManager, assertion on state transitions | `:android` |
| RevenueCat | Fake CustomerInfo, mock Purchases, verify state mapping | `:android` |
| Wear | `Robolectric` + fake DataClient, assert on MessageClient calls | `:wear` |
| Compose | `createComposeRule` smoke for navigation destination + touch target | `:android` |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `android/src/test/` | New | Unit tests for Room, Focus, ViewModels, Auth, RevenueCat |
| `android/src/androidTest/` | New | Instrumented tests for Room migration |
| `android/src/androidTest/.../compose/` | New | Compose smoke tests |
| `wear/src/test/` | New | Wear OS unit tests |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Room migration tests break on toolchain update | Medium | Pin Room/Kotlin versions; use `MigrationTestHelper` |
| RevenueCat fakes diverge from real SDK behavior | Low | Mirror `Purchases` interface exactly; cross-check with RC docs |
| Flaky Compose smoke tests in CI | Medium | Use `@Test` ordering; skip touch-target assertion in CI env |
| PR exceeds 400-line budget | High | Split into 2 chained PRs: (1) unit tests, (2) instrumented + Compose |

## Rollback Plan

- Revert the single commit(s) deleting all new test files
- No production code to revert
- CI returns to previous coverage baseline automatically

## Dependencies

- `androidTest` runner with Room `MigrationTestHelper` available
- RevenueCat test fakes already in project (verify presence before starting)

## Success Criteria

- [ ] MIGRATION_10_11 runs in CI without error
- [ ] serverId preservation, mode/phase mapping, dirty session skip all asserted
- [ ] Pause + recovery elapsed reconstruction test passes
- [ ] Paused restore state test passes
- [ ] start → stop race condition test passes
- [ ] Silent completion when notifications denied test passes
- [ ] Filter matrix includes far-future due date scenario
- [ ] Undo timing test validates window behavior
- [ ] Concurrent update / complete race test passes
- [ ] Recurrence complete test passes
- [ ] Verified vs unverified login paths tested
- [ ] Verify → merge pipeline tested
- [ ] Logout data isolation tested
- [ ] Double-submit guard tested
- [ ] Purchase success applies Pro from customerInfo
- [ ] Restore awaits RevenueCat restore
- [ ] Offerings empty/error states tested
- [ ] Cancel/fail paths tested
- [ ] Disconnect does not clobber Running status
- [ ] Resume remaining time test passes
- [ ] Pro gate on START test passes
- [ ] phase_complete call site test passes
- [ ] Onboarding start destination tested
- [ ] Touch-target / string locale smoke tested
