---
tags:
  - cross-platform
  - status
  - parity
aliases:
  - Estado Cross-Platform
  - Estado de Paridad
platform: cross-platform
type: status
doc_role: status
status: active
date: 2026-04-27
updated: 2026-04-27
---

# Estado Plataforma — Cross-Platform + Paridad

> [!abstract] Fuente canonica
> Documento de control para paridad funcional entre iOS, Android, watchOS y Wear OS, con limitaciones explícitas por plataforma.

## Estado actual

- Base de producto alineada en Focus Engine y Tasks core.
- Paridad de account shell y billing en transicion controlada.
- Ecosystem watch surfaces en progreso para cierre de gating y reviews.

## Bloqueantes externos

- [ ] RevenueCat: claves y offerings/entitlements en estado legacy.
- [ ] App Store Connect: metadata/review info de IAPs en cierre.
- [ ] Play Console: ajuste de catalogo y rollout de naming Everywhere/AI+.

## Riesgos de paridad de implementacion

- [ ] Propagacion de entitlement a watch surfaces (watchOS + Wear OS).
- [ ] Divergencia temporal de account ownership entre phone iOS y Android.
- [ ] Falta de cierre de capability split backend para enforcement uniforme.

## Referencias operativas

- [[Cross-Platform MOC]]
- [[Parity Matrix]]
- [[../_views/Parity Gaps|Parity Gaps]]
- [[Runbooks/RevenueCat Guia Apple Review|RevenueCat Apple review runbook]]
