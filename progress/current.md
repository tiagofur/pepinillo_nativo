# Estado vivo de sesión — 2026-11-10

> Archivo de trabajo append-friendly: se actualiza al inicio y cierre de cada
> sesión de agente. No es fuente de verdad de producto (`docs/product-map.md`)
> ni cola de trabajo (GitHub Issues).

## Sesión actual

- **Fecha**: 2026-11-10
- **Rama**: `docs/agent-docs-overhaul`
- **Alcance autorizado**: reconciliación documental Agent-First (limpieza Git,
  archivo `docs/legacy/`, contratos OpenAPI, ADRs, gobernanza raíz y docs
  canónicos en español).
- **Estado**: en progreso — bloque de gobernanza raíz.

## Próximos pasos inmediatos

1. Completar docs canónicos (`docs/README.md`, `product-map.md`, `prd-v2.md`,
   `architecture.md`, `conventions.md`, `design.md`, `verification.md`,
   `deployment.md`, `git-workflow.md`).
2. Crear guías por plataforma (`backend/AGENTS.md`, `ios/AGENTS.md`,
   `android/AGENTS.md`) y actualizar skills.
3. Verificación end-to-end (`make test-factory`, `make contracts-lint`,
   `python3 scripts/check_secrets.py`, `make test-backend`).

## Cambios locales apartados (fuera de este alcance)

- `android/gradle/libs.versions.toml` e `ios/Shared/Resources/*.xcstrings`
  (6–9 nov) preservados en la rama `chore/local-deps-and-xcstrings`.
