# Effort Estimation & Phased Roadmap (v3 — Actualizado Marzo 2026)

**Date:** Marzo 15, 2026
**Assumption:** Solo developer (Tiago) + Claude (Cowork/Claude Code)
**Work pace:** ~20-30 hours/week
**Estado:** Core code completo (84 archivos Swift). Falta integración Xcode + features 2026.

---

## Cambio desde v2

El código base ya está escrito. Las fases originales 1-3 (Foundation, Ecosystem, Polish) se completaron en código. Lo que queda es:

1. **Integración Xcode** (targets, entitlements, SPM, build)
2. **Features 2026** (widgets interactivos, Liquid Glass, Siri completo, StandBy, etc.)
3. **Testing real** en devices
4. **Launch**

Esto reduce el timeline total de ~31 semanas a ~8-12 semanas.

---

## Fase A: Setup & Integración Xcode (Semanas 1-3)

**Goal:** Proyecto compilando en Xcode con todos los targets funcionando.

| Task | Hours | Notes |
|------|-------|-------|
| Crear proyecto Xcode con estructura multi-target | 4h | Main app, Widget, Watch, Intents, LiveActivity, ControlCenter |
| Agregar SPM: `swift-composable-architecture` ≥ 1.17 | 2h | + swift-dependencies |
| Configurar App Group `group.com.pepinillo.app` | 2h | En todos los targets |
| Configurar CloudKit container | 4h | `iCloud.com.pepinillo.app` + SwiftData sync |
| Asignar archivos a targets correctos | 4h | ModeColors, WatchConnectivityClient, etc. |
| Build & fix — resolver errores de compilación | 12h | TCA + SwiftData + multi-target |
| Info.plist entries (Health, Notifications, etc.) | 2h | |
| Entitlements (Focus Filter, HealthKit, Push) | 2h | |
| StoreKit config file + productos sandbox | 4h | Monthly, Annual, Lifetime |
| Agregar archivos de audio (8 soundscapes) | 4h | Buscar/comprar audio libre de regalías |
| Generar .xcstrings (EN, ES, PT) | 8h | Strings ya wrapped en código |
| Primer build en device real | 4h | iPhone + Watch |

**Fase A Total: ~52 hours (~2-3 semanas)**

**Milestone:** App compila y corre en device. Timer funciona. Datos persisten.

---

## Fase B: Features Competitivas (Semanas 4-7)

**Goal:** Paridad con Focus App y Structured en features de ecosistema 2026.

| Task | ID | Hours | Priority |
|------|----|-------|----------|
| **Siri + App Intents completos** | B4 | 16h | CRÍTICO |
| Completar TaskEntityQuery con queries reales | | 4h | |
| StopFocusIntent + CheckStatsIntent | | 6h | |
| Frases en 3 idiomas + Action Button | | 6h | |
| **Notificaciones con acciones contextuales** | B5 | 8h | ALTO |
| Categorías por fase + botones de acción | | 4h | |
| Timer persistente en notificación activa | B1 | 4h | |
| **Widgets interactivos** | B2 | 12h | ALTO |
| AppIntent buttons en widgets S/M/L | | 8h | |
| StandBy mode optimization | B3 | 4h | |
| **Liquid Glass theme** | B6 | 12h | ALTO |
| `.glassEffect()` en nav/tab bars | | 4h | |
| Material backgrounds en cards/sheets | | 4h | |
| Widget transparencies | | 4h | |
| **iPad + Stage Manager** | B7 | 16h | MEDIO |
| NavigationSplitView adaptativo | | 8h | |
| Keyboard shortcuts (⌘N, Space, ⌘.) | | 4h | |
| Stage Manager window sizing | | 4h | |
| **macOS nativo** | B8 | 32h | MEDIO |
| Menu bar extra con timer | | 12h | |
| Ventana principal | | 12h | |
| Keyboard-first UX + macOS conventions | | 8h | |
| **CloudKit sync testing** | — | 8h | ALTO |
| Multi-device sync verification | | 4h | |
| Offline conflict testing | | 4h | |
| **Unit + integration tests** | — | 16h | ALTO |
| Tests para nuevos intents | | 4h | |
| Tests para widgets interactivos | | 4h | |
| Integration tests Watch ↔ Phone | | 4h | |
| End-to-end timer background tests | | 4h | |

**Fase B Total: ~120 hours (~3-4 semanas)**

**Milestone:** App competitiva con Focus App y Structured. Widgets interactivos, Siri funcional, Liquid Glass, iPad, macOS.

---

## TestFlight + Polish (Semanas 8-10)

| Task | Hours |
|------|-------|
| TestFlight beta setup + invites (100+ users) | 4h |
| Bug fixes from beta feedback | 30h |
| Performance optimization (launch time, timer accuracy) | 8h |
| Accessibility audit final (VoiceOver, Dynamic Type, contrast) | 8h |
| App Store screenshots (iPhone, iPad, Mac, Watch) | 12h |
| App Store preview video | 8h |
| ASO: title, subtitle, keywords, description (EN/ES/PT) | 6h |
| Privacy Policy + Terms | 4h |

**TestFlight Total: ~80 hours (~2-3 semanas)**

---

## Launch (Semana 11)

| Task | Hours |
|------|-------|
| App Store submission | 4h |
| Marketing site / landing page | 8h |
| Launch campaign (ProductHunt, Reddit, Twitter, LATAM blogs) | 8h |
| Post-launch monitoring + hot fixes | 16h |

**Launch Total: ~36 hours (~1 semana)**

---

## Fase C: Diferenciadores (Post-Launch, Rolling)

**Goal:** Features premium que justifican el precio y separan de competidores.

| Task | ID | Hours | Impact |
|------|----|-------|--------|
| Session journaling | C1 | 10h | Retención |
| Apple Calendar integration | C3 | 14h | Power users |
| Shortcuts automations | C4 | 8h | Power users |
| Spotlight integration | C5 | 8h | Discoverability |
| Handoff entre devices | C2 | 16h | Ecosistema |
| ADHD-friendly mode | C7 | 12h | Nuevo segmento |
| Apple Intelligence insights | C6 | 12h | Modernidad |
| SharePlay social focus | C8 | 24h | Viral |

**Fase C Total: ~104 hours (rolling, 1-2 features por update)**

---

## Summary

| Fase | Hours | Semanas | Target |
|------|-------|---------|--------|
| A: Setup Xcode | 52h | 2-3 | Abril 2026 |
| B: Features 2026 | 120h | 3-4 | Mayo 2026 |
| TestFlight + Polish | 80h | 2-3 | Junio 2026 |
| Launch | 36h | 1 | Julio 2026 |
| **Pre-launch total** | **288h** | **8-11** | |
| C: Diferenciadores | 104h | Rolling | Ago-Dic 2026 |
| **Grand total** | **392h** | | |

**Comparación con v2:**
- v2 total: 814h / ~31 semanas
- v3 total: 392h / ~11 semanas (pre-launch) + rolling
- **Ahorro: ~52% de horas** gracias al código ya escrito

---

## Critical Path

```
Fase A: Xcode Setup
    ├── Crear proyecto + targets
    ├── SPM + App Groups + CloudKit
    ├── Build & fix
    └── Device testing
         ↓
Fase B: Features 2026
    ├── Siri completo (B4) ← CRITICAL
    ├── Notificaciones (B5 + B1)
    ├── Widgets interactivos (B2 + B3)
    ├── Liquid Glass (B6)
    ├── iPad (B7) ──→ macOS (B8)
    └── CloudKit sync testing
         ↓
TestFlight Beta
    ├── 100+ users
    ├── Bug fixes
    ├── Screenshots + ASO
    └── Accessibility audit
         ↓
    App Store Launch (Julio 2026)
         ↓
Fase C: Rolling Updates
    ├── C1: Journaling
    ├── C3: Calendar
    ├── C7: ADHD mode
    └── C6: Apple Intelligence
```

---

## Risk Register (Actualizado)

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Xcode build issues con TCA + SwiftData + multi-target | High | Medium | Compilar incrementalmente por target |
| CloudKit sync edge cases | Medium | High | Testing exhaustivo en beta. Offline-first. |
| Liquid Glass API changes en iOS 26 betas | Medium | Low | Conditional check `if #available(iOS 26, *)` |
| macOS port toma más de lo estimado | Medium | Medium | Lanzar sin Mac, agregar en v1.1 |
| Focused Work 5 gana tracción con múltiples modos | Medium | High | Lanzar rápido. Nuestro task management es diferenciador. |
| Solo developer bandwidth | High | High | Claude como co-developer. Focus en MVP. |
| Apple rechaza por duplicación | Low | High | Concepto multi-modo es único. Bien diferenciado. |
