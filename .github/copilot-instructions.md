# Pepinillo Project Instructions (Copilot)

## Alcance

Estas instrucciones aplican a todo el repositorio y complementan
[`AGENTS.md`](../AGENTS.md) (mapa de navegación) y
[`CHECKPOINTS.md`](../CHECKPOINTS.md) (compuertas `C1`–`C5`).

## Comunicación

- Idioma por defecto: inglés para respuestas, commits y artefactos de
  colaboración, salvo que se pida otro idioma explícitamente.
- Sé directo, práctico y explica el razonamiento técnico al proponer cambios.

## Prioridades de ingeniería

- Mantén paridad funcional entre iOS, watchOS, macOS, Android y Wear OS en el
  motor de foco, sesiones y tareas. `web/` y `windows/` están en pausa.
- UI nativa por plataforma: HIG-first en Apple, Material 3 Expressive en
  Android/Wear OS (`docs/design.md`). Paridad funcional obligatoria; paridad
  visual no.
- Prefiere claridad de arquitectura sobre parches rápidos.

## Gestión de cambios

- Mantén los diffs mínimos y evita refactors no relacionados.
- No reviertas cambios no relacionados del usuario.
- No añadas líneas de atribución IA en los commits.

## Validación

- Ejecuta primero los checks focalizados (lint, tests específicos), luego
  builds de las plataformas tocadas antes del handoff cuando sea práctico.

| Área tocada | Checks focalizados | Build/handoff |
| :--- | :--- | :--- |
| `backend/` | `cd backend && go test ./...` | ídem |
| `android/app` | `cd android && ./gradlew :app:testDebugUnitTest` | `./gradlew :app:assembleDebug` |
| `android/wear` | `cd android && ./gradlew :wear:testDebugUnitTest` | `./gradlew :wear:assembleDebug` |
| `ios/` (iPhone/iPad) | `xcodegen generate` + `xcodebuild test -scheme "Pepinillo Dev"` (ver `docs/verification.md`) | `xcodebuild build -scheme "Pepinillo Dev"` |
| `ios/` (macOS) | `xcodebuild build -scheme "PepinilloMac Dev"` | ídem |
| `contracts/` | `make contracts-lint` | `make contracts-diff` |

## Sincronización de documentación

- La fuente de verdad de producto vive en `docs/prd-v2.md` y
  `docs/product-map.md` (no hay forks de PRD bajo `docs/legacy/`).
- Actualiza `docs/product-map.md` y/o `docs/prd-v2.md` para features nuevas y
  cambios significativos; no para bugfixes menores salvo que alteren
  arquitectura o dirección de producto.

## Flujo Git

- Conventional Commits en inglés, commits atómicos, sin trailers de co-autoría
  IA. Nunca uses `git stash` como depósito entre sesiones.
- Tras checkpoints locales, haz push para preservar puntos de rollback.

## Checklist de Pull Request

- Todo PR declara paridad por plataforma (o justifica "not impacted").
- Todo PR incluye evidencia de validación según la matriz de arriba.
- Todo PR clasifica impacto en PRD: `No PRD update required` o
  `PRD update required` con los archivos exactos.
- Todo PR incluye evaluación de riesgo y nota de rollback
  (plantilla `.github/PULL_REQUEST_TEMPLATE.md`, validada por
  `scripts/check_pr_metadata.py`).
