# Design: App Release Review

## Technical Approach
The implementation focuses on aligning the Android application's logic and aesthetics with the polished iOS version. We will migrate to the correct backend endpoints, implement missing filtering logic in the domain layer, and apply Material 3 polish to the UI layer.

## Architecture Decisions

### Decision: Backend API Alignment
**Choice**: Standardize on `/api/v1/focus/` endpoints for both platforms.
**Alternatives considered**: Maintaining deprecated `/api/v1/pomodoro/` for Android.
**Rationale**: Parity and long-term maintainability. Using deprecated endpoints is a risk for production release.

### Decision: Filter Implementation
**Choice**: Calculate `Upcoming` and `Inbox` filters in the `TaskRepository` (SQL/Room) and `ViewModel`.
**Alternatives considered**: Server-side filtering.
**Rationale**: Ensures offline functionality and responsiveness. Follows the existing pattern of local-first task management in Android.

## Data Flow
```
UI (Compose) ──→ ViewModel (Hilt) ──→ Repository ──→ Room DB / API Client
      ↑              │                  │
      └──────────────┴──────────────────┘
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `android/.../network/PepinilloApiClient.kt` | Modify | Change `pomodoro/` to `focus/`. |
| `android/.../feature/tasks/TasksViewModel.kt` | Modify | Update `TaskFilter` enum and filtering logic. |
| `android/.../data/repository/TaskRepository.kt` | Modify | Add query logic for `Upcoming` (next 7 days). |
| `android/.../feature/paywall/PaywallScreen.kt` | Modify | Sync tier features and descriptions with iOS. |
| `android/.../ui/theme/Theme.kt` | Modify | Enable Edge-to-Edge and standard Material 3 color tokens. |

## Interfaces / Contracts
```kotlin
// Updated TaskFilter in TasksViewModel.kt
enum class TaskFilter {
    Today, Inbox, Upcoming, Completed
}
```

## Testing Strategy
| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Filter logic | JUnit tests for `TasksViewModel` filtering logic. |
| Integration | API migration | MockWebServer tests for `PepinilloApiClient`. |
| E2E | Flow parity | Manual verification of Plan screen parity. |

## Migration / Rollout
No data migration required. API change is a direct replacement.

## Open Questions
- None.
