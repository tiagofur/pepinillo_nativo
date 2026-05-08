---
tags:
  - android
  - status
  - wearos
  - parity
aliases:
  - Estado Android
  - Estado Android + Wear OS
  - Estado Paridad Android
platform: android
type: status
doc_role: status
status: active
date: 2026-04-27
updated: 2026-04-27
---

# Estado Plataforma — Android + Wear OS

> [!abstract] Fuente canonica
> Este documento es la fuente de verdad operativa para estado y riesgos de Android/Wear OS.

## Baseline de paridad

- Baseline funcional: iOS + watchOS (no paridad visual).
- Regla: Android/Wear deben igualar capacidades de negocio y comportamiento, respetando UI nativa Android.
- Referencia canonica: [[../iOS/Estado Plataforma|Estado iOS + watchOS]].

## Estado actual

- Android phone: shell `Focus / Plan / Dashboard / More` implementada y operativa.
- Android phone: `More` ya centraliza profile/subscription/settings/app setup; faltan cierres de ownership para help/about/export.
- Wear OS: companion funcional con timer/tasks/stats, pero con deuda en propagacion de entitlement y surfaces premium.
- Build local: compila, pero hay fallas en tests unitarios de Wear OS que afectan la confianza de regresion.

## Status de paridad funcional (vs iOS baseline)

| Area | Estado | Android phone | Wear OS | Nota |
|---|---|---|---|---|
| Shell principal (`Focus/Plan/Dashboard/More`) | 🚧 Parcial | Implementado, falta validacion final en device y QA de ownership | N/A | Paridad de IA en cierre |
| Account hub ownership (`More`) | 🚧 Parcial | Profile/subscription/settings listos; help/about/export pendientes de cierre real | N/A | `Export` aun sin surface Android equivalente |
| Focus Engine (4 modos) | ✅ Implementado | 4 modos activos, journaling y task linking | 4 modos activos con gating | Diferencias solo de UI nativa |
| Tasks core (CRUD, subtareas, recurrencia, reorder) | ✅ Implementado | Funcional en runtime actual | Parcial en companion | Reorder ya disponible en phone |
| Dashboard + reviews | 🚧 Parcial | Diario/semanal/mensual implementados | Stats simplificadas | Falta cierre premium y UX de watch |
| Billing/entitlements v3.1 | 🚧 Parcial | Runtime mezcla naming legacy y nuevo | Depende de propagacion phone->wear | Riesgo alto de drift de entitlement |
| Companion entitlement propagation | 🚧 Parcial | Envio desde phone implementado | Recepcion y gating implementados, falta cierre Everywhere/AI+ | Gap declarado en parity |

## Bloqueantes externos

- Migracion comercial completa depende de cierre cross-platform de billing (RevenueCat + stores).
- Cierre de offerings/entitlements canonicos sigue condicionado por tareas externas de consola.

## Gaps de paridad de implementacion

- [ ] Completar `More` como owner canonical de profile/settings/billing/help/about/export (incluyendo surface de export en Android).
- [ ] Cerrar links funcionales de `Help & Support` y `About` (hoy dependen de surfaces secundarias no dedicadas).
- [ ] Completar feature gating por capabilities en analytics/widgets/temas y eliminar drift legacy `pro/premium`.
- [ ] Cerrar propagacion de estado Everywhere/AI+ al companion Wear OS en todas las surfaces (views, tiles y complications).
- [ ] Alinear validacion de entitlements Android con naming canonico (`pepinillo_plus` / `everywhere_plus`) sin perder backward compatibility.
- [ ] Recuperar verde en tests unitarios Wear OS como gate minimo de paridad estable.

## Roadmap de ejecucion

- Ver [[Roadmap Paridad Funcional con iOS]] para plan por fases, hitos y criterio de salida.

## Evidencia y referencias

- [[Android MOC]]
- [[Audit Produccion Android]]
- [[../Cross-Platform/Parity Matrix|Parity Matrix]]
- [[../_views/Parity Gaps|Parity Gaps]]
- [[../iOS/Estado Plataforma|Estado iOS + watchOS]]
