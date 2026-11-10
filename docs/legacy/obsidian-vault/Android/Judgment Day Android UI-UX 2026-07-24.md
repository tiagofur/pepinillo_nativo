---
tags:
  - android
  - wearos
  - judgment-day
  - ui
  - ux
  - material3
  - quality
aliases:
  - JD Android UI UX Jul 2026
  - Judgment Day Morphing Review
platform: android
type: audit
doc_role: quality-audit
status: active
date: 2026-07-24
updated: 2026-07-24
source: Judgment Day Round 1 (blind dual judges A+B)
branch_context: feat/sprint6-morphing-492
---

# Judgment Day — Android Phone + Wear OS (UI/UX + Functionality)

> [!abstract] Resumen
> Revisión adversarial completa (dos jueces ciegos) de la superficie Android phone (`android/app`) y Wear OS (`android/wear`), con foco en Material 3 Expressive, funcionalidad del timer, paridad free/Pro, i18n, recovery y competitividad en Play Store.
>
> **Fecha:** 2026-07-24  
> **Método:** Judgment Day Round 1 — judges A + B en paralelo  
> **Skills:** critique, impeccable, frontend-design, code-review  
> **Estado terminal Round 1:** hallazgos documentados + issues creados; **fixes pendientes de implementación** (no se auto-aplicaron).

---

## 1. Contexto y objetivo

Meta de producto: app **muy funcional, intuitiva y de las más bonitas de Play Store** (competencia Forest, Focus To-Do, structured, etc.).

Observación del usuario (seed): el Pomodoro se ve **cuadrado con cantos muy redondeados**; ¿es mejor? ¿Hay que replicarlo en todos los timers?

### Veredicto de diseño (consenso A+B)

| Opción | Veredicto |
|--------|-----------|
| Squircle permanente en todos los timers | **No** — se lee como chrome de card, no como reloj; pelea con glanceability y con hardware redondo de Wear |
| Círculo siempre | **Seguro y competitivo** como baseline |
| **Híbrido (recomendado)** | Círculo por defecto; morph a squircle solo en el **último ~20% elapsed** (urgencia periférica), con reduce-motion off; widget/tile/complication **siempre círculo** |

**Hallazgo clave:** el squircle al inicio/idle **no es un look deliberado premium** — es un **bug de polaridad** del morph (#492 regression). El countdown expone `progress` como **remaining** (`1.0` lleno → `0.0` done), y el morph interpreta `progress > 0.8` como urgencia → morph máximo al **inicio**.

---

## 2. Roadmap Material 3 Expressive (#487–#494) — auditoría

Serie de issues de diseño nativo:

| Issue | Sprint | Estado GitHub | Cumple AC real | Notas |
|------:|--------|---------------|----------------|-------|
| [#487](https://github.com/tiagofur/pepinillo_nativo/issues/487) | Wear Compose Material 3 | CLOSED (PR #495) | Sí (estructura) | Residual Wear UX fuera del AC |
| [#488](https://github.com/tiagofur/pepinillo_nativo/issues/488) | NavigationSuiteScaffold | CLOSED (PR #496) | Sí | Base nav OK |
| [#489](https://github.com/tiagofur/pepinillo_nativo/issues/489) | Shared elements + motion | CLOSED (PR #497) | Sí | Infra motion centralizada |
| [#490](https://github.com/tiagofur/pepinillo_nativo/issues/490) | Predictive Back | CLOSED (PR #498) | Sí | Manifest app-wide |
| [#491](https://github.com/tiagofur/pepinillo_nativo/issues/491) | Háptico centralizado | CLOSED (PR #499) | Sí | `PepinilloHaptics` + tests |
| [#492](https://github.com/tiagofur/pepinillo_nativo/issues/492) | Morph circular→squircle | **CLOSED (PR #500)** | **NO** | AC: morph con ≤20% restante; hoy morph al inicio. **Reabrir o trackear regresión** |
| [#493](https://github.com/tiagofur/pepinillo_nativo/issues/493) | ListDetailPaneScaffold | **OPEN** | WIP | Código en branch: `TasksAdaptiveLayout`, `DashboardAdaptiveLayout` |
| [#494](https://github.com/tiagofur/pepinillo_nativo/issues/494) | Palettes Forest/Ocean/Sunset Expressive | **OPEN** | No arrancado | Alto impacto “premium brand” |

> Nota: en GitHub hay **6 cerradas + 2 abiertas** (no 5). La #492 cerrada **no cumple** su propio acceptance criteria.

Documento de plan original: [[Diseño UI-UX Material3 Expressive]].

---

## 3. Tabla de veredictos Judgment Day (Round 1)

### 3.1 Confirmados (ambos jueces)

| ID | Hallazgo | Sev | Superficie | Archivos clave |
|----|----------|-----|------------|----------------|
| JD-01 | Morph invertido (remaining vs elapsed) | **CRITICAL** | Phone Focus ring | `TimerMorph.kt`, `FocusState.kt`, `FocusScreen.kt`, `TimerMorphTest.kt` |
| JD-02 | Phone remaining vs Wear elapsed → anillo salta en sync | **CRITICAL / WARNING** | Phone↔Wear | `FocusState.kt`, `WearTimerDisplay.kt`, tile/complication |
| JD-03 | Side-effect paywall en composition | **WARNING (real)** (B: CRITICAL) | Phone Focus | `FocusScreen.kt` (~298–301) |
| JD-04 | Pause metrics leídos pero nunca persistidos en recovery | **WARNING (real)** | Phone service | `FocusTimerService.kt` |
| JD-05 | UI ring muestreada a 1 Hz (comentario dice smooth/raw) | **WARNING (real)** | Phone Focus | `FocusViewModel.kt`, `FocusScreen.kt` |
| JD-06 | Free locked en tile/complication Wear; phone free tiene Pomodoro/Chrono | **WARNING (real)** | Wear | `FocusTileService.kt`, `FocusComplicationDataSource.kt` |
| JD-07 | Keys es/pt faltantes (~13–14) en phone | **WARNING (real)** | Phone i18n | `values-es/`, `values-pt/` |
| JD-08 | Strings/a11y Wear hardcode EN | **WARNING (real)** | Wear i18n | `TimerScreen.kt`, `TasksScreen.kt`, `WearViewModel.kt` |
| JD-09 | WaitingForNext usa `CircularProgressIndicator` ≠ morph ring | **WARNING / SUGGESTION** | Wear timer | `TimerScreen.kt` WaitingForNextLayout |

### 3.2 Sospechos (un solo juez) — se trackean igual

| ID | Hallazgo | Sev | Superficie |
|----|----------|-----|------------|
| JD-10 | Morph path no arranca a las 12 en punto (salto de origen al morph) | WARNING (real) | Phone + Wear rings |
| JD-11 | `Shape.kt` tokens ignorados; radii one-off en pantallas | WARNING (real) | Phone UI system |
| JD-12 | Wear hardcodea long-break cycle = 4 | WARNING (real) | Wear dots/tile |
| JD-13 | Recovery no suma wall-clock tras process death/reboot | **CRITICAL (suspect)** | Phone service |
| JD-14 | Locked modes en Wear: tap silencioso sin cue Pro | WARNING (real) | Wear TimerScreen |
| JD-15 | Skip optimista siempre ShortBreak en límite long-break | WARNING (theoretical) | WearViewModel |

### 3.3 Opcionales / polish (Play Store “perfecta”)

| ID | Hallazgo | Sev | Notas |
|----|----------|-----|-------|
| JD-16 | Tipografía solo `FontFamily.Default` | SUGGESTION | Brand display + body pairing |
| JD-17 | M3 Expressive motion tokens incompletos | SUGGESTION | Unificar motion scheme |
| JD-18 | Emoji como chrome primario del modo Focus | SUGGESTION | Preferir icons / jerarquía tipográfica |
| JD-19 | `GlassComponents` casi dead code | SUGGESTION | Usar una vez o borrar |
| JD-20 | Mode chips a 10.sp | SUGGESTION | ≥12.sp / layout más legible |
| JD-21 | Tests morph sin integración vs `FocusTimerState.progress` | SUGGESTION | Evitar regresión de polaridad |
| JD-22 | Tile active refresh 30s (stale glance) | SUGGESTION | 5–10s o confiar en complication |
| JD-23 | Two-pane solo `EXPANDED` (no `MEDIUM`) | WARNING (theoretical) | Tablets/fold landscape |
| JD-24 | Spring bouncy en cambio de modo vs reduce-motion | WARNING (theoretical) | Critically damped |
| JD-25 | Soundscape policy en WaitingForNext | WARNING (theoretical) | Fade on phase complete |
| JD-26 | Nav icons `contentDescription = null` | SUGGESTION | CD = label destino |
| JD-27 | Widget ring siempre circular + polarity remaining | SUGGESTION | Documentar excepción + alinear polarity |

### 3.4 Consistencia de shape language (timer)

| Superficie | Shape hoy | Progreso hoy | Acción |
|------------|-----------|--------------|--------|
| Phone Focus idle/start Pomodoro | Full squircle | remaining=1 → morph bug | Fix polaridad |
| Phone Focus last 20% | Circle | invertido | Fix polaridad |
| Phone Flow/Chrono | Circle | count-up | OK |
| Wear active (local tick) | Morph on elapsed | elapsed fill | Unificar semantic |
| Wear WaitingForNext | Stock circle indicator | 100% | Reuse WearTimerRing |
| Wear tile / complication | Circle arc | mix | Círculo OK; fix free gate |
| Home widget | Circle ProgressBar | remaining | Círculo OK; documentar |

---

## 4. Issues de seguimiento

> Los números se rellenan al crear issues en GitHub. Ver sección **Issue map** actualizada al final / en el commit de docs.

### 4.1 Bugs confirmados (P0–P1)

| JD | Issue | Título | Relacionado |
|----|------:|--------|-------------|
| JD-01 | #501 | TimerMorph polarity inverted (#492 regression) | #492 |
| JD-02 | #502 | Unify progress semantic phone ↔ Wear | widget, tile |
| JD-03 | #503 | Paywall navigate side-effect during composition | FocusScreen |
| JD-04 | #504 | Persist pause metrics in recovery | FocusTimerService |
| JD-05 | #505 | High-rate timer display flow | FocusViewModel |
| JD-06 | #506 | Free Pomodoro/Chrono on tile & complication | FeatureGate |
| JD-07 | #507 | Backfill missing es/pt string keys | i18n phone |
| JD-08 | #508 | Localize Wear hardcoded EN strings | Wear a11y |
| JD-09 | #509 | WaitingForNext → WearTimerRing | shape system |

### 4.2 Sospechos (P1–P2, triaje en implementación)

| JD | Issue | Título |
|----|------:|--------|
| JD-10 | #510 | Morph path origin at 12 o'clock |
| JD-11 | #511 | Use MaterialTheme.shapes tokens |
| JD-12 | #512 | Sync sessionsBeforeLongBreak (stop hardcode 4) |
| JD-13 | #513 | Wall-clock recovery after process death |
| JD-14 | #514 | Locked mode Pro upgrade cue |
| JD-15 | #515 | Optimistic skip long-break boundary |

### 4.3 Opcionales / excelencia Play Store (P2–P3)

| JD | Issue | Título |
|----|------:|--------|
| JD-16 | #516 | Brand typography display + body pairing |
| JD-17 | #517 | M3 Expressive motion tokens app-wide |
| JD-18 | #518 | Replace emoji-first Focus chrome with icons |
| JD-19 | #519 | Use or remove GlassComponents |
| JD-20 | #520 | Focus mode chips ≥12sp |
| JD-21 | #521 | Morph integration tests vs FocusTimerState |
| JD-22 | #522 | Tune Focus tile active refresh |
| JD-23 | #523 | Two-pane adaptive on MEDIUM width |
| JD-24 | #524 | Critically damped mode spring + reduce-motion |
| JD-25 | #525 | Soundscape fade on WaitingForNext |
| JD-26 | #526 | Nav suite icon contentDescription |
| JD-27 | #527 | Widget circle exception + progress polarity |

### 4.4 Issues de sprint ya existentes (no recrear)

| Issue | Acción |
|-------|--------|
| #492 | Trackear regresión vía JD-01; comentar en #492 y considerar reopen |
| #493 | Completar WIP adaptive + PR; revisar JD-23 como extensión |
| #494 | Ejecutar como sprint de color system (alto impacto visual) |

---

## 5. Siguientes pasos (orden de ejecución recomendado)

### Fase A — Correctness del timer (bloquea “hermosa y confiable”)

1. **JD-01** Fix polaridad morph + gate Running/Paused + tests (incl. JD-21).
2. **JD-02** Unificar semántica de progress phone/Wear/widget/tile (una sola convención, preferible elapsed 0→1 o remaining documentado en un solo mapper).
3. **JD-13** (suspect crítico) Validar y fix recovery wall-clock.
4. **JD-04** Persistir pause metrics en recovery.
5. **JD-05** High-rate display flow para anillo (competitivo vs chop de 1s).
6. **JD-10** Origen 12 o'clock del path morph.

### Fase B — UX / paridad Wear + i18n

7. **JD-03** Paywall `LaunchedEffect`.
8. **JD-06** Free tile/complication.
9. **JD-14** Locked tap cue Pro.
10. **JD-12** + **JD-15** Ciclo long-break Wear.
11. **JD-09** WaitingForNext ring.
12. **JD-07** + **JD-08** i18n phone + Wear.

### Fase C — Cerrar sprints abiertos del roadmap M3

13. Completar **#493** ListDetail (PR desde WIP branch).
14. Ejecutar **#494** palettes Expressive.
15. **JD-11** Shape tokens consistency pass.

### Fase D — Excelencia visual Play Store (opcional pero objetivo “perfecta”)

16. **JD-16** Typography brand.
17. **JD-17** Motion tokens Expressive.
18. **JD-18**, **JD-20**, **JD-24**, **JD-25**, **JD-26**.
19. **JD-19**, **JD-22**, **JD-23**, **JD-27**.

### Fase E — Cierre de calidad

20. Re-run **Judgment Day Round 2** solo sobre archivos tocados tras fixes.
21. Actualizar este doc + [[Diseño UI-UX Material3 Expressive]] + [[Estado Plataforma]] con status final.
22. Screenshot / visual pass en phone compact, tablet EXPANDED, Wear round, light/dark, es/pt.

---

## 6. Criterios de “app perfecta” (definition of done global)

- [ ] Morph cumple AC de #492 (urgencia al final, no al inicio)
- [ ] Progress semantic idéntico phone / Wear local / tile / widget (o documentado con mapper único)
- [ ] Recovery post-muerte: tiempo real correcto + pause metrics
- [ ] Free tier: mismas capacidades free en phone y glance Wear
- [ ] Cero strings EN hardcode en flujos es/pt (phone + Wear)
- [ ] Shape system: tokens de tema, no one-offs; timer language híbrido documentado
- [ ] Adaptive tablets (#493) + palettes (#494) cerrados
- [ ] Typography + motion con identidad de marca (no genérico system-only)
- [ ] Judgment Day Round 2: **JUDGMENT: APPROVED** (0 CRITICAL confirmados, 0 WARNING real confirmados)

---

## 7. Issue map (creados 2026-07-24)

| JD | GitHub | Título corto | Prioridad |
|----|--------|--------------|-----------|
| JD-01 | [#501](https://github.com/tiagofur/pepinillo_nativo/issues/501) | TimerMorph polarity inverted (#492 regression) | critical |
| JD-02 | [#502](https://github.com/tiagofur/pepinillo_nativo/issues/502) | Unify progress semantic phone ↔ Wear | critical |
| JD-03 | [#503](https://github.com/tiagofur/pepinillo_nativo/issues/503) | Paywall side-effect in composition | high |
| JD-04 | [#504](https://github.com/tiagofur/pepinillo_nativo/issues/504) | Persist pause metrics in recovery | high |
| JD-05 | [#505](https://github.com/tiagofur/pepinillo_nativo/issues/505) | High-rate timer display flow | high |
| JD-06 | [#506](https://github.com/tiagofur/pepinillo_nativo/issues/506) | Free Pomodoro/Chrono on tile/complication | high |
| JD-07 | [#507](https://github.com/tiagofur/pepinillo_nativo/issues/507) | Backfill es/pt string keys | high |
| JD-08 | [#508](https://github.com/tiagofur/pepinillo_nativo/issues/508) | Localize Wear hardcoded EN strings | high |
| JD-09 | [#509](https://github.com/tiagofur/pepinillo_nativo/issues/509) | WaitingForNext → WearTimerRing | medium |
| JD-10 | [#510](https://github.com/tiagofur/pepinillo_nativo/issues/510) | Morph path origin at 12 o'clock | medium (suspect) |
| JD-11 | [#511](https://github.com/tiagofur/pepinillo_nativo/issues/511) | Use MaterialTheme.shapes tokens | medium (suspect) |
| JD-12 | [#512](https://github.com/tiagofur/pepinillo_nativo/issues/512) | Sync sessionsBeforeLongBreak on Wear | medium (suspect) |
| JD-13 | [#513](https://github.com/tiagofur/pepinillo_nativo/issues/513) | Wall-clock recovery after process death | critical (suspect) |
| JD-14 | [#514](https://github.com/tiagofur/pepinillo_nativo/issues/514) | Locked mode Pro upgrade cue | medium (suspect) |
| JD-15 | [#515](https://github.com/tiagofur/pepinillo_nativo/issues/515) | Optimistic skip long-break boundary | low (suspect) |
| JD-16 | [#516](https://github.com/tiagofur/pepinillo_nativo/issues/516) | Brand typography display + body | medium (optional) |
| JD-17 | [#517](https://github.com/tiagofur/pepinillo_nativo/issues/517) | M3 Expressive motion tokens app-wide | medium (optional) |
| JD-18 | [#518](https://github.com/tiagofur/pepinillo_nativo/issues/518) | Replace emoji-first Focus chrome | low (optional) |
| JD-19 | [#519](https://github.com/tiagofur/pepinillo_nativo/issues/519) | Use or remove GlassComponents | low (optional) |
| JD-20 | [#520](https://github.com/tiagofur/pepinillo_nativo/issues/520) | Mode chips ≥12sp | low (optional) |
| JD-21 | [#521](https://github.com/tiagofur/pepinillo_nativo/issues/521) | Morph integration tests | medium (optional) |
| JD-22 | [#522](https://github.com/tiagofur/pepinillo_nativo/issues/522) | Tune Focus tile active refresh | low (optional) |
| JD-23 | [#523](https://github.com/tiagofur/pepinillo_nativo/issues/523) | Two-pane on MEDIUM width | low (optional) |
| JD-24 | [#524](https://github.com/tiagofur/pepinillo_nativo/issues/524) | Critically damped mode spring | low (optional) |
| JD-25 | [#525](https://github.com/tiagofur/pepinillo_nativo/issues/525) | Soundscape fade on WaitingForNext | low (optional) |
| JD-26 | [#526](https://github.com/tiagofur/pepinillo_nativo/issues/526) | Nav suite icon contentDescription | low (optional) |
| JD-27 | [#527](https://github.com/tiagofur/pepinillo_nativo/issues/527) | Widget circle exception + polarity | low (optional) |

### Sprint issues (pre-existing, not recreated)

| Issue | Role |
|-------|------|
| [#492](https://github.com/tiagofur/pepinillo_nativo/issues/492) | Morph sprint CLOSED with regression → tracked by #501 |
| [#493](https://github.com/tiagofur/pepinillo_nativo/issues/493) | ListDetail adaptive OPEN (WIP on branch) |
| [#494](https://github.com/tiagofur/pepinillo_nativo/issues/494) | Palettes Expressive OPEN |

### GitHub search shortcuts

- All JD batch: `is:issue is:open label:android created:>=2026-07-24` (filter #501–#527)
- Critical only: `is:issue is:open label:priority:critical`
- Wear residual: `is:issue is:open label:wear #501..#527`

---

## 8. Referencias

- Diseño plan: [[Diseño UI-UX Material3 Expressive]]
- Focus engine: [[Modulo Focus Engine]]
- Wear/widgets: [[Widgets & Wear OS]]
- PRD features: [[../PRD/02_FEATURES]]
- Engram: `judgment-day/android-wear-ui-r1`, `judgment-day/android-ui-sprints-audit`
- PR morph: https://github.com/tiagofur/pepinillo_nativo/pull/500
