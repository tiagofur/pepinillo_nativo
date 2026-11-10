# AGENTS.md — Mapa de navegación

> Punto de entrada para cualquier agente. Es un mapa, no un manual: lee sólo lo
> necesario y respeta las fuentes canónicas vigentes.

Pepinillo es un producto multiplataforma de **deep work / focus + tasks**
(`Plan → Focus → Complete → Reflect`) en fase de **Validación de Crecimiento**
(prioridades: Activación, Retención, Monetización y Confiabilidad).

---

## 0. Inicio y autorización

1. Lee la issue de GitHub aprobada (`status:ready` o `status:approved`), sus
   criterios de aceptación (`S1..Sn`), exclusiones, rama base y PR existente.
   GitHub Issues es la **única** cola operativa de trabajo.
2. Lee el skill de tu rol cognitivo en `.agents/skills/<rol>/SKILL.md` y
   `docs/factory/human-start.md`.
3. Ejecuta el preflight en modo solo lectura:
   ```bash
   python3 scripts/factory_preflight.py
   ```
   Usa `--require-clean` antes del handoff final. No ejecuta tests ni autoriza escrituras.
4. Verifica el alcance y lee **únicamente** las fuentes canónicas del dominio
   afectado (`docs/README.md`). Nunca escanees `odd/tasks/` ni `docs/legacy/`.

`make test` ejecuta los guardrails de la factoría y la suite del backend cuando
el alcance lo requiere.

---

## 1. Ejecución portátil G-ODD

Pepinillo opera con los gates deterministas `C1`–`C5`
([`CHECKPOINTS.md`](CHECKPOINTS.md)):

| Topología G-ODD | Cuándo usarla | Artefacto de ejecución |
| :--- | :--- | :--- |
| **Inline Direct** | Cambio pequeño, acotado y comprendido donde el contexto cabe en el diff | **Ninguno** (ciclo RED → GREEN y suite focalizada) |
| **Delegated Direct** | Trabajo sustancial, multi-unidad o multi-superficie con recuperación entre sesiones | **Exactamente un `odd/tasks/<issue>-<slug>.md`** |

- **Un solo escritor por issue:** acotado estrictamente a `## Allowed edit surfaces`.
- **Revisión independiente con contexto limpio (`C4`):** el `reviewer` **jamás**
  lee el historial de chat del implementador; evalúa únicamente el paquete
  determinista generado por `python3 scripts/factory_handoff.py`.
- **Revisión dual ciega (`judgment-day`):** obligatoria cuando el diff toca
  auth/seguridad, migraciones, contratos (`contracts/**`), scripts de la
  factoría o supera las ~400 líneas modificadas.

---

## 2. Roles, áreas y fuentes canónicas

| Rol / Área | Lectura obligatoria aplicable |
| :--- | :--- |
| **Líder / Orquestador** | `.agents/skills/leader/SKILL.md`, `docs/factory/human-start.md` |
| **Implementador (por defecto)** | `.agents/skills/implementer/SKILL.md`, `CHECKPOINTS.md` |
| **Revisor independiente** | `.agents/skills/reviewer/SKILL.md`, `docs/factory/clean-context-review.md` |
| **Explorer read-only / Triage DoR** | `.agents/skills/explorer/SKILL.md`, `docs/factory/human-start.md` |
| **UX Brief (issues `ux:shape`)** | `.agents/skills/ux-brief/SKILL.md` (antes de escribir código) |
| **Mapa general de documentación** | `docs/README.md` (tabla de enrutamiento por tarea; no leer todo) |
| **Mapa mental y estado real hoy** | `docs/product-map.md` (qué existe hoy vs. visión y plataformas en pausa) |
| **Producto, alcance y monetización** | `docs/prd-v2.md`, `docs/strategy/PRODUCT_DIRECTION.md` |
| **Arquitectura, contratos y convenciones** | `docs/architecture.md`, `docs/conventions.md`, `docs/architecture/adr/README.md`, `contracts/openapi.yaml` |
| **Metodología Agent-First (presupuesto ~500 líneas)** | `docs/agent-first-methodology.md` |
| **Backend Go + ML (`backend/`)** | `backend/AGENTS.md`, `.agents/skills/go-backend/SKILL.md`, `docs/architecture/adr/ADR-0001-go-backend-and-db-matrix.md` |
| **Apple Nativo: iOS, watchOS y macOS (`ios/`)** | `ios/AGENTS.md`, `.agents/skills/ios-native/SKILL.md`, `ios/docs/macos-design-contract.md` |
| **Android y Wear OS Nativo (`android/`)** | `android/AGENTS.md`, `.agents/skills/android-native/SKILL.md` |
| **Sistema de Diseño UI/UX (HIG + Material 3)** | `docs/design.md`, `.impeccable.md` |
| **Verificación, CI y Flujo Git** | `docs/verification.md`, `docs/git-workflow.md` |
| **Despliegue, VPS y Secretos** | `docs/deployment.md`, `SECURITY.md` |
| **Reconciliación docs ↔ código y archivo histórico** | `docs/documentation-sync-2026-11-10.md`, `docs/legacy/README.md` |

### Regla de conflicto documental

Si un documento histórico (`docs/legacy/**`) contradice una fuente canónica
actual y el código moderno:
1. Verifica la fuente ejecutable (código + tests + `contracts/openapi.yaml`).
2. Distingue **implemented today** (`docs/product-map.md`) de **target/visión**.
3. No reviertas código moderno sólo para coincidir con un PRD antiguo.
4. Registra y corrige la discrepancia en la fuente de verdad apropiada.

---

## 3. Invariantes que nunca se omiten por eficiencia

- **Plataformas activas vs. en pausa:** activas son **iOS**, **watchOS**,
  **macOS (`PepinilloMac`)**, **Android**, **Wear OS** y **Backend Go
  (`backend/`)**. **Web (`web/`)** y **Windows (`windows/`)** están **en pausa**;
  no expandirlos sin autorización explícita.
- **Paridad cross-platform en superficies activas:** todo fix o feature del
  motor de foco (`Pomodoro`, `Flowtime`, `TimeBlock`, `Stopwatch`), sesiones o
  tareas mantiene paridad funcional entre iOS, watchOS, macOS, Android y Wear OS.
- **Offline-first y autoridad de sincronización:** los clientes nativos operan
  100% offline sobre su base local (SwiftData `SchemaV6` en Apple; Room v14 en
  Android). La sincronización cloud (`POST /api/v1/sync/initial-upload`,
  `GET /api/v1/sync/full`, `POST /api/v1/sync/sessions`, `POST /api/v1/tasks/sync`)
  usa resolución **Last-Write-Wins (LWW)** gobernada por el reloj del servidor y
  requiere el entitlement activo `everywhere_plus`.
- **Modelo de monetización de dos niveles (v3.1):**
  - `pepinillo_plus` (**Pepinillo+**, compra única / lifetime): capacidades
    premium locales e informes de IA on-device (Foundation Models con fallback
    de plantilla).
  - `everywhere_plus` (**Everywhere/AI+**, suscripción mensual/anual):
    sincronización cloud multi-dispositivo (`RequireBackendSync`) y endpoints de
    IA avanzada/predicciones en el backend (`RequireProFeatureMiddleware`).
- **Contract-First OpenAPI 3.1:** todo cambio en rutas HTTP actualiza
  `contracts/openapi.yaml` primero y pasa `make contracts-lint` (`C2`). Los
  errores HTTP actuales usan la envolvente real documentada en el contrato
  (`ErrorEnvelope` / `ERR_TIER_INSUFFICIENT`); RFC 9457 es el objetivo para
  endpoints nuevos (`ADR-0003`).
- **Gramática nativa por plataforma, marca compartida:** **HIG-first** en
  iOS/watchOS/macOS y **Material 3 Expressive** en Android/Wear OS
  (`docs/design.md`). Nunca estirar vistas de iPhone/iPad para macOS.
- **Presupuesto cognitivo y regla de extracción al tocar:** archivos de
  producción bajo ~500 líneas (`docs/agent-first-methodology.md`). Lo nuevo no
  entra a monolitos; al tocar un monolito, extrae la costura en un commit
  mecánico separado.
- **Seguridad y secretos:** prohibido commitear `.env`, claves `sk_` de
  RevenueCat, certificados o tokens (`SECURITY.md`). Ejecutar
  `python3 scripts/check_secrets.py` antes de publicar. Nunca ejecutar SQL
  destructivo (`DROP`, `TRUNCATE`, `DELETE` sin `WHERE`) sin confirmación
  explícita y backup.
- **Flujo Git determinista:** prohibido usar `git stash` como depósito entre
  sesiones (`docs/git-workflow.md`); usa ramas `wip/<tema>` con `git push`.
  Commits atómicos con Conventional Commits en **inglés** y **sin trailers de
  co-autoría de IA**.

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
contracts/    → Especificación OpenAPI 3.1 (`openapi.yaml`), reglas Spectral y detección de breaking changes.
docs/         → Documentación canónica Agent-First (`README.md`, `product-map.md`, `prd-v2.md`,
                `architecture.md`, `conventions.md`, `verification.md`, `design.md`, `deployment.md`,
                `git-workflow.md`, `factory/`, `strategy/`, `legacy/`).
scripts/      → Guardrails deterministas (`factory_preflight.py`, `factory_handoff.py`,
                `check_pr_metadata.py`, `check_secrets.py`, `setup-labels.sh`).
odd/tasks/    → Artefactos de ejecución por issue autorizada (`<issue>-<slug>.md`).
progress/     → Estado vivo de sesión (`current.md`) y bitácora append-only (`history.md`).
web/          → [EN PAUSA] Web Companion en Svelte 5 + SvelteKit 2 + IndexedDB (`idb`).
windows/      → [EN PAUSA] Cliente de escritorio en C# / .NET / WinUI 3 (`Pepinillo.Core`, `Pepinillo.WinUI`).
```

---

## 5. Comandos rápidos

```bash
make preflight        # Chequeo read-only de salud del arnés y árbol git (C1)
make test             # Tests de guardrails Python + suite unitaria del backend Go (C3)
make test-factory     # Tests unitarios de scripts de la factoría (tests/test_factory_scripts.py)
make test-backend     # go test ./... en backend/
make test-android     # ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest en android/
make contracts-lint   # Valida contracts/openapi.yaml con Spectral (C2)
make contracts-diff   # Verifica ausencia de breaking changes OpenAPI contra origin/main (C2)
make handoff          # Genera paquete stateless de revisión con contexto limpio (C4)
```
