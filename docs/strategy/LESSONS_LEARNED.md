# Pepinillo — Product Lessons Learned

## Purpose

This document captures the strategic lessons learned during Pepinillo's evolution. It is not a technical specification. Its goal is to preserve product context and decision reasoning for future contributors and AI agents.

---

# Origin

Pepinillo started as an early Flutter application and became an important personal project. The decision to rebuild it natively was not made because Flutter was insufficient, but because the product direction evolved toward deep operating-system integration.

Native implementations allow Pepinillo to better integrate with:

- iOS widgets
- Live Activities
- Dynamic Island
- Apple Watch
- Siri/App Intents
- Android widgets
- Wear OS
- platform-specific lifecycle behavior

The objective was not technology migration. The objective was a better product experience.

---

# What Worked Well

## Building a strong technical foundation

Pepinillo was built with production quality in mind:

- native mobile architecture;
- automated testing;
- CI/CD pipelines;
- backend separation;
- billing architecture;
- documentation-first development.

This foundation reduces future product risk.

## Focusing on the core experience

The most valuable part of Pepinillo is not the task manager or analytics screen. It is helping people enter and maintain focused work.

The core loop is:

```
Plan → Focus → Complete → Reflect
```

Future decisions should protect this loop.

---

# What Could Have Been Better

## Product validation should happen earlier

A common trap in software development is improving the product before validating whether users need it.

Pepinillo now has enough functionality to validate the market. The next phase should prioritize:

- users;
- retention;
- feedback;
- monetization signals.

Not simply more features.

---

# Platform Expansion Lessons

Windows and Web experiments were valuable because they answered technical questions.

They proved feasibility.

However, platform expansion should follow user demand, not only technical possibility.

Current priority:

```
Android + iOS growth

before

additional platforms
```

---

# AI Strategy Lesson

AI should enhance Pepinillo's mission, not replace it.

Pepinillo is not an AI application.

Pepinillo is a focus application that can use AI where it creates meaningful value:

- reflection;
- insights;
- planning assistance;
- coaching.

---

# Strategic Rule Going Forward

Before adding a major feature ask:

> Does this improve activation, retention, or revenue?

If the answer is unclear, the feature should probably wait.

---

# Product Mission

Pepinillo exists to help people do meaningful work with less distraction.

Technology is the tool.

Focus is the product.
