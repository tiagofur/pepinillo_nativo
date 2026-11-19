# 669 — iOS Share Extension: Add Task to Pepinillo from any app
Objective: The iOS analog of the Mac Quick Capture surface — share text or a URL from any app into a Pepinillo task, created through the existing composer pipeline on next app activation.
Branch: `feat/ios-share-extension-669` (worktree, off origin/main `009522f5`) | Delivery: `complete` | Test runners: `xcodebuild test -scheme "Pepinillo Dev"`, `xcodebuild build -scheme "PepinilloMac Dev"` (stable Xcode 27.2; Mac Dev scheme needs Xcode-beta per the Live-Activities setup)

## Specs

- **S1**: New `PepinilloShareExtension` target (iOS 17, bundle `com.pepinillo.app.share`, app group `group.com.pepinillo.app`) in project.yml, embedded in all 3 schemes. Activation rule: 1 text and/or 1 URL. Light extension: one Swift file writing `UserDefaults(suiteName:)` directly — no model stack compiled into the extension.
- **S2**: Quick-Capture-style UI: editable title prefilled with the shared text (or the URL string), Save/Cancel; Save persists to the app group and completes `extensionContext`; localized EN/ES/PT via the shared `Localizable.xcstrings`. (The share sheet shows the app icon automatically — no custom asset.)
- **S3**: App-side drain with the S7 pattern: `AppGroupDefaults.takeExternalCapturedTaskTitle()` consumed in `.consumeExternalCommands` — tasks loaded: the Mac precedent triple-send (`tabSelected(.plan)` + `newTaskTitleChanged(title)` + `addTaskTapped`, same as `MacQuickCaptureController.submit`); cold start: stashed in `pendingCapturedTaskTitle` and consumed in `.tasks(.tasksLoaded)` (the `pendingDeepLinkTaskID` pattern). The existing pipeline applies the free cap (#216) → paywall preserving the title, quick-add defaults, list insertion.
- **S4**: RED→GREEN tests for both drain paths (loaded → sends creation; cold → stashed → `tasksLoaded` creates).
- **S5**: `Pepinillo Dev` builds with the `.appex` embedded in PlugIns; `PepinilloMac Dev` still green; "Cómo probar" in the PR.

## Assumptions

- A1: The extension stays model-free — it writes the raw suite keys; only the app-side `AppGroupDefaults` gains typed accessors (`takeExternalCapturedTaskTitle` mirroring `takeExternalCompleteTask`).
- A2: The drain switches to the Plan tab like the Mac Quick Capture (the Mac precedent is the explicit analog); one-time per share.
- A3: No TTL on the queued title (S7 semantics: capture is not time-sensitive; `clearExternalCommands` doesn't know the keys so early exits leave it queued).
- A4: URL-only shares prefill the title with the URL string; text wins when both are present.

## Allowed edit surfaces

- `ios/project.yml`
- `ios/ShareExtension/**` (new)
- `ios/Shared/Persistence/AppGroupContainer.swift` (only the captured-task accessors)
- `ios/App/AppFeature.swift` (drain + stash + tab switch)
- `ios/Features/Tasks/TaskListFeature.swift` (parked-title state, `capturedTaskReady`, `tasksLoaded` adoption — required by S3/T1; amended after round-one review flagged the omission)
- `ios/Tests/**`
- `odd/tasks/669-ios-share-extension.md`

## Tasks

- [x] **T1** (`S3`, risk: `V1`): `takeExternalCapturedTaskTitle` accessor + drain/stash in AppFeature + `tasksLoaded` consume — tests first.
- [x] **T2** (`S1`/`S2`, risk: `V0`): ShareExtension target in project.yml + `ShareViewController.swift` + entitlements + Info properties.
- [x] **T3** (`S5`, risk: `V1`): builds both schemes, `.appex` embedded, "Cómo probar".

## Log

- **L1 (2026-11-19)**: DoR shaping — issue rewritten into the house template before implementation (S1–S5 above verified against the real machinery: `addTaskTapped` cap/paywall path, S7 take…() drain, `pendingDeepLinkTaskID` cold-start precedent).
- **L2 (2026-11-19)**: Implementation. A design change from the issue text: the parked title lives on TaskListFeature state (not AppFeature) and `capturedTaskReady` is a child action — the AppFeature drain stashes + sends, and `tasksLoaded` adopts it inside the child. This deliberately avoids the `.disabled()` deep-link test's TCA 1.26 merge path (AppFeatureIntegrationTests:75) by keeping the creation self-send inside the same feature. Tests: 4 new (3 TaskListFeature + 1 AppFeature integration); TCA effect-sends require `store.receive` before state assertions (found live).
- **L3 (2026-11-19)**: Verification — captured-task tests 4/4 green; full TaskListFeatureTests + AppFeatureIntegrationTests regression: only the 2 pre-existing `KeychainClient.hasTokens` failures (documented debt on main); `PepinilloShareExtension.appex` embedded in PlugIns; `PepinilloMac Dev` BUILD SUCCEEDED (Xcode-beta). The extension compiles with `CFNotificationCenterGetDarwinNotifyCenter()` (not `…DarwinNotificationCenter` — API name gotcha) and needs an explicit CoreFoundation import under Swift 6.
- **L4 (2026-11-19)**: Judgment-day round 1 (dual blind judges). Findings acted on: (1) surfaces omission — TaskListFeature.swift was required by S3 but missing from this artifact's surface list; issue + artifact amended (the CRITICAL was a doc inconsistency, not a code defect). (2) Consensus — the Darwin-signal comment claimed an iOS drain-immediately behavior that does not exist (no iOS observer of com.pepinillo.app.externalCommand; drain fires on bootstrap/appBecameActive only): comment corrected. (3) Consensus — an unrelated pre-existing assertion (#expect(!reopened.isCompleted)) was silently dropped during a transcription edit: restored. (4) Judge A — captured titles lacked the Mac precedent's prefix(200) truncation: truncateCapturedTitle applied at both adoption sites + truncation test. (5) Suggestions acted on: NSAttributedString coercion for rich-text providers, single-mount share UI (BindingHolder — no flash/lost keystrokes), cap→paywall-keeps-title test. Recorded without fix (proportionate): monolith growth (+46/+21 lines in TaskListFeature/AppFeature without a mechanical seam-extraction commit — same budget note as the #848 L3 precedent, the logic cannot live outside its features); single-slot capture overwrite (S7 single-key contract); silent success if the suite is nil (house style).
