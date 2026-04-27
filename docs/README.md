---
tags:
  - pepinillo
  - docs
  - obsidian
aliases:
  - Pepinillo Docs
  - Pepinillo Vault
status: active
date: 2026-04-17
updated: 2026-04-27
---

# Pepinillo - Documentacion Operativa

> [!abstract] Resumen
> Esta carpeta replica el estilo de Solennix para documentar Pepinillo con foco en arquitectura, paridad cross-platform y roadmap ejecutable.

## Punto de entrada

- [[00_DASHBOARD]]

## Fuentes canonicas de estado

- [[iOS/Estado Plataforma|Estado iOS + watchOS]]
- [[Android/Estado Plataforma|Estado Android + Wear OS]]
- [[Backend/Estado Plataforma|Estado Backend]]
- [[Cross-Platform/Estado Plataforma|Estado Cross-platform + Paridad]]

## Navegacion por area

- [[iOS/iOS MOC|iOS MOC]]
- [[Android/Android MOC|Android MOC]]
- [[Backend/Backend MOC|Backend MOC]]
- [[Cross-Platform/Cross-Platform MOC|Cross-Platform MOC]]
- [[Cross-Platform/Parity Matrix|Parity Matrix]]

## Estructura operativa recomendada

- `type: status`: fuente viva de estado por plataforma.
- `type: module` y `type: moc`: arquitectura y funcionalidad.
- `type: runbook`: guias operativas paso a paso.
- `type: audit` + `status: historical`: evidencia historica, no estado actual.

## Reglas de mantenimiento

1. Todo cambio que afecte paridad actualiza `Parity Matrix` y el `Estado Plataforma` correspondiente.
2. Los bloqueos externos (stores, billing dashboards) se registran en `Estado Plataforma` cross-platform.
3. Ningun audit historico reemplaza al estado canónico vigente.

## Fuente estrategica

- [[PRD/README|PRD Index]]
