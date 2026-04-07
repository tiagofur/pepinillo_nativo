---
status: in_progress
generated: 2026-04-07
agents:
  - type: "mobile-specialist"
    role: "Primary implementation of Android-specific fixes."
  - type: "architect-specialist"
    role: "Design background sync and battery-safe widget updates."
  - type: "security-auditor"
    role: "Ensure RevenueCat key and sync gating are secure."
  - type: "test-writer"
    role: "Verify fixes with unit and integration tests."
docs:
  - "project-overview.md"
  - "architecture.md"
phases:
  - id: "wave-1"
    name: "Stability & Policy (P0)"
    prevc: "P"
    agent: "mobile-specialist"
  - id: "wave-2"
    name: "Google Native Polish (P1)"
    prevc: "E"
    agent: "mobile-specialist"
  - id: "wave-3"
    name: "UX Refinement (P2)"
    prevc: "V"
    agent: "mobile-specialist"
---

# Android Audit Fixes Plan

> Fixing P0, P1, and P2 issues identified in ANDROID-JUDGE.md to achieve production readiness for the Android app.

## Task Snapshot
- **Primary goal:** Resolve 14 identified issues (4 P0, 6 P1, 4 P2) to ensure system stability, security, and a high-quality "Google-Native" user experience.
- **Success signal:** All P0 and P1 issues fixed, app passes a follow-up audit with no blocking issues, and background battery drain is within acceptable limits.
- **Key references:**
  - [ANDROID-JUDGE.md](../../docs/ANDROID-JUDGE.md)
  - [Architecture Notes](../docs/architecture.md)

## Codebase Context
- **Primary Platform:** Android (Compose, Material 3, Hilt, Room, WorkManager)
- **Architecture layers:** Services, UI, Data Sync, Wear OS, Billing

## Agent Lineup
| Agent | Role in this plan | Playbook | First responsibility focus |
| --- | --- | --- | --- |
| Mobile Specialist | Primary implementation of Android-specific fixes. | [Mobile Specialist](../agents/mobile-specialist.md) | Focus on FocusTimerService and SyncEngine fixes. |
| Architect Specialist | Design background sync and battery-safe widget updates. | [Architect Specialist](../agents/architect-specialist.md) | Redesign widget update mechanism. |
| Security Auditor | Ensure RevenueCat key and sync gating are secure. | [Security Auditor](../agents/security-auditor.md) | Verify BuildConfig implementation. |
| Test Writer | Verify fixes with unit and integration tests. | [Test Writer](../agents/test-writer.md) | Add tests for SyncEngine gating. |

## Working Phases

### Phase 1 — Wave 1: Stability & Policy (P0)
**Objective:** Fix blocking issues that prevent production submission or cause severe system issues.

**Tasks**
| # | Task | Agent | Status | Deliverable |
|---|------|-------|--------|-------------|
| 1.1 | Redesign `FocusTimerService` widget update loop (P0-1) | `mobile-specialist` | pending | Battery-safe widget updates |
| 1.2 | Move RevenueCat API key to `BuildConfig` (P0-2) | `mobile-specialist` | pending | Secure key management |
| 1.3 | Implement subscription gating in `SyncEngine` (P0-3) | `mobile-specialist` | pending | Restricted cloud sync |
| 1.4 | Implement Pro-gating in Wear OS via DataLayer (P0-4) | `mobile-specialist` | pending | Pro-gated Wear OS features |

### Phase 2 — Wave 2: "Google Native" Polish (P1)
**Objective:** Improve UX, performance, and platform consistency.

**Tasks**
| # | Task | Agent | Status | Deliverable |
|---|------|-------|--------|-------------|
| 2.1 | Implement Splash Screen API (P1-5) | `mobile-specialist` | pending | Branded splash screen |
| 2.2 | Add UI Locks/Gating in Compose (P1-1) | `mobile-specialist` | pending | Visual Pro-gating |
| 2.3 | Add `WorkManager` for background sync (P1-3) | `mobile-specialist` | pending | Reliable background sync |
| 2.4 | Audit and fix `sp` vs `dp` usage (P1-2) | `mobile-specialist` | pending | Accessibility compliance |
| 2.5 | Implement Pro-Theme Locking (P1-4) | `mobile-specialist` | pending | Subscription-locked themes |

### Phase 3 — Wave 3: UX Refinement (P2)
**Objective:** Final polish for a "Pixel-Feeling" experience.

**Tasks**
| # | Task | Agent | Status | Deliverable |
|---|------|-------|--------|-------------|
| 3.1 | Add Haptic Feedback to key actions (P2-1) | `mobile-specialist` | pending | Tactile interactions |
| 3.2 | Enable Predictive Back Gesture (P2-3) | `mobile-specialist` | pending | Modern navigation support |
| 3.3 | Fix Room Database Export Schema (P2-2) | `mobile-specialist` | pending | Clean build logs |

## Success Metrics
- 0 P0/P1 issues remaining.
- Successful build and local test run on Android 14 emulator/device.
- RevenueCat key not found in source code.
