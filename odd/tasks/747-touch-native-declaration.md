# 747 — Declaración touch-native de PepinilloMac (NSIsTouchNative)

> Unidad Delegated Direct. Issue #747. Rama `feat/macos-touch-native-747`
> desde main `c6b4b2eb`. Worktree `~/dev/pepinillo-wt-747`.

## Contexto

Post-labs (18–19 nov) y con la auditoría del spike (20-nov): todo el paquete
touch previo está en producción (targets ≥36pt #744+#818-#820, hover-adaptations
#745, gestos directos #845-#849/#850, Live Activities #746). El ring scrubbing
de #758 ya vive en main vía #845/#849 — esa issue queda como cierre formal.

## Criterios (refinados post-labs, 20-nov)

- [x] S1: Decisión `NSIsTouchNative` documentada con trade-offs en
  `ios/docs/touch-on-mac.md` §4 (declarar; condiciones #744/#745 cumplidas;
  `NSViewGestureRecognizerIsExclusive` no aplica — sin NSGestureRecognizers
  directos)
- [x] S2-parcial: flag declarado en `ios/project.yml` (target PepinilloMac,
  `info.properties`) → `Mac/Info.plist` regenerado; **verificado en el bundle
  compilado** (PepinilloMac Dev, Xcode-beta 27.3, BUILD SUCCEEDED). El resto de
  S2 (hover-gating y targets verificados sin puntero en superficies clave) es
  el QA físico — gate de release, ver S5
- [x] S3: sin regresiones de puntero/trackpad/teclado — el flag NO cambia la
  ruta de entrada de puntero (solo apaga la síntesis touch→click); suite iOS
  intacta (sin cambios de código Swift en esta unidad)
- [x] S4: builds + guardrails verdes (Mac Dev 27.3 ✓; CI al push)
- [ ] S5 (gate de release 1.2.4): QA físico táctil — los 4 checks de gestos
  (tap pausa / dial ±5 / pinch Zen / no scroll accidental) + barrido post-flag
  de controles estándar (botones, List/Table, menús, contextMenus, sidebar) SIN
  puntero. **Vía: Sidecar con iPad + iPadOS 27** (touch-on-mac.md §5, decisión
  del leader 20-nov — sin hardware PROLED); checklist ejecutable abajo.

### S5 — Checklist Sidecar (iPad + iPadOS 27)

Setup: Mac e iPad con el mismo Apple ID, Sidecar conectado (inquilino AirPlay o
USB). Instalado un build con la key (Dev o Staging local). Arrastrar la ventana
de Pepinillo a la pantalla Sidecar y operarla SOLO con el dedo sobre el iPad.

**Los 4 checks de gestos (stage de Foco, idle):**

- [ ] G1 Tap en el centro del anillo **con sesión corriendo** → pausa/reanuda
      (`FocusToggleCommand.toggle`; el tap solo se adjunta si `store.isRunning`
      — `MacFocusRingTouch.swift:92-95`). El inicio NO es tap: es el botón hero
      (⌘↩). En idle el centro no es tap-target.
- [ ] G2 Dial: arrastre circular en la banda externa del anillo → duración ±5
      min por detent, numerales del timer en vivo (TimeBlock 5–480, Pomodoro
      5–120; solo idle)
- [ ] G3 Pinch sobre el stage → modo Zen (umbral `FocusZenMode.pinchThreshold`);
      pinch inverso sale
- [ ] G4 Sin scroll accidental: arrastres verticales sobre el stage no mueven
      nada (`scrollBounceBehavior(.basedOnSize)`)

**Barrido post-flag de controles estándar SIN puntero:**

- [ ] C1 Sidebar: navegación Focus/Plan/Dashboard (Today vive dentro) + gear
      Settings; ventana Statistics (propia)
- [ ] C2 Foco: chips de modo, steppers ±5, botón primario, Soundscapes
      (popover con slider + filas)
- [ ] C3 Plan: Table (selección, long-press ⇒ contextMenu), inspector ⓘ con
      sus controles
- [ ] C4 Today: refreshable (pull) + botón Refresh gemelo
- [ ] C5 Menu bar (popover): Skip/Stop/Open/Quick Capture
- [ ] C6 Notch panel: pill → expandir, acciones, collapse
- [ ] C7 Quick Capture (⌃⌥T): campo de texto (teclado táctil Sidecar), submit
      y cancel
- [ ] C8 Settings + búsqueda de tareas (⌘F, en Plan) + menús de barra
      (App/File/View/…): abrir y accionar con tap

**S3 puntero intacto (en la Mac, sin Sidecar):** trackpad/mouse/teclado como
siempre — navegación, dial NO activable con mouse (solo `.directTouch`),
steppers, atajos ⌘→/⌘N/⌃⌥T.

Criterio de salida: G1–G4 + C1–C8 ✅ → marcar S5 y habilitar el archive 1.2.4.
Cualquier falla → evaluar fix puntual o fallback aprobado por el leader (enviar
con rollback documentado: 1.2.5 retirando la key — review Mac = horas).

## Allowed edit surfaces

- `ios/project.yml` (solo bloque info del target PepinilloMac)
- `ios/Mac/Info.plist` (regenerado por xcodegen)
- `ios/docs/touch-on-mac.md` (§3 tabla + §4 decisión + R3)
- `ios/docs/macos-design-contract.md` (§18.5 — añadida en ronda de corrección C4)
- `odd/tasks/747-touch-native-declaration.md`

## Exclusiones

- Migrar gestos SwiftUI a `NSPanGestureRecognizer` (no requerido: los
  `inputKinds` equivalentes ya están en producción — R3 satisfecha por vía
  SwiftUI)
- #758 refinamientos (haptics no aplica: pantalla Mac sin haptics; anuncio
  a11y del scrub = follow-up opcional)
- Subir deployment target (sigue 15.0)
- Live Activities (#746 ya cerrado)

## Log

- 2026-11-20: spike read-only completado (símbolos SDK 27.3 verificados
  empíricamente en headers/swiftinterfaces; `NSIsTouchNative` es clave de
  Info.plist, no símbolo compilable). Baseline Mac Dev verde. Flag + docs
  aplicados; build verde con flag en bundle. Pendiente: push, PR, jueces C4,
  QA físico S5 antes de archive 1.2.4.
- 2026-11-20 (C4.3): veredicto APPROVED con hallazgos; correcciones: §18.5 del
  contrato de diseño marcado RESOLVED (P2), precisión pinch (dual
  touch+trackpad, no .directTouch) en docs §4 + comentario project.yml (P2),
  R3 armonizada con la vía SwiftUI equivalente (P3), macos-design-contract.md
  añadida a superficies.
- 2026-11-20 (ejecución final): issue #747 reabierta `status:ready`; merge a
  main vía **PR #969** (`e315078a`, CI verde ×3). Verificación de envío:
  **Release con Xcode 27.2 estable (27B52) BUILD SUCCEEDED** y
  `plutil -extract NSIsTouchNative raw` = **true** en el Info.plist del bundle
  Release (hasta ahora sólo se había verificado en Debug/beta). S5 pasa a
  ejecutarse **por Sidecar (iPad + iPadOS 27)** antes del archive 1.2.4 —
  decisión del leader con fallback de rollback documentado. Checklist G1–G4 +
  C1–C8 arriba.
- 2026-11-20 (juez C4 del PR #981, contexto limpio): **VERDICT: APPROVED**
  (V1–V5 PASS, 0×P0, 0×P2). Corregido **P1**: G1 describía un tap-to-start
  inexistente — el tap del anillo solo se adjunta con sesión corriendo
  (`MacFocusRingTouch.swift:92-95`), el inicio es el botón hero; sin la
  corrección el gate S5 daba un falso negativo. P3 aplicados: C1 nombra
  Dashboard (no Today/Stats), C8 refiere la búsqueda ⌘F de Plan, EN "⌘N
  creates a task". Verificación V2 del juez: todo bullet de las notas ASC
  existe en el código del archive Release; Live Activities Mac no se promete.
