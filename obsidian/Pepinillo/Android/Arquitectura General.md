---
tags:
  - android
  - arquitectura
  - compose
aliases:
  - Android Arquitectura
platform: android
type: architecture
status: active
date: 2026-04-17
updated: 2026-04-21
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

## Monetizacion y sync

| Capability / oferta | Regla |
|---|---|
| Oferta paga Android | `Everywhere Monthly` o `Everywhere Annual` durante el rollout Apple-first |
| Premium local Android | viene incluido dentro de `Everywhere` |
| Backend sync | solo con `Everywhere` |
| Wear OS | hereda estado desde Android companion |
| Apple Unlock | no aplica a Android / Wear OS |
| Runtime actual | todavia usa un flag `premium` legacy, pendiente capability split |

## Principios

- Motor de foco unificado por estrategia (4 modos).
- Foreground service para sesiones resilientes.
- Paridad funcional obligatoria con iOS para features P0.

## Relacion con backend

- Auth y sync sobre API Go.
- Batch sync y reconciliacion por timestamps.
- Enforcement de `Everywhere` en app y server, con backend como autoridad final para sync e IA.

Ver tambien: [[../Backend/Arquitectura General|Backend Arquitectura]] · [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]]
