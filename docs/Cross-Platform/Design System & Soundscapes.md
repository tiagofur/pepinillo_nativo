---
tags:
  - design-system
  - soundscape
  - cross-platform
aliases:
  - Design System
  - Soundscapes
platform: cross-platform
type: reference
status: active
date: 2026-04-17
updated: 2026-04-17
---

# Design System & Soundscapes

> [!abstract] Resumen
> La experiencia debe sentirse nativa en cada OS, pero con lenguaje visual consistente de Pepinillo.

## Principios visuales

1. Mismo significado, distinto componente nativo.
2. Colores de modo de foco consistentes entre plataformas.
3. Tipografia y spacing adaptados a HIG (Apple) y Material (Google).

## Paleta por modo de foco

| Modo | Color guia | Uso |
|---|---|---|
| Pomodoro | rojo | urgencia y ritmo |
| Flowtime | azul/teal | continuidad y flow |
| TimeBlock | violeta | planificacion estructurada |
| Stopwatch | verde | registro libre |

## Componentes equivalentes

| Concepto | Apple side | Android side |
|---|---|---|
| Timer always-on | Live Activity / Dynamic Island | Persistent Foreground Notification |
| Surface rapida | Widgets + Lock Screen | Glance widgets + lock screen widget |
| Voice command | Siri App Intents | Google Assistant App Actions |
| Watch surfacing | Smart Stack + complications | Tiles + complications |

## Soundscapes

- Objetivo: soporte cognitivo, no distraccion.
- Base inicial: lluvia suave, cafe, ruido blanco, bosque.
- Regla: loops cortos sin picos de volumen.
- Fallback: silencio cuando audio session/policy del OS lo requiera.

## Criterio de calidad

> [!success] Done cuando
> - El usuario reconoce el modo de foco en menos de 1 segundo.
> - El timer se entiende igual en iOS y Android, aunque cambie el componente.
> - Watch surfaces mantienen el mismo estado de sesion que el telefono.
