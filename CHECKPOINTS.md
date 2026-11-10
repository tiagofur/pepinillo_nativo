# CHECKPOINTS.md — Compuertas Fail-Closed de la Software Factory

Todo cambio en Pepinillo atraviesa cinco checkpoints deterministas (`C1`–`C5`).
Los checkpoints los aplican scripts, tests y CI ejecutables, no promesas en prosa.

---

## C1 — Autoridad, DoR y Workspace Limpio

**Actor**: `leader`, `explorer`, `implementer`
**Script**: `python3 scripts/factory_preflight.py`

1. **Autoridad de issue**: el trabajo enlaza a una issue abierta en
   `status:ready` o `status:approved`.
2. **Definition of Ready (DoR)**:
   - Objetivo, valor para usuario/sistema y exclusiones explícitas declarados.
   - Criterios de aceptación verificables (`S1..Sn`).
   - Etiquetas asignadas: exactamente una `type:*`, una `priority:p0..p2`, una
     `size:xs..l`, y `ux:shape` si cambian flujos de UI.
   - Si hay `ux:shape`, el brief UX (`.agents/skills/ux-brief/SKILL.md`) se
     publica como comentario de la issue **antes** de iniciar implementación.
3. **Topología y superficie de edición**:
   - Clasificar como **Inline Direct** o **Delegated Direct**
     (`odd/tasks/<issue>-<slug>.md`).
   - Las `## Allowed edit surfaces` se enumeran explícitamente antes de que
     cualquier escritor ejecute.

---

## C2 — Arquitectura, Jerarquía de Verdad y Compuerta de Contratos

**Actor**: `implementer`
**Script**: `make contracts-lint` y `make contracts-diff`

1. **Jerarquía de verdad (orden estricto)**:
   1. **ADRs activos (`docs/architecture/adr/`)** — vinculantes.
   2. **Fuente de verdad de producto (`docs/prd-v2.md`) y contratos ejecutables
      (`contracts/openapi.yaml`)** — alcance de features y contratos HTTP.
   3. **Estrategia y docs operativos (`docs/strategy/`, `docs/`)** — dirección
      de producto y decisiones de plataforma.
   4. **Código existente** — sigue la arquitectura establecida; nunca anula los
      niveles 1–3.
2. **Contract-First OpenAPI**:
   - Cualquier cambio en la API HTTP actualiza `contracts/openapi.yaml` **primero**.
   - `Spectral` pasa sin errores (`make contracts-lint`).
   - `oasdiff` no detecta breaking changes contra `origin/main`
     (`make contracts-diff`), salvo etiqueta `contract-break` autorizada por humano.
3. **Higiene estructural Agent-First**:
   - Archivos fuente respetan el presupuesto blando de ~500 líneas
     (`docs/agent-first-methodology.md`).
   - Símbolos públicos descriptivos y greppables.

---

## C3 — Verificación Proporcional Test-First (`V0` / `V1` / `V2`)

**Actor**: `implementer`
**Script**: `make test` y comandos por superficie

La verificación escala con el nivel de riesgo del diff:

| Nivel | Perfil de riesgo | Evidencia requerida |
| :--- | :--- | :--- |
| **V0 — Estructural y estático** | Docs pasivos, comentarios o config no ejecutable | Lectura estructural, `python3 scripts/factory_preflight.py`, lint de markdown/schema |
| **V1 — RED/GREEN focalizado y suite afectada** | Cambio de comportamiento estándar en un módulo/plataforma | Observar test **RED** determinista → implementar **GREEN** → tests de plataforma: <br>• Backend: `cd backend && go test ./...`<br>• Android/Wear: `cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest`<br>• iOS/watchOS/macOS: `xcodebuild test` (ver `docs/verification.md`) |
| **V2 — Integración, contratos y límites** | Alto riesgo: migraciones DB, auth/seguridad, protocolo de sync, contratos, CI/scripts de factoría | V1 + regresión cross-platform, `make contracts-lint`, `make test-factory` |

- Cada unidad de trabajo cierra con un Conventional Commit atómico
  (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`) sin trailers de
  atribución IA.
- Cierra toda entrega de código con una línea explícita `Risk:`
  (`Risk: none` o `Risk: item N (<reason>)`), donde `N` es un elemento de la
  lista canónica siguiente.

### Ítems de Alto Riesgo (canónicos — referenciados por `Risk: item N`)

Un cambio es de alto riesgo cuando un error sería difícil de detectar, difícil
de deshacer o alcanza más allá del cambio. Toca:

1. **Datos / efectos irreversibles**: migraciones, cambiar o borrar datos
   existentes de foco/tareas, cambios de formato persistido.
2. **Seguridad**: auth, permisos, credenciales, secretos, claves de billing.
3. **Contratos que otros consumen**: cambiar o eliminar API pública, protocolo
   de sync de companion, formatos de config, o código compartido del que
   depende comportamiento existente no mencionado.
4. **Concurrencia**: locks, races, orden async, dispatch de timers, sync en
   background de wear/watch.
5. **Entrega / entorno**: configuraciones de stores, CI de release, scripts de
   deploy, guardrails de la factoría.
6. **Ningún test detectaría una regresión** en lo que cambia.

Antes de escribir `Risk: none`, verifica si el diff cambia código del que
depende comportamiento existente no mencionado en la petición; si es así, es el
ítem 3.

---

## C4 — Revisión Independiente Stateless con Contexto Limpio

**Actor**: `reviewer` (subagente o sesión fresca con **cero** contexto de chat del implementador)
**Script**: `python3 scripts/factory_handoff.py --base <base> --head <head> --issue <N> --verification-file <evidence.txt> --out <bundle.md>`

1. **Cero contaminación de racional**: el reviewer nunca lee el transcript del
   implementador. Consume solo el paquete determinista de
   `scripts/factory_handoff.py`:
   - `base_sha` y `head_sha` fijados + digest de alcance SHA-256
   - Criterios de aceptación y exclusiones explícitas de la issue
   - `## Allowed edit surfaces` declaradas y archivos tocados fuera de ellas
   - `git diff <base_sha>...<head_sha>` completo
   - Salidas registradas de `V0`/`V1`/`V2`
   - Falla cerrada (`HANDOFF_BLOCKED`, exit 3) si faltan criterios de aceptación
     o evidencia de verificación.
2. **Rúbrica de severidad (`P0`–`P3`)**: canónica en
   [`reviewer/SKILL.md` §3](.agents/skills/reviewer/SKILL.md). Cualquier
   `P0`/`P1` bloquea la aprobación. Veredictos: `APPROVED` |
   `CHANGES_REQUESTED` | `BLOCKED`.
3. **Límite de corrección**: como máximo **un** lote consolidado de
   correcciones para los bloqueantes `P0`/`P1` reportados, seguido de una
   re-revisión acotada sobre un bundle regenerado. Si persiste algún `P0`/`P1`,
   detén la iteración automatizada, etiqueta `needs-human` y escala como
   `Needs your decision`.
4. **Disparadores de Judgment-Day (canónicos)**: revisión dual ciega
   (`judgment-day`: `jd-judge-a` + `jd-judge-b`, mismo bundle congelado, sin
   salida compartida) requerida cuando el diff toca:
   - **Detectado por rutas** en `scripts/factory_handoff.py`
     (`judgment_day_required: true`):
     - `contracts/**`, `scripts/**`, `.github/workflows/**`,
       `docs/architecture/adr/**`, `CHECKPOINTS.md`
     - Tokens de ruta de auth/seguridad/secrets/crypto/permissions/migrations
     - Más de **400** líneas modificadas (excepción de tamaño / slice de
       chained-PR que no se dividió)

---

## C5 — Contrato de Entrega de PR Fail-Closed

**Actor**: `leader`
**Script**: `python3 scripts/check_pr_metadata.py`

Todo cuerpo de PR debe ajustarse a `.github/PULL_REQUEST_TEMPLATE.md`:
1. Línea 1: `Closes #N`, `Fixes #N`, `Resolves #N` (si `complete`) o `Refs #N`
   (si `partial`).
2. Línea 2: `Delivery: complete` o `Delivery: partial`.
3. Secciones requeridas: `## Summary`, `## Decisions Made Without Asking`,
   `## Verification Evidence`, `## Clean-Context Review Handoff`, `## Risk`.
4. Línea de riesgo válida que coincida con `Risk: none` o
   `Risk: item <1-6> (<reason>)`.
5. Prueba mecánica de aprobación `C4` en `## Clean-Context Review Handoff`.
