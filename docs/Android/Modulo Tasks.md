---
tags:
  - android
  - tasks
aliases:
  - Android Tasks
platform: android
type: module
status: active
date: 2026-04-17
updated: 2026-04-21
---

# Android - Modulo Tasks

> [!abstract] Resumen
> Tasks integra planificacion y ejecucion de deep work: priorizar, estimar foco, vincular sesiones y revisar progreso.

## Scope funcional

- CRUD de tareas.
- Subtareas (EVERYWHERE).
- Prioridad y energia.
- Recurrencia.
- Reordenado por prioridad.
- Vinculo tarea-sesion de foco.

## Integraciones

- Import de Google Tasks.
- Sync backend incremental.

## Paridad esperada

El comportamiento de negocio debe coincidir con [[../iOS/Modulo Tasks|iOS Modulo Tasks]], variando solo UI nativa.

## Nota comercial

En Android, subtareas y recurrencia forman parte de `Everywhere`. El backend sync de Tasks solo vive dentro de esa misma oferta paga.
