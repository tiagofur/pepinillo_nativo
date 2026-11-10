# Bitácora de sesiones (append-only)

Una entrada por sesión de agente relevante. No editar entradas previas; añadir
al final. Detalle vivo por sesión en `progress/current.md`.

---

## 2026-11-10 — Reconciliación documental Agent-First

- **Issue de referencia**: cierre de deuda de `#706` (fork `docs/PRD/`, artefactos raíz/backend) y adaptación de la plantilla `software-factory-base` mergeada en PR #720.
- **Rama**: `docs/agent-docs-overhaul` (desde `origin/main` @ `2668d5fc`).
- **Decisiones registradas**:
  - Los cambios locales de Android/iOS del 6–9 nov se apartaron en `chore/local-deps-and-xcstrings`.
  - `docs/legacy/` se mantiene como archivo histórico con `README.md` de precedencia; se eliminó el fork duplicado `obsidian-vault/PRD/` y los docs obsoletos señalados por `#706`.
  - `odd/tasks/` se vació hacia `docs/legacy/odd-tasks/` (los archivos no seguían la convención `<issue>-<slug>.md`).
  - `contracts/openapi.yaml` reescrito con las ~90 rutas reales `/api/v1` y las envolventes de error vigentes (`ErrorEnvelope`, `ERR_TIER_INSUFFICIENT`).
  - Documentación unificada en español; commits y símbolos permanecen en inglés.
