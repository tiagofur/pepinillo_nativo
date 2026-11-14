# Touch on Mac — Guía canónica para PepinilloMac

**Status:** v1 (post-anuncio, pre-SDK)
**Target:** `PepinilloMac` (macOS 15+; APIs touch requieren macOS 27 / Xcode 27.3 beta)
**Related:** [`macos-design-contract.md`](macos-design-contract.md), [`../../docs/design.md`](../../docs/design.md), [hub oficial Touch on Mac](https://developer.apple.com/touch-on-mac/)

---

## 1. Contexto

El MacBook Pro con PROLED XDR Display (anunciado 28-oct-2026, disponible 6-nov-2026)
incorpora **touch integrado al panel** por primera vez en Mac, con **macOS 27 "Golden
Gate"** y el **Dynamic Island en Mac** (hogar de Spotlight, Live Activities y Siri AI).
Para desarrolladores:

- **macOS traduce toques→clicks automáticamente** para apps existentes; sin trabajo
  extra, PepinilloMac ya es ~90% tap-compatible (botones estándar, `List`/`Table`,
  context menus, drag & drop).
- Las **APIs nuevas** (gesture recognizers en AppKit, `NSIsTouchNative`, Live
  Activities en menú bar/Dynamic Island) requieren **Xcode 27.3 beta** (aún "coming
  soon" al 14-nov-2026).
- La auditoría de touch-readiness (2026-11-14) está plasmada en los issues
  #744 (hit targets), #745 (ⓘ hover + Quick Capture), #746 (Live Activities) y
  #747 (APIs macOS 27).

Fuentes oficiales: tech talks
[111456 Design for Touch on Mac](https://developer.apple.com/videos/play/tech-talks/111456/),
[111468 Bring Touch to your Mac app](https://developer.apple.com/videos/play/tech-talks/111468/),
[111467 Bring Live Activities to Mac](https://developer.apple.com/videos/play/tech-talks/111467/),
[anuncio Newsroom](https://www.apple.com/newsroom/2026/10/apple-unveils-groundbreaking-macbook-pro-with-proled-xdr-display/),
HIG [Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures)
y [Pointing devices](https://developer.apple.com/design/human-interface-guidelines/pointing-devices).

---

## 2. Reglas adoptadas (verificables)

### R1 — Hover-never-only
Ninguna affordance funcional puede depender **solo** de hover: si un control se
revela con `onHover`, debe existir un camino táctil equivalente (estado de
selección, botón siempre visible, o long-press → context menu). Los tooltips
`.help()` degradan sin romper y quedan exentos. *Verificación: ningún
`allowsHitTesting`/`opacity` gated por hover en `ios/Mac/**` (grep en CI del issue
#745).*

### R2 — Hit targets ≥36pt por eje en superficies interactivas
El tech talk 111468 fija **36pt mínimo por eje** para touch en Mac (iOS mantiene
los 44pt HIG). La expansión es de **área táctil**, no de glyph: se preserva la
densidad visual con puntero (filas sidebar, Table, notch panel). El mínimo visual
del contrato de diseño (28×28, §15) no cambia; el área efectiva de toque sí.
*Verificación: inventario del issue #744.*

### R3 — Gestos: nativos primero
- Long-press ⇒ context menu (el sistema lo mapea; mantener `contextMenu` como
  camino universal).
- Scroll con `ScrollView`/`Table` nativo; no interceptar.
- Gestos custom **solo** con `NSGestureRecognizer` táctil
  (`allowedTouchTypes = .direct`, `buttonMask = 0`) y refactor
  start/continue/end/cancelTracking — nunca loops `NSApp.nextEvent` ni overrides
  `mouseDown` (tech talk 111468).

### R4 — Entradas críticas siempre visibles
Toda acción central (Quick Capture, Start/Pause, inspector) debe ser alcanzable
con ≤2 taps sin teclado ni puntero. Los hotkeys son aceleradores, nunca el único
camino.

### R5 — Live Activities en Mac: mismo stack que iOS
`ActivityConfiguration` con vista expandida en **barra de menú** + regiones
**Dynamic Island** (compact/minimal), botones interactivos vía **App Intents**
(`Button(intent:)` → `activity.update`). Portar `FocusActivityAttributes`, no
bifurcar el motor (invariante de paridad de foco). Detalle en issue #746.

---

## 3. Digest de APIs (macOS 27, gating `#available`)

| API | Uso | Nota |
| --- | --- | --- |
| `NSPanGestureRecognizer` (+ familia) en AppKit | Gestos táctiles estilo UIKit | `allowedTouchTypes = .direct`; `buttonMask = 0` excluye mouse |
| `addTarget(for: .trackingBegan/.trackingEndedInside/...)` | Reemplazo de overrides `mouseDown` | NSControl control events |
| `minimumNumberOfTouchesForScrolling` | Scroll multi-touch | `enclosingScrollView` |
| `exclusiveGestureBehavior = .notExclusive` | Gestos simultáneos | Ej. varios sliders |
| `window?.disablesDirectTouchSystemGestures` | Opt-out de gestos del sistema | SwiftUI: `.directTouchSystemGesturesDisabled()` |
| `NSIsTouchNative` (Info.plist) | Declarar app touch-native | **Decisión abierta — ver §4** |
| ActivityKit + WidgetKit en macOS | Live Activities menú bar + Dynamic Island | Tech talk 111467 |

---

## 4. Decisiones abiertas (labs 18–19 nov 2026)

1. **`NSIsTouchNative`**: NO declarar por ahora. Con la traducción automática
   touch→click, declararlo solo tiene sentido cuando las hover-adaptations y los
   targets ≥36pt estén completos (#744/#745) y conozcamos los costes exactos
   (¿perdemos la traducción mientras migramos? ¿long-press sintetiza
   right-click en modo traducción?). Re-evaluar post-labs.
2. **Notch panel custom (NSPanel) vs Dynamic Island del sistema**: nuestro panel
   (`MacNotchPanelController`, auxiliaryTopArea) ocupa el mismo espacio físico
   que el Dynamic Island del sistema. Preguntar coexistencia/choque en el lab;
   la respuesta condiciona #746.
3. **Entitlements y OS mínimo** de ActivityKit en Mac (issue #746).

Labs: [18 nov 11:00–12:00 CDMX](https://developer.apple.com/events/view/U73S889C8X/dashboard)
y [19 nov 20:00–21:00 CDMX](https://developer.apple.com/events/view/6M6NX7TQFS/dashboard).

---

## 5. Pruebas táctiles

- **Sidecar** (iPad + macOS 27): soporte táctil "greatly expanded" para ventanas
  Mac desde iPadOS 27/macOS 27 — vía principal sin hardware nuevo
  ([soporte Apple 102597](https://support.apple.com/en-us/102597)).
- **Hardware touch** (MacBook Pro PROLED XDR): validación final; también ejecuta
  apps iOS/iPadOS para probar sus gestos directamente.
- Checklist por superficie: sidebar, Focus stage, Plan Table + inspector,
  Today/Stats, notch panel, Quick Capture, menús/context menus, drag & drop.
