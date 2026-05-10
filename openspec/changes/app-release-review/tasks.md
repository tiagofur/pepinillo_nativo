# Tasks: App Release Review

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250-350 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Medium

## Phase 1: Infrastructure (Android API Migration)

- [ ] 1.1 Update `android/.../network/PepinilloApiClient.kt`: Change `pomodoro/` endpoints to `focus/`.
- [ ] 1.2 Update `android/.../network/ApiModels.kt`: Ensure DTO parity with iOS `FocusSessionSyncDTO`.
- [ ] 1.3 Verify `NetworkModule.kt` logging for the new endpoints.

## Phase 2: Domain & Repository (Task Filters)

- [ ] 2.1 Modify `android/.../data/repository/TaskRepository.kt`: Implement `getUpcomingTasks()` query (next 7 days).
- [ ] 2.2 Update `android/.../feature/tasks/TasksViewModel.kt`: Align `TaskFilter` enum (`Today`, `Inbox`, `Upcoming`, `Completed`).
- [ ] 2.3 Update `TasksUiState.filteredTasks` logic to support `Inbox` (no date/no today) and `Upcoming` filters.

## Phase 3: UI & Polish (Android Screens)

- [ ] 3.1 Update `android/.../feature/tasks/TasksScreen.kt`: Add filter pills/tabs for Inbox and Upcoming.
- [ ] 3.2 Update `android/.../feature/paywall/PaywallScreen.kt`: Sync feature descriptions and tiers with iOS `PaywallView.swift`.
- [ ] 3.3 Apply Edge-to-Edge: Update `Theme.kt` and add `systemBarsPadding()` to main screen layouts.
- [ ] 3.4 Add Haptics: Inject `Vibrator` or use `HapticFeedback` in `TasksViewModel` for completion.

## Phase 4: Verification

- [ ] 4.1 Test: Verify `Upcoming` filter shows tasks due in 1-7 days but NOT today.
- [ ] 4.2 Test: Verify `Inbox` filter shows tasks with no date and no today flag.
- [ ] 4.3 Verify: Run `./gradlew test` to ensure no regressions in Task logic.
