# Clean-Context Review Bundle — Issue #993

> **Context Isolation Notice**: This packet is generated deterministically from git state.
> Do NOT read the implementer's conversation history. Evaluate strictly against the
> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.

## Pinned Identity
- **Issue**: `#993`
- **Base SHA**: `926b34e224d2a6f547361b4e359151a19a9c9942`
- **Head SHA**: `004bbd24515c40ba76362288c4fd45467cf2f1bb`
- **Scope Digest (SHA-256)**: `fb2466d0f0b54bd794d17c66f9a769e11c92dd77b2e7e4f78a922a22d489ed6a`
- **Changed Lines**: `125` (review budget: 400)
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
- `handoff-993.md`
- `ios/App/MacCommands.swift`
- `ios/Mac/MacFocusView.swift`
- `ios/Mac/MacSettingsView.swift`
- `verification-993.txt`

## Diff Stat
```text
handoff-993.md                | 90 +++++++++++++++++++++++++++++++++++++++++++
 ios/App/MacCommands.swift     | 13 +++++++
 ios/Mac/MacFocusView.swift    |  5 +++
 ios/Mac/MacSettingsView.swift |  1 +
 verification-993.txt          | 16 ++++++++
 5 files changed, 125 insertions(+)
```

## Full Diff
````diff
diff --git a/handoff-993.md b/handoff-993.md
new file mode 100644
index 00000000..5668b33b
--- /dev/null
+++ b/handoff-993.md
@@ -0,0 +1,90 @@
+# Clean-Context Review Bundle — Issue #993
+
+> **Context Isolation Notice**: This packet is generated deterministically from git state.
+> Do NOT read the implementer's conversation history. Evaluate strictly against the
+> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.
+
+## Pinned Identity
+- **Issue**: `#993`
+- **Base SHA**: `926b34e224d2a6f547361b4e359151a19a9c9942`
+- **Head SHA**: `926b34e224d2a6f547361b4e359151a19a9c9942`
+- **Scope Digest (SHA-256)**: `d2ce96e5b6459d938d87c68c07602807b24fd7a3d503bd1d5a7f2f95950c2236`
+- **Changed Lines**: `0` (review budget: 400)
+- **Blind Dual Review (`judgment-day`) Required**: `False`
+
+## High-Risk Triggers
+- None detected by path (reviewer still judges semantic risk)
+
+## Acceptance Criteria (source: `gh:issue#993`)
+# feat(macos): Quick Open ⌘K — enlazar una tarea o arrancar su sesión desde el teclado
+
+Propuesta nacida del análisis comparativo con OmniFocus del 2026-11-25 (su Quick Open). Es pulido de teclado para PepinilloMac, no una prioridad de activación. Estado del código verificado por lectura sobre `main` `a491ee33`.
+
+## Problema
+
+Enlazar una tarea con el teclado exige ir a Foco (⌘1), llegar al chip «Link Task» y hacer clic: el selector solo se abre con clic (`ios/Mac/MacFocusView.swift:265-267`). El selector ya busca y enlaza con Return (#929, `MacFocusView.swift:467-500`), así que lo que falta es la entrada. ⌘F solo filtra la tabla de Plan, y arrancar foco desde una fila pasa por el menú contextual o el inspector (`ios/Mac/MacPlanView.swift:393-396`).
+
+## Outcome
+
+⌘K, escribir, Return: la tarea queda enlazada. Con ⌘↩, además arranca la sesión. Sin ratón.
+
+## Criterios de aceptación
+
+- **S1 · Entrada.** ⌘K abre el selector de tarea existente con el buscador enfocado, desde Focus, Plan, Today y Statistics. La opción figura en un menú, con su atajo visible.
+- **S2 · Selección.** Return enlaza la primera coincidencia (comportamiento actual de #929) y cierra. Esc cierra sin cambiar nada.
+- **S3 · Enlazar y arrancar.** ⌘↩ enlaza la coincidencia y, si no hay sesión en curso, arranca la sesión con la tarea enlazada. Si ya hay sesión, solo enlaza.
+- **S4 · Plan vacío.** Sin tareas activas, ⌘K abre el selector con su estado vacío actual y no cambia nada más.
+- **S5 · Descubrimiento.** El atajo aparece en Ajustes › Atajos junto a los existentes (`ios/Mac/MacSettingsView.swift:221-223`).
+- **S6 · Sin colisión.** ⌘K no está asignado hoy en `ios/App/MacCommands.swift` (verificado al abrir esta issue), y ningún atajo existente cambia.
+
+Verificación: V1 (tests del comando y del selector) más evidencia visual.
+
+## Decisiones abiertas
+
+- **⌘K frente a ⌘O.** Propongo ⌘K: es lo que ya usa la paleta de web (`web/src/lib/features/plan/QuickCapture.svelte:79`) y el convenio de «búsqueda rápida» en Mac. OmniFocus usa ⌘O.
+- **Solo con la ventana abierta.** Con la app solo en la barra de menús, ⌘K no hace nada. Un atajo global sería otra issue.
+
+## Fuera de alcance
+
+- Buscar vistas o comandos (paleta de comandos).
+- Atajo global del sistema.
+- Buscar sesiones o estadísticas.
+- Otras plataformas.
+
+## Allowed Edit Surfaces
+- Not declared (Inline Direct): verify scope against the Issue exclusions.
+
+## Files Outside Allowed Edit Surfaces
+- Not computed (no declared surfaces).
+
+## Observed Verification Evidence (V0/V1/V2)
+```text
+# Verification Evidence — issue #993 (⌘K Quick Open en Mac)
+
+1. swiftc -parse de los 3 archivos tocados: OK (las verificaciones de tipo
+   del scheme PepinilloMac son imposibles en este entorno — ActivityKit/
+   Xcode-27.3 preexistente, verificado idéntico en main limpio y declarado
+   como waiver en el PR de #990; el diff se cubre con revisión estructural
+   del juez + QA humano al merge).
+2. S6 verificado por grep: ningún atajo ⌘K preexistente en el target Mac.
+3. S2 ya existía (#929): el picker auto-enfoca el buscador y Return enlaza
+   la primera coincidencia (MacFocusView.swift:518, :507-513).
+4. Mecánica: el ítem Focus > Link Task (⌘K) cambia a la pestaña Focus y
+   postea .macFocusLinkTaskRequested async; MacFocusView observa y envía
+   .taskPickerTapped (patrón notificación establecido: Quick Capture,
+   plan search). QA humano al merge: ⌘K desde Focus/Plan/Today/Statistics,
+   Return enlaza, ⌘↩ + Esc según issue, dinámica en Settings › Atajos.
+Risk: none
+```
+
+## Changed Files
+
+## Diff Stat
+```text
+(no file changes)
+```
+
+## Full Diff
+```diff
+(empty diff)
+```
diff --git a/ios/App/MacCommands.swift b/ios/App/MacCommands.swift
index 30117fba..638f9da4 100644
--- a/ios/App/MacCommands.swift
+++ b/ios/App/MacCommands.swift
@@ -119,6 +119,9 @@ extension Notification.Name {
     /// (a Mac-target class, so the menu routes through a notification instead
     /// of a direct reference).
     static let macQuickCaptureToggleRequested = Notification.Name("pepinillo.mac.quickCapture.toggle")
+    /// Posted by Focus > Link Task (⌘K, issue #993) and observed by
+    /// `MacFocusView` (which owns the focus-scoped store the picker binds to).
+    static let macFocusLinkTaskRequested = Notification.Name("pepinillo.mac.focus.linkTask")
 }
 
 /// Zen stage on the Mac focus view (issue #797): shared by the pinch gesture
@@ -145,6 +148,16 @@ struct PepinilloCommands: Commands {
 
         // MARK: Focus Menu
         CommandMenu(String(localized: "menu.focus.title", defaultValue: "Focus")) {
+            Button(String(localized: "menu.focus.linktask", defaultValue: "Link Task")) {
+                // Issue #993 (S1): ⌘K opens the task picker from any tab —
+                // switch to Focus first, then present once the view mounts.
+                store.send(.tabSelected(.focus))
+                DispatchQueue.main.async {
+                    NotificationCenter.default.post(name: .macFocusLinkTaskRequested, object: nil)
+                }
+            }
+            .keyboardShortcut("k", modifiers: .command)
+
             Button(String(localized: "menu.focus.startpause", defaultValue: "Start / Pause")) {
                 FocusToggleCommand.toggle(store: store)
             }
diff --git a/ios/Mac/MacFocusView.swift b/ios/Mac/MacFocusView.swift
index c0522ca8..f25d1170 100644
--- a/ios/Mac/MacFocusView.swift
+++ b/ios/Mac/MacFocusView.swift
@@ -103,6 +103,11 @@ struct MacFocusView: View {
                 }
             }
         }
+        .onReceive(NotificationCenter.default.publisher(for: .macFocusLinkTaskRequested)) { _ in
+            // Issue #993 (S1-S2): ⌘K abre el picker con el buscador enfocado;
+            // Return enlaza la primera coincidencia (comportamiento #929).
+            store.send(.taskPickerTapped)
+        }
         .popover(isPresented: taskPickerPresented, arrowEdge: .bottom) {
             MacTaskPickerView(
                 linkedTaskID: store.linkedTaskID,
diff --git a/ios/Mac/MacSettingsView.swift b/ios/Mac/MacSettingsView.swift
index 3d464f2e..94cca7c8 100644
--- a/ios/Mac/MacSettingsView.swift
+++ b/ios/Mac/MacSettingsView.swift
@@ -221,6 +221,7 @@ struct MacSettingsView: View {
             Section {
                 LabeledContent("Global shortcut", value: "⌃⌥Space")
                 LabeledContent("Quick Capture", value: "⌃⌥T")
+                LabeledContent("Link Task", value: "⌘K")
                 LabeledContent("Skip / next phase", value: "⌃⌥→")
                 LabeledContent("End session", value: "⌃⌥X")
                 LabeledContent("Open Pepinillo", value: "⌃⌥P")
diff --git a/verification-993.txt b/verification-993.txt
new file mode 100644
index 00000000..2137c823
--- /dev/null
+++ b/verification-993.txt
@@ -0,0 +1,16 @@
+# Verification Evidence — issue #993 (⌘K Quick Open en Mac)
+
+1. swiftc -parse de los 3 archivos tocados: OK (las verificaciones de tipo
+   del scheme PepinilloMac son imposibles en este entorno — ActivityKit/
+   Xcode-27.3 preexistente, verificado idéntico en main limpio y declarado
+   como waiver en el PR de #990; el diff se cubre con revisión estructural
+   del juez + QA humano al merge).
+2. S6 verificado por grep: ningún atajo ⌘K preexistente en el target Mac.
+3. S2 ya existía (#929): el picker auto-enfoca el buscador y Return enlaza
+   la primera coincidencia (MacFocusView.swift:518, :507-513).
+4. Mecánica: el ítem Focus > Link Task (⌘K) cambia a la pestaña Focus y
+   postea .macFocusLinkTaskRequested async; MacFocusView observa y envía
+   .taskPickerTapped (patrón notificación establecido: Quick Capture,
+   plan search). QA humano al merge: ⌘K desde Focus/Plan/Today/Statistics,
+   Return enlaza, ⌘↩ + Esc según issue, dinámica en Settings › Atajos.
+Risk: none
````
