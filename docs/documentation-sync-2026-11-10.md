# Bitácora de reconciliación docs ↔ código — 2026-11-10

Sesión de consolidación documental sobre la rama `docs/agent-docs-overhaul`
(desde `origin/main` @ `2668d5fc`, que incluía la factoría de PR #720).

## Problemas encontrados y corregidos

1. **Migración a medias (8 nov)**: renames a `docs/legacy/` staged + borrador
   de `AGENTS.md` que citaba ~18 archivos inexistentes. **Corregido**: todos
   los paths citados ahora existen; el índice operativo vive en
   `docs/README.md` (tabla de enrutamiento) y el estado real en
   `docs/product-map.md`.
2. **Fork de PRD prohibido** (issue #706): `docs/legacy/obsidian-vault/PRD/`
   duplicaba la serie legacy. **Corregido**: eliminado (los 10 documentos
   diferían solo en su stub "Deprecated PRD Location"); `PRD/` y `docs/PRD/`
   raíz ya no existen.
3. **Artefactos obsoletos** (#706): `INFRASTRUCTURE_SUMMARY.txt`,
   `backend/BACKENDEND_ALIGNMENT_SUMMARY.md`, `backend/OAUTH_INTEGRATION.md`
   **eliminados** (cubiertos por `docs/deployment.md`, `docs/architecture.md`
   y `backend/AGENTS.md`).
4. **`odd/tasks/` no conforme**: 18 bitácoras sin prefijo `<issue>-` (rompería
   el matching de `factory_handoff.py`). **Corregido**: archivadas en
   `docs/legacy/odd-tasks/`; `odd/tasks/` queda vacío para tareas activas.
5. **Basura trackeada eliminada**: `.context/` (45), `.artifacts/` (3),
   `android/.artifacts/` (3), `scratch/` (9), `ios/apple_store/logs/*.log` (9
   logs de distribución Xcode — reincidente tras PR #705, que limpió
   `ios/docs/logs/`), dumps UIAutomator de `android/`, `emulator_start.log`,
   `error.jpeg`, `.atl/.skill-registry.cache.json`, `install-debug-pair.ps1`,
   `install_physical.ps1`, `validate_wear_sync.ps1` (scripts ADB Windows sin
   referencias activas). `.gitignore` actualizado (`ios/` en vez de
   `pepinillo_ios/`, `android/*.xml`, `android/emulator.log`, `.context/`,
   excepción `!.atl/skill-registry.md`).
6. **Plantilla `software-factory-base` sin adaptar**: `contracts/openapi.yaml`
   (solo `/healthz` ficticio), `ADR-0001..0003` (chi/sqlc/Tauri/React
   inexistentes), `feature_list.json` (entrypoints `ios/Sources/`,
   `ios/watchOS/`, `backend/cmd/api/` de plantilla), `ISSUE_TEMPLATE/feature.yml`
   (superficies Tauri/React), `PULL_REQUEST_TEMPLATE.md` (referenciaba `PRD/..`).
   **Corregido**: contrato OpenAPI 3.1 con las ~90 rutas reales `/api/v1` y
   envolventes de error vigentes; ADRs reescritos al stack real (Fiber v2 +
   GORM + Postgres 16 + Redis 7 + `ml_service`; Swift 6/TCA/SwiftData V6;
   Kotlin/Compose/Hilt/Room v14); `feature_list.json` con entrypoints reales;
   templates alineados (secciones exactas que valida `check_pr_metadata.py`).
7. **Instrucciones contradictorias**: `CLAUDE.md` raíz (Agent Teams Lite, PRD/
   de 14 docs, Windows activo) y `.github/copilot-instructions.md` (solo
   4 plataformas, PRD fork). **Corregido**: `CLAUDE.md` es ahora un puntero a
   `AGENTS.md`; copilot-instructions reescrito con la matriz real de 6
   superficies y comandos verificables.
8. **Docs de estrategia y factoría** traducidos/actualizados al español con
   paths reales (sin `docs/stack/`, sin `--non-interactive` inexistente,
   `apps/*` → superficies reales).

## Regla vigente de precedencia

1. Código + tests + `contracts/openapi.yaml` (ejecutable).
2. `docs/prd-v2.md` / `docs/product-map.md` / `docs/architecture.md` /
   ADRs / skills.
3. `docs/legacy/**` — **solo referencia histórica** (`docs/legacy/README.md`).
