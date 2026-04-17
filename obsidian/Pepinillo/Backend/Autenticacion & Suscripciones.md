---
tags:
  - backend
  - auth
  - billing
status: active
date: 2026-04-17
updated: 2026-04-17
---

# Backend - Autenticacion & Suscripciones

> [!abstract] Resumen
> Este modulo controla identidad, sesiones y entitlement PRO para garantizar reglas consistentes en todas las plataformas.

## Autenticacion

- Login/Register con JWT.
- Renovacion de token para sesiones largas.
- Integracion con proveedores OAuth segun plataforma.

## Suscripciones

| Fuente | Rol |
|---|---|
| RevenueCat | Estado de entitlement `pro` |
| Backend | Enforcement final por usuario |
| Apps cliente | UX de paywall y gating local |

## Endpoint operativo

- Verificacion de billing: `POST /api/v1/billing/verify`
- Webhook RevenueCat: `POST /api/v1/webhooks/revenuecat`

## Regla de enforcement

1. Cliente consulta estado y adapta UI.
2. Backend valida entitlement para operaciones protegidas.
3. Si hay divergencia, backend prevalece.

## Checklist de paridad

- iOS y Android deben mapear el mismo entitlement (`pro`/`premium`).
- watchOS y Wear OS respetan gating recibido desde companion app.
- Cambios de pricing se documentan tambien en PRD monetizacion.
