---
tags:
  - super-plan
  - release
  - quality
  - governance
aliases:
  - Release Gates
status: active
created: 2026-04-10
updated: 2026-04-10
---

# 05 - Release Governance and Quality Gates

## Politica

No se fusiona ni se libera nada sin evidencia objetiva de calidad.

## Gates por Pull Request

1. Build obligatorio por plataforma afectada.
2. Tests obligatorios por dominio afectado.
3. Validacion de contratos si cambia API.
4. Checklist de impacto cross-platform.

## Gates por Release Candidate

1. Matriz de dispositivos completa aprobada.
2. Flujo core de negocio aprobado (crear evento end-to-end).
3. Cero bugs P0/P1 abiertos.
4. Reporte de riesgos actualizado en [[08_RISK_REGISTER_AND_CONTINGENCIES]].

## Severidades y bloqueo

- P0: bloquea merge y release.
- P1: bloquea release.
- P2: se planifica en ola siguiente.

## Evidencias minimas

1. Salida de builds/tests.
2. Checklist firmado de UX por dispositivo.
3. Referencia de issues y fixes asociados.

## Enlaces

- [[SUPER PLAN MOC]]
- [[12_EXECUTION_CHECKLISTS]]
- [[11_CROSS_PLATFORM_KPI_SCORECARD]]
- [[Testing]]
- [[Roadmap Web]]
- [[Roadmap iOS]]
- [[Roadmap Android]]
- [[Roadmap Backend]]
