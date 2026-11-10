---
tags:
  - android
  - roadmap
  - parity
aliases:
  - Roadmap Paridad Android
  - Android Parity Roadmap
platform: android
type: roadmap
status: active
date: 2026-04-27
updated: 2026-04-27
owner: mobile
---

# Roadmap Paridad Funcional con iOS

> [!abstract] Objetivo
> Lograr paridad funcional Android + Wear OS respecto del baseline iOS + watchOS, manteniendo diseno nativo por plataforma.

## Baseline y reglas

- Baseline funcional: [[../iOS/Estado Plataforma|Estado iOS + watchOS]].
- Contrato de paridad: [[../Cross-Platform/Parity Matrix|Parity Matrix]].
- Regla de cierre: no se cierra un item de Android sin validar impacto equivalente en Wear OS y en docs de paridad.

## Estado de partida (2026-04-27)

| Stream | Estado | Riesgo |
|---|---|---|
| Shell + Account ownership | En progreso | Medio |
| Billing/entitlements v3.1 | En progreso | Alto |
| Wear entitlement propagation | En progreso | Alto |
| Analytics/widgets capability gating | En progreso | Medio |
| Test reliability (Wear unit tests) | Inestable | Medio |

## Fase 1 — Cierre de account parity (P0)

**Objetivo:** que `More` en Android replique ownership funcional de iOS para account/admin.

### Entregables

- Surface Android de `Export` accesible desde `More`.
- Cierre funcional de `Help & Support` y `About` con destinos dedicados o equivalentes claros.
- Confirmacion de ownership final: profile/settings/subscription/help/about/export bajo `More`.

### Criterio de salida

- `ACC-001` pasa a ✅ en [[../Cross-Platform/Parity Matrix|Parity Matrix]].
- `Export accesible desde account area` pasa de 📋/🚧 a ✅ para Android phone.

## Fase 2 — Billing y entitlements canonicos (P0)

**Objetivo:** eliminar drift entre Android y iOS en evaluacion de entitlements.

### Entregables

- Android reconoce entitlements canonicos (`pepinillo_plus`, `everywhere_plus`) con fallback legacy (`premium`, `pro`).
- Naming de runtime/paywall/settings alineado a v3.1 (evitar lenguaje ambiguo legacy en nuevas surfaces).
- Matriz de capabilities consistente entre app phone y companion watch.

### Criterio de salida

- Verificacion de compra/restauracion en escenarios nuevos y grandfathered.
- Sin regresiones en gating de modos, analytics, widgets y sync.

## Fase 3 — Wear OS parity hardening (P0/P1)

**Objetivo:** paridad funcional de companion respecto a watchOS dentro de limites de UX de reloj.

### Entregables

- Propagacion confiable de entitlement phone -> wear en vistas, tiles y complications.
- Cierre de gating premium en stats y superficies de foco/tareas.
- Definicion explicita de limitaciones aceptadas de UX en reloj (si aplica).

### Criterio de salida

- `BILL-001` actualizado con evidencia nueva en matriz.
- Gaps de watch sin blockers funcionales abiertos.

## Fase 4 — Quality gate y consistencia documental (P1)

**Objetivo:** estabilizar validacion y dejar docs sincronizadas con runtime real.

### Entregables

- Recuperar verde en tests unitarios de Wear OS.
- Checklist de validacion por release para Android + Wear OS.
- Actualizacion sincronizada de:
  - [[Estado Plataforma]]
  - [[Android MOC]]
  - [[../Cross-Platform/Parity Matrix|Parity Matrix]]

### Criterio de salida

- Build + tests de Android/Wear sin fallos de regresion.
- Documentacion sin drift entre estado declarado y comportamiento real.

## Riesgos y mitigaciones

| Riesgo | Impacto | Mitigacion |
|---|---|---|
| Drift de entitlements por rollout parcial | Alto | Doble lectura canonica+legacy y tests de regresion de billing |
| Cierres solo de UI sin comportamiento equivalente | Alto | Checklist funcional por capability, no por pantalla |
| Drift docs vs runtime | Medio | Actualizar docs como parte del definition of done de cada fase |
| Companion wear con estado inconsistente | Alto | Validacion end-to-end phone->wear en QA de cada release |

## Secuencia recomendada

1. Fase 1 (Account ownership).
2. Fase 2 (Billing/entitlements).
3. Fase 3 (Wear hardening).
4. Fase 4 (Quality gate + docs lock).

## Referencias

- [[Estado Plataforma]]
- [[Android MOC]]
- [[../iOS/Estado Plataforma|Estado iOS + watchOS]]
- [[../Cross-Platform/Parity Matrix|Parity Matrix]]
- [[../Cross-Platform/Monetizacion y Entitlements|Monetizacion y Entitlements]]
