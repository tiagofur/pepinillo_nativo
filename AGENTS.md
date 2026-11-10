# AGENTS.md — Mapa de navegación

> Punto de entrada para cualquier agente. Es un mapa, no un manual: lee sólo lo
> necesario y respeta las fuentes canónicas vigentes.

Pepinillo es un producto multiplataforma de **deep work / focus + tasks**
(`Plan → Focus → Complete → Reflect`) en fase de **Validación de Crecimiento**
(prioridades: Activación, Retención, Monetización y Confiabilidad).

---

## 0. Inicio y autorización

1. Lee la issue de GitHub aprobada (`status:ready` o `status:approved`), sus
   criterios (`S1..Sn`), exclusiones, rama base y PR existente. GitHub Issues es
   la **única** cola operativa de trabajo.
2. Lee el skill de tu rol en `.agents/skills/<rol>/SKILL.md` y
   `docs/factory/human-start.md`.
3. Preflight read-only: `python3 scripts/factory_preflight.py` (usa
   `--require-clean` antes del handoff final; no ejecuta tests ni autoriza escrituras).
4. Lee **únicamente** las fuentes canónicas del dominio afectado
   (`docs/README.md`). Nunca escanees `odd/tasks/` ni `docs/legacy/`.
   `make test` ejecuta guardrails + suite backend cuando el alcance lo requiere.

---

## 1. Ejecución portátil G-ODD

Gates deterministas `C1`–`C5` en [`CHECKPOINTS.md`](CHECKPOINTS.md):

| Topología G-ODD | Cuándo usarla | Artefacto de ejecución |
| :--- | :--- | :--- |
| **Inline Direct** | Cambio pequeño, acotado y comprendido; el contexto cabe en el diff | **Ninguno** (RED → GREEN y suite focalizada) |
| **Delegated Direct** | Trabajo sustancial, multi-unidad o multi-superficie entre sesiones | **Exactamente un `odd/tasks/<issue>-<slug>.md`** |

- **Un solo escritor por issue**, acotado a `## Allowed edit surfaces`.
- **Revisión independiente con contexto limpio (`C4`):** el `reviewer` jamás lee
  el chat del implementador; evalúa solo el paquete de
  `python3 scripts/factory_handoff.py`.
- **Revisión dual ciega (`judgment-day`):** obligatoria si el diff toca
  auth/seguridad, migraciones, `contracts/**`, scripts de la factoría o supera
  ~400 líneas modificadas.

---

## 2. Roles, áreas y fuentes canónicas

| Rol / Área | Lectura obligatoria aplicable |
| :--- | :--- |
| **Líder / Orquestador** | `.agents/skills/leader/SKILL.md`, `docs/factory/human-start.md` |
| **Implementador (por defecto)** | `.agents/skills/implementer/SKILL.md`, `CHECKPOINTS.md` |
| **Revisor independiente** | `.agents/skills/reviewer/SKILL.md`, `docs/factory/clean-context-review.md` |
| **Explorer read-only / Triage DoR** | `.agents/skills/explorer/SKILL.md`, `docs/factory/human-start.md` |
| **UX Brief (issues `ux:shape`)** | `.agents/skills/ux-brief/SKILL.md` (antes de escribir código) |
| **Mapa de documentación y estado hoy** | `docs/README.md` (enrutamiento), `docs/product-map.md` (implemented today) |
| **Producto, alcance y monetización** | `docs/prd-v2.md`, `docs/strategy/PRODUCT_DIRECTION.md` |
| **Arquitectura y contratos** | `docs/architecture.md`, `docs/conventions.md`, `docs/architecture/adr/README.md`, `contracts/openapi.yaml` |
| **Metodología Agent-First (~500 líneas)** | `docs/agent-first-methodology.md` |
| **Backend Go + ML (`backend/`)** | `backend/AGENTS.md`, `.agents/skills/go-backend/SKILL.md`, `ADR-0001` |
| **Apple Nativo (iOS/watchOS/macOS, `ios/`)** | `ios/AGENTS.md`, `.agents/skills/ios-native/SKILL.md`, `ios/docs/macos-design-contract.md` |
| **Android y Wear OS (`android/`)** | `android/AGENTS.md`, `.agents/skills/android-native/SKILL.md` |
| **Sistema de Diseño (HIG + Material 3)** | `docs/design.md`, `.impeccable.md` |
| **Verificación, CI y Flujo Git** | `docs/verification.md`, `docs/git-workflow.md` |
| **Despliegue, VPS y Secretos** | `docs/deployment.md`, `SECURITY.md` |
| **Reconciliación docs ↔ código e histórico** | `docs/documentation-sync-2026-11-10.md`, `docs/legacy/README.md` |

### Regla de conflicto documental

Si un documento histórico (`docs/legacy/**`) contradice una fuente canónica
actual y el código moderno: verifica la fuente ejecutable (código + tests +
`contracts/openapi.yaml`), distingue **implemented today**
(`docs/product-map.md`) de **target/visión**, no reviertas código moderno por
un PRD antiguo, y registra la discrepancia en la fuente de verdad apropiada.

---

## 3. Invariantes que nunca se omiten por eficiencia

- **Plataformas activas vs. en pausa:** activas son **iOS**, **watchOS**,
  **macOS (`PepinilloMac`)**, **Android**, **Wear OS** y **Backend Go**.
  **Web (`web/`)** y **Windows (`windows/`)** están **en pausa**; no expandirlos
  sin autorización explícita.
- **Paridad cross-platform activa:** todo fix o feature del motor de foco
  (`Pomodoro`, `Flowtime`, `TimeBlock`, `Stopwatch`), sesiones o tareas mantiene
  paridad funcional entre iOS, watchOS, macOS, Android y Wear OS.
- **Offline-first y sync LWW:** los clientes operan 100% offline (SwiftData
  `SchemaV6` en Apple; Room v14 en Android). La sync cloud
  (`POST /api/v1/sync/initial-upload`, `GET /api/v1/sync/full`,
  `POST /api/v1/sync/sessions`, `POST /api/v1/tasks/sync`) resuelve
  **Last-Write-Wins** con el reloj del servidor y requiere `everywhere_plus`.
- **Monetización v3.1:** `pepinillo_plus` (**Pepinillo+**, compra única) →
  premium local + IA on-device (Foundation Models con fallback de plantilla);
  `everywhere_plus` (**Everywhere/AI+**, suscripción) → sync cloud
  (`RequireBackendSync`) y IA avanzada en backend (`RequireProFeatureMiddleware`).
- **Contract-First OpenAPI 3.1:** todo cambio HTTP actualiza
  `contracts/openapi.yaml` primero y pasa `make contracts-lint` (`C2`). Errores
  HTTP con las envolventes reales del contrato (`ErrorEnvelope` /
  `ERR_TIER_INSUFFICIENT`); RFC 9457 objetivo para endpoints nuevos (`ADR-0003`).
- **Gramática nativa, marca compartida:** **HIG-first** en Apple y
  **Material 3 Expressive** en Android/Wear OS (`docs/design.md`). Nunca estirar
  vistas de iPhone/iPad para macOS.
- **Presupuesto cognitivo:** archivos de producción bajo ~500 líneas
  (`docs/agent-first-methodology.md`). Lo nuevo no entra a monolitos; al tocar
  uno, extrae la costura en un commit mecánico separado.
- **Seguridad y secretos:** prohibido commitear `.env`, claves `sk_` de
  RevenueCat, certificados o tokens (`SECURITY.md`). Ejecuta
  `python3 scripts/check_secrets.py` antes de publicar. Nunca ejecutes SQL
  destructivo sin confirmación explícita y backup.
- **Flujo Git determinista:** prohibido `git stash` como depósito entre sesiones
  (`docs/git-workflow.md`); usa ramas `wip/<tema>` con push. Commits atómicos
  con Conventional Commits en **inglés** y sin trailers de co-autoría IA.

---

## 4. Mapa físico del repositorio

```text
ios/          → App nativa iOS (`App/`, `Features/`, `Domain/`, `Shared/`), `PepinilloWatch` (watchOS),
                `PepinilloMac` (`Mac/`: menu bar AppKit, Notch panel, Quick Capture, Spotlight, Dock arc),
                Widgets, Live Activities, Control Center y App Intents (Swift 6 + TCA + SwiftData SchemaV6).
android/      → App nativa Android (`:app`) y reloj Wear OS (`:wear` con Tiles, Complications y Data Layer)
                en Kotlin + Jetpack Compose + Hilt + Room v14 + Glance.
backend/      → API REST/WebSocket en Go 1.24 (Fiber v2, hexagonal `internal/domain`, `ports`,
                `services`, `adapters`, PostgreSQL 16 + GORM, Redis 7) + sidecar Python `ml_service/`.
contracts/    → Especificación OpenAPI 3.1 (`openapi.yaml`), reglas Spectral y breaking changes.
docs/         → Documentación canónica (`README.md`, `product-map.md`, `prd-v2.md`, `architecture.md`,
                `conventions.md`, `verification.md`, `design.md`, `deployment.md`, `git-workflow.md`,
                `factory/`, `strategy/`, `legacy/`).
scripts/      → Guardrails (`factory_preflight.py`, `factory_handoff.py`, `check_pr_metadata.py`,
                `check_secrets.py`, `setup-labels.sh`).
odd/tasks/    → Artefactos de ejecución por issue (`<issue>-<slug>.md`).
progress/     → Estado vivo de sesión (`current.md`) y bitácora (`history.md`).
web/          → [EN PAUSA] Web Companion (Svelte 5 + SvelteKit 2 + IndexedDB).
windows/      → [EN PAUSA] Cliente de escritorio (C# / .NET / WinUI 3).
```

---

## 5. Comandos rápidos

```bash
make preflight        # Chequeo read-only de salud del arnés y árbol git (C1)
make test             # Guardrails Python + suite unitaria del backend Go (C3)
make test-factory     # Tests unitarios de scripts de la factoría
make test-backend     # go test ./... en backend/
make test-android     # ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest
make contracts-lint   # Valida contracts/openapi.yaml con Spectral (C2)
make contracts-diff   # Breaking changes OpenAPI contra origin/main (C2)
make handoff          # Paquete stateless de revisión con contexto limpio (C4)
```
