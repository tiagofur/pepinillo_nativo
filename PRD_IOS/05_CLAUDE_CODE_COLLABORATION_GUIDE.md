# Claude Code Collaboration Guide: Pepinillo Native (Deep Work Companion)

**How to maximize your Claude Code Max 5x plan for building Pepinillo Native**

---

## The Claude Code Advantage for Solo Developers

With the Max 5x plan, you get extended context windows and higher usage limits. This is transformative for a solo developer building a multi-platform Apple app because Claude Code excels at exactly the tedious, repetitive, and boilerplate-heavy tasks that slow down solo development.

---

## What Claude Code Does Best (Lean Into These)

### 1. TCA Boilerplate Generation
TCA is powerful but verbose. Each feature needs State, Action, Reducer, View, and often a Client. Claude Code can generate the complete scaffolding for any feature in minutes.

**Example prompt:**
> "Create a complete TCA feature for task management. State should include a list of TaskItem (SwiftData model), selection state, and filter options. Actions: add, delete, reorder, toggle completion, select task. Include a SwiftUI view with a List, swipe actions, and drag-to-reorder. Follow the patterns in FocusFeature.swift."

### 1b. Focus Mode Strategy Generation (NEW)
The Strategy pattern for focus modes is highly formulaic. Claude Code can generate new mode strategies quickly.

**Example prompt:**
> "Create a new FocusModeStrategy called '52/17 Strategy' — 52 minutes of work followed by 17 minutes of break, repeating. Conform to FocusModeProtocol. Follow the pattern in PomodoroStrategy.swift. Include unit tests."

### 2. SwiftData Model Generation
Models with relationships, migrations, and CloudKit compatibility.

**Example prompt:**
> "Create a SwiftData @Model for PomodoroSession with: id (UUID), startedAt (Date), endedAt (Date?), duration (TimeInterval), type (enum: work/shortBreak/longBreak), wasCompleted (Bool), interruptions (Int), and a relationship to TaskItem. Include CloudKit-compatible defaults."

### 3. SwiftUI Views from Descriptions
Describe what you want visually and Claude Code builds it.

**Example prompt:**
> "Create a timer circle view: 200pt diameter, circular progress ring (green when working, blue on break), time remaining in center (large monospaced font), task name below in smaller text. Support dark mode. Use the theme system from Theme.swift."

### 4. Widget & Live Activity Templates
WidgetKit and ActivityKit have specific patterns. Claude Code knows them.

**Example prompt:**
> "Create a medium Home Screen widget showing: current timer countdown (or 'No active timer'), today's completed Pomodoros count, and the next task name. Use WidgetKit with IntentConfiguration for the timeline provider."

### 5. Test Generation
TCA makes testing formulaic — perfect for Claude Code.

**Example prompt:**
> "Write TCA reducer tests for TaskListFeature: test adding a task, deleting a task, reordering tasks, toggling completion, and filtering by completion status. Use TestStore and verify all state mutations."

### 6. Localization
Extracting strings and creating translations across EN/ES/PT.

**Example prompt:**
> "Extract all user-facing strings from TimerView.swift and TaskListView.swift into Localizable.xcstrings format. Provide translations for Spanish (Latin American) and Brazilian Portuguese. Use informal tone."

### 7. App Intents / Shortcuts
Declarative and pattern-heavy — Claude Code generates these quickly.

**Example prompt:**
> "Create App Intents for: StartPomodoro (with optional duration and task parameters), StopPomodoro, GetTodayStats (returns dialog with session count and focus minutes). Include an AppShortcutsProvider with Siri phrases in English, Spanish, and Portuguese."

---

## What Claude Code Struggles With (Do These Yourself or Review Carefully)

### 1. Visual Design Decisions
Claude Code can build any layout you describe, but it can't make subjective aesthetic choices. You decide the visual direction — Claude Code implements it.

**Workflow:** Sketch on paper or in Figma → describe to Claude Code → iterate on the output.

### 2. CloudKit Sync Debugging
CloudKit issues are notoriously hard to debug (silent failures, sync delays, merge conflicts). Claude Code can write the sync code, but you need to test on real devices with real iCloud accounts.

**Tip:** Ask Claude Code to add extensive logging to all CloudKit operations so you can diagnose issues.

### 3. watchOS Real-Device Behavior
The watchOS Simulator doesn't accurately reflect real Watch behavior (haptics, complications, battery, connectivity). Test on hardware.

### 4. App Store Submission Process
Screenshots, metadata, review guidelines compliance — Claude Code helps prepare materials, but you navigate App Store Connect.

### 5. Performance Profiling
Instruments profiling, memory leaks, battery usage analysis require Xcode's profiler. Claude Code can suggest optimizations, but measurement is manual.

---

## Recommended Workflow: Day-to-Day with Claude Code

### Morning (Planning)
1. Open the PRD and check the current phase/task
2. Tell Claude Code what you're building today
3. Have Claude Code generate the scaffolding (TCA feature + views + tests)

### Building (Implementation)
4. Review generated code, adjust to your taste
5. Ask Claude Code for specific implementations: "Add haptic feedback when timer completes" or "Make the widget timeline update every minute during active sessions"
6. Run tests — if they fail, paste the error and let Claude Code fix

### Evening (Review)
7. Ask Claude Code to review the day's code: "Review all files changed today for bugs, memory leaks, and TCA best practices"
8. Ask Claude Code to update tests for any new behavior
9. Commit with a descriptive message

---

## Session-Starting Prompts (Copy-Paste Ready)

### New Feature Session
> "I'm building the [Feature Name] for Pepinillo Native. Read the PRD at PRD_IOS/01_PRD_PEPINILLO_NATIVE.md for context. The technical architecture is in PRD_IOS/03_TECHNICAL_ARCHITECTURE.md. I want to implement [specific requirement ID]. Start by creating the TCA feature file and the SwiftUI view."

### Bug Fix Session
> "There's a bug in Pepinillo Native: [describe bug]. The relevant files are [list files]. Debug this and propose a fix. Consider edge cases around [timer background behavior / CloudKit sync / Watch connectivity]."

### Refactor Session
> "Review the current implementation of [feature]. Suggest improvements for: code quality, testability, performance, and alignment with TCA best practices. Then implement the changes."

### Test Writing Session
> "Write comprehensive tests for [Feature]Feature.swift. Cover: happy path, edge cases, error states, and integration with [dependent feature]. Use TCA's TestStore."

### Localization Session
> "Extract all new user-facing strings from the following files: [list]. Add translations in Spanish (LATAM) and Brazilian Portuguese. Use informal 'tú' for Spanish and 'você' for Portuguese. Match the tone of existing localizations."

---

## Claude Code + SDD (Spec-Driven Development)

Your CLAUDE.md already includes SDD orchestration. Here's how to combine it with this PRD:

1. **For each Phase, run `/sdd:new phase-1-timer`** — Claude Code creates a focused proposal
2. **`/sdd:ff phase-1-timer`** — Fast-forward through specs, design, and task breakdown
3. **`/sdd:apply phase-1-timer`** — Claude Code implements the tasks
4. **`/sdd:verify phase-1-timer`** — Automated verification

This keeps each development sprint organized and documented.

---

## Maximizing the 5x Plan

### Context Window Strategy
The Max 5x plan gives you larger context windows. Use this by:
- Loading multiple related files at once (Feature + View + Tests + Models)
- Asking for comprehensive reviews across multiple files
- Generating entire features (TCA reducer + view + tests + localization) in a single session

### Usage Optimization
- **Batch related work** — Don't context-switch between unrelated features mid-session
- **Use sub-agents** for research tasks (finding Apple documentation, checking API availability)
- **Let Claude Code write the boring stuff** — focus your creative energy on design and UX decisions
- **Daily code review sessions** — cheap insurance against accumulated tech debt

### What 5x Enables That Normal Plans Don't
- Complete feature generation in one session (not split across multiple)
- Multi-file refactors with full context
- Comprehensive test suites generated alongside features
- End-to-end debugging sessions with full stack visibility

---

## Estimated Claude Code Involvement by Phase

| Phase | Claude Code % of Work | Best Used For |
|-------|----------------------|---------------|
| Phase 1: Foundation | 60-70% | TCA scaffolding, SwiftData models, basic views, tests |
| Phase 2: Ecosystem | 40-50% | Widget/Activity templates, App Intents, Watch scaffolding (manual testing needed) |
| Phase 3: Polish | 30-40% | Accessibility audit, localization, performance suggestions, StoreKit boilerplate |
| Phase 4: Launch | 50-60% | Marketing content, landing page, bug fix implementation, ASO optimization |

---

## Key Files Claude Code Should Always Have Context On

When starting any session, load these files for context:
1. `PRD_IOS/01_PRD_PEPINILLO_NATIVE.md` — what we're building and why
2. `PRD_IOS/03_TECHNICAL_ARCHITECTURE.md` — how it's structured
3. The specific feature files you're working on
4. `CLAUDE.md` — project conventions

This ensures Claude Code understands the big picture and doesn't make decisions that conflict with the architecture.
