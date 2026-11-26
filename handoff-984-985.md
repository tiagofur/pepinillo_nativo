# Clean-Context Review Bundle — Issue #985

> **Context Isolation Notice**: This packet is generated deterministically from git state.
> Do NOT read the implementer's conversation history. Evaluate strictly against the
> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.

## Pinned Identity
- **Issue**: `#985`
- **Base SHA**: `5c1255225c2bbc3492cd4aa68ef77c0fee787117`
- **Head SHA**: `5c1255225c2bbc3492cd4aa68ef77c0fee787117`
- **Scope Digest (SHA-256)**: `00b2d46ae9d5cbd0464f3ebec7c46c77df6bdda27046cadab239aca870595f6a`
- **Changed Lines**: `0` (review budget: 400)
- **Blind Dual Review (`judgment-day`) Required**: `False`

## High-Risk Triggers
- None detected by path (reviewer still judges semantic risk)

## Acceptance Criteria (source: `gh:issue#985`)
# bug(widgets): el widget de Tasks siempre dice «Todo listo» para usuarios free — el conteo diario de #675 es inalcanzable

Hallazgo vecino a #983, encontrado leyendo el código (no ejecutado).

## Problema

Para usuarios free, el widget de Tasks siempre muestra «Todo listo / Sin tareas pendientes» con contador en 0, aunque tengan tareas para hoy. El conteo diario que introdujo #675 no está funcionando.

En `ios/PepinilloWidget/TasksWidgetProvider.swift`, `buildEntry` abre el store con `TasksWidgetAccess.loadIfAuthorized(...)`, que devuelve `nil` sin cargar nada cuando el usuario no está autorizado; el provider retorna `.empty` (`isProUser: false`, `todayTaskCount: 0`). Por eso la rama `if !isPro { return … todayTaskCount }` es inalcanzable y `TasksWidgetFreeCountView` pinta siempre el estado vacío en vez de «N tareas para hoy — Pepinillo+ muestra tu lista completa».

El comentario del propio método («free gets the daily count, Pro the interactive list») y el doc de `TasksWidgetEntry.todayTaskCount` describen la intención original. `WidgetProGatingTests.tasksWidgetAccessMatrix` fija que `loadIfAuthorized` no carga para `free`, así que el helper se comporta como fue especificado: el desfase está en cómo lo usa el provider.

## Decisión de producto pendiente

- ¿El conteo para free debe abrir el store (una pasada, como dice el comentario) o se mantiene la puerta cerrada?
- Si se abre: ¿qué se muestra si la lectura falla? Hoy un error también termina en «Todo listo».

## Allowed Edit Surfaces
- Not declared (Inline Direct): verify scope against the Issue exclusions.

## Files Outside Allowed Edit Surfaces
- Not computed (no declared surfaces).

## Observed Verification Evidence (V0/V1/V2)
```text
# Verification Evidence — issues #984 + #985 (widget Tasks)

## #984 — fetch limit después del filtro de hoy
1. RED observado: test nuevo `todayTaskSurvivesLargeNonTodayBacklog`
   (55 tareas inbox con sortOrder menor + 1 de hoy) → FAILED contra el
   código con fetchLimit=50 pre-filtro.
2. GREEN: filtro de hoy empujado al #Predicate (fechas capturadas:
   todayStart/tomorrowStart; coalescing en dueDate) + límite después →
   `TasksWidgetQueryTests` 5/5 TEST SUCCEEDED.

## #985 — conteo free abre el store
3. Provider: `loadIfAuthorized` deja de usarse en buildEntry — el
   contenedor abre para todo tier (el gate protege solo la lista
   interactiva; el conteo diario es la intención documentada del método
   y de TasksWidgetEntry.todayTaskCount). Free con tareas hoy →
   TasksWidgetFreeCountView muestra «N tareas para hoy». Falta de
   lectura → estado vacío desbloqueado (sin estado engañoso bloqueado).
4. WidgetProGatingTests (matriz loadIfAuthorized) sin cambios: el helper
   conserva su contrato — el desfase era del provider. TEST SUCCEEDED.

## Decisión documentada (Decisions Made Without Asking en el PR)
- Free: el conteo abre el store una vez (intención original del código).
- Error de lectura en cualquier tier → estado vacío desbloqueado.

Risk: item 3 (widget Tasks visible en home screen; el predicado cambia
el SQL generado — cubierto por TasksWidgetQueryTests ejecutando el
fetch real contra contenedor en memoria)
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
