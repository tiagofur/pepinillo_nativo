---
tags:
  - backend
  - status
aliases:
  - Estado Backend
platform: backend
type: status
doc_role: status
status: active
date: 2026-04-27
updated: 2026-04-27
---

# Estado Plataforma — Backend

> [!abstract] Fuente canonica
> Este documento es la fuente de verdad operativa para estado y riesgos del backend.

## Estado actual

- API base funcional y testeada.
- Integraciones de autenticacion/sync activas.
- Enfoque vigente: monetizacion capability-based y enforcement server-side.

## Bloqueantes externos

- Dependencia de configuracion estable en RevenueCat para cerrar flujo end-to-end.

## Gaps de paridad de implementacion

- [ ] Capability split: `local_premium`, `apple_cloud_sync`, `backend_sync`, `ai_credits_monthly`.
- [ ] Ledger de creditos IA y reset mensual.
- [ ] Migracion de catalogo legacy `pro/premium` a modelo v3.1.

## Evidencia y referencias

- [[Backend MOC]]
- [[Autenticacion & Suscripciones]]
- [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]]
- [[../Cross-Platform/Parity Matrix|Parity Matrix]]
