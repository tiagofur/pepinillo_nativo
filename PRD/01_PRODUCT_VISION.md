# Pepinillo — Unified Product Document: Deep Work Platform for Multi-Platform

**Version:** 1.0  
**Last Updated:** 2026-03-24  
**Author:** Tiago David + Claude Code  
**Status:** Active  
**Platforms:** iOS, Android, watchOS, Wear OS  
**Update Cadence:** Per-feature

---

## 1. Problem

Knowledge workers, students, and creatives lose an average of **2.1 hours per day** to context switching and interruptions. The market's response has been fragmented:

- **Pomodoro timers** (Forest, Focus Keeper, Brain Focus) offer a single rigid technique.
- **Task managers** (Things 3, Todoist) don't integrate focus time.
- **Time-blocking apps** (Structured) lack flexible timer methods.

**No app combines multiple focus techniques + task management + deep analytics in one experience.** The market competes on price ($2-5) with single-technique apps. There is no premium solution that offers:

1. **4 focus techniques** in one app
2. **Integrated task management** with energy levels and recurrence
3. **Complete ecosystem** on both platforms (Apple: widgets, Dynamic Island, watchOS, Siri; Android: widgets, Wear OS, Quick Settings, Google Assistant)
4. **Mode-specific analytics** to discover which technique works best
5. **LATAM-first pricing** that's accessible

Pepinillo started as a Flutter Pomodoro app. While functional, it had two critical limitations: (1) it was locked to Pomodoro as the only focus method, and (2) Flutter's abstraction blocked access to native platform APIs that are essential for a premium experience.

**The opportunity:** Reposition Pepinillo from "another Pomodoro timer" (saturated market, low price ceiling) to **"the multi-platform deep work platform"** — a premium productivity tool that offers multiple focus techniques, integrated task management, and the deepest possible integration with Apple and Android ecosystems. This moves us from competing with $3.99 apps to the premium tier of $30-60/year.

---

## 2. Vision

> **"Pepinillo is your command center for deep work."**
>
> An app where you plan what to work on, choose how to focus, track your progress, and build lasting productivity habits — all integrated natively into your Apple and Android devices.

The name "Pepinillo" (pickle/gherkin) is a playful contrast with the seriousness of deep work — memorable, accessible, and distinctive in a market full of generic names like "Focus Timer Pro" and "Session."

### Platform Availability

| Platform            | Native Stack                       | Status         |
| ------------------- | ---------------------------------- | -------------- |
| **iOS (iPhone)**    | Swift + TCA + SwiftData            | In Development |
| **Android (Phone)** | Kotlin + MVI (Circuit) + Room      | In Development |
| **watchOS**         | SwiftUI native                     | In Development |
| **Wear OS**         | Jetpack Compose                    | In Development |
| **iPad**            | SwiftUI (NavigationSplitView)      | Planned        |
| **macOS**           | SwiftUI native                     | Planned        |
| **Android Tablets** | Jetpack Compose (adaptive layouts) | Planned        |

---

## 3. Objectives

| #      | Objective                                                                                                            | Metric                                                                                                                               |
| ------ | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **G1** | **Be THE deep work app** — Pepinillo must feel as if it were built by Apple/Google for their ecosystems respectively | App Store rating >= 4.7; Play Store rating >= 4.5; featured editorial placement in both stores within 6 months                       |
| **G2** | **Multi-mode focus** — Users choose the technique that works for them, not the one the app imposes                   | >= 3 modes used across the user base; Pomodoro accounts for < 60% of sessions (proving users want variety)                           |
| **G3** | **Premium conversion through undeniable value** — Users pay because the FREE tier already impressed them             | Premium conversion >= 8% (vs. industry avg 3-5% for timer apps); ARPU >= $3.50/month                                                 |
| **G4** | **Ecosystem depth as a competitive moat** — No competitor matches our integration breadth                            | >= 60% of focus sessions started outside the main app (widgets, Watch/Wear, Siri/Assistant, Dynamic Island/Notification)             |
| **G5** | **Lead the LATAM market** — First premium productivity app with LATAM-first pricing and localization                 | Top 10 Productivity in Brazil and Mexico within 12 months; 40%+ of the user base in LATAM                                            |
| **G6** | **Build lasting habits, not just usage** — Users develop real productivity improvements                              | >= 40% D30 retention; average streak >= 14 days among retained users                                                                 |
| **G7** | **Cross-platform parity** — Same features, same quality, across all platforms                                        | 100% of P0 features available on iOS and Android simultaneously; bugs fixed on one platform verified and fixed on the other platform |

---

## 4. No-Objectives

| #       | No-Objective                                | Reason                                                                                                      |
| ------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **NG1** | **No team/collaboration features**          | Individual deep work comes first; B2B is a separate initiative                                              |
| **NG2** | **No note-taking / document editor**        | We complement apps like Craft, Notion, and Google Docs; we do not replace them                              |
| **NG3** | **No AI task breakdown**                    | AI is only for insights and analysis (Mode Intelligence, Weekly Review); the workflow remains human-driven  |
| **NG4** | **No ambient music creation / marketplace** | Curated pre-included soundscapes are enough; we are not a music app                                         |
| **NG5** | **No web app parity target**                | The web app (Next.js) has its own separate roadmap                                                          |
| **NG6** | **No calendar replacement**                 | We integrate with Apple Calendar and Google Calendar; we do not compete with Fantastical or Google Calendar |

> **Note:** The former iOS NG1 ("Android remains on Flutter") is **obsolete**. Android is now native Kotlin with full parity.

---

## 5. Target Users

### P0 — Core (Launch)

| Segment               | Description                                                                      | Platforms    |
| --------------------- | -------------------------------------------------------------------------------- | ------------ |
| **Power Users**       | Apple users (iPhone/Watch) and Samsung/Pixel users seeking premium productivity  | iOS, Android |
| **LATAM Students**    | Need affordable pricing, Spanish/Portuguese support, and varied study techniques | iOS, Android |
| **Remote Workers**    | Need daily structure, Pomodoro + Time Blocks, and productivity tracking          | iOS, Android |
| **Knowledge Workers** | Professionals who do deep work regularly (writers, analysts, researchers)        | iOS, Android |

### P1 — Expansion

| Segment                 | Description                                                               | Platforms        |
| ----------------------- | ------------------------------------------------------------------------- | ---------------- |
| **ADHD Community**      | Multiple techniques for different mental states; flexibility is essential | iOS, Android     |
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

### 6.2 Flowtime Mode (PRO)

| Aspect       | Detail                                                                                                      |
| ------------ | ----------------------------------------------------------------------------------------------------------- |
| **Mechanic** | Open-ended focus session. No forced intervals. The user taps to take a break when concentration drops       |
| **Behavior** | The app suggests break duration based on focused time (10 min focus -> 2 min break, 50 min -> 10 min break) |
| **Best for** | Creative work, writing, programming — any activity where interrupting flow is counterproductive             |
| **Tier**     | PRO                                                                                                         |

> **Why this matters:** Many productivity experts (including Cal Newport) argue that forced 25-minute blocks interrupt flow states. Flowtime captures the audience that tried Pomodoro and abandoned it.

### 6.3 Time-Block Mode (PRO)

| Aspect       | Detail                                                                                                                 |
| ------------ | ---------------------------------------------------------------------------------------------------------------------- |
| **Mechanic** | Fixed focus block (e.g., "2 hours of writing"). A continuous countdown with optional midpoint check-ins                |
| **Behavior** | Tracks how many blocks are completed per day. Integrates with Apple Calendar / Google Calendar to display blocked time |
| **Best for** | Users of the time-blocking technique; full-day planning                                                                |
| **Tier**     | PRO                                                                                                                    |

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
| US-20a | As someone who values aesthetics, I want multiple themes including a Liquid Glass theme for iOS 26.                                                    | [iOS]     |
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
| **Sync**            | CloudKit                       | Backend Go (REST API)                          |
| **Widgets**         | WidgetKit                      | Glance (Jetpack Compose)                       |
| **Live activity**   | Live Activity + Dynamic Island | Rich Ongoing Notification (Foreground Service) |
| **Watch**           | watchOS (SwiftUI native)       | Wear OS (Compose)                              |
| **Voice assistant** | Siri Shortcuts (App Intents)   | Google Assistant App Actions                   |
| **Quick control**   | Control Center Widget          | Quick Settings Tile                            |
| **Health**          | Apple HealthKit                | Google Health Connect                          |
| **Payments**        | StoreKit 2                     | Google Play Billing 7                          |
| **OS focus mode**   | Apple Focus Filters            | Android Focus Mode / DND                       |
| **Theming**         | Manual themes + Liquid Glass   | Material You (Dynamic Color)                   |

### Verification Process

1. **When fixing a bug:** Before closing the issue, verify whether the same bug can exist on the other platform. If yes, fix it.
2. **When implementing a feature:** The feature is not considered complete until it exists on both platforms with equivalent behavior.
3. **In code review:** Always ask: "Does this have an equivalent on the other platform? Is it up to date?"

### Acceptable Exceptions

The only acceptable differences are those **imposed by the platform**:

- Dynamic Island (only iOS) vs. Ongoing Notification (only Android)
- CloudKit sync (iOS) vs. Backend REST sync (Android)
- Material You dynamic theming (only Android) vs. Liquid Glass (only iOS)
- Apple Reminders import (iOS) vs. Google Tasks import (Android)
- Siri (iOS) vs. Google Assistant (Android)

In all these cases, **equivalent functionality** must exist even if the technical implementation differs.

---

_This document unifies and replaces the individual platform PRDs (`PRD_IOS/01_PRD_PEPINILLO_NATIVE.md` and `PRD_ANDROID/01_PRD_PEPINILLO_ANDROID.md`) as the source of truth for product vision._
