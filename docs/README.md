# Pepinillo — Documentación canónica (Agent-First)

> Tabla de enrutamiento: lee **solo** lo que tu tarea necesita. Nunca escanees
> `docs/legacy/` ni `odd/tasks/` al iniciar una sesión.

## Enrutamiento por tarea

| Si vas a tocar... | Lee primero | Complementos |
| :--- | :--- | :--- |
| Cualquier cosa (entrada general) | [`../AGENTS.md`](../AGENTS.md) | [`../CHECKPOINTS.md`](../CHECKPOINTS.md) |
| Alcance de producto, prioridades, pricing | [`prd-v2.md`](prd-v2.md) | [`strategy/PRODUCT_DIRECTION.md`](strategy/PRODUCT_DIRECTION.md), [`strategy/GROWTH_VALIDATION_PLAN.md`](strategy/GROWTH_VALIDATION_PLAN.md) |
| "¿Existe X hoy?" (estado por plataforma) | [`product-map.md`](product-map.md) | [`strategy/PLATFORM_DECISIONS.md`](strategy/PLATFORM_DECISIONS.md) |
| `backend/**`, sync LWW, auth, billing | [`architecture.md`](architecture.md), [`../contracts/openapi.yaml`](../contracts/openapi.yaml) | [`../backend/AGENTS.md`](../backend/AGENTS.md), [`architecture/adr/ADR-0001-go-backend-and-db-matrix.md`](architecture/adr/ADR-0001-go-backend-and-db-matrix.md) |
| `ios/**` (iPhone/iPad/watchOS/macOS) | [`architecture.md`](architecture.md) § Apple | [`../ios/AGENTS.md`](../ios/AGENTS.md), [`../ios/docs/macos-design-contract.md`](../ios/docs/macos-design-contract.md) |
| `android/**` (phone/Wear OS) | [`architecture.md`](architecture.md) § Android | [`../android/AGENTS.md`](../android/AGENTS.md) |
| UI/UX, tema, glass, soundscapes | [`design.md`](design.md) | [`../.impeccable.md`](../.impeccable.md) |
| Cambios HTTP | [`../contracts/openapi.yaml`](../contracts/openapi.yaml) **antes del código** | [`architecture/adr/ADR-0003-contract-first-openapi.md`](architecture/adr/ADR-0003-contract-first-openapi.md) |
| Verificación y CI | [`verification.md`](verification.md) | [`../Makefile`](../Makefile), `.github/workflows/` |
| Despliegue, VPS, secretos | [`deployment.md`](deployment.md) | [`../SECURITY.md`](../SECURITY.md) |
| Flujo Git y PRs | [`git-workflow.md`](git-workflow.md) | [`../.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md) |
| Estructura de archivos / presupuesto de líneas | [`agent-first-methodology.md`](agent-first-methodology.md) | [`conventions.md`](conventions.md) |
| Proceso de factoría (roles, review C4) | [`factory/human-start.md`](factory/human-start.md) | [`factory/clean-context-review.md`](factory/clean-context-review.md) |
| Contexto histórico o PRD antiguo | [`legacy/README.md`](legacy/README.md) (solo referencia; no es fuente de verdad) | [`documentation-sync-2026-11-10.md`](documentation-sync-2026-11-10.md) |

## Reglas de mantenimiento

1. Todo cambio que afecte paridad actualiza `product-map.md`.
2. Todo cambio de alcance/pricing actualiza `prd-v2.md`.
3. Todo cambio HTTP actualiza `contracts/openapi.yaml` **primero** (`C2`).
4. Ningún documento bajo `docs/legacy/` reemplaza a la fuente canónica vigente.
5. Archivo nuevo de producción bajo ~500 líneas (`agent-first-methodology.md`).
