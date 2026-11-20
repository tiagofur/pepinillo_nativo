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
- [ ] S5 (gate de release 1.2.4): QA físico en pantalla táctil (labs): los 4
  checks de gestos (tap pausa / dial ±5 / pinch Zen / no scroll accidental) +
  barrido post-flag de controles estándar (botones, List/Table, menús,
  contextMenus, sidebar) SIN puntero

## Allowed edit surfaces

- `ios/project.yml` (solo bloque info del target PepinilloMac)
- `ios/Mac/Info.plist` (regenerado por xcodegen)
- `ios/docs/touch-on-mac.md` (§3 tabla + §4 decisión)

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
