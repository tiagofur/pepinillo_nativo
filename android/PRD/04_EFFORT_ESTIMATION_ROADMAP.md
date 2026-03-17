# Estimación de Esfuerzo y Roadmap — Pepinillo Android

**Versión:** 1.0
**Fecha:** 2026-03-12

---

## 1. Supuestos

- **Desarrollador:** Tiago + Claude Code Max 5x
- **Horas/semana:** 20-25 horas (Android es proyecto secundario después de iOS launch)
- **Inicio:** Después de iOS launch (Q3 2026)
- **Ventaja:** La lógica de negocio y UX ya están resueltas por iOS — solo hay que adaptarlas a Android
- **Reutilización estimada:** ~40% del diseño/lógica se traduce directamente (Strategy pattern, modelos, flujos)

---

## 2. Comparación de Esfuerzo: iOS vs Android

| Área | iOS (horas) | Android (horas) | Ratio | Razón |
|------|-------------|-----------------|-------|-------|
| Focus Engine (Strategy) | 80 | 55 | 0.69x | Patrón ya diseñado, solo traducir |
| Task Management | 60 | 45 | 0.75x | Room + Circuit vs SwiftData + TCA |
| UI (Compose vs SwiftUI) | 120 | 100 | 0.83x | Compose es más verboso pero similar |
| Widgets | 40 | 50 | 1.25x | Glance es más nuevo, menos docs |
| Live Activity / Notification | 30 | 45 | 1.50x | Foreground Service es más complejo |
| Watch | 50 | 60 | 1.20x | Wear OS tiene más boilerplate |
| Assistant / Siri | 25 | 30 | 1.20x | App Actions XML + BII mapping |
| Backend Sync | 0 | 70 | N/A | iOS usa CloudKit; Android necesita sync engine |
| Auth | 20 | 30 | 1.50x | JWT + Go backend vs Sign in with Apple |
| Health | 15 | 20 | 1.33x | Health Connect es newer API |
| Billing | 20 | 35 | 1.75x | Play Billing es más complejo que StoreKit 2 |
| Testing | 60 | 50 | 0.83x | Circuit testing es excelente |
| Soundscapes | 25 | 25 | 1.0x | ExoPlayer ≈ AVAudioPlayer |
| Onboarding | 20 | 18 | 0.90x | Compose pages son simples |
| Settings | 15 | 15 | 1.0x | DataStore vs UserDefaults |
| Localization | 15 | 12 | 0.80x | Android string resources son straightforward |
| CI/CD + Store | 20 | 20 | 1.0x | GitHub Actions + Play Console |
| Polish + QA | 60 | 70 | 1.17x | Fragmentación Android requiere más testing |
| **TOTAL** | **~675** | **~750** | **1.11x** | |

**Conclusión:** Android toma ~11% más horas que iOS, principalmente por:
1. Sync engine custom (vs CloudKit automático)
2. Foreground Service complexity (vs Live Activities)
3. Play Billing complexity (vs StoreKit 2)
4. OEM fragmentation testing

---

## 3. Roadmap por Fases

### Phase 1: Foundation (Semanas 1-10) — 250 horas

| Semana | Tarea | Horas | Claude Code % |
|--------|-------|-------|---------------|
| 1 | Proyecto Android + Gradle + Hilt + CI setup | 20 | 70% |
| 1-2 | Room database + entities + DAOs + migrations | 25 | 80% |
| 2-3 | Domain models (FocusMode, FocusPhase, FocusConfig) | 15 | 90% |
| 3-4 | Strategy pattern: 4 mode strategies | 30 | 70% |
| 4-5 | FocusEngine (coroutines, StateFlow) | 25 | 50% |
| 5-6 | FocusPresenter (Circuit) + FocusScreen (Compose) | 30 | 60% |
| 6-7 | TaskListPresenter + TaskListScreen + TaskDetail | 25 | 70% |
| 7-8 | Auth (JWT login/register via Go backend) | 20 | 60% |
| 8-9 | Sync engine (Room ↔ Backend, dirty flags) | 35 | 40% |
| 9-10 | Onboarding flow (5 screens, mode test) | 20 | 80% |
| 10 | Unit tests (domain, presenters, DAOs) | 25 | 70% |

**Milestone:** App funcional con 4 modos, tasks, auth, y sync.

### Phase 2: Ecosystem (Semanas 11-18) — 220 horas

| Semana | Tarea | Horas | Claude Code % |
|--------|-------|-------|---------------|
| 11-12 | Foreground Service + ongoing notification | 30 | 50% |
| 12-13 | Home Screen widgets (Glance: timer + stats) | 30 | 60% |
| 13-14 | Quick Settings Tile | 15 | 80% |
| 14-15 | Wear OS: timer screen + mode picker | 35 | 50% |
| 15-16 | Wear OS: tile + complication + phone sync | 25 | 50% |
| 16-17 | Google Assistant App Actions | 20 | 70% |
| 17 | Tablet/foldable adaptive layouts | 20 | 60% |
| 17-18 | Material You dynamic color + theming | 15 | 80% |
| 18 | Integration tests (sync, notification, widget) | 30 | 60% |

**Milestone:** Ecosistema Android completo: widgets, notificación, Wear OS, Assistant.

### Phase 3: Polish (Semanas 19-25) — 185 horas

| Semana | Tarea | Horas | Claude Code % |
|--------|-------|-------|---------------|
| 19 | Dashboard + analytics charts (Vico) | 20 | 70% |
| 19-20 | Weekly Review screen | 15 | 80% |
| 20 | Mode Intelligence service | 15 | 90% |
| 20-21 | Soundscapes (ExoPlayer, 6 tracks) | 20 | 60% |
| 21-22 | Google Health Connect integration | 15 | 60% |
| 22-23 | Google Play Billing 7 (subscriptions) | 30 | 40% |
| 23 | Recurring task generation engine | 10 | 90% |
| 23-24 | Google Tasks import | 15 | 60% |
| 24 | Streaks + achievements | 10 | 80% |
| 24-25 | Android Focus Mode / DND integration | 10 | 60% |
| 25 | Accessibility (TalkBack, font scaling) | 10 | 50% |
| 25 | Performance optimization + ProGuard | 15 | 40% |

**Milestone:** Feature-complete, listo para testing.

### Phase 4: Launch (Semanas 26-29) — 95 horas

| Semana | Tarea | Horas | Claude Code % |
|--------|-------|-------|---------------|
| 26 | Internal testing track en Play Store | 15 | 30% |
| 26-27 | Bug fixes de testing | 25 | 50% |
| 27-28 | OEM testing (Samsung, Pixel, Xiaomi, OnePlus) | 20 | 20% |
| 28 | Play Store listing (screenshots, descripción, ASO) | 15 | 60% |
| 28-29 | Beta (open testing track) | 10 | 30% |
| 29 | Launch (staged rollout 10% → 50% → 100%) | 10 | 30% |

**Milestone:** App publicada en Play Store.

---

## 4. Dependencias Críticas

```
Gradle setup → Room models → Domain models
    ↓                          ↓
Hilt DI ──────→ Strategy Pattern → FocusEngine → FocusPresenter → FocusScreen
                                       ↓
                              Foreground Service → Ongoing Notification
                                       ↓
                                  Glance Widgets
                                       ↓
                                   Wear OS sync

Room models → TaskPresenter → TaskScreen
    ↓
Sync Engine (requires Auth + Room + Ktor)
    ↓
Backend integration tests

Play Billing ──→ Paywall UI ──→ Feature gating
```

**Critical path:** Room → Domain → FocusEngine → FocusPresenter → Foreground Service → Widgets → Wear OS → Billing → Launch

---

## 5. Riesgos de Timeline

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Play Billing 7 complexity | +1-2 semanas | Start early, use billing-ktx samples |
| Wear OS DataLayer bugs | +1 semana | Minimal Wear OS MVP first |
| OEM battery kill issues | +1 semana | dontkillmyapp.com guidance + user education |
| Sync engine conflicts | +1 semana | Simple last-write-wins, no CRDT |
| Circuit learning curve | +0.5 semanas | Circuit docs are excellent; similar to TCA mental model |
| **Total risk buffer** | **+3-5 semanas** | |

**Adjusted timeline:** 29-34 semanas (7-8 meses)
**Target launch:** Q4 2026 - Q1 2027

---

## 6. Claude Code Efectividad por Fase

| Fase | Claude % | Mejor para | Human-only |
|------|----------|------------|------------|
| Phase 1 | 65% | Room entities, Circuit boilerplate, Strategy translation | Sync engine edge cases, auth flow |
| Phase 2 | 55% | Widget layouts, Tile service, App Actions XML | Foreground Service lifecycle, Wear OS real-device |
| Phase 3 | 60% | Health Connect, billing boilerplate, import logic | Play Billing testing, soundscape mixing |
| Phase 4 | 35% | Play Store description, bug triage | OEM testing, staged rollout |
| **Overall** | **~55%** | | |
