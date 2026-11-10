# Sistema de diseño

Fuente ejecutable de tokens: `ios/Shared/Design/` (Apple) y
`android/app/src/main/java/dev/creapolis/pepinillo/core/theme/` + res (Android).
Guía de personalidad: [`../.impeccable.md`](../.impeccable.md). Contrato macOS:
[`../ios/docs/macos-design-contract.md`](../ios/docs/macos-design-contract.md).

---

## 1. Principio rector

**Gramática nativa por plataforma, marca compartida.** HIG-first en
iOS/watchOS/macOS; Material 3 Expressive en Android/Wear OS. La paridad es
funcional y de vocabulario visual (paleta, ring, glass, movimiento, copy);
**nunca** estructural (no estirar iPhone a Mac, no hibridar componentes).

## 2. Identidad visual compartida

### Acento de marca
- Rampa verde de marca: `#2E7D46` (base) / `#3D9C5E` (claro), aplicada vía
  `ASSETCATALOG_GLOBAL_ACCENT` (`AccentColor` en el asset catalog). El sidebar
  macOS sigue el patrón Podcasts (cápsula inset que **llena** la fila de 26 pt).

### Colores por modo de foco (invariante multiplataforma)
| Modo | Acento | Uso emocional |
| :--- | :--- | :--- |
| Pomodoro | rojo | urgencia y ritmo |
| Flowtime | azul/teal | continuidad y flow |
| Time Block | violeta | planificación estructurada |
| Stopwatch | verde | registro libre |
| Streak | ámbar | celebración/consistencia |

Fuentes de verdad: `ios/Shared/Design/AppTheme.swift` (modos),
`PhaseColors.swift` (variantes de descanso por hue-shift + desaturación +
lighten), `ModeColors.swift` (widgets). Android replica en el theme Compose.

### Glass y materiales (Apple)
- Radios: tile 12 / card 20 / hero 28 (`GlassTokens.swift`).
- `GlassModifier` ambient: deriva 60 s, beats de timeline 2 s, opacidad 0.12
  light / 0.22 dark. ⚠️ No compilar `GlassModifiers` en targets watch/widget
  sin revisar los condicionales de plataforma.
- El glass ambiente vive **solo** en la escena Focus (iOS y stage de Mac);
  Plan/Dashboard/Settings usan fondos de sistema.

### Material 3 Expressive (Android)
- Dynamic color del wallpaper (Material You), `NavigationSuiteScaffold`,
  transiciones compartidas (`SharedTransitionLayout`) respetando reduce-motion,
  `TimerMorph` (círculo→squircle en el 20% final).

## 3. Temas y modos

- Temas de acento: Classic / Forest / Ocean / Sunset. Modo claro/oscuro/sistema
  seleccionable explícitamente en ambas plataformas.
- Tipografía: SF Pro (Apple; rounded reservado a numerales y celebración) y
  Roboto/Google Sans (Android). Numerales siempre `.monospacedDigit()`.
  En Mac, estilos semánticos macOS (`.body` 13 pt, timer 72–84 pt).

## 4. Soundscapes

8 paisajes: Rain, Forest, Café, White Noise (free) + Ocean, Fireplace,
Binaural, Lo-fi (Pepinillo+). Reglas: loops cortos sin picos, fallback a
silencio según política del OS, elección device-local (`CompletionSound`
también reproduce en macOS desde T23).

## 5. Accesibilidad y presencia

- One-tap-to-focus: el start siempre alcanzable en un toque (home, widget,
  reloj, Control Center, menú bar, Siri/Assistant).
- Legible de un vistazo: widgets/notificaciones/complications comunican tiempo
  y fase en <0.5 s; sin depender del color solo (menú bar es template).
- Reduce Motion y Reduce Transparency respetados en ambas plataformas (el
  panel Notch y la glass de Mac honor `NSAppearance`/settings).
- VoiceOver/TalkBack con labels descriptivos; anuncios por minuto en Android
  (`FocusA11yState`).
