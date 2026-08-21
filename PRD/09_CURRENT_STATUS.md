# Pepinillo — Current Implementation Status

**Last Updated:** 2026-08-21  
**Version:** 3.x  
**Status:** Production + Growth Validation Phase

---

# 1. Product Phase

Pepinillo has moved from a product construction phase into a **growth validation phase**.

The main objective is no longer maximizing feature count. The objective is validating that real users:

1. Discover Pepinillo.
2. Understand its value.
3. Complete focus sessions.
4. Build a recurring habit.
5. Are willing to pay for premium features.

See:

- `docs/strategy/PRODUCT_DIRECTION.md`
- `docs/strategy/GROWTH_VALIDATION_PLAN.md`

---

# 2. Platform Status

| Platform | Status | Notes |
| --- | --- | --- |
| Android | Active Production Platform | Native Android app released and available. Current focus: stability, acquisition and retention. |
| iOS | Active Production Platform | Native iOS app released and available. Current focus: stability, acquisition and retention. |
| watchOS | Active Companion Platform | Supports Apple ecosystem experience. Maintained as part of iOS strategy. |
| Wear OS | Active Companion Platform | Supports Android ecosystem experience. Maintained as part of Android strategy. |
| Backend | Active Infrastructure | Required services and infrastructure should prioritize current mobile needs. |
| Windows | Paused Experiment | Technical feasibility validated. Not an active roadmap commitment. |
| Web Companion | Paused Experiment | Technical feasibility explored. Not an active roadmap commitment. |

---

# 3. Active Product Priorities

Current priorities:

## User Growth

- Improve onboarding.
- Improve store conversion.
- Acquire first meaningful group of real users.
- Collect qualitative feedback.

## Retention

- Improve the Focus → Complete → Return loop.
- Understand which focus modes create the most value.
- Improve daily and weekly engagement.

## Reliability

- Maintain Android and iOS production quality.
- Resolve critical bugs quickly.
- Improve automated confidence.

## Monetization

- Validate premium positioning.
- Measure conversion.
- Improve paywall clarity.

---

# 4. Product Direction

Pepinillo is a native deep-work companion.

The core experience is:

```
Plan → Focus → Complete → Reflect
```

Primary pillars:

## Focus

Helping users enter meaningful work sessions with minimal friction.

Supported methods:

- Pomodoro
- Flowtime
- Time Block
- Stopwatch

## Plan

Tasks exist to support focused execution.

Pepinillo is not intended to become a complete project management platform.

## Reflect

Analytics and reviews help users understand their work patterns.

---

# 5. Platform Decisions

## Active

- Android
- iOS
- watchOS
- Wear OS
- Backend services required for production functionality

## Paused

### Windows

Status: Archived exploration.

Reason:

The implementation validated technical feasibility, but current business validation must happen on mobile first.

Resume criteria:

- Proven mobile traction.
- User demand.
- Clear business justification.

### Web Companion

Status: Archived exploration.

Reason:

The companion experience was technically explored, but browser access is not a current growth priority.

Resume criteria:

- User demand.
- Sync maturity.
- Clear acquisition or retention benefit.

---

# 6. Monetization Direction

Current model:

## Pepinillo+

One-time purchase.

Provides premium local capabilities.

## Everywhere / AI+

Subscription model for recurring-cost capabilities such as:

- cloud features;
- advanced AI capabilities;
- future cross-device services.

The monetization strategy should be validated through real user behavior before expanding complexity.

---

# 7. Important Product Rules

Before implementing major features, evaluate:

- Does this improve activation?
- Does this improve retention?
- Does this improve monetization?
- Is there evidence users need it?

If the answer is unclear, document the idea but avoid prioritizing implementation.

---

# 8. Documentation Rules

Source of truth:

- `PRD/` → product requirements, roadmap and official status.
- `docs/strategy/` → strategic context and decision reasoning.
- `docs/` → technical documentation, guides and operational notes.

Avoid duplicated product status documents.

---

# 9. Current Strategic Statement

Pepinillo already has a strong technical foundation.

The next challenge is not building more software. The next challenge is proving product value with real users.

Technology enables the experience.

Focused work is the product.
