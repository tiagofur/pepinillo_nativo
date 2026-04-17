---
tags:
  - super-plan
  - risks
  - contingencies
aliases:
  - Risk Register
status: active
created: 2026-04-10
updated: 2026-04-10
---

# 08 - Risk Register and Contingencies

## Riesgos P0 iniciales

1. Regresiones en navegacion/formularios core.
2. Drift de contrato entre backend y clientes.
3. Paridad incompleta en flujo de eventos.
4. Inconsistencias financieras entre plataformas.

## Riesgos P1 iniciales

1. Rendimiento en listas grandes.
2. Comportamiento offline/online no uniforme.
3. UX tablet incompleta frente a smartphone.
4. Cobertura de tests insuficiente en modulos clave.

## Mecanismo de contingencia

1. Congelamiento temporal de merges de riesgo.
2. Hotfix lane con validacion reducida pero controlada.
3. Rollback de release candidate a ultimo baseline green.
4. Escalamiento de decision en ritual de riesgo semanal.

## Trigger de accion inmediata

- Cualquier bug P0 nuevo.
- Falla de build en dos plataformas a la vez.
- Diferencia de contratos en endpoint core.
- Falla de flujo crear evento en cualquier dispositivo matriz.

## Enlaces

- [[SUPER PLAN MOC]]
- [[05_RELEASE_GOVERNANCE_AND_QUALITY_GATES]]
- [[07_WAVE_PLAN_12_WEEKS]]
- [[11_CURRENT_STATUS]]
- [[Roadmap Backend]]
- [[Roadmap Android]]
- [[Roadmap iOS]]
- [[Roadmap Web]]
