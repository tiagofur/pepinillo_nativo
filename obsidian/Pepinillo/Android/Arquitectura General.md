---
tags:
  - android
  - arquitectura
  - compose
status: active
date: 2026-04-17
updated: 2026-04-17
---

# Android - Arquitectura General

> [!abstract] Resumen
> Android usa Kotlin + Compose con capas limpias para foco, tareas, sync y billing, incluyendo extension nativa a Wear OS.

## Stack

| Capa | Tecnologia |
|---|---|
| UI | Jetpack Compose |
| Estado | ViewModel + StateFlow |
| Persistencia local | Room + DataStore |
| Networking | Ktor client |
| Ejecucion en background | Foreground Service + WorkManager |
| Integraciones | Health Connect, App Actions, Data Layer (Wear) |

## Modulos funcionales

- [[Modulo Focus Engine]]
- [[Modulo Tasks]]
- [[Widgets & Wear OS]]

## Principios

- Motor de foco unificado por estrategia (4 modos).
- Foreground service para sesiones resilientes.
- Paridad funcional obligatoria con iOS para features P0.

## Relacion con backend

- Auth y sync sobre API Go.
- Batch sync y reconciliacion por timestamps.
- Enforcement de entitlement PRO en app y server.

Ver tambien: [[../Backend/Arquitectura General|Backend Arquitectura]]
