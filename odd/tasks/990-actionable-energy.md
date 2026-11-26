# odd/tasks/990-actionable-energy.md

Issue: https://github.com/tiagofur/pepinillo_nativo/issues/990 (status:approved + GO de Tiago)
Topología: Delegated Direct · Único escritor: implementador de esta sesión
Base: main 5c125522 · Rama: feat/990-actionable-energy (worktree pepinillo-wt-990)

## Specs (S1..Sn de la issue)
- **S1** tabla 24h compartida → `contracts/fixtures/energy-hours-989.json`; suites iOS/web/Android la afirman (macOS comparte el motor iOS). ✓
- **S2** sugerencia visible en «Hoy» sin agrupado en iOS/macOS/Android/web; descarte por sesión. ✓
- **S3** sin candidatos → no se muestra. ✓
- **S4** tap → filtra; «Mostrar todo»/segundo tap quita. ✓
- **S5** arranque por las acciones existentes (startFocusOnTask / inspector web). ✓ (sin nuevo camino)
- **S6** gratis, sin cambios en el tope Free. ✓
- **S7** accesibilidad + `## Visual Evidence` en el PR (en curso).

## Allowed edit surfaces
- `contracts/fixtures/energy-hours-989.json` (nuevo)
- `ios/Features/Tasks/EnergySuggestionPrompt.swift` (nuevo) · `TaskListFeature.swift` · `PlanTaskList.swift`
- `ios/Mac/MacPlanView.swift` · `ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift`
- `android/.../domain/tasks/EnergySuggestion.kt` + test (nuevos) · `feature/tasks/TasksScreen.kt` · res strings ×3
- `web/src/routes/(app)/plan/+page.svelte` · `src/lib/i18n/messages.ts` · `tests/unit/energy.test.ts` (nuevo)

## Tasks
- **T1** (S1): fixture + tests 4 plataformas. RED: Android sin motor (compile fail) → GREEN. ✓
- **T2** (S2-S4-S3 Apple): prompt compartido + acciones + enrutado por píldora. ✓
- **T3** (S2-S4 Android): chip + wiring del ViewModel existente + strings ×3. ✓
- **T4** (S2-S4 web): pill + filtro + i18n ×3 (+ quita el hint viejo gateado a free). ✓
- **T5** (S7 + handoff + jueces + PR): en curso

## Log
- 26-nov: brief UX publicado como comentario (ux:shape) antes de implementar.
- Nota entorno: el scheme PepinilloMac NO compila en este entorno por ActivityKit/27.3 (preexistente, verificado con stash — falla idéntico en main limpio); validación Mac = swiftc -parse + Visual Evidence/QA humano.
