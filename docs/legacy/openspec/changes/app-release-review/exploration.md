## Exploration: App Release Review

### Current State
The apps are functionally similar but have implementation divergences and parity gaps. iOS is using modern TCA architecture and polished SwiftUI views. Android is using Material 3 with Compose but relies on some deprecated backend endpoints and lacks some filters present in iOS.

### Affected Areas
- `android/.../PepinilloApiClient.kt` — Using deprecated `pomodoro/` endpoints.
- `android/.../TasksViewModel.kt` — Missing `Inbox` and `Upcoming` filters.
- `ios/Features/Plan/PlanFilter.swift` — Mismatch with Android filters.
- `android/.../PaywallScreen.kt` — Content mismatch with iOS Paywall.

### Approaches
1. **Full Parity Fix** — Update Android to use `focus/` endpoints, align filters with iOS (Inbox/Upcoming), and sync Paywall content.
   - Pros: Consistent experience, future-proof API usage.
   - Cons: More work before release.
   - Effort: Medium

2. **UI/UX Polish Only** — Keep logic as is (even deprecated), focus only on making Android "feel" more native and polished.
   - Pros: Faster to release.
   - Cons: Technical debt (deprecated API), confusing for users switching platforms.
   - Effort: Low

### Recommendation
I recommend **Approach 1**. We cannot release an app using deprecated endpoints, and the filter mismatch in "Plan" (Tasks) is a core feature divergence. We should also add some "Wow" polish to Android (animations, edge-to-edge) to match iOS quality.

### Risks
- API changes in Android might introduce regressions in session tracking.
- Adding new filters requires ensuring the `TaskRepository` in Android supports the same logic as iOS.

### Ready for Proposal
Yes.
