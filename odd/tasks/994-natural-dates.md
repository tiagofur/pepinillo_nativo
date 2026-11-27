# odd/tasks/994-natural-dates.md

Issue: https://github.com/tiagofur/pepinillo_nativo/issues/994 (status:approved + status:in-progress; ux)
Topología: Delegated Direct · Único escritor: implementador de esta sesión
Base: main 3df01d22 · 4 PRs encadenados (secuenciales desde main, merge previo antes del siguiente)
UX Brief: https://github.com/tiagofur/pepinillo_nativo/issues/994#issuecomment-7222026190 (publicado antes de código)

## Specs (S1..S6 de la issue)

- **S1** gramática compartida es/en/pt versionada en `contracts/fixtures/natural-date-cases-994.json`: hoy/mañana/pasado mañana (hoje/amanhã/depois de amanhã, today/tomorrow/day after tomorrow), días de semana («el viernes», «on Friday», «na sexta») y fechas explícitas `dd/mm`, `dd/mm/aaaa`, `aaaa-mm-dd`. Reglas: siempre el siguiente día futuro; día-semana = hoy cae semana siguiente; sin coincidencia → sin fecha.
- **S2** misma implementación en 4 plataformas: iOS/macOS, Android y web consumen la tabla en sus suites y producen misma fecha y mismo título por caso. On-device, sin red, sin IA.
- **S3** entradas cubiertas: alta rápida iOS (composer inline + Share Extension + Quick Capture Mac vía el mismo reducer), Quick Capture macOS, barra Android, paleta ⌘K web (+ barra del Plan web, misma tienda).
- **S4** visible y corregible: la fila muestra la fecha como cualquier planificada (ya existe, #991); aviso transitorio con acción «Quitar fecha» que deja la tarea sin fecha y con el texto reconocido de vuelta en el título.
- **S5** solo al final del texto; preposición/artículo («del», «el», «on»…) se retira con la fecha; texto sin fecha final se guarda exacto (regresión: «Viernes de rollout», «Reunión lunes de estrategia»).
- **S6** gratis y sin cambios en el límite: sin paywall, tope Free de 3 activas intacto.

## Algoritmo compartido (semántica idéntica en los 3 resolvers)

1. `s = text.trim()`; vacío → sin match.
2. **Guardias morning**: si `s` termina (word-boundary, case-insensitive) con «de la mañana / por la mañana / esta mañana / da manhã / de manhã / pela manhã / esta manhã» → sin match (evita «Café de la mañana» → «Café de la»).
3. **Fechas numéricas primero** (unívocas), al final de `s` con ≤1 signo de puntuación final (`. , ! ?`), opcionalmente precedido de whitespace: `\d{1,2}/\d{1,2}(/\d{4})?` y `\d{4}-\d{2}-\d{2}` con **dígitos ASCII `[0-9]` únicamente** (el `\d` de JS es ASCII; UNICODE_CHARACTER_CLASS de Java o ICU harían matchear dígitos arábigo-indios — divergencia S2). La validez es **de calendario real** (roundtrip: `29/2` solo en bisiesto, `31/2` y `2026-13-45` jamás; el año+1 de un `29/2` no bisiesto también falla → sin match), no solo de rango; inválida → tratar como sin match. `dd/mm` sí, `mm/dd` no. Sin año → ocurrencia futura más próxima (mismo día → hoy; pasada este año → próximo año). Con año/ISO → tal cual.
4. **Frases** (case-insensitive, variantes con/sin acento explícitas): hoy/today/hoje; mañana|manana/tomorrow/amanhã|amanha; pasado mañana|pasado manana/day after tomorrow/depois de amanhã|depois de amanha; lunes..domingo / monday..sunday / segunda(-feira)?..domingo. Debe terminar en `s` (tras puntuación opcional). **Frontera de palabra = inicio de texto o un carácter del set exacto de JS `\s`** (U+0009-000D, U+0020, U+00A0, U+1680, U+2000-200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF); NUNCA puntuación ni `Character.isWhitespace` de plataforma (incluye U+001C-001F y excluye U+FEFF — diverge en ambas direcciones) ni `\b` de regex (aceptaría `compra:viernes`). Orden de prueba: toda frase padre precede a su sufijo («pasado mañana» antes que «mañana», «segunda-feira» antes que «segunda») — el matching por sufijo-exacto hace irrelevante el resto del orden.
5. **Preposición/artículo se retira con la fecha**: si la palabra/frase inmediatamente anterior (misma frontera de palabra) ∈ strip-set es {el, del, para, para el, el próximo, próximo, la próxima} · en {on, for, by, next} · pt {em, na, no, para, próxima, na próxima}, se retira junto con la fecha. **Una sola frase por match, longest-first, en una sola pasada** (los compuestos «para el», «el próximo», «na próxima» son unidades del set, no bucles). Case-insensitive = lowercase invariante sin normalización Unicode (NFD ñ descompuesta NO matchea). Título = original menos el span reconocido, re-trimmed de whitespace (case/acento del original intacto).
6. **Resolución** (contra `now` local, start-of-day): hoy → hoy; mañana → +1; pasado mañana → +2; día-semana → próxima ocurrencia estrictamente futura (== hoy → +7). Salida en la unidad canónica de cada plataforma: iOS `Date?` start-of-day local (`TaskPlanning.plannedDay`), Android `Long?` millis medianoche local (`TaskPlanning.plannedDay`), web day-key `YYYY-MM-DD` local (`localDateKey`).
7. Sin match ⇒ título byte-idéntico al input y fecha null. Un match que dejaría el título vacío NO es match («el viernes» a secas queda intacto).

## Fixture compartido

`contracts/fixtures/natural-date-cases-994.json` (nuevo, patrón `task-planning-cases-991.json`):
`fixedNow` = 2026-11-27 12:00 **local** (viernes) — los tests lo construyen en hora local de la máquina (iOS `DateComponents`→`Calendar.date`, Android `Calendar.set`, web `new Date(2026, 10, 27, 12)`). Casos con `expectedDate` simbólico (`today | tomorrow | dayAfterTomorrow | nextWeekday{weekday ISO 1=Lu..7=Do} | explicit{year,month,day}`) y `expectedDate: null` = sin fecha + título intacto. 46 casos: positivo ×3 idiomas (artículo, preposición compuesta, numéricas ×3 formatos, puntuación final, mayúsculas), negativos de la issue («Viernes de rollout», «Reunión lunes de estrategia», «Friday rollout»), guardias morning ×2, validez de calendario (29/2 no bisiesto, ISO fuera de rango), dd/mm == hoy, sin fecha, bare-date con título vacío.

## Corte en PRs (cada uno ≤ ~400 líneas → juez único; judgment-day solo si `factory_handoff.py` lo dispara por rutas)

- **PR-a (S1, S2-web)** — fixture compartido + parser web (`web/src/lib/domain/tasks/natural-date.ts` nuevo) + `web/tests/unit/natural-date-fixture.test.ts`. RED→GREEN. Referencia de la gramática; las demás plataformas la portan de la tabla.
- **PR-b (S2-Android)** — `NaturalDateParser.kt` en `domain/tasks/` + `NaturalDateParserFixtureTest.kt` (mismo fixture, resolución relativa al repo root como `TaskPlanningFixtureTest`). RED→GREEN.
- **PR-c (S2-iOS/Mac)** — `NaturalDateParser` como enum propio **dentro de `ios/Domain/Models/TaskPlanning.swift`** (evita cirugía de targets en project.yml; el archivo ya compila en iOS app + Mac + tests; presupuesto ≤500 líneas se mantiene ~280) + `ios/Tests/IntegrationTests/NaturalDateParserTests.swift` (carga el fixture por `#filePath` como `TaskPlanningTests`). RED→GREEN. Compañero mecánico: alta de la suite al gate de `ios-test.yml` (divulgar en PR).
- **PR-d (S3, S4, S5, S6)** — wiring + undo + regresión:
  - **iOS/Mac**: `TaskListFeature.addTaskTapped` parsea tras el trim (chokepoint único: composer + Share Extension + Quick Capture Mac heredan gratis). Fecha parseada **reemplaza/añade** sobre `planQuickAddDefaults.plannedDate`; sin match ⇒ defaults de la píldora como hoy. Undo: estado `parsedDateUndo (taskID, originalTitle)` + timer (patrón `undoDelete`), banner variante en `PlanTaskList.undoBanner` + `MacPlanView.undoBannerContent`; acción → `persistPlannedDate(nil)` + título restaurado con el seam de persistencia existente. xcstrings +1 clave banner ×3 idiomas (ancla `^    "`, validar con xcstringstool).
  - **Android**: `TasksViewModel.addQuickTask` parsea al inicio (tras guard isBlank) → sobreescribe `plannedDate`/título → SnackbarController con «Quitar fecha» (ventana undo existente ~10s) → undo = title original + plannedDate null + scheduledForToday false. Strings ×3.
  - **Web**: paleta ⌘K (`QuickCapture.runResult`) y barra del Plan (`quickAdd()`) parsean y pasan el override por el parámetro `defaults` existente de `plan.addTask` (sin cambios en la store); toast existente con `actionLabel`/`onAction` «Quitar fecha» → `plan.updateTask(id, {plannedDate: null, scheduledForToday: false, title: original})`. messages +1 clave ×3 (DESPUÉS del spread `...en`).
  - **Regresión S5**: los casos negativos del fixture ya cubren «Viernes de rollout» y «Reunión lunes de estrategia»; añadir 1 test de wiring por plataforma afirmando que un quick-add sin fecha produce el mismo Task que antes del cambio.
  - **S6**: sin gates nuevos; el cap Free se evalúa antes de la construcción (iOS L407-414, web `freeCapReached`) — camino intacto; afirmar en PR body.

## Allowed edit surfaces

- `contracts/fixtures/natural-date-cases-994.json` (nuevo, PR-a)
- `web/src/lib/domain/tasks/natural-date.ts` (nuevo) · `web/tests/unit/natural-date-fixture.test.ts` (nuevo) · PR-d: `web/src/lib/features/plan/QuickCapture.svelte` · `web/src/routes/(app)/plan/+page.svelte` · `web/src/lib/i18n/messages.ts` · tests unitarios web
- PR-b: `android/app/src/main/java/dev/creapolis/pepinillo/domain/tasks/NaturalDateParser.kt` (nuevo) · `android/app/src/test/java/dev/creapolis/pepinillo/domain/tasks/NaturalDateParserFixtureTest.kt` (nuevo) · PR-d: `android/.../feature/tasks/TasksViewModel.kt` · `android/.../ui/components/SnackbarController.kt` (solo si la acción necesita extensión) · res strings ×3 (`values/`, `values-es/`, `values-pt/`)
- PR-c: `ios/Domain/Models/TaskPlanning.swift` (enum nuevo dentro) · `ios/Tests/IntegrationTests/NaturalDateParserTests.swift` (nuevo) · `.github/workflows/ios-test.yml` (gate: +1 suite)
- PR-d iOS/Mac: `ios/Features/Tasks/TaskListFeature.swift` · `ios/Features/Plan/PlanTaskList.swift` · `ios/Mac/MacPlanView.swift` · `ios/Shared/Resources/Localizable.xcstrings` · `ios/Tests/TaskFeatureTests/TaskListFeatureTests.swift`

## Tasks

- **T1 (PR-a)**: fixture + parser web + vitest fixture-driven. RED→GREEN. Handoff + jueces (dual si el script dispara por `contracts/**`) + PR + CI + merge.
- **T2 (PR-b)**: parser Android + fixture test. RED→GREEN. Handoff + juez + PR + CI + merge.
- **T3 (PR-c)**: parser iOS/Mac + IntegrationTests + gate CI. RED→GREEN (filtro flat `Target/Suite`, exigir líneas "Test case" en el log). Handoff + juez + PR + CI + merge.
- **T4 (PR-d)**: wiring ×4 entradas + undo «Quitar fecha» ×4 + i18n (xcstrings/messages/strings con gotchas de ancla/spread) + test de wiring sin-fecha. Handoff + juez + PR + CI + merge + cierre de issue. Visual Evidence en el PR (issue `ux`).

## Gotchas aplicables (de la tanda #991)

- Scripts multi-edit que mueren a mitad no escriben nada: verificar lo que EXISTE tras cada inserción (`assert old in t`).
- xcstrings: ancla `^    "` con re.M; validar SIEMPRE con `xcstringstool` + claves parseadas; formato canónico `separators=(',', ' : ')`.
- i18n web: insertar claves DESPUÉS del spread `...en`.
- `-only-testing` solo Target/Suite plano; 3 niveles o carpeta = 0 tests con TEST SUCCEEDED vacuo.
- `@Dependency(\.date)` sin override rompe TestStore (`$0.date = .constant`); suites con defaults compartidos necesitan `.serialized, .appGroupDefaultsSerialized`.
- xcodegen generate tras añadir archivos nuevos (no aplica a PR-c si TaskPlanning.swift ya está listado).
- NUNCA editar sin `cd` explícito al worktree.

## Log

- 27-nov: labels a status:in-progress (status:new fuera). UX Brief publicado (comment 7222026190). Inventario de wiring verificado sobre main 3df01d22: iOS chokepoint `addTaskTapped` (TaskListFeature.swift:401-473; planQuickAddDefaults en TaskListFeature+PlanQueries.swift:50); Mac Quick Capture delega en el mismo store (MacQuickCaptureController.swift:110-119); Android `TasksViewModel.addQuickTask` (:237-279); web `plan.addTask(title, defaults)` (plan.svelte.ts:81-107) consumida por paleta (QuickCapture.svelte:116) y barra (plan/+page.svelte:250). Undo existente: banner iOS/Mac (PlanTaskList.swift:421, MacPlanView.swift:765), SnackbarController Android (actionLabel ✓, ventana undo en TasksViewModel:344), toast web (toast.svelte.ts con actionLabel/onAction ✓). Artefacto creado.
