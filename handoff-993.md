# Clean-Context Review Bundle — Issue #993

> **Context Isolation Notice**: This packet is generated deterministically from git state.
> Do NOT read the implementer's conversation history. Evaluate strictly against the
> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.

## Pinned Identity
- **Issue**: `#993`
- **Base SHA**: `926b34e224d2a6f547361b4e359151a19a9c9942`
- **Head SHA**: `926b34e224d2a6f547361b4e359151a19a9c9942`
- **Scope Digest (SHA-256)**: `d2ce96e5b6459d938d87c68c07602807b24fd7a3d503bd1d5a7f2f95950c2236`
- **Changed Lines**: `0` (review budget: 400)
- **Blind Dual Review (`judgment-day`) Required**: `False`

## High-Risk Triggers
- None detected by path (reviewer still judges semantic risk)

## Acceptance Criteria (source: `gh:issue#993`)
# feat(macos): Quick Open ⌘K — enlazar una tarea o arrancar su sesión desde el teclado

Propuesta nacida del análisis comparativo con OmniFocus del 2026-11-25 (su Quick Open). Es pulido de teclado para PepinilloMac, no una prioridad de activación. Estado del código verificado por lectura sobre `main` `a491ee33`.

## Problema

Enlazar una tarea con el teclado exige ir a Foco (⌘1), llegar al chip «Link Task» y hacer clic: el selector solo se abre con clic (`ios/Mac/MacFocusView.swift:265-267`). El selector ya busca y enlaza con Return (#929, `MacFocusView.swift:467-500`), así que lo que falta es la entrada. ⌘F solo filtra la tabla de Plan, y arrancar foco desde una fila pasa por el menú contextual o el inspector (`ios/Mac/MacPlanView.swift:393-396`).

## Outcome

⌘K, escribir, Return: la tarea queda enlazada. Con ⌘↩, además arranca la sesión. Sin ratón.

## Criterios de aceptación

- **S1 · Entrada.** ⌘K abre el selector de tarea existente con el buscador enfocado, desde Focus, Plan, Today y Statistics. La opción figura en un menú, con su atajo visible.
- **S2 · Selección.** Return enlaza la primera coincidencia (comportamiento actual de #929) y cierra. Esc cierra sin cambiar nada.
- **S3 · Enlazar y arrancar.** ⌘↩ enlaza la coincidencia y, si no hay sesión en curso, arranca la sesión con la tarea enlazada. Si ya hay sesión, solo enlaza.
- **S4 · Plan vacío.** Sin tareas activas, ⌘K abre el selector con su estado vacío actual y no cambia nada más.
- **S5 · Descubrimiento.** El atajo aparece en Ajustes › Atajos junto a los existentes (`ios/Mac/MacSettingsView.swift:221-223`).
- **S6 · Sin colisión.** ⌘K no está asignado hoy en `ios/App/MacCommands.swift` (verificado al abrir esta issue), y ningún atajo existente cambia.

Verificación: V1 (tests del comando y del selector) más evidencia visual.

## Decisiones abiertas

- **⌘K frente a ⌘O.** Propongo ⌘K: es lo que ya usa la paleta de web (`web/src/lib/features/plan/QuickCapture.svelte:79`) y el convenio de «búsqueda rápida» en Mac. OmniFocus usa ⌘O.
- **Solo con la ventana abierta.** Con la app solo en la barra de menús, ⌘K no hace nada. Un atajo global sería otra issue.

## Fuera de alcance

- Buscar vistas o comandos (paleta de comandos).
- Atajo global del sistema.
- Buscar sesiones o estadísticas.
- Otras plataformas.

## Allowed Edit Surfaces
- Not declared (Inline Direct): verify scope against the Issue exclusions.

## Files Outside Allowed Edit Surfaces
- Not computed (no declared surfaces).

## Observed Verification Evidence (V0/V1/V2)
```text
# Verification Evidence — issue #993 (⌘K Quick Open en Mac)

1. swiftc -parse de los 3 archivos tocados: OK (las verificaciones de tipo
   del scheme PepinilloMac son imposibles en este entorno — ActivityKit/
   Xcode-27.3 preexistente, verificado idéntico en main limpio y declarado
   como waiver en el PR de #990; el diff se cubre con revisión estructural
   del juez + QA humano al merge).
2. S6 verificado por grep: ningún atajo ⌘K preexistente en el target Mac.
3. S2 ya existía (#929): el picker auto-enfoca el buscador y Return enlaza
   la primera coincidencia (MacFocusView.swift:518, :507-513).
4. Mecánica: el ítem Focus > Link Task (⌘K) cambia a la pestaña Focus y
   postea .macFocusLinkTaskRequested async; MacFocusView observa y envía
   .taskPickerTapped (patrón notificación establecido: Quick Capture,
   plan search). QA humano al merge: ⌘K desde Focus/Plan/Today/Statistics,
   Return enlaza, ⌘↩ + Esc según issue, dinámica en Settings › Atajos.
Risk: none
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
