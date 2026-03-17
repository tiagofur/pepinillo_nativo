# Effort Estimation & Phased Roadmap (v2 — Deep Work Pivot)

**Date:** March 11, 2026
**Assumption:** Solo developer (Tiago) + Claude Code Max 5x
**Work pace:** ~20-30 hours/week

---

## What Changed from v1 (Pomodoro-only)

The Deep Work pivot adds **~80-100 hours** to the total, primarily from:
- Multi-mode Focus Engine (+25h): 4 strategy implementations instead of 1
- Mode-aware analytics (+12h): Charts broken down by mode, mode comparison
- Onboarding with mode selection (+6h): Explain 4 modes, let user pick default
- Soundscapes P1 (+16h): Audio engine for ambient sounds during focus
- Mode Intelligence P1 (+12h): Historical analysis suggesting optimal mode per task
- Updated UI throughout (+10h): Mode selector, mode-specific icons/colors in widgets, Watch, Dynamic Island

**However**, the Strategy pattern means the 4 modes share ~80% of code (engine, Live Activity, Widget, Watch, Siri all work with any mode). The marginal cost of modes 2-4 is much less than building mode 1.

---

## Phase 1: Foundation (Weeks 1-11)

**Goal:** Multi-mode focus app on iPhone with task management and CloudKit.

| Task | Size | Hours | Claude Code |
|------|------|-------|-------------|
| Project setup (Xcode, targets, App Groups, TCA) | S | 4h | High |
| SwiftData models (TaskItem, SubTask, FocusSession, DailyStats) | M | 10h | High |
| **FocusModeProtocol + Strategy pattern** | M | 8h | High |
| **PomodoroStrategy implementation** | M | 12h | High |
| **FlowtimeStrategy** (count-up + dynamic break calculation) | M | 10h | High |
| **TimeBlockStrategy** (single countdown block) | S | 6h | High |
| **StopwatchStrategy** (count-up, no target) | S | 4h | High |
| **FocusEngine Actor** (unified engine for all modes) | L | 24h | Medium |
| **FocusFeature TCA** (reducer + mode selection state) | L | 16h | High |
| **FocusView SwiftUI** (mode selector + timer display per mode) | L | 20h | Medium |
| Task List Feature (CRUD, reorder, swipe) | L | 20h | High |
| Task Detail Feature (subtasks, estimated focus time) | M | 12h | High |
| Link tasks to focus sessions (any mode) | M | 8h | High |
| **Mode-aware analytics dashboard** (SwiftCharts, mode breakdown) | L | 24h | Medium |
| Settings (per-mode durations, sounds, defaults) | M | 12h | High |
| Navigation & Tab structure | M | 10h | High |
| Notifications (mode-aware actions) | M | 10h | High |
| Theme system (4 themes + Liquid Glass) | L | 16h | Medium |
| **Onboarding with mode explainer + default picker** | M | 10h | Medium |
| Localization (EN, ES, PT) | M | 12h | High |
| Unit tests (all 4 strategies + FocusEngine + Tasks) | L | 20h | High |

**Phase 1 Total: ~268 hours (~9-11 weeks at 25h/week)**

**Milestone:** Full multi-mode focus app on iPhone. All 4 modes working. Tasks linked. Analytics with mode breakdown. Internal TestFlight.

---

## Phase 2: Apple Ecosystem (Weeks 12-20)

**Goal:** Widgets, Live Activities, Watch, Siri, iPad, Mac — all mode-aware.

| Task | Size | Hours | Claude Code |
|------|------|-------|-------------|
| Home Screen Widgets (S/M/L, mode-aware display) | XL | 32h | Medium |
| Lock Screen Widget | M | 10h | High |
| **Live Activity + Dynamic Island** (4 mode-specific UIs) | XL | 40h | Medium |
| **Apple Watch app** (mode picker + timer + tasks + complications) | XL | 45h | Medium |
| Watch ↔ Phone connectivity (mode sync) | L | 20h | Low |
| **Siri / App Intents** (multi-mode commands, 3 languages) | L | 18h | High |
| iPad adaptive layouts (NavigationSplitView, Stage Manager, keyboard) | L | 16h | High |
| macOS target (menu bar + window + keyboard shortcuts) | XL | 32h | Medium |
| CloudKit sync setup | L | 20h | Medium |
| Offline conflict resolution | M | 12h | Medium |
| Integration tests | L | 16h | High |

**Phase 2 Total: ~261 hours (~7-9 weeks at 25-30h/week)**

**Milestone:** Full ecosystem. Every Apple surface knows about all 4 modes.

---

## Phase 3: Polish & Premium (Weeks 21-27)

**Goal:** Subscription-worthy quality. The features that make users pay.

| Task | Size | Hours | Claude Code |
|------|------|-------|-------------|
| Focus Modes integration (P1) | M | 12h | Medium |
| Apple Health (Mindful Minutes) (P1) | M | 10h | High |
| **Ambient soundscapes** (P1: rain, café, library, white noise) | L | 16h | Medium |
| Recurring tasks (P1) | M | 12h | High |
| **Weekly Review screen** (P1: mode comparison, trends) | M | 14h | High |
| **Mode Intelligence** (P1: suggest optimal mode per task type) | L | 16h | Medium |
| Streak system + milestones (P1) | M | 10h | High |
| Task energy levels (P1: deep/shallow/admin tags) | S | 6h | High |
| **StoreKit 2** (paywall, tiers, LATAM pricing, restore) | L | 22h | Medium |
| Control Center widget | S | 6h | High |
| Animation & micro-interactions polish | L | 20h | Low |
| Accessibility audit (VoiceOver, Dynamic Type) | M | 12h | High |
| Performance optimization | M | 12h | Medium |
| App Store screenshots & preview video | L | 16h | Medium |
| ASO (update existing EN/ES/PT with Deep Work positioning) | M | 8h | High |
| Privacy Policy & Terms | S | 4h | High |

**Phase 3 Total: ~196 hours (~5-7 weeks at 25-30h/week)**

**Milestone:** Premium-ready. Soundscapes, Mode Intelligence, Weekly Review — the features worth $35/year.

---

## Phase 4: Launch (Weeks 28-31)

| Task | Size | Hours | Claude Code |
|------|------|-------|-------------|
| TestFlight public beta (100+ users) | M | 8h | N/A |
| Bug fixes from beta | L | 35h | High |
| App Store submission | S | 4h | N/A |
| Marketing site / landing page | M | 12h | High |
| Launch campaign (ProductHunt, Reddit, Twitter, LATAM blogs) | M | 10h | Medium |
| Post-launch monitoring & hot fixes | L | 20h | High |

**Phase 4 Total: ~89 hours (~3-4 weeks)**

---

## Summary Comparison

| | v1 (Pomodoro) | v2 (Deep Work) | Delta |
|---|---|---|---|
| Phase 1 | 198h | 268h | +70h |
| Phase 2 | 245h | 261h | +16h |
| Phase 3 | 172h | 196h | +24h |
| Phase 4 | 90h | 89h | -1h |
| **Total** | **705h** | **814h** | **+109h (+15%)** |
| **Timeline (25h/wk)** | **28 weeks** | **~31 weeks** | **+3 weeks** |
| **Timeline (full-time)** | **19 weeks** | **~21 weeks** | **+2 weeks** |

**The Deep Work pivot costs ~15% more effort but roughly doubles revenue potential.** The ROI per hour invested is significantly better.

---

## Aggressive Timeline (Full-Time + Claude Code)

| Phase | Duration |
|-------|----------|
| Phase 1 | 6-7 weeks |
| Phase 2 | 5-6 weeks |
| Phase 3 | 4-5 weeks |
| Phase 4 | 2-3 weeks |
| **Total** | **~17-21 weeks (4-5 months)** |

**Target: September 2026** — aligned with iOS 26 launch.

---

## Critical Path (Updated)

```
Project Setup → SwiftData Models → FocusModeProtocol
                                         ↓
                   PomodoroStrategy + FlowtimeStrategy
                   TimeBlockStrategy + StopwatchStrategy
                                         ↓
                                    FocusEngine (Actor)
                                         ↓
                                    FocusFeature (TCA)
                                         ↓
                                    Task Management
                                         ↓
                                   Link Tasks to Sessions
                                         ↓
                                Mode-Aware Analytics + Settings
                                         ↓
                              CloudKit Sync ──→ Widgets (mode-aware)
                                    ↓                    ↓
                              Watch App          Live Activities (4 UIs)
                              (mode picker)              ↓
                                    ↓              iPad / macOS
                              Siri (multi-mode)
                                    ↓
                        Soundscapes + Mode Intelligence
                                    ↓
                           StoreKit 2 + Polish
                                    ↓
                                 LAUNCH
```

---

## Risk-Adjusted Timeline

| Risk | Impact | Mitigation |
|------|--------|------------|
| 4 mode strategies increase testing surface | +1-2 weeks | Strategy pattern keeps modes isolated. Test each independently. |
| Flowtime break calculation UX unclear | +1 week | User test in beta. Start with simple formula, iterate. |
| Soundscapes audio engine complexity | +1 week | Use AVAudioPlayer for v1 (simple presets). AVAudioEngine only if needed later. |
| Mode Intelligence needs 2+ weeks of data | N/A | Ship as P1 fast-follow. Collect data from day 1. |
| Everything from v1 risk register still applies | Same | Same mitigations |

**Realistic launch: September-November 2026**
