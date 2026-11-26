# Clean-Context Review Bundle — Issue #986

> **Context Isolation Notice**: This packet is generated deterministically from git state.
> Do NOT read the implementer's conversation history. Evaluate strictly against the
> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.

## Pinned Identity
- **Issue**: `#986`
- **Base SHA**: `2617d83bc31eddd757fd98829631ee6fd2da6246`
- **Head SHA**: `2617d83bc31eddd757fd98829631ee6fd2da6246`
- **Scope Digest (SHA-256)**: `4e4f8729e9694fdd68a1e04a1d7fb3d61e777b0501428e3b7f4a3a45c8088ade`
- **Changed Lines**: `0` (review budget: 400)
- **Blind Dual Review (`judgment-day`) Required**: `False`

## High-Risk Triggers
- None detected by path (reviewer still judges semantic risk)

## Acceptance Criteria (source: `gh:issue#986`)
# ci(ios): las líneas -only-testing con segmento de carpeta ejecutan 0 tests — la puerta rápida de CI solo corre TaskListFeatureTests y PaywallFeatureTests

Hallazgo hecho mientras se agregaba la suite de #983 a las puertas de CI.

## Problema

En `.github/workflows/ios-test.yml`, la mayoría de las líneas `-only-testing:` usan identificadores con segmento de carpeta (`PepinilloTests/WidgetTests/AppGroupContainerTests`, `PepinilloTests/IntegrationTests/AppFeatureIntegrationTests/...`, `PepinilloTests/FocusFeatureTests/FocusFeatureReducerTests`, `PepinilloTests/SiriIntentsTests/SiriPauseResumeIntentTests`). El identificador real de un test es `Target/Suite/Test` — `WidgetTests/` es una carpeta del proyecto, no un namespace, así que **esas líneas matchean cero tests** y `xcodebuild` reporta `TEST SUCCEEDED` vacuo (el gotcha ya documentado en la memoria del equipo: «-only-testing que matchea 0 tests igual reporta SUCCEEDED»).

## Evidencia

- Log del run 44863259256 (fast gate, PR #982, Xcode 26.3): 94 líneas `✔ Test "…" passed after` — todas de `TaskListFeatureTests` y `PaywallFeatureTests` (las dos únicas líneas en formato plano). Cero líneas de `WidgetProGating`, `AppGroupContainer`, `FocusActivityAttributes`, `SiriPauseResume`, `FocusFeatureReducer` o los tests de `subscription*WritesCapabilitiesToAppGroup`.
- Local (Xcode 27.2) reproducido: `-only-testing:PepinilloTests/WidgetTests/WidgetProGatingTests` → `totalTestCount: 0`; `-only-testing:PepinilloTests/WidgetProGatingTests` (plano) → 12 tests corriendo.

## Impacto

- Las suites de widgets (incluida la matriz de entitlements `TasksWidgetAccess`), `AppFeatureIntegrationTests` de capabilities, `FocusFeatureReducerTests` y `SiriPauseResumeIntentTests` **no protegen ningún PR ni push de main** desde que se escribieron esas líneas.
- Es exactamente el hueco por el que el bug de #983 (widget de Tasks crashea en cada timeline) pasó 5 meses sin ser detectado.

## Dirección propuesta

- Convertir todas las líneas con carpeta a formato plano (`PepinilloTests/WidgetProGatingTests`, `PepinilloTests/AppGroupContainerTests`, `PepinilloTests/FocusFeatureReducerTests`, `PepinilloTests/AppFeatureIntegrationTests` por método con `Suite/`…, `PepinilloTests/SiriPauseResumeIntentTests`), en ambas puertas (fast y full).
- Verificar en el log del run que cada suite listada produzca líneas `✔ Test`/`Test case`, no solo `TEST SUCCEEDED`.

## Fuera de alcance

- El fix del widget (#983) y su suite nueva (ese PR ya lista su línea en formato plano).

## Allowed Edit Surfaces
- Not declared (Inline Direct): verify scope against the Issue exclusions.

## Files Outside Allowed Edit Surfaces
- Not computed (no declared surfaces).

## Observed Verification Evidence (V0/V1/V2)
```text
# Verification Evidence — issue #986 (flatten CI -only-testing filters)

1. Conversión completa: fast gate (9 líneas) y full gate (11 líneas) en
   formato plano Target/Suite — cero líneas con segmento de carpeta
   (verificado con rg).
2. Ejecución local de los 9 suites aplanados del fast gate:
   145 test cases corridos (vs 0 efectivos antes) — TEST SUCCEEDED salvo
   2 fallos PREEXISTENTES expuestos (contaminación cruzada de efectos
   escapados de suscripción → KeychainClient.hasTokens unimplemented;
   ambos PASAN en aislado). Excluidos del gate con comentario y
   follow-up #1003.
3. Suites verificados con test-case real: FocusFeatureReducerTests,
   WidgetProGatingTests (12), AppGroupContainerTests, FocusActivityAttributes,
   SiriPauseResumeIntent, AppFeatureIntegrationTests (40/42), +
   TaskListFeatureTests/PaywallFeatureTests/TasksWidgetQueryTests ya verificados.
4. Full gate: LocalToCloudStoreMigratorTests/PersistenceStoreRouterTests
   aplanados también.
5. make test (guardrails) OK. Sin cambios de producción (solo .github +
   2 tests que requieren mock de keychain que el reducer ya consulta).
Risk: item 5 (gate de CI expone 2 fallos preexistentes → excluidos con
documentación y follow-up #1003; el resto del gate se vuelve REAL)
```

## Changed Files

## Diff Stat
```text
(no file changes)
```

## Full Diff
```diff
(empty diff)
```
