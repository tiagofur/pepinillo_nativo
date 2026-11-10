# Metodología de codebase Agent-First

Un **codebase Agent-First** está diseñado a la vez para humanos y para la
fiabilidad cognitiva de LLMs. Los agentes fallan más por **contaminación de
contexto**, **archivos monolíticos** y **convenciones implícitas ambiguas** que
por límites de razonamiento.

---

## 1. Fundamentos (y contramedidas de la factoría)

1. **Lost in the Middle (Liu et al., 2023)** — la atenciónTransformer recupera
   bien el inicio y el final de la ventana; lo enterrado en medio de un archivo
   de 2000 líneas se degrada.
   **Contramedida**: presupuesto blando de **~500 líneas** por archivo y
   `AGENTS.md` ≤150 líneas para que las invariantes queden en los picos de
   atención.
2. **Context Rot y contaminación de racional (Chroma / Anthropic ACI)** — el
   transcript acumula hipótesis fallidas y autojustificaciones; si la misma
   sesión se auto-revisa (o pasa su historia al reviewer), el reviewer hereda
   los puntos ciegos del implementador.
   **Contramedida**: **Revisión Independiente con Contexto Limpio**
   (`factory/clean-context-review.md`); el reviewer solo ve el paquete
   determinista de `scripts/factory_handoff.py`.
3. **Agent-Computer Interface (SWE-agent, Yang et al., 2024)** — los agentes
   rinden mejor con navegación determinista, errores accionables y señales
   pass/fail concisas.
   **Contramedida**: targets estandarizados (`make preflight`, `make test`,
   `make contracts-lint`, `make handoff`) y guardrails Python fail-closed.

## 2. Reglas estructurales por superficie

### 2.1 Presupuesto cognitivo de ~500 líneas
- Blando: entre **150 y 500 líneas**.
- Gatillo duro: >500 líneas exige verificación de cohesión antes de añadir
  lógica; si mezcla transporte, política de dominio y persistencia, se divide
  por límites de responsabilidad.
- Guarda anti-fragmentación: no crear veinte archivos de 15 líneas que obliguen
  a abrir diez archivos para trazar una llamada.

### 2.2 Organización vertical-slice ("screaming")
Directorios por **capacidad de dominio**, no por capa genérica. Prohibidos los
nombres catch-all (`utils.go`, `helpers.ts`, `common.py`, `misc.rs`); nombra
por responsabilidad concreta (`money_format.go`, `rfc9457_error.ts`).

### 2.3 Símbolos greppables y sin ambigüedad
Los agentes navegan por `grep`/símbolos antes de abrir archivos. Prefiere
nombres explícitos y globalmente buscables (`CreateInvoiceCommand`,
`PostgresInvoiceRepository`, `useInvoiceListQuery`) sobre genéricos
(`Manager`, `Handler`, `Process`, `Data`). Firma determinista y tipos de error
explícitos para que nadie tenga que leer el cuerpo para saber qué puede fallar.

### 2.4 Fronteras de módulo y dirección de dependencias
Las dependencias apuntan **hacia adentro** (UI/transport → app/servicios →
dominio puro). Los adapters de DB/HTTP/implementan interfaces definidas por el
dominio/aplicación (ver `docs/architecture.md` y ADR-0001).

## 3. Carga progresiva de contexto

Nunca volcar el árbol `docs/` completo en un prompt:
1. **Nivel 0 — Mapa raíz**: `AGENTS.md` (≤150 líneas) + `feature_list.json`.
2. **Nivel 1 — Skill de rol**: solo `.agents/skills/<rol>/SKILL.md`.
3. **Nivel 2 — Skill de stack y ADR**: solo el skill y ADR que corresponden a
   los archivos tocados (p. ej. `go-backend/SKILL.md` + `ADR-0001` para
   `backend/`).
4. **Nivel 3 — Archivos acotados**: solo los dentro de
   `## Allowed edit surfaces` y sus dependencias de contrato directas.

## 4. Protocolo de toque a archivos legacy/monolíticos

Cuando una tarea autorizada debe tocar un archivo que ya supera 500 líneas:
1. **No reescribas el mundo**: el diff se acota al alcance de la issue.
2. **Extrae la costura tocada**: la nueva unidad cohesiva va a un archivo
   hermano en el mismo paquete/módulo.
3. **Respeta el presupuesto de revisión de 400 líneas**: separa el commit
   mecánico de extracción del commit de comportamiento si la extracción
   excede el presupuesto.
