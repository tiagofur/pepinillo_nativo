# ADR-0003: Contratos OpenAPI 3.1 (`contracts/openapi.yaml`) y Envolventes de Error

- **Estado**: Accepted (alineado con implementación HTTP real y hoja de ruta de errores)
- **Fecha**: 2026-11-10 (original de plantilla: 2026-10-29)
- **Decisores**: Pepinillo Architecture Core

---

## 1. Contexto

El backend Go de Pepinillo sirve ~90 rutas HTTP bajo `/api/v1` consumidas por Swift (`NetworkClient.swift`) y Kotlin (`PepinilloApiClient.kt`), además de un endpoint WebSocket (`/api/v1/ws`). Para evitar deriva entre el servidor y los clientes nativos, la especificación `contracts/openapi.yaml` debe reflejar con exactitud el contrato HTTP en producción y someterse a compuertas automáticas (`Checkpoint C2`).

---

## 2. Decisión

1. **Única fuente de verdad HTTP (`contracts/openapi.yaml`)**:
   - Toda ruta HTTP nueva o cambio en payloads, query params, cabeceras (`Authorization`, `X-Device-ID`) o códigos de estado bajo `/api/v1` se declara primero en `contracts/openapi.yaml` (OpenAPI 3.1.0).
   - El canal WebSocket `/api/v1/ws` y sus eventos (`WSMessage`) se documentan en `info.description` del contrato y en `docs/architecture.md`.
2. **Envolventes de error reales y transición a RFC 9457**:
   - **Comportamiento vigente (no romper clientes actuales)**: el `ErrorHandler` global de Fiber retorna `ErrorEnvelope` (`{"error": "<codigo_o_mensaje>"}`), y `RequireBackendSync` devuelve HTTP `402` con `BackendSyncRequiredError` (`{"error":"subscription_required","code":"ERR_TIER_INSUFFICIENT","message":...,"upgrade_url":...}`).
   - **Política para cambios futuros**: no alterar en caliente el formato de rutas ya consumidas por apps publicadas en App Store / Play Store sin coordinar clientes o versionar. Para nuevas superficies/versiones (`/api/v2` o endpoints nuevos opt-in), RFC 9457 `ProblemDetails` (`application/problem+json`) es el formato objetivo a declarar en `contracts/openapi.yaml`.
3. **Compuertas automáticas (`contracts/Makefile`)**:
   - `make contracts-lint`: ejecuta Spectral (`@stoplight/spectral-cli@6.17.0` con `contracts/.spectral.yaml`). Exige `operationId` único, `tags` y esquema válido (fail-closed si falta el runner).
   - `make contracts-diff`: ejecuta `oasdiff breaking --fail-on ERR` contra `origin/main` (fail-closed salvo etiqueta `contract-break` aprobada por humano).
   - El target `generate` en `contracts/Makefile` conserva referencias de compatibilidad para los tests de la factoría (`tests/test_factory_scripts.py`); hoy los DTOs nativos en Swift y Kotlin se validan contra `contracts/openapi.yaml` hasta introducir codegen automatizado en una issue dedicada.

---

## 3. Consecuencias

- Los agentes `explorer`, `implementer` y `reviewer` pueden verificar cualquier endpoint, payload o header en `contracts/openapi.yaml` sin adivinar structs Go.
- Cualquier modificación bajo `contracts/**` dispara automáticamente revisión dual ciega (`judgment-day`) en `scripts/factory_handoff.py`.
