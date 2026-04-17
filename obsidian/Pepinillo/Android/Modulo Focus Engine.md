---
tags:
  - android
  - focus-engine
aliases:
  - Android Focus Engine
platform: android
type: module
status: active
date: 2026-04-17
updated: 2026-04-17
---
date: 2026-04-17
updated: 2026-04-17
---

# Android - Modulo Focus Engine

> [!abstract] Resumen
> El Focus Engine corre sobre estrategias por modo y usa Foreground Service para sesiones robustas incluso fuera de la app.

## Modos

| Modo | Tier | Resultado esperado |
|---|---|---|
| Pomodoro | FREE | Ciclos trabajo/descanso |
| Flowtime | PRO | Sesion libre con break sugerido |
| TimeBlock | PRO | Bloque fijo con objetivo |
| Stopwatch | FREE | Conteo ascendente sin presion |

## Comportamientos clave

- Timer resiliente con proceso en foreground.
- Acciones rapidas en notificacion (pause/resume/stop).
- Vinculacion opcional a tarea activa.
- Registro de sesion para analytics y revisiones.

## Dependencias del modulo

- [[Widgets & Wear OS]]
- [[../Backend/Arquitectura General|Backend Arquitectura]]
- [[../Cross-Platform/Parity Matrix|Parity Matrix]]
