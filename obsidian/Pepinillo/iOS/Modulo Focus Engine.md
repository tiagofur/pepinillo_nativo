---
tags:
  - ios
  - focus-engine
aliases:
  - iOS Focus Engine
platform: ios
type: module
status: active
date: 2026-04-17
updated: 2026-04-17
---
date: 2026-04-17
updated: 2026-04-17
---

# iOS - Modulo Focus Engine

> [!abstract] Resumen
> El Focus Engine implementa Pomodoro, Flowtime, TimeBlock y Stopwatch sobre un contrato comun para mantener coherencia de UX y analytics.

## Modos

| Modo | Tier | Resultado esperado |
|---|---|---|
| Pomodoro | FREE | Ciclos trabajo/descanso |
| Flowtime | PRO | Sesion libre con break sugerido |
| TimeBlock | PRO | Bloque fijo con objetivo |
| Stopwatch | FREE | Conteo ascendente sin presion |

## Comportamientos clave

- Pausa/reanudar con metrica de interrupciones.
- Vinculacion opcional a tarea activa.
- Registro de sesion (duracion, modo, nota, satisfaccion).
- Exposicion de estado en Live Activity y watch.

## Dependencias del modulo

- [[Widgets & Live Activity]]
- [[../Backend/Arquitectura General|Backend Arquitectura]]
- [[../Cross-Platform/Parity Matrix|Parity Matrix]]
