# Protocolo de revisión independiente con contexto limpio

La revisión de código es el principal cortafuegos de calidad de la factoría.
En sistemas multi-agente, la revisión falla cuando el reviewer comparte la
memoria conversacional del implementador. Este documento define la
**Revisión Independiente con Contexto Limpio** (`Checkpoint C4`).

---

## 1. Por qué el contexto limpio es obligatorio ("gaslighting by rationale")

Cuando un LLM implementa una feature a lo largo de 20–40 tool calls, su
contexto se llena de:
- Hipótesis de debugging intermedias parcialmente correctas.
- Justificaciones verbosas de por qué un atajo era "necesario".
- Sesgo de encuadre centrado en el happy path al que el agente dedicó más
  esfuerzo.

Si la misma sesión se auto-revisa —o su transcript se reenvía al reviewer— el
reviewer sufre **contaminación de racional**: evalúa la *plausibilidad de la
historia del implementador* en vez de la *corrección objetiva del diff frente
a la especificación*.

### La regla de contexto limpio
> El agente `reviewer` DEBE instanciarse en una ventana de contexto fresca y
> aislada. Recibe **cero** mensajes de chat del implementador, **cero** logs de
> razonamiento intermedio y **cero** notas de scratch no publicadas.

---

## 2. Paquete determinista de handoff (`scripts/factory_handoff.py`)

El reviewer recibe un único bundle markdown inmutable:

```bash
python3 scripts/factory_handoff.py \
  --base origin/main \
  --head HEAD \
  --issue 42 \
  --verification-file /tmp/verification-42.txt \
  --out /tmp/handoff-issue-42.md
```

El script **falla cerrado** (`HANDOFF_BLOCKED`, exit 3) cuando no puede
resolver criterios de aceptación o evidencia de verificación, en lugar de
emitir texto de relleno que un reviewer podría confundir con prueba.

### Contenido del paquete
1. **Identidad criptográfica fijada**: `base_sha`/`head_sha` exactos y
   `scope_sha256` (SHA-256 sobre número de issue, SHAs, rutas ordenadas y SHA
   del diff completo). Cualquier commit posterior invalida el digest.
2. **Autoridad y especificación** (primera fuente encontrada gana):
   `--issue-body-file`, `--acceptance`, `odd/tasks/<issue>-<slug>.md`
   (`## Specs`), o `gh issue view`.
3. **Control de alcance**: `## Allowed edit surfaces` declaradas y lista de
   archivos cambiados fuera de ellas (mutaciones fuera de alcance = `P0`
   visible sin lookups extra).
4. **Superficie de cambio objetiva**: archivos cambiados, `git diff --stat`,
   total de líneas contra el presupuesto de 400, y el **diff completo**
   embebido en el bundle.
5. **Evidencia de verificación**: salida capturada de `V0`/`V1`/`V2` desde
   `--verification-file` (recomendado) o `--verification-note`. Incluye las
   secciones `## Decisions Made Without Asking` y las líneas `Risk:` del
   implementador — son declaraciones, no racional.
6. **Riesgo detectado por rutas**: `high_risk_triggers` y
   `judgment_day_required` (reglas canónicas en `CHECKPOINTS.md` C4.4).

El reviewer puede además leer archivos del repo en `head_sha`, ADRs y
`contracts/openapi.yaml` en modo read-only.

---

## 3. Rúbrica de severidad, veredictos y límite de corrección

- **Rúbrica (`P0`–`P3`), requisito de evidencia y veredictos**: canónicos en
  [`../../.agents/skills/reviewer/SKILL.md`](../../.agents/skills/reviewer/SKILL.md) §3.
- **Ronda única de corrección**: canónica en `CHECKPOINTS.md` C4.3. Existe
  para impedir ping-pong implementer↔reviewer; tras una ronda fallida decide
  un humano.

---

## 4. Revisión dual ciega (`judgment-day`)

La revisión simple es suficiente para unidades rutinarias. Los diffs de alto
riesgo escalan a dos jueces independientes read-only (`jd-judge-a`,
`jd-judge-b`) que inspeccionan el mismo paquete congelado sin verse entre sí.
Disparadores y resolución de acuerdo/desacuerdo: canónicos en
`CHECKPOINTS.md` C4.4.

La detección por rutas usa tokens de palabra completa, nunca subcadenas: un
matcher de subcadenas anterior marcaba `package-lock.json` ("lock") y
`AUTHORS.md` ("auth"), pagando dos jueces por diffs inofensivos.
