# Pepinillo

Producto multiplataforma de **deep work / focus + tasks** construido con apps
nativas, companions de wearables y un backend ligero en Go.

Gobernado por una **Agentic Software Factory** con **Organic Driven Development
(G-ODD)**, **Contract-First OpenAPI 3.1** y **Revisiones Independientes con
Contexto Limpio**.

---

## Arquitectura y plataformas

| Plataforma | Stack tecnológico | Estado |
| :--- | :--- | :--- |
| **iOS / iPadOS** | Swift 6, The Composable Architecture (TCA), SwiftUI, SwiftData SchemaV6 | Activa |
| **watchOS** | Swift 6, TCA, SwiftUI (companion con Tiles/Complications equivalentes) | Activa |
| **macOS (`PepinilloMac`)** | Swift 6, SwiftUI + AppKit (NSStatusItem, Notch panel, Quick Capture) | Activa |
| **Android / Wear OS** | Kotlin, Jetpack Compose, Hilt, Room v14, Glance, Tiles | Activa |
| **Backend** | Go 1.24 (Fiber v2 + GORM), PostgreSQL 16, Redis 7, sidecar Python `ml_service` | Activa |
| **Windows Desktop** | C# / WinUI 3 / Windows App SDK | Experimento en pausa |
| **Web Companion** | Svelte 5 + SvelteKit 2 + IndexedDB (`idb`) | Experimento en pausa |

- **Fuente de verdad de producto**: [`docs/prd-v2.md`](docs/prd-v2.md) y
  [`docs/product-map.md`](docs/product-map.md) (qué existe hoy).
- **Fuente de verdad HTTP**: [`contracts/openapi.yaml`](contracts/openapi.yaml).
- **Documentación operativa**: [`docs/README.md`](docs/README.md) (tabla de
  enrutamiento por tarea) y [`docs/strategy/`](docs/strategy/).

---

## Agentic Software Factory

Pepinillo usa gobernanza estricta de ingeniería para prevenir context rot,
trabajo no autorizado y sesgo de auto-revisión:

1. **Autoridad estricta**: las GitHub Issues (`status:ready` / `status:approved`)
   son la única cola de trabajo autorizada.
2. **Agentes de rol cognitivo** ([`.agents/skills/`](.agents/skills/)):
   - `leader`: orquesta la ejecución G-ODD y los checkpoints `C1`–`C5`.
   - `explorer`: mapeo read-only del codebase (<2k tokens) y triage de issues (DoR).
   - `implementer`: único escritor acotado por superficie de edición; sigue TDD (V0/V1/V2).
   - `reviewer`: revisor independiente stateless; jamás lee el chat del implementador.
3. **Checkpoints deterministas** ([`CHECKPOINTS.md`](CHECKPOINTS.md)):
   - `C1`: chequeo de salud y Definition of Ready (`factory_preflight.py`).
   - `C2`: jerarquía de verdad (ADRs > PRD > Contratos > Docs > Código).
   - `C3`: verificación proporcional test-first (V0, V1, V2) y Conventional Commits.
   - `C4`: handoff stateless de revisión con contexto limpio (`factory_handoff.py`)
     y *Judgment Day* dual ciego para cambios de alto riesgo.
   - `C5`: verificación de metadatos de PR (`check_pr_metadata.py`).

---

## Comandos rápidos

```bash
make preflight        # Chequeo read-only de salud de la factoría y árbol git (C1)
make test             # Guardrails de la factoría y suite del backend (C3)
make test-factory     # Solo guardrails de la factoría
make test-android     # Tests unitarios de Android y Wear OS
make test-backend     # Tests unitarios del backend Go
make contracts-lint   # Lint de contracts/openapi.yaml con Spectral (C2)
make contracts-diff   # Breaking changes OpenAPI contra origin/main (C2)
make handoff          # Genera paquete de revisión con contexto limpio (C4)
make labels           # Sincroniza etiquetas de la factoría en GitHub (status, type, priority, size)
```
