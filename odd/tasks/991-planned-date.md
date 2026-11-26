# odd/tasks/991-planned-date.md

Issue: https://github.com/tiagofur/pepinillo_nativo/issues/991 (status:approved + status:in-progress; judgment-day + ux:shape)
Topología: Delegated Direct · Único escritor: implementador de esta sesión
Base: main 8a9eaa1e · 4 PRs encadenados (secuenciales desde main, merge previo antes del siguiente)
UX Brief: https://github.com/tiagofur/pepinillo_nativo/issues/991#issuecomment-7200802430 (publicado antes de código)

## Specs (S1..Sn de la issue)

- **S1** modelo `plannedDate: Date?` (día local, sin hora): SchemaV7 Apple + Room v15 (esquema exportado `android/app/schemas/`) + modelo web. Migración: `scheduledForToday=true → plannedDate=hoy`; resto vacío.
- **S2** regla única «Hoy»: activa ∈ Hoy ⇔ `plannedDate ≤ hoy` ∨ `dueDate ≤ hoy`. Bandeja = sin ninguna. Próximas = futuras por fecha, sin tope de semana (#182).
- **S3** una función por plataforma + tabla de casos compartida (fixture JSON en `contracts/fixtures/`) afirmada por las 4 suites (ayer con/sin vencimiento, recurrente, completada, ambas fechas).
- **S4** «Planificar para…» en detalle/inspector: Hoy/Mañana/Este fin de semana/Elegir fecha (picker nativo) + Quitar fecha; swipe «Añadir a Hoy» de lista se conserva.
- **S5** alta rápida: desde Próximas `plannedDate=mañana` (ya no vencimiento); desde Hoy `plannedDate=hoy`.
- **S6** lo no hecho no desaparece: planeada pasada y sin completar → «Pospuesta» en Hoy; no depende de rollover a medianoche (retira el de iOS #190). Test de cambio de día.
- **S7** superficies que leen Hoy (widget Apple/Android, lista Watch, complicación, tile Wear OS, Siri, Panel Hoy Mac) usan la función de S2. Tile Wear + widget Android pasan de «activas» a «de hoy».
- **S8** instancias recurrentes nacen con `plannedDate` = día de su ocurrencia.
- **S9** `plannedDate` aditivo en schema Task de `contracts/openapi.yaml`; `make contracts-lint` OK, `make contracts-diff` sin breaking.
- **S10** límite Free sin cambios (tope 3 activas).

## Corte en PRs

- **PR-a (S1, S2, S3, S6, S8)** — modelo + migraciones + regla única + fixture + tests 4 plataformas. UI sigue escribiendo el booleano (transición segura): el archivo del fixture + resolvers + migraciones no cambian comportamiento visible. Incluye el backfill `scheduledForToday→plannedDate` en launch/migración. iOS: retira el rollover #190 SOLO cuando la regla nueva sea la que consulta la app (PR-b) — en PR-a el rollover sigue vivo para no partir la app.
- **PR-b (S4, S5)** — UI de asignación + alta rápida en 4 plataformas; la app entera conmuta a la regla S2 (acá se retira el rollover iOS y el write del booleano).
- **PR-c (S7)** — superficies compactas conmutan a la regla única (widget iOS/Android, Watch, complicación, tile Wear OS, Siri, Panel Hoy Mac, watchTasks pre-filter de AppFeature, repo Wear push Android).
- **PR-d (S9)** — contrato aditivo + backend (columna + entidades + round-trip tests) + clientes envían/reciben `plannedDate`; `scheduledForToday` sigue viajando derivado para installs viejas.

## Allowed edit surfaces

- `contracts/fixtures/task-planning-cases-991.json` (nuevo)
- `ios/Domain/Models/TaskItem.swift` · `ios/Domain/Models/TaskPlanning.swift` (nuevo) · `ios/Shared/Persistence/SchemaVersioning.swift` · `ios/Shared/Persistence/SwiftDataPersistenceService.swift` · `ios/Domain/Models/TasksWidgetQuery.swift` · `ios/PepinilloIntents/TaskIntentService.swift` · `ios/Mac/MacTodayView.swift` · `ios/App/AppFeature.swift` (watchTasks filter) · `ios/Shared/Resources/Localizable.xcstrings` (claves nuevas)
- `ios/Features/Tasks/TaskListFeature.swift` · `TaskListFeature+Plan.swift` · `TaskDetailView.swift` · `TaskDetailFeature.swift` · `TaskRow.swift` · `ios/Features/Plan/PlanTaskList.swift` · `EnergyGroupedTaskList.swift` · `PlanFilter.swift`
- Compañeros mecánicos del bump de esquema (r1): `ios/Shared/Persistence/AppGroupContainer.swift` · `ios/Shared/Persistence/LocalToCloudStoreMigrator.swift` · `ios/Shared/Persistence/SchemaSnapshotsV5V6.swift` (nuevo) · tests de contenedores frescos (`TasksWidgetQueryTests`, `SiriIntentsTests` ×3)
- Android (r1): `android/app/src/main/java/dev/creapolis/pepinillo/di/DatabaseModule.kt` (registro MIGRATION_14_15) · `data/sync/SyncEngine.kt` (pull preserva plannedDate hasta PR-d) · `feature/tasks/model/Task.kt` (campo dominio)
- Web: `web/src/lib/data/sync/mappers.ts` (PR-d)
- `ios/Mac/MacPlanView.swift` · `MacTaskInspectorView.swift` · `ios/PepinilloWatch/**` (lista/complicación lectura)
- `android/app/src/main/java/dev/creapolis/pepinillo/data/local/` (TaskEntity, PepinilloDatabase, TaskDao, migrations) · `android/app/schemas/**/15.json` (generado)
- `android/.../domain/tasks/` (resolver nuevo + test) · `feature/tasks/` (TasksViewModel, TasksScreen, TaskDetailScreen/ViewModel, TaskItem) · `data/repository/TaskRepository.kt` (recurrencia + wear push) · `widget/TasksWidget.kt` · res strings ×3
- `android/wear/src/main/java/dev/creapolis/pepinillo/tile/TasksTileService.kt`
- `web/src/lib/domain/tasks/plan.ts` · `web/src/lib/domain/entities/types.ts` · `web/src/lib/features/plan/TaskInspector.svelte` · `web/src/routes/(app)/plan/+page.svelte` · `web/src/lib/i18n/messages.ts` · tests unitarios web
- `backend/**` (PR-d: entidad, migración, service, tests) · `contracts/openapi.yaml` (PR-d)

## Tasks

- **T1 (PR-a)**: fixture S3 + resolver iOS (`TaskPlanning`) + SchemaV7 + backfill + tests PersistenceServiceTests. RED→GREEN.
- **T2 (PR-a)**: Room v15 + MIGRATION_14_15 + resolver Android + fixture test. RED→GREEN.
- **T3 (PR-a)**: web `plannedDate` en tipos + resolver en plan.ts + fixture test (vitest). RED→GREEN.
- **T4 (PR-a)**: handoff + jueces dual (judgment-day: toca migraciones) + PR + CI + merge.
- **T5 (PR-b)**: iOS asignación (menú fila + detalle + inspector Mac + contexto Mac) + conmutación app a regla S2 + retiro rollover + alta rápida S5 + xcstrings ×3 idiomas. Tests TCA.
- **T6 (PR-b)**: Android fila planificación (bottom sheet + MaterialDatePicker) + chip Pospuesta + alta rápida S5 + strings ×3. Tests VM.
- **T7 (PR-b)**: web inspector + menú fila + alta rápida S5 + i18n ×3. vitest.
- **T8 (PR-b)**: handoff + jueces + PR + CI + merge. Visual Evidence obligatorio (ux:shape).
- **T9 (PR-c)**: conmutar superficies compactas a la regla (TasksWidgetQuery, TaskIntentService, MacTodayView, AppFeature watchTasks, TasksComplications, TasksWidget Android, TasksTileService, Wear push repo). Tests por superficie.
- **T10 (PR-c)**: handoff + juez + PR + CI + merge.
- **T11 (PR-d)**: openapi schema + backend columna/entidad/migración + round-trip + clientes envían/reciben (derivado scheduledForToday). contracts-lint + contracts-diff.
- **T12 (PR-d)**: handoff + jueces dual (contrato) + PR + CI + merge + cierre de issue.

## Log

- 27-nov r1 (judgment-day dual): Juez A 1 CRITICAL + 1 P1 + 1 P2 + 3 INFO · Juez B 1 P1 + 3 P2 + 2 INFO. **CONFIRMADO DUAL**: SchemaV5 con clases vivas → store V5 real no abre por el plan ("unknown model version", repro determinista del Juez A) → V5 congelado en SchemaSnapshotsV5V6.swift + test on-disk V5→V7. **CONFIRMADO DUAL**: superficies incompletas → sección de compañeros mecánicos añadida. **P1 single-judge (A), auto-verificado por lectura**: Android borraba plannedDate en mergeInto y en el pull full-row de SyncEngine → plannedDate en Task/toDomain/toEntity, mergeInto preserva (?: existing), SyncEngine preserva local hasta PR-D, 3 tests nuevos. **Contradicción resuelta**: el P2 de B sobre DEFAULT NULL fue refutado por A con el runtime de Room 2.8.5 decompilado (defaults solo se comparan si la entidad declara uno) — sin remedio. INFO mecánicos aplicados: shim sin force-unwrap, comentario 8_9 reubicado, pin de base temporal en test web. Monolito: extracción verbatim del freeze a archivo propio (V1-V4 siguen inline, deuda #995). Todos los gates verdes: iOS 22/22 (TaskPlanning 7 + SchemaVersioning 10 + WidgetQuery 5), Android repos+sync+fixture, web 3/3. Gotcha de project.yml: los archivos nuevos bajo Shared/ hay que listarlos EXPLÍCITAMENTE en los targets que no usan globs (3 entradas junto a SchemaVersioning.swift).
- 27-nov: commit previo 8a9eaa1e (xcstrings post-1005 + traducciones Siri). Brief UX publicado; labels a status:in-progress. Artefacto creado. Limpieza: 10 handoff/verification trackeados de tandas viejas fuera de main (69a3ffb0).
- 27-nov PR-a en worktree pepinillo-wt-991a / feat/991-planned-date-model: fixture compartido + resolver iOS (TaskPlanning) + TaskItem.plannedDate + **freeze SchemaV6** (patrón 3247e31d: las clases vivas de V5/V6 solo funcionaron porque ningún modelo cambió; V7 cambia TaskItem) + SchemaV7 + etapa custom con backfill booleano→hoy + S8 recurrencia iOS/Android + Room v15 (MIGRATION_14_15) + resolver Android + resolver web + plannedDate en tipos web. **Mutante verificado**: backfill corrupto (+5 días) rompe v6StoreMigratesToV7WithBackfill y backfillIsIdempotent — los tests no son tautológicos. iOS 16/16 verde en simulador (TaskPlanning 6 + SchemaVersioning 10); web 3/3 planning + fixture 989 intacto.
- Nota entorno: scheme 'Pepinillo Dev' (no existe scheme "Pepinillo"); destino simulador iPhone Air booteado. GOTCHA NUEVO: -only-testing con TRES niveles (Target/Suite/func) corre 0 tests y reporta TEST SUCCEEDED vacuo — mismo mecanismo que el caso carpeta de #986; usar Target/Suite plano y exigir líneas "Test case" en el log. GOTCHA: xcodebuild test NO propaga env vars al runner sin prefijo TEST_RUNNER_.
