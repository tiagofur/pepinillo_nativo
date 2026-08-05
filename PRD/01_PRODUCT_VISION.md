# Pepinillo — Product Vision: Deep Work Operating System

**Version:** 1.1  
**Last Updated:** 2026-04-21  
**Author:** Tiago David + Claude Code  
**Status:** Active  
**Platforms:** iOS, Android, watchOS, Wear OS  
**Update Cadence:** Per-feature

---

## 1. Problem

Knowledge workers, students, and creatives do not just need a timer. They need a **deep-work execution loop**: decide what matters, start fast, stay in flow, and learn what actually works. The market response is still fragmented:

- **Pomodoro timers** (Forest, Focus Keeper, Brain Focus) offer one rigid technique and weak planning.
- **Task managers** (Things 3, Todoist, TickTick) help organize work, but they do not turn that plan into focused execution.
- **Calendar / time-blocking apps** (Structured) shine at scheduling, but not at flexible focus methods or reflection.
- **AI productivity tools** are often vague assistants with little behavioral truth behind them.

**The real gap is not "better timer features". The gap is a product that connects planning, execution, and reflection in one native experience.**

Pepinillo started as a Flutter Pomodoro app. While functional, it had two critical limitations: (1) it was locked to Pomodoro as the center of the product, and (2) Flutter's abstraction blocked the native platform integration required for a premium experience.

**The opportunity:** reposition Pepinillo from "another focus timer" to **the deep-work operating system for knowledge workers and creatives**. That means:

1. **Multiple focus techniques** so the app adapts to the user instead of forcing one method
2. **Medium-depth planning** strong enough for daily deep work without becoming a bloated PM tool
3. **Reflective intelligence** that helps users improve, not just log time
4. **Native ecosystem depth** across Apple and Android surfaces
5. **LATAM-first pricing and localization** in a premium category with weak regional competition

---

## 2. Vision

> **"Pepinillo is the calm, native operating system for deep work."**
>
> You decide what matters, start focusing in seconds, reflect on what worked, and repeat across every device you actually use.

The name "Pepinillo" (pickle/gherkin) is a playful contrast with the seriousness of deep work — memorable, accessible, and distinctive in a market full of generic names like "Focus Timer Pro" and "Session."

### Product Pillars

| Pillar | Job | Guardrail |
| ------ | --- | --------- |
| **Execute** | Start a session fast, stay in focus, complete meaningful work | The hero surface must remain calm, obvious, and one-tap fast |
| **Plan** | Turn work into a realistic deep-work plan | Medium depth only; serious personal planning, not team PM |
| **Reflect** | Understand patterns, review progress, and improve behavior | Analytics must teach something, not just display charts |
| **Admin** | Manage identity, settings, subscription, export, and support | Admin flows must not pollute daily focus/navigation |

### Primary Product Surfaces

| Surface | Purpose |
| ------- | ------- |
| **Focus** | Hero execution surface: timer, mode, active task, session state |
| **Plan** | Inbox, today, upcoming, lightweight projects/areas, task detail |
| **Dashboard** | Reviews, analytics, goals, reportes, and coaching |
| **Account / Admin** | Profile, auth, subscription, settings, sync state, export, help |

**Experience rule:** on phone, only `Focus`, `Plan`, and `Dashboard` are primary productivity destinations. `Account / Admin` is essential, but lives off the main work axis.

### Platform Availability

| Platform            | Native Stack                       | Status         |
| ------------------- | ---------------------------------- | -------------- |
| **iOS (iPhone)**    | Swift + TCA + SwiftData            | In Development |
| **Android (Phone)** | Kotlin + MVI (Circuit) + Room      | In Development |
| **watchOS**         | SwiftUI native                     | In Development |
| **Wear OS**         | Jetpack Compose                    | In Development |
| **Windows**         | WinUI 3 / Windows App SDK (C#)     | In Development |
| **Web (companion)** | Lightweight SPA (planned: SvelteKit + TS) | **Planned** — product approved; not shipped ([PRD/14](14_WEB_CLIENT_DECISION_BRIEF.md)) |
| **iPad**            | SwiftUI (NavigationSplitView)      | Planned        |
| **macOS**           | SwiftUI native                     | Planned        |
| **Android Tablets** | Jetpack Compose (adaptive layouts) | Planned        |

**Web role:** companion extra (larger screen without install). Free = browser-local with Free caps; Everywhere/AI+ unlocks web-capable premium features + backend sync. Not a fourth native OS — OS-exclusive surfaces stay N/A. Canonical decision: [14_WEB_CLIENT_DECISION_BRIEF.md](14_WEB_CLIENT_DECISION_BRIEF.md).

---

## 3. Objectives

| #      | Objective                                                                                                            | Metric                                                                                                                               |
| ------ | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **G1** | **Be the best daily deep-work experience** — Pepinillo must feel as if Apple/Google built it for their ecosystems   | App Store rating >= 4.7; Play Store rating >= 4.5; featured editorial placement in at least one store within 6 months               |
| **G2** | **Own the execution loop** — users can move from intent to timer-running in seconds                                  | >= 60% of retained users start sessions in <= 10 seconds from app, widget, watch, or voice entry                                     |
| **G3** | **Planning that earns its place** — strong enough for daily deep work without becoming a generic task manager        | >= 50% of retained users link tasks to sessions or actively use planning views weekly                                                 |
| **G4** | **Reflection that changes behavior** — reviews and coaching must improve choices, not just describe history          | >= 35% of retained users open Weekly Review monthly; >= 20% of mode recommendations lead to action                                   |
| **G5** | **Premium conversion through undeniable value** — users pay because Execute + Plan + Reflect feels materially better | Premium conversion >= 8%; ARPU >= $3.50/month                                                                                         |
| **G6** | **Ecosystem depth as moat** — no competitor matches our cross-device entry and control surfaces                      | >= 60% of focus sessions started outside the main app (widgets, watch/wear, Siri/Assistant, Dynamic Island/notification)            |
| **G7** | **Cross-platform mental-model parity** — same product logic, native visual execution                                 | 100% of P0 features on iOS and Android simultaneously; canonical `Focus / Plan / Dashboard / Account` model shared across phone apps |
| **G8** | **Lead the LATAM premium productivity lane**                                                                          | Top 10 Productivity in Brazil and Mexico within 12 months; 40%+ of the user base in LATAM                                            |

---

## 4. No-Objectives

| #       | No-Objective                                | Reason                                                                                                      |
| ------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **NG1** | **No team/collaboration features**          | Individual deep work comes first; B2B is a separate initiative                                              |
| **NG2** | **No note-taking / document editor**        | We complement apps like Craft, Notion, and Google Docs; we do not replace them                              |
| **NG3** | **No autonomous AI project manager in MVP** | MVP AI is reflection + coaching + recommendations. Scheduling help and subtask generation are post-MVP only |
| **NG4** | **No meditation / wellness brand pivot**    | Calm is the tone, but Pepinillo remains a productivity tool, not a relaxation product                       |
| **NG5** | **No ambient music creation / marketplace** | Curated soundscapes are enough; we are not building an audio business                                       |
| **NG6** | **No web / desktop promise before reality** | Do not market or sell web/macOS value until a real client ships. **Web product model is approved** as a planned companion ([PRD/14](14_WEB_CLIENT_DECISION_BRIEF.md)); commercial promise stays off until W1+ exists. |
| **NG7** | **No calendar replacement**                 | We align with Apple Calendar / Google Calendar; we do not compete with Fantastical or Google Calendar       |

> **Note:** The former iOS NG1 ("Android remains on Flutter") is **obsolete**. Android is now native Kotlin with full parity.

---

## 5. Target Users

### P0 — Core (Launch)

| Segment               | Description                                                                      | Platforms    |
| --------------------- | -------------------------------------------------------------------------------- | ------------ |
| **Knowledge Workers / Creatives** | Writers, analysts, researchers, designers, and builders who do deep work daily | iOS, Android |
| **Remote Workers**    | Need daily structure, flexible focus methods, and reliable personal planning     | iOS, Android |
| **LATAM Students**    | Need affordable pricing, Spanish/Portuguese support, and multiple study techniques | iOS, Android |
| **Professionals rebuilding focus habits** | People who already know they are distracted and want a calmer execution loop | iOS, Android |

### P1 — Expansion

| Segment                 | Description                                                               | Platforms        |
| ----------------------- | ------------------------------------------------------------------------- | ---------------- |
| **ADHD / flexible cognition users** | Multiple techniques for different mental states; flexibility is essential | iOS, Android     |
| **Watch Users**         | Want to control the timer from their wrist without taking out their phone | watchOS, Wear OS |
| **Cal Newport Readers** | Already convinced by deep work; looking for the tool that implements it   | iOS, Android     |

### P2 — Future

| Segment                    | Description                                               | Platforms             |
| -------------------------- | --------------------------------------------------------- | --------------------- |
| **Tablet Users**           | Productivity on large screens, split-screen, multitasking | iPad, Samsung Tablets |
| **Developers / Creatives** | Long coding or design sessions; prefer Flowtime           | iOS, Android          |

---

## 6. Focus Modes — The Differentiator

Unlike pure Pomodoro apps, Pepinillo offers **four focus techniques** that users can switch between freely. This is the biggest differentiator versus the entire competitive set. **All four modes are identical in behavior and UX across all platforms.**

### 6.1 Pomodoro Mode (FREE)

| Aspect       | Detail                                                                                            |
| ------------ | ------------------------------------------------------------------------------------------------- |
| **Mechanic** | Classic 25/5/15 cycles with full duration customization                                           |
| **Behavior** | Auto-advances through work -> break -> work cycles. Shows current Pomodoro count (e.g., "3 of 4") |
| **Best for** | Studying, administrative tasks, and any work that benefits from rigid structure                   |
| **Tier**     | FREE                                                                                              |

### 6.2 Flowtime Mode (APPLE)

| Aspect       | Detail                                                                                                      |
| ------------ | ----------------------------------------------------------------------------------------------------------- |
| **Mechanic** | Open-ended focus session. No forced intervals. The user taps to take a break when concentration drops       |
| **Behavior** | The app suggests break duration based on focused time (10 min focus -> 2 min break, 50 min -> 10 min break) |
| **Best for** | Creative work, writing, programming — any activity where interrupting flow is counterproductive             |
| **Tier**     | APPLE                                                                                                       |

> **Why this matters:** Many productivity experts (including Cal Newport) argue that forced 25-minute blocks interrupt flow states. Flowtime captures the audience that tried Pomodoro and abandoned it.

### 6.3 Time-Block Mode (APPLE)

| Aspect       | Detail                                                                                                                 |
| ------------ | ---------------------------------------------------------------------------------------------------------------------- |
| **Mechanic** | Fixed focus block (e.g., "2 hours of writing"). A continuous countdown with optional midpoint check-ins                |
| **Behavior** | Tracks how many blocks are completed per day. Integrates with Apple Calendar / Google Calendar to display blocked time |
| **Best for** | Users of the time-blocking technique; full-day planning                                                                |
| **Tier**     | APPLE                                                                                                                  |

> **Why this matters:** Time-blocking is the #1 technique recommended by Cal Newport in "Deep Work." Currently, no major app implements it as a first-class timer mode.

### 6.4 Stopwatch Mode (FREE)

| Aspect       | Detail                                                                                                |
| ------------ | ----------------------------------------------------------------------------------------------------- |
| **Mechanic** | Open timer that counts up. No pressure, no targets. It only tracks how long you work                  |
| **Behavior** | Tap to pause. Tap to stop. No interruption notifications                                              |
| **Best for** | Days when you just want to sit and work without a technique telling you when to stop; casual tracking |
| **Tier**     | FREE                                                                                                  |

### 6.5 Mode Intelligence (P1)

After **2+ weeks of data**, Pepinillo suggests which mode works best for different task types based on completion rates and user interruption patterns.

> _"You complete 80% more writing tasks with Flowtime. Want to use it for today's blog post?"_

**Available on:** iOS and Android (same logic, platform-specific data).

---

## 7. User Stories

### 7.1 Focus Session Experience

| ID    | Story                                                                                                                                                                            | Platform          |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| US-1  | As a developer starting a coding session, I want to choose Flowtime mode and begin focusing with one tap so my concentration is not artificially interrupted by rigid intervals. | [All]             |
| US-2  | As a student preparing for exams, I want to use 25/5 Pomodoro mode from my lock screen widget so I can start studying without unlocking my phone.                                | [All]             |
| US-3a | As a writer blocking 3 hours for a novel, I want to set up a Time-Block and see it in Dynamic Island so I always know how much of my block remains.                              | [iOS]             |
| US-3b | As a writer blocking 3 hours for a novel, I want to set up a Time-Block and see it in my persistent notification so I always know how much of my block remains.                  | [Android]         |
| US-4a | As a remote worker who only wants to track focus time, I want to start a Stopwatch from my Apple Watch and forget about it until I finish.                                       | [iOS/watchOS]     |
| US-4b | As a remote worker who only wants to track focus time, I want to start a Stopwatch from my Wear OS watch and forget about it until I finish.                                     | [Android/Wear OS] |
| US-5a | As an Apple Focus Modes user, I want Pepinillo to automatically activate my "Deep Work" mode when I start any focus session.                                                     | [iOS]             |
| US-5b | As an Android user, I want Pepinillo to activate Focus Mode / Do Not Disturb when I start any focus session.                                                                     | [Android]         |
| US-6a | As someone who prefers voice commands, I want to say "Hey Siri, start a 2-hour deep work block in Pepinillo."                                                                    | [iOS]             |
| US-6b | As someone who prefers voice commands, I want to say "Hey Google, start a 2-hour deep work block in Pepinillo."                                                                  | [Android]         |
| US-7  | As a user who has tried multiple techniques, I want Pepinillo to show which focus mode gives me the best results for different task types.                                       | [All]             |

### 7.2 Task Management

| ID     | Story                                                                                                                                                       | Platform  |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| US-8   | As a freelancer with multiple clients, I want to create tasks with subtasks and assign estimated focus time to each one so I can plan my day realistically. | [All]     |
| US-9   | As a power user, I want to tag tasks with energy levels (deep work, shallow work, admin) to group similar work.                                             | [All]     |
| US-10  | As someone with recurring responsibilities, I want recurring tasks that appear automatically each day/week.                                                 | [All]     |
| US-11a | As an Apple Reminders user, I want to import tasks from Reminders to have a consolidated view.                                                              | [iOS]     |
| US-11b | As a Google Tasks user, I want to import tasks from Google Tasks to have a consolidated view.                                                               | [Android] |
| US-12  | As a student, I want to drag tasks to reorder by priority and see the total estimated focus time for my day.                                                | [All]     |

### 7.3 Analytics and Growth

| ID     | Story                                                                                                                                                                         | Platform  |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| US-13  | As someone optimizing my productivity, I want to see which focus mode I use most, which gives me the best completion rate, and when I am most productive (hour, day of week). | [All]     |
| US-14a | As a health-conscious professional, I want my focus time logged in Apple Health as Mindful Minutes.                                                                           | [iOS]     |
| US-14b | As a health-conscious professional, I want my focus time logged in Google Health Connect as Mindful Minutes.                                                                  | [Android] |
| US-15  | As a user reviewing my week, I want a "Weekly Review" that compares my focus hours, completed tasks, and streak against last week, with trend arrows.                         | [All]     |
| US-16  | As someone motivated by consistency, I want a focus streak (consecutive days with >= 1 completed session) with milestones at 7, 30, 100, and 365 days.                        | [All]     |

### 7.4 Multi-Device and Sync

| ID     | Story                                                                                                                       | Platform         |
| ------ | --------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| US-17a | As someone who starts tasks on Mac and continues on iPhone, I want CloudKit sync within seconds.                            | [iOS]            |
| US-17b | As someone who uses multiple Android devices, I want backend sync within seconds.                                           | [Android]        |
| US-18a | As an Apple Watch user, I want to see my task list, start any focus mode, and receive haptic feedback when my session ends. | [watchOS]        |
| US-18b | As a Wear OS user, I want to see my task list, start any focus mode, and receive haptic feedback when my session ends.      | [Wear OS]        |
| US-19a | As an iPad user, I want Pepinillo in Split View next to my writing app with keyboard shortcuts for quick timer control.     | [iOS/iPad]       |
| US-19b | As a Samsung tablet user, I want Pepinillo in split-screen next to my work app.                                             | [Android/Tablet] |

### 7.5 Personalization

| ID     | Story                                                                                                                                                  | Platform  |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- |
| US-20a | As someone who values aesthetics, I want multiple selectable themes (Classic, Forest, Ocean, Sunset) on iOS 26, plus the iOS 26 system glass aesthetic applied app-wide. | [iOS]     |
| US-20b | As someone who values aesthetics, I want dynamic Material You theming based on my wallpaper.                                                           | [Android] |
| US-21  | As a user who works at night, I want ambient soundscapes (rain, cafe, white noise) to play during focus sessions and stop automatically during breaks. | [All]     |

### 7.6 Ecosystem

| ID     | Story                                                                                                     | Platform  |
| ------ | --------------------------------------------------------------------------------------------------------- | --------- |
| US-22a | As an iOS power user, I want to start quick sessions from the Control Center Quick Settings tile.         | [iOS]     |
| US-22b | As an Android power user, I want to start quick sessions from the notification panel Quick Settings tile. | [Android] |
| US-23a | As a calendar user, I want my Time-Blocks to appear in Apple Calendar.                                    | [iOS]     |
| US-23b | As a calendar user, I want my Time-Blocks to appear in Google Calendar.                                   | [Android] |

### 7.7 Edge Cases

| ID     | Story                                                                                                                | Platform          |
| ------ | -------------------------------------------------------------------------------------------------------------------- | ----------------- |
| US-24  | As a user who receives a call mid-session, I want the timer to handle the interruption gracefully (pause or log it). | [All]             |
| US-25  | As a user who force-quits the app, I want my timer to continue and alert me when it completes.                       | [All]             |
| US-26a | As a user switching devices, I want my active iPhone session to appear on my Watch immediately.                      | [iOS/watchOS]     |
| US-26b | As a user switching devices, I want my active Android phone session to appear on my Wear OS watch.                   | [Android/Wear OS] |

---

## 8. Cross-Platform Parity Principle

### Mandatory Rule

Cross-platform parity is **MANDATORY** in this project. This means:

> **Every feature built on one platform MUST be built on the other. Every bug fixed on one platform MUST be verified and fixed on the other.**

### Parity Matrix

| Change in...      | Must be verified and applied in... |
| ----------------- | ---------------------------------- |
| Android phone     | iOS phone, Wear OS, watchOS        |
| iOS phone         | Android phone, Wear OS, watchOS    |
| Wear OS           | watchOS, Android phone, iOS phone  |
| watchOS           | Wear OS, Android phone, iOS phone  |
| Android + Wear OS | iOS + watchOS                      |
| iOS + watchOS     | Android + Wear OS                  |

### Parity Implementation

| Aspect              | iOS / watchOS                  | Android / Wear OS                              |
| ------------------- | ------------------------------ | ---------------------------------------------- |
| **Language**        | Swift                          | Kotlin                                         |
| **UI Framework**    | SwiftUI                        | Jetpack Compose                                |
| **Architecture**    | TCA (Composable Architecture)  | MVI (Circuit/Orbit)                            |
| **Local database**  | SwiftData                      | Room                                           |
| **Sync**            | CloudKit + Backend Go (REST)   | Backend Go (REST API)                          |
| **Widgets**         | WidgetKit                      | Glance (Jetpack Compose)                       |
| **Live activity**   | Live Activity + Dynamic Island | Rich Ongoing Notification (Foreground Service) |
| **Watch**           | watchOS (SwiftUI native)       | Wear OS (Compose)                              |
| **Voice assistant** | Siri Shortcuts (App Intents)   | Google Assistant App Actions                   |
| **Quick control**   | Control Center Widget          | Quick Settings Tile                            |
| **Health**          | Apple HealthKit                | Google Health Connect                          |
| **Payments**        | StoreKit 2                     | Google Play Billing 7                          |
| **OS focus mode**   | Apple Focus Filters            | Android Focus Mode / DND                       |
| **Theming**         | 4 manual themes + iOS 26 system glass | Material You (Dynamic Color)                   |

### Verification Process

1. **When fixing a bug:** Before closing the issue, verify whether the same bug can exist on the other platform. If yes, fix it.
2. **When implementing a feature:** The feature is not considered complete until it exists on both platforms with equivalent behavior.
3. **In code review:** Always ask: "Does this have an equivalent on the other platform? Is it up to date?"

### Acceptable Exceptions

The only acceptable differences are those **imposed by the platform**:

- Dynamic Island (only iOS) vs. Ongoing Notification (only Android)
- CloudKit as secondary sync layer (iOS only) alongside shared Backend REST sync
- Material You dynamic theming (only Android) vs. iOS 26 system glass aesthetic (only iOS)
- Apple Reminders import (iOS) vs. Google Tasks import (Android)
- Siri (iOS) vs. Google Assistant (Android)

In all these cases, **equivalent functionality** must exist even if the technical implementation differs.

---

_This document unifies and replaces the individual platform PRDs (`PRD_IOS/01_PRD_PEPINILLO_NATIVE.md` and `PRD_ANDROID/01_PRD_PEPINILLO_ANDROID.md`) as the source of truth for product vision._
