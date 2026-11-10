# Guía operativa para humanos y agentes (`human-start.md`)

Define cómo colaboran operadores humanos y agentes autónomos dentro de la
Software Factory, desde la inicialización hasta PRs mergeados.

---

## 1. Issues de GitHub como única cola de trabajo

GitHub Issues es el **único** backlog operativo. Los agentes nunca inventan
tareas desde comentarios `TODO` ni de `feature_list.json` (que es solo contexto
de capacidades).

### Máquina de estados de issue

```text
[status:new] ──(explorer triage + DoR)──► [status:ready]
                                                       │
                                      (leader asigna implementer)
                                                       ▼
[status:blocked] ◄──(falta input externo)── [status:in-progress]
                                                       │
                                    (C1-C3 pasan + C4 revisión con contexto limpio)
                                                       ▼
                                          [status:in-review / PR abierto]
                                                       │
                                        (C5 metadatos + CI + merge humano)
                                                       ▼
                                                   [Closed]
```

### Definition of Ready (DoR) — checklist antes de pasar a `status:ready`
1. Problema y outcome (usuario/sistema) claros.
2. Criterios de aceptación numerados y testeables (`S1`, `S2`, ...).
3. Sección explícita de **Out of Scope / Exclusiones**.
4. Etiquetas requeridas: una `type:*`, una `priority:p0..p2`, una `size:xs..l`,
   y `ux:shape` cuando cambien flujos user-facing.

---

## 2. Topologías de ejecución G-ODD

Con la issue autorizada, el `leader` elige la topología más ligera que
preserve seguridad:

| Topología | Criterio de selección | Artefacto de estado | Estrategia de commits |
| :--- | :--- | :--- | :--- |
| **Inline Direct** | Cambio pequeño y comprendido, riesgo contenido (ningún Ítem de Alto Riesgo de `CHECKPOINTS.md` C3), recuperable desde la petición + `git diff`. El número de archivos nunca decide la topología. | Ninguno (`git diff` + Issue bastan) | Un Conventional Commit atómico |
| **Delegated Direct** | Feature multi-unidad, superficies disjuntas en paralelo, área desconocida que requiere `explorer`, o trabajo entre sesiones | `odd/tasks/<issue>-<slug>.md` | Un commit por tarea completada (`T1..Tn`) |

### Contrato de `odd/tasks/<issue>-<slug>.md`
Cuando **Delegated Direct** está activo, el archivo contiene:
- **`## Specs (S1..Sn)`**: mapeados 1:1 de los criterios de la issue, con
  comandos de verificación concretos.
- **`## Allowed edit surfaces`**: whitelist exacta de archivos/directorios por
  escritor delegado. Los escritores se niegan a tocar rutas fuera de la lista.
- **`## Tasks (T1..Tn)`**: unidades acotadas enlazando `S#`, ruta de ejecución
  (`inline`/`delegated`), resultado de verificación, `Risk:` y SHA de commit.
- **`## Log`**: bitácora cronológica de decisiones del usuario e hitos
  arquitectónicos.

---

## 3. Matriz de verificación proporcional (`V0` / `V1` / `V2`)

Cada unidad de trabajo debe probar corrección en primer plano antes de
commitear (comandos exactos por superficie en `docs/verification.md`):

| Tier | Cuándo es requerido | Comandos obligatorios |
| :--- | :--- | :--- |
| **V0 — Estructural** | Docs, ADRs, plantillas markdown, config no ejecutable | `python3 scripts/factory_preflight.py` + checks de enlaces/estructura |
| **V1 — RED/GREEN focalizado** | Lógica estándar, componentes UI, bugfixes | Test determinista en **RED** → fix mínimo en **GREEN** → tests de módulo + linter |
| **V2 — Contratos e integración** | Cambios OpenAPI, esquema/queries DB, auth, concurrencia, CI/scripts de factoría | V1 + `make contracts-lint` + `make contracts-diff` + suite completa (`make test`) |

---

## 4. Contrato de asertividad ("el default de proceso gana a preguntar")

1. **Resuelve decisiones técnicas con los defaults del stack**:
   - Si la issue no especifica librería, formato de error o layout, sigue
     `docs/architecture/adr/` y `docs/conventions.md` de inmediato.
   - Documenta toda decisión autónoma en `## Decisions Made Without Asking`
     del cuerpo del PR.
2. **Cuándo pausar (`status:blocked` + `needs-human`)**: solo por la lista
   cerrada de `CHECKPOINTS.md` (credenciales, coste externo, legal/privacidad,
   contradicción de ADR o invariante de dominio, alcance de producto
   contradictorio).

---

## 5. Revisión con contexto limpio y merge humano (`C4`–`C5`)

1. Al terminar implementación y checks `V0`/`V1`/`V2`, guarda la salida en un
   archivo y genera el paquete determinista (falla cerrado con
   `HANDOFF_BLOCKED` si faltan criterios o evidencia):
   ```bash
   python3 scripts/factory_handoff.py --base origin/main --head HEAD --issue <N> \
     --verification-file /tmp/verification.txt --out /tmp/handoff.md
   ```
2. Invoca al `reviewer` independiente con **solo** `/tmp/handoff.md`
   (cero historial de chat del implementador).
3. Si el bundle reporta `judgment_day_required: true`, o el diff toca
   semánticamente un disparador de `CHECKPOINTS.md` C4.4, ejecuta revisión
   dual ciega (`judgment-day`).
4. Valida los metadatos del PR antes de abrirlo o actualizarlo (requiere SHAs
   reales, scope digest y veredicto `APPROVED`):
   ```bash
   python3 scripts/check_pr_metadata.py --body-file /tmp/pr_body.md
   ```
5. Reporta `PR_READY_FOR_HUMAN_MERGE` cuando `C1`–`C5` y CI estén verdes.
