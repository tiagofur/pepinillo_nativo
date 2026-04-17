---
tags:
  - ios
  - arquitectura
  - tca
aliases:
  - iOS Arquitectura
platform: ios
type: architecture
status: active
date: 2026-04-17
updated: 2026-04-17
---

# iOS - Arquitectura General

> [!abstract] Resumen
> iOS usa SwiftUI + TCA con clientes de dependencia para aislar foco, tareas, sync y billing con alta testabilidad.

## Stack

| Capa | Tecnologia |
|---|---|
| UI | SwiftUI |
| Estado | TCA |
| Persistencia local | SwiftData |
| Networking | URLSession + API client |
| Tiempo activo | ActivityKit / Live Activity |
| Integraciones | Siri App Intents, Apple Health, WatchConnectivity |

## Modulos funcionales

- [[Modulo Focus Engine]]
- [[Modulo Tasks]]
- [[Widgets & Live Activity]]

## Principios

- Un unico contrato de negocio para los 4 modos de foco.
- Efectos asincronos encapsulados en dependency clients.
- Paridad funcional obligatoria con Android para features P0.

## Relacion con backend

- Auth + refresh token via API central.
- Sync de sesiones y tareas con estrategia incremental.
- Enforcement de entitlement PRO coordinado con backend.

Ver tambien: [[../Backend/Arquitectura General|Backend Arquitectura]]
