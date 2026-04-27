# Collaboration Guide with Claude Code: Pepinillo Native (All Platforms)

**Unified guide to get the most out of Claude Code in native iOS and Android development.**

---

## 1. What Claude Code Does Well

### iOS

- **Complete TCA boilerplate** (State, Action, Reducer, View, Client) -- generates the scaffolding for any feature in minutes.
- **Focus Mode Strategy generation** -- the Strategy pattern for focus modes is formulaic; Claude Code creates new strategies quickly.
- **SwiftData models** -- models with relationships, migrations, and CloudKit compatibility.
- **SwiftUI views from descriptions** -- describe what you want visually and Claude Code builds it.
- **Widget and Live Activity templates** -- WidgetKit and ActivityKit have specific patterns that Claude Code knows.
- **TCA test generation** -- TCA makes tests formulaic (TestStore), which is perfect for automated generation.
- **Localization (EN/ES/PT)** -- string extraction and translation creation in `.xcstrings` format.
- **App Intents / Shortcuts** -- declarative and pattern-based, Claude Code generates them quickly.

### Android

- **Compose UI from descriptions** -- screens and components generated from textual descriptions.
- **ViewModel + StateFlow boilerplate** -- complete scaffolding for presenters/viewmodels with status flows.
- **Room Entity + DAO generation** -- entities, DAOs, relationships, and type converters.
- **Hilt modules** -- dependency injection with automatic module generation.
- **Glance widget templates** -- Home Screen widgets built with Glance Compose.
- **Wear OS screen templates** -- scaffolding for the watch app.
- **Test generation (JUnit 5)** -- unit and integration tests.
- **Localization (strings.xml)** -- generation and translation of XML string files.

### All Platforms

- **Strategy pattern implementation** — for focus modes (Pomodoro, Flowtime, Time Block, Stopwatch).
- **Data model design** — translating entities across platforms while preserving parity.
- **Business logic services** — shared rules that must remain identical across platforms.
- **Accessibility improvements** — semantic labels, VoiceOver/TalkBack, Dynamic Type/Font Scaling.
- **Code review and refactoring** — cross-review to keep consistency across platforms.

---

## 2. What Requires Human Intervention

| Area                              | Reason                                                                                           | Applies to |
| --------------------------------- | ------------------------------------------------------------------------------------------------ | ---------- |
| Visual design decisions           | Claude Code can build any described layout, but it does not make subjective aesthetic decisions  | Both       |
| CloudKit sync debugging           | Silent failures, sync delays, merge conflicts -- requires real devices with real iCloud accounts | iOS        |
| Real device testing               | Simulators do not reflect real behavior (haptics, battery, connectivity, complications)          | Both       |
| OEM-specific issues               | Inconsistent behavior across Android manufacturers (Samsung, Xiaomi, etc.)                       | Android    |
| App Store / Play Store submission | Screenshots, metadata, and compliance with review guidelines                                     | Both       |
| Performance profiling             | Instruments (iOS) and Android Profiler require interactive tooling                               | Both       |
| Certificate/signing configuration | Signing, provisioning profiles, keystores                                                        | Both       |
| Health/HealthConnect permissions  | Approval requires specific justification for Apple/Google                                        | Both       |

---

## 3. Recommended Workflow

### Morning (Planning)

1. Open the PRD and verify the current phase/task.
2. Tell Claude Code what will be built today.
3. Claude Code generates the scaffolding (TCA feature + views + tests on iOS, or Presenter + Compose + tests on Android).

### Build (Implementation)

4. Review the generated code and adjust as needed.
5. Ask for specific implementations: "Add haptic feedback when the timer completes" or "Make the widget update every minute during active sessions."
6. Run tests -- if they fail, paste the error so Claude Code can fix it.

### Afternoon (Review)

7. Ask Claude Code for a review of the day's code: "Review all files changed today looking for bugs, memory leaks, and best practices."
8. Update tests for any new behavior.
9. Commit with a descriptive message.

---

## 4. Session Start Prompts

### New Feature

> "I am building [Feature Name] for Pepinillo native. Read the PRD at PRD/01_PRODUCT_VISION.md for context. I want to implement [specific requirement]. Start by creating [the TCA feature and SwiftUI view / the Presenter and Compose screen]."

### Bug Fix

> "There is a bug in Pepinillo native: [describe bug]. The relevant files are [list files]. Debug this and propose a fix. Consider edge cases around [background timer / sync / watch connectivity]."

### Refactor Session

> "Review the current implementation of [feature]. Suggest improvements for code quality, testability, performance, and alignment with best practices for [TCA / Circuit+Compose]. Then implement the changes."

### Test Session

> "Write complete tests for [Feature]. Cover: happy path, edge cases, error states, and integration with [dependent feature]. Use [TCA TestStore / JUnit 5 + Turbine]."

### Localization Session

> "Extract all new strings from the following files: [list]. Add translations in Spanish (LATAM) and Brazilian Portuguese. Use informal second-person style for Spanish and 'voce' for Portuguese. Keep the tone of existing localizations."

### Cross-Platform Parity Verification

> "I just implemented [feature/fix] on [iOS/Android]. Verify that the equivalent exists on [the other platform]. If it does not exist or has differences, implement parity."

---

## 5. SDD Integration (Spec-Driven Development)

The SDD workflow makes it possible to plan and execute substantial features in a structured way:

1. **`/sdd-new feature-name`** -- Claude Code creates a focused proposal.
2. **`/sdd-ff feature-name`** -- Fast-forward through specs, design, and task breakdown.
3. **`/sdd-apply feature-name`** -- Claude Code implements tasks in batches.
4. **`/sdd-verify feature-name`** -- Automated verification against the spec.

### When to Use SDD

- Substantial new features (e.g., Flowtime mode, Weekly Review, Wear OS app).
- Refactors that touch multiple files or layers.
- Any change that requires coordination between iOS and Android.

### When NOT to Use SDD

- Simple bug fixes.
- Cosmetic or localization changes.
- Configuration adjustments.

---

## 6. Cross-Platform Parity Rule (MANDATORY)

This is a multi-platform project: **Android (phone)**, **Wear OS (watch)**, **iOS (phone)**, and **watchOS (Apple Watch)**.

Every time a bug is fixed or a feature is implemented on ANY platform, the equivalent MUST be verified and applied on ALL other platforms before considering the task complete.

| Changed platform  | Also review and fix               |
| ----------------- | --------------------------------- |
| Android phone     | iOS phone, Wear OS, watchOS       |
| iOS phone         | Android phone, Wear OS, watchOS   |
| Wear OS           | watchOS, Android phone, iOS phone |
| watchOS           | Wear OS, Android phone, iOS phone |
| Android + Wear OS | iOS + watchOS                     |
| iOS + watchOS     | Android + Wear OS                 |

**This is not optional.** The objective is to keep all platforms functionally identical and free of the same bugs.

### Process

1. Implement on the primary platform.
2. **IMMEDIATELY** verify/implement on the counterpart platform.
3. Verify both before marking as complete.

---

## 7. Key Files for Context

At the start of any session, load these files for context:

### General

- `PRD/01_PRODUCT_VISION.md` -- what we are building and why.
- `PRD/10_FLUTTER_MIGRATION_REFERENCE.md` -- migration reference from Flutter.
- `CLAUDE.md` -- project conventions and orchestrator rules.

### iOS

- `PRD/05_TECHNICAL_ARCHITECTURE_IOS.md` -- iOS technical architecture (TCA, SwiftData, sync, etc.).
- The specific feature files in `ios/`.

### Android

- `PRD/06_TECHNICAL_ARCHITECTURE_ANDROID.md` -- Android technical architecture (MVVM, Room, sync, etc.).
- The specific feature files in `android/`.

---

## 8. Estimated Claude Code Effectiveness by Phase

| Phase                | % of Work with Claude Code | Best Used For                                                                                      |
| -------------------- | -------------------------- | -------------------------------------------------------------------------------------------------- |
| Phase 1: Foundations | 60-70%                     | Scaffolding (TCA/Circuit), data models, basic views, tests                                         |
| Phase 2: Ecosystem   | 40-50%                     | Widget/activity templates, App Intents/Assistant, Watch/Wear scaffolding (manual testing required) |
| Phase 3: Polish      | 30-40%                     | Accessibility audits, localization, performance suggestions, StoreKit/Play Billing boilerplate     |
| Phase 4: Launch      | 50-60%                     | Marketing content, landing page, bug fix implementation, ASO optimization                          |

---

## 9. Tips to Maximize the Max 5x Plan

### Context Window Strategy

- Load multiple related files at once (Feature + View + Tests + Models).
- Request full reviews across multiple files.
- Generate complete features (reducer/presenter + view + tests + localization) in a single session.

### Usage Optimization

- **Group related work** -- do not switch context between unrelated features mid-session.
- **Use sub-agents** for research tasks (Apple/Google documentation, API availability).
- **Let Claude Code write the tedious parts** -- focus creative energy on design and UX decisions.
- **Daily code review sessions** -- low-cost prevention against accumulated technical debt.
