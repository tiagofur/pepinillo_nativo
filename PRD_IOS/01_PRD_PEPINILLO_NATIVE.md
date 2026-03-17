# PRD: Pepinillo — Deep Work Companion for Apple

**Version:** 2.0 (Pivot from Pomodoro App → Deep Work Platform)
**Author:** Tiago David + Claude Code
**Date:** March 11, 2026
**Status:** Draft — Planning Phase

---

## 1. Problem Statement

Knowledge workers, students, and creatives lose an average of 2.1 hours per day to context switching and interruptions. The market response has been fragmented: Pomodoro timers (Forest, Focus Keeper) offer one rigid technique, task managers (Things 3, Todoist) don't integrate focus time, and time-blocking apps (Structured) lack flexible timer methods. **No single app combines multiple focus techniques with task management and deep analytics on Apple platforms.**

Pepinillo currently exists as a Flutter-based Pomodoro app. While functional, it has two critical limitations: (1) it's locked into the Pomodoro technique as its only focus method, limiting its appeal to users who prefer Flowtime, time-blocking, or free-form deep work sessions, and (2) Flutter's abstraction blocks access to the Apple ecosystem features (widgets, Live Activities, Dynamic Island, Apple Watch, Siri, Focus Modes, Apple Health) that are now table stakes for premium productivity apps.

**The opportunity:** Reposition Pepinillo from "yet another Pomodoro timer" (saturated market, low price ceiling) to **"the Deep Work companion built for Apple"** — a premium productivity tool that offers multiple focus techniques, integrated task management, and the deepest possible Apple ecosystem integration. This moves us from competing with $3.99 timer apps to competing in the $30-60/year premium productivity tier alongside Things 3, Fantastical, and Craft.

---

## 2. Vision

> **Pepinillo is the command center for deep work on Apple.** One app where you plan what to work on, choose how to focus, track your progress, and build lasting productivity habits — all woven seamlessly into your Apple devices.

The name "Pepinillo" (pickle/gherkin) becomes a playful contrast to the seriousness of deep work — memorable, approachable, and distinctive in a market full of generic names like "Focus Timer Pro" and "Session."

---

## 3. Goals

| # | Goal | Measurement |
|---|------|-------------|
| G1 | **Become the go-to deep work app for Apple power users** — Pepinillo should feel like it was made by Apple | App Store rating ≥ 4.7; featured in "Apps We Love" or editorial within 6 months |
| G2 | **Multi-technique focus sessions** — Users choose the focus method that works for them, not the one the app forces | ≥3 focus modes used across the user base; Pomodoro accounts for <60% of sessions (proving users want variety) |
| G3 | **Premium conversion through undeniable value** — Users pay because the free tier already impressed them | Premium conversion ≥ 8% (vs. industry avg 3-5% for timer apps); ARPU ≥ $3.50/month |
| G4 | **Apple ecosystem depth as competitive moat** — No competitor matches our integration breadth | ≥60% of focus sessions initiated from outside the main app (widget, Watch, Siri, Dynamic Island) |
| G5 | **Own the LATAM deep work market** — First premium productivity app with LATAM-first pricing and localization | Top 10 Productivity in Brazil and Mexico within 12 months; 40%+ of user base from LATAM |
| G6 | **Build lasting habits, not just usage** — Users develop genuine productivity improvement | ≥40% D30 retention; average streak length ≥ 14 days among retained users |

---

## 4. Non-Goals

| # | Non-Goal | Reason |
|---|----------|--------|
| NG1 | **Android version rewrite** | Android stays on Flutter with current Pomodoro feature set |
| NG2 | **Team/collaboration features** | Individual deep work first; B2B is a separate initiative |
| NG3 | **Note-taking / document editing** | We complement apps like Craft and Notion, we don't replace them |
| NG4 | **AI-generated task breakdown** | v2 feature; focus on perfecting the human-driven workflow first |
| NG5 | **Ambient music creation / marketplace** | Pre-bundled soundscapes sufficient; not a music app |
| NG6 | **Web app parity** | Web stays Next.js; separate roadmap |
| NG7 | **Calendar replacement** | We integrate with Apple Calendar, we don't compete with Fantastical |

---

## 5. Focus Modes — The Core Differentiator

Unlike pure Pomodoro apps, Pepinillo offers **four focus techniques** that users can switch between freely. This is the single biggest differentiator from every competitor.

### 5.1 Pomodoro Mode
Classic 25/5/15 with full customization. Auto-advance through work→break→work cycles. Track which Pomodoro number you're on (e.g., "🍅 3 of 4"). This is the mode existing users know and love.

### 5.2 Flowtime Mode
Start an open-ended focus session. When you feel your concentration fading, tap to take a break. The app suggests break length based on how long you focused (10 min focus → 2 min break, 50 min → 10 min break, etc.). No rigid intervals. Ideal for creative work, writing, coding.

**Why this matters:** Many productivity experts (including Cal Newport) argue that forced 25-minute blocks interrupt flow states. Flowtime captures the audience that tried Pomodoro and bounced.

### 5.3 Time-Block Mode
Set a fixed focus block (e.g., "2 hours of writing"). One continuous countdown with optional mid-point check-ins. The app tracks how many blocks you complete per day. Integrates with Apple Calendar to show blocked time.

**Why this matters:** Time-blocking is the #1 technique recommended by Cal Newport in "Deep Work." Currently no major app implements it as a first-class timer mode.

### 5.4 Stopwatch Mode (Free Focus)
Open-ended timer that counts up. No pressure, no goals. Just track how long you work. Tap to pause. Tap to stop. Ideal for users who want tracking without structure.

**Why this matters:** Some days you just want to sit down and work without a technique telling you when to stop. This captures the casual/flexible segment.

### 5.5 Mode Intelligence (P1)
After 2+ weeks of data, Pepinillo suggests which mode works best for different task types based on your completion rates and interruption patterns. "You complete 80% more writing tasks with Flowtime. Want to try it for today's blog post?"

---

## 6. User Stories

### 6.1 Focus Session Experience

**US-1** As a developer entering a coding session, I want to choose Flowtime mode and start focusing with one tap so that my concentration isn't artificially interrupted by rigid timer intervals.

**US-2** As a student preparing for exams, I want to use Pomodoro mode with 25/5 intervals from my Lock Screen widget so that I can begin studying without unlocking my phone.

**US-3** As a writer blocking 3 hours for their novel, I want to set a Time-Block and see it appear in my Dynamic Island so that I always know how much of my block remains.

**US-4** As a remote worker who just wants to track focus time, I want to start a Stopwatch session from my Apple Watch and forget about it until I'm done.

**US-5** As a user who uses Focus Modes, I want Pepinillo to automatically activate my "Deep Work" Focus Mode when I start any focus session so that notifications are silenced contextually.

**US-6** As someone who prefers voice commands, I want to say "Hey Siri, start a 2-hour deep work block in Pepinillo" so that I can begin hands-free.

**US-7** As a user who's tried multiple techniques, I want Pepinillo to show me which focus mode gives me the best results for different task types.

### 6.2 Task Management

**US-8** As a freelancer juggling clients, I want to create tasks with subtasks and assign estimated focus time to each so that I plan my day realistically.

**US-9** As a power user, I want to tag tasks with energy levels (deep work, shallow work, admin) so that I can batch similar work together.

**US-10** As someone with recurring responsibilities, I want recurring tasks that appear automatically each day/week.

**US-11** As an Apple Reminders user, I want to import tasks from Reminders so that I have one consolidated view.

**US-12** As a student, I want to drag tasks to reorder by priority and see estimated total focus time for my day.

### 6.3 Analytics & Growth

**US-13** As someone optimizing my productivity, I want to see which focus mode I use most, which gives me the best completion rate, and when I'm most productive (hour, day of week).

**US-14** As a health-conscious professional, I want my focus time logged to Apple Health as Mindful Minutes.

**US-15** As a user reviewing my week, I want a "Weekly Review" that compares my focus hours, tasks completed, and streak against last week — with trend arrows.

**US-16** As someone motivated by consistency, I want a focus streak (consecutive days with ≥1 completed session) with milestones at 7, 30, 100, and 365 days.

### 6.4 Multi-Device & Sync

**US-17** As someone who starts tasks on Mac and continues on iPhone, I want seamless CloudKit sync within seconds.

**US-18** As an Apple Watch user, I want to see my task list, start any focus mode, and get haptic feedback when my session ends.

**US-19** As an iPad user, I want Pepinillo in Split View next to my writing app with keyboard shortcuts for quick timer control.

### 6.5 Customization

**US-20** As someone who values aesthetics, I want multiple themes including a Liquid Glass theme for iOS 26.

**US-21** As a user who works at night, I want ambient soundscapes (rain, café, white noise) that play during focus sessions and automatically stop during breaks.

### 6.6 Edge Cases

**US-22** As a user who gets a phone call mid-session, I want the timer to handle the interruption gracefully (pause or log it).

**US-23** As a user switching devices, I want my active session on iPhone to appear on my Watch immediately.

**US-24** As a user who force-quits the app, I want my timer to continue and alert me when complete.

---

## 7. Requirements

### 7.1 Must-Have (P0) — Cannot Ship Without

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| P0-1 | **Multi-mode Focus Engine** (Pomodoro, Flowtime, Time-Block, Stopwatch) | User can select any mode before starting. Each mode has distinct UI and behavior. Timer accurate to ±1s in background. State persists across app restarts. |
| P0-2 | **Task CRUD with subtasks** | Create, edit, delete, reorder tasks. ≥20 subtasks per task. Swipe actions. |
| P0-3 | **Link tasks to focus sessions** | Any focus mode can be linked to a task. Session records task, mode used, duration, completion. |
| P0-4 | **Mode-aware analytics dashboard** | Shows daily/weekly/monthly focus time broken down by mode. Completion rates per mode. Most productive times. SwiftCharts. |
| P0-5 | **CloudKit sync (iPhone, iPad, Mac)** | Tasks, sessions, settings, streaks sync within 10s on Wi-Fi. Offline-first with automatic merge. |
| P0-6 | **Home Screen widgets (S/M/L)** | Small: active timer or daily progress. Medium: timer + today's top 3 tasks. Large: timer + tasks + daily stats by mode. |
| P0-7 | **Live Activity + Dynamic Island** | Shows countdown, mode icon, task name, progress. Quick actions: pause/skip/stop. Works for all 4 modes. |
| P0-8 | **Lock Screen widget** | Daily progress or active timer. Tap to start quick session (default mode). |
| P0-9 | **Apple Watch app** | Start any focus mode from Watch. Countdown with haptics. Today's tasks. Complications (timer + daily focus hours). |
| P0-10 | **Siri Shortcuts + App Intents** | "Start deep work in Pepinillo", "Start a Pomodoro", "How much did I focus today?", "Start working on [task]". All 3 languages. |
| P0-11 | **Actionable notifications** | Session end, break end, daily reminder. Actions: "Start Break" / "Continue" / "Switch Mode" / "Done". |
| P0-12 | **Themes (≥4) + Dark/Light** | Default, Forest, Ocean, Sunset, Liquid Glass (iOS 26). System appearance respected. |
| P0-13 | **Full offline support** | 100% functional offline. Sync opportunistically. |
| P0-14 | **Localization: EN, ES, PT** | All strings, notifications, Siri phrases in three languages. |
| P0-15 | **iPad + Stage Manager** | NavigationSplitView for tablet. Split View/Slide Over support. Keyboard shortcuts (Cmd+N, Space, etc.). |
| P0-16 | **macOS native** | Menu bar focus timer. Full window app. Keyboard-first UX. Proper macOS conventions. |
| P0-17 | **Onboarding with mode selection** | 3-4 screen onboarding that explains the 4 focus modes and lets user pick their default. Sets up permissions (notifications, Health). |

### 7.2 Nice-to-Have (P1) — Strong Fast-Follows

| ID | Requirement | Notes |
|----|-------------|-------|
| P1-1 | **Focus Modes integration** | Auto-activate a linked Apple Focus Mode per session type. |
| P1-2 | **Apple Health integration** | Log as Mindful Minutes. Read sleep data to suggest optimal focus windows. |
| P1-3 | **Ambient soundscapes** | Rain, café, library, white noise. Play during focus, auto-pause on break. AVAudioEngine. |
| P1-4 | **Recurring tasks** | Daily, weekly, monthly, custom. |
| P1-5 | **Weekly Review screen** | Automated comparison: this week vs last. Focus hours, mode distribution, tasks, streaks. |
| P1-6 | **Mode Intelligence** | After 2 weeks, suggest optimal mode per task type based on user's historical data. |
| P1-7 | **Streak system + milestones** | Consecutive days tracked. Celebrations at 7, 30, 100, 365 days. |
| P1-8 | **Control Center widget** | Quick-start focus session from Control Center. |
| P1-9 | **Task energy levels** | Tag tasks as deep/shallow/admin for batching. |
| P1-10 | **StoreKit 2 subscriptions** | See Monetization Strategy (Section 9). |
| P1-11 | **Apple Reminders import** | One-way import via EventKit. |
| P1-12 | **Advanced Watch features** | Full task list, mark complete, session history, choose mode on Watch. |
| P1-13 | **Achievements system** | 6+ predefined achievements (First Session, Week Streak, Pomodoro Master, Deep Diver, Century Club, Early Bird). Progress tracking + unlock celebrations. Horizontal scroll in Analytics. Parity with Android. |

### 7.3 Future Considerations (P2)

| ID | Requirement | Notes |
|----|-------------|---------------------|
| P2-1 | **AI-powered insights** (Core ML) | Predict productive windows, suggest task scheduling, detect burnout patterns. |
| P2-2 | **Calendar integration** (→ promoted to P1) | Block focus time in Apple Calendar. Read events to suggest session slots. Parity with Android's Google Calendar integration. |
| P2-3 | **Pomodoro → Flowtime auto-switch** | If user consistently skips Pomodoro breaks, suggest switching to Flowtime for that task type. |
| P2-4 | **Social accountability** | Shared focus sessions with a partner. CloudKit shared zones. |
| P2-5 | **Apple Vision Pro** | SwiftUI multiplatform — immersive focus environment. |
| P2-6 | **Handoff between devices** | NSUserActivity-based. Continue session seamlessly across devices. |
| P2-7 | **Shortcuts automation** | Complex workflows: "When I arrive at library, start Pomodoro" via Shortcuts. |
| P2-8 | **Session journaling** | Quick note after each session: "What did I accomplish?" for reflection. |

---

## 8. Monetization Strategy — Premium Deep Work

**Key insight:** Repositioning from "Pomodoro app" to "Deep Work companion" unlocks a higher price tier. Users pay $49.99/year for Things 3, $39.99/year for Fantastical, $44.99/year for Craft. A $29.99-39.99/year price point for Pepinillo is defensible if the quality justifies it.

### Pricing Tiers

| Tier | Price (US) | Price (LATAM) | Includes |
|------|-----------|---------------|----------|
| **Free** | $0 | $0 | Pomodoro + Stopwatch modes. 3 active tasks. Basic daily stats. 1 theme. iPhone only. |
| **Pro Monthly** | $4.99/mo | $2.99/mo | All 4 focus modes. Unlimited tasks. Full analytics. All themes. Soundscapes. iPad + Mac. |
| **Pro Annual** | $34.99/yr ($2.92/mo) | $19.99/yr ($1.67/mo) | Same as monthly. 42% savings. |
| **Pro Lifetime** | $79.99 | $49.99 | One-time purchase. All current + future features. |

### Free → Pro Conversion Hooks

The free tier is genuinely useful (not crippled) but strategically limited:
- Only 2 of 4 focus modes free → "Unlock Flowtime and Time-Block" is the primary conversion trigger
- 3-task limit creates natural upgrade pressure for active users
- Basic stats vs full analytics with mode comparison, Weekly Review, trends
- iPhone-only in free tier → Mac/iPad/Watch require Pro (power users always upgrade)
- Single theme → "Unlock all themes including Liquid Glass" for aesthetic-motivated users

### Revenue Projections (Conservative)

| Scenario | MAU | Conversion | ARPU | MRR |
|----------|-----|-----------|------|-----|
| Base (Month 6) | 8K | 6% | $3.50 | $1,680 |
| Good (Month 6) | 15K | 8% | $3.80 | $4,560 |
| Stretch (Month 12) | 30K | 10% | $4.00 | $12,000 |

Compare to the old Pomodoro plan: 10K MAU × 5% × $2.50 = $1,250 MRR. The Deep Work pivot roughly **doubles revenue potential** at the same user count due to higher ARPU.

---

## 9. Success Metrics

### 9.1 Leading Indicators (First 30 Days)

| Metric | Target | Stretch |
|--------|--------|---------|
| App Store rating | ≥ 4.5 | ≥ 4.8 |
| D1 retention | ≥ 35% | ≥ 45% |
| D7 retention | ≥ 25% | ≥ 35% |
| Multi-mode usage (≥2 modes tried) | ≥ 30% | ≥ 50% |
| Widget adoption | ≥ 40% | ≥ 60% |
| Live Activity usage | ≥ 50% of sessions | ≥ 70% |
| Watch install rate | ≥ 15% | ≥ 25% |
| Focus sessions per user per day | ≥ 2 | ≥ 4 |

### 9.2 Lagging Indicators (90 Days)

| Metric | Target | Stretch |
|--------|--------|---------|
| D30 retention | ≥ 30% | ≥ 40% |
| MAU | 10K | 25K |
| Premium conversion | ≥ 6% | ≥ 10% |
| Monthly ARPU (paying users) | ≥ $3.50 | ≥ $4.50 |
| App Store rank (Productivity, BR/MX) | Top 50 | Top 20 |
| NPS | ≥ 40 | ≥ 60 |
| Avg streak length (retained users) | ≥ 7 days | ≥ 14 days |

---

## 10. Open Questions

| # | Question | Blocking? |
|---|----------|-----------|
| OQ-1 | Feature parity with Flutter, or start fresh with curated set? | Yes |
| OQ-2 | Same App Store listing or new app? | Yes — affects ASO, reviews migration |
| OQ-3 | Migrate Flutter user data to native? | Yes — affects CloudKit schema |
| OQ-4 | Use Go backend or go fully CloudKit-native for v1? | Yes |
| OQ-5 | Lifetime purchase option — does it hurt long-term MRR? | No — test after 6 months |
| OQ-6 | Analytics: TelemetryDeck vs custom? | No |
| OQ-7 | Apply for Apple Design Award? | No — but should inform design quality target |

---

## 11. Timeline

| Phase | Scope | Duration |
|-------|-------|----------|
| **Phase 1: Foundation** | Multi-mode timer + Tasks + CloudKit + iPhone | 9-11 weeks |
| **Phase 2: Ecosystem** | Widgets + Live Activities + Watch + Siri + iPad + macOS | 7-9 weeks |
| **Phase 3: Polish** | Analytics + Themes + Soundscapes + Streaks + Localization + Onboarding | 5-7 weeks |
| **Phase 4: Launch** | TestFlight + ASO + Bug fixes + Subscription setup + App Store submission | 3-4 weeks |

**Total: ~24-31 weeks (~6-8 months)**

Target: **August-October 2026** (iOS 26 launch window + back-to-school)

---

## Appendix A: Feature Parity Matrix

| Feature | Flutter Today | Native v1 | Change from Pomodoro PRD |
|---------|--------------|-----------|--------------------------|
| Pomodoro Timer | ✅ | ✅ P0 | Same |
| Flowtime Mode | ❌ | ✅ P0 | **NEW — core differentiator** |
| Time-Block Mode | ❌ | ✅ P0 | **NEW — core differentiator** |
| Stopwatch Mode | ✅ (separate) | ✅ P0 (unified) | Integrated into focus engine |
| Task Management | ✅ | ✅ P0 | + energy levels (P1) |
| Task energy tags | ❌ | 🟡 P1 | **NEW** |
| Analytics by mode | ❌ | ✅ P0 | **NEW — mode comparison** |
| Mode Intelligence | ❌ | 🟡 P1 | **NEW** |
| Soundscapes | ❌ | 🟡 P1 | **NEW** |
| Widgets | ❌ | ✅ P0 | Same |
| Live Activities | ❌ | ✅ P0 | + multi-mode support |
| Apple Watch | ❌ | ✅ P0 | + mode selection |
| Siri/Shortcuts | ❌ | ✅ P0 | + mode-specific commands |
| Focus Modes | ❌ | 🟡 P1 | Same |
| Apple Health | ❌ | 🟡 P1 | Same |
| Streaks | ❌ | 🟡 P1 | Same |
| Recurring tasks | ❌ | 🟡 P1 | Same |
| Premium ($35/yr) | ✅ RevenueCat | StoreKit 2 P1 | **Higher price tier** |
| Session journaling | ❌ | 🔴 P2 | **NEW** |

---

## Appendix B: Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Scope creep from 4 focus modes | High | High | Modes share 80% of timer engine. Strict P0 discipline. |
| "Deep Work" positioning too niche | Medium | Medium | Free tier has Pomodoro (universal appeal). Premium unlocks the niche. |
| Users confused by 4 modes | Medium | Medium | Excellent onboarding. Smart defaults (start with Pomodoro). Mode Intelligence guides over time. |
| Higher price reduces LATAM adoption | Medium | High | LATAM pricing at 40-60% of US. Generous free tier. |
| CloudKit sync edge cases | Medium | Critical | Test extensively. Additive merge. Local backups. |
| Solo developer bandwidth | High | High | Claude Code Max 5x. Focus modes share engine code. |
| Apple rejects for similarity | Low | High | Unique multi-mode concept. No close competitor does this. |
