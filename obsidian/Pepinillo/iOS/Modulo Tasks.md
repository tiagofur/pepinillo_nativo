---
tags:
  - ios
  - tasks
aliases:
  - iOS Tasks
platform: ios
type: module
status: active
date: 2026-04-17
updated: 2026-04-21
---

# iOS - Modulo Tasks

> [!abstract] Resumen
> Tasks integra planificacion y ejecucion de deep work: priorizar, estimar foco, vincular sesiones y revisar progreso.

## Scope funcional

- CRUD de tareas.
- Subtareas (APPLE).
- Prioridad y energia.
- Recurrencia.
- Reordenado por prioridad.
- Vinculo tarea-sesion de foco.

## Integraciones

- Import de Reminders (one-way).
- Sync backend incremental.

## Paridad esperada

El comportamiento de negocio debe coincidir con [[../Android/Modulo Tasks|Android Modulo Tasks]], variando solo UI nativa.

## Nota comercial

En Apple, subtareas y recurrencia viven bajo `Apple Unlock`. El backend sync de Tasks solo forma parte de `Everywhere`.
