# odd/tasks/992-focus-gaps.md

Issue: https://github.com/tiagofur/pepinillo_nativo/issues/992 (status:approved + status:in-progress; ux:shape)
Topología: Delegated Direct · Único escritor: implementador de esta sesión
Base: main ee1fea3a · 3 PRs encadenados (secuenciales, merge previo antes del siguiente)
UX Brief: https://github.com/tiagofur/pepinillo_nativo/issues/992#issuecomment-7226686145
Decisión del leader (27-nov, comment 7226595670): puerta abierta + **S4 = Apple primero** (iOS+macOS ahora; Android/web como follow-ups aprobados; excepción de paridad §3 autorizada).

## Specs (S1..S5 de la issue, ronda Apple)

- **S1 lectura+visibilidad**: eventos EventKit del día visible; sin permiso, denegado o sin huecos → la tarjeta no existe y nada falla. CTA «Conectar calendario» solo para Pro sin permiso (request en contexto).
- **S2 cálculo puro**: huecos = intervalos libres entre eventos ocupados desde `max(ahora, inicio del día)`; descartar < 25 min (default, constante del engine); eventos de todo el día = día ocupado completo; solapados se fusionan. Tabla de casos compartida en `contracts/fixtures/focus-gaps-cases-992.json` (patrón 991/994) afirmada por la suite Swift.
- **S3 acción**: hueco → hoja con tareas de Hoy → tarea elegida → secuencia in-app existente (modeSelected(.timeBlock) → customDurationChanged(clamp 1…480) → linkTask → startTapped vía AppFeature, patrón startFocusOnTask AppFeature:1509-1517); duración = hueco acotado al máximo del modo (480).
- **S4 paridad**: Apple primero (registrado). macOS misma tarjeta en MacPlanView rama .today. watchOS/Android/web fuera de alcance esta ronda.
- **S5 pago**: tarjeta solo `isProUser` (patrón SettingsFeature:511-524); timeBlock ya no es free (FocusModels.swift:57-62) — el gate del modo existente protege el arranque.

## Corte en PRs

- **PR-a (S2)** — engine puro `Domain/Models/FocusGaps.swift` (`FocusGap` struct, `computeGaps(events:now:dayStart:minimum:minShown:maxBlock:)`) + fixture `contracts/fixtures/focus-gaps-cases-994…992.json` + suite fixture-driven `Tests/IntegrationTests/FocusGapsTests.swift`. Cero EventKit, cero UI. RED→GREEN.
- **PR-b (S1, S5 + cliente)** — `CalendarClient.fetchDayEvents(start:end:)` (closure + live con `predicateForEvents` + testValue) + estado y acciones en `TaskListFeature` (gapsState enum: idle/connecting/authorized(no gaps)/ready([FocusGap]), aparición al entrar a Hoy, refresh onAppear) + gate Pro + delegate a AppFeature para el arranque + tests con mocks de closures (patrón SettingsFeatureTests/FocusCalendarCleanupTests).
- **PR-c (S3 + UI + i18n)** — tarjeta en `PlanTaskList` (rama .today, junto a EnergySuggestionPrompt) y `MacPlanView` (rama .today) + hoja de tareas de Hoy + secuencia de arranque vía AppFeature + CTA «Conectar calendario» + xcstrings ×3 idiomas (ancla `^    "`, xcstringstool) + a11y (labels/hints de chips, hoja con contexto) + Visual Evidence.

## Allowed edit surfaces

- `contracts/fixtures/focus-gaps-cases-992.json` (nuevo, PR-a)
- `ios/Domain/Models/FocusGaps.swift` (nuevo) · `ios/Tests/IntegrationTests/FocusGapsTests.swift` (nuevo)
- `ios/Domain/Clients/CalendarClient.swift` (closure de lectura, PR-b)
- `ios/Features/Tasks/TaskListFeature.swift` (+PlanQueries si el estado necesita seam) · `ios/App/AppFeature.swift` (consumo del delegate + lanzamiento)
- `ios/Features/Plan/PlanTaskList.swift` · `ios/Mac/MacPlanView.swift` · `ios/Shared/Resources/Localizable.xcstrings`
- `ios/Tests/TaskFeatureTests/TaskListFeatureTests.swift` · tests de fixture/web N/A (Apple-only)
- Compañero mecánico: `.github/workflows/ios-test.yml` (+ suites nuevas al gate fast/full si aplica)

## Gotchas aplicables (de la sesión)

- project.yml: CalendarClient ya compila en Pepinillo + PepinilloMac (NO watch) — archivos NUEVOS bajo Domain/Models entran por glob; verificar tras xcodegen.
- EventKit auto-link por import; usage descriptions ya presentes en ambos targets.
- Closures TCA: asignar directamente en withDependencies (no Unimplemented); LockIsolated para capturas en closures @Sendable.
- @Dependency(\.date) sin override rompe TestStore; exhaustivity .off para caminos con efectos.
- xcstrings: ancla `^    "` + xcstringstool a archivo temporal (NO /dev/null) + claves parseadas.
- iOS CI: suites nuevas al gate con formato plano Target/Suite; exigir líneas "Test case" reales.
- Jueces EN SECUENCIA (límite de concurrencia del plan); CI ANTES del merge (lección #1015).
- NUNCA editar sin cd explícito al worktree; scripts de edición en scratch con asserts.

## Log

- 27-nov: puerta abierta + S4 Apple primero registrados por el leader (comment 7226595670). Labels: status:new fuera. UX Brief publicado (comment 7226686145). Inventario verificado por explorador: CalendarClient write-only (closure de lectura nueva), TimeBlock clamp 1…480 (3 sitios), patrón EnergySuggestionPrompt en PlanTaskList:205-224 y MacPlanView:191-206, secuencia in-app de arranque (modeSelected→customDuration→linkTask→startTapped), mocks de CalendarClient existentes en SettingsFeatureTests:638-665. Artefacto creado.
