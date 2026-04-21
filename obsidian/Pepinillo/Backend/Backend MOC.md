---
tags:
  - backend
  - moc
  - navegacion
aliases:
  - Backend MOC
  - Backend Hub
platform: backend
type: moc
status: active
date: 2026-04-17
updated: 2026-04-17
---

# ⚙️ Backend — Mapa de Contenido

> [!info] Plataforma
> **Stack**: Go, Fiber v2, GORM, PostgreSQL 16, Redis 7, MinIO
> **Rol**: Fuente de verdad para identidad, sync y billing
> **Estado**: ✅ Funcional y testeado — listo para deploy a VPS

---

## Infraestructura

| Area | Documento |
|------|-----------|
| Capas y arquitectura | [[Arquitectura General]] |
| Autenticacion y suscripciones | [[Autenticacion & Suscripciones]] |
| Monetizacion y entitlements | [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]] |
| Contrato API completo para iOS | [[API Contract iOS]] |
| Contrato de paridad app/watch | [[../Cross-Platform/Parity Matrix\|Parity Matrix]] |

## Impacto cross-platform

> [!tip] Regla operativa
> Todo cambio de API debe declarar impacto en iOS, Android, watchOS y Wear OS para preservar paridad funcional.

| Cambio backend | Revisar en |
|---|---|
| Endpoints de focus | iOS Focus + Android Focus + Watch/Wear |
| Endpoints de tasks | iOS Tasks + Android Tasks + Watch/Wear |
| Billing / entitlement | iOS paywall + Android paywall + server enforcement |
