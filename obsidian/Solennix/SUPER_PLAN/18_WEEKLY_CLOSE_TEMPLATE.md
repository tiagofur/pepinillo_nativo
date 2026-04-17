---
tags:
  - super-plan
  - weekly-close
  - reporting
  - governance
aliases:
  - Weekly Close
  - Cierre de Semana
  - Reporte Semanal
status: template
created: 2026-04-10
updated: 2026-04-10
---

# 18 - Weekly Close Template (Every Friday 5pm)

## Propósito

Snapshot semanal de Wave 1: qué salió, qué quedó, qué bloqueó. Actualizar Master Table y scorecard. Base para decisión de Go/No-Go en cierre de ola.

---

## Template (Copiar y Rellenar cada Viernes)

### Fecha: Viernes [DD/MM] — Semana [N] de Wave 1

---

## 1. Status de T-01: Event Lifecycle Reliability

### Tabla de Progreso (E1.B1, E1.B2, E1.W1, E1.I1, E1.A1)

| Epic  | Owner   | Estado                               | % Done | Bloqueos | Evidencia |
| ----- | ------- | ------------------------------------ | ------ | -------- | --------- |
| E1.B1 | Backend | [ ] Planned [ ] In Progress [ ] Done | \_%    | —        | —         |
| E1.B2 | Backend | [ ] Planned [ ] In Progress [ ] Done | \_%    | —        | —         |
| E1.W1 | Web     | [ ] Planned [ ] In Progress [ ] Done | \_%    | —        | —         |
| E1.I1 | iOS     | [ ] Planned [ ] In Progress [ ] Done | \_%    | —        | —         |
| E1.A1 | Android | [ ] Planned [ ] In Progress [ ] Done | \_%    | —        | —         |

### Deliverables Esperados (Semana X)

- [ ] E1.B1: OpenAPI spec eventos (4h) ← **si es Week 1, debe estar started**
- [ ] E1.B2: Tests happy path (6h) ← **si es Week 1, debe estar started**
- [ ] E1.W1: Form refactor (12h) ← **si es Week 1, debe estar en progreso**
- [ ] E1.I1: iOS navigation (8h) ← **si es Week 2, debe iniciarse**
- [ ] E1.A1: Android multi-step (8h) ← **si es Week 2, debe iniciarse**

### Comentarios

```
Semana 1 (Apr 10-16):

[Rellenar aquí qué pasó]

Ejemplo:
- E1.B1: OpenAPI spec creado con 180 LOC, types core listos. Martes continúo con clientes/productos.
- E1.B2: Comencé tests mínimos, 2 test cases escritos, compiled sin errors.
- E1.W1: Auditoria hecha, identifiqué 3 "Próximamente" en EventForm. Refactor comienza miércoles.
- E1.I1: No iniciado esta semana (depende backend).
- E1.A1: No iniciado esta semana (depende backend).

Blockers:
  - Ninguno crítico, todo on track.

Risky:
  - E1.W1 12h puede apretarse si web tiene más refactor del esperado.
```

---

## 2. Status de T-02: Backend Contract Freeze

| Epic  | Owner           | Estado                                           | % Done | Bloqueos | Evidencia |
| ----- | --------------- | ------------------------------------------------ | ------ | -------- | --------- |
| E2.B1 | Backend         | [ ] Planned [ ] In Progress [ ] Done             | \_%    | —        | —         |
| E2.B2 | Backend         | [ ] Planned [ ] In Progress [ ] Done             | \_%    | —        | —         |
| E2.C1 | Web/iOS/Android | [ ] Planned [ ] In Progress [ ] Done [ ] Blocked | \_%    | —        | —         |

### Deliverables Esperados (Semana X)

- [ ] E2.B1: OpenAPI 3.1 spec completo (4-6h) ← **Week 1, CRITICAL PATH**
- [ ] E2.B2: Contract breaking change tests (6-8h) ← **Week 1-2**
- [ ] E2.C1: Client validation audit (6h) ← **Week 2, BLOCKED on E2.B1**

### Comentarios

```
Semana 1 (Apr 10-16):

[Rellenar aquí]

Ejemplo:
- E2.B1: OpenAPI spec iniciado Monday. Endpoints /events core + /clients base.
  - Falta aún: /products, /inventory, /payments (estimado Martes).
  - Blocker: Necesito confirmar si hay breaking changes en schema de payment (revisar git history).
- E2.B2: Aún no iniciado (espero E2.B1 complete mínimo Tuesday).
- E2.C1: Bloqueado en E2.B1 (es dependencia explícita).

Risks:
  - E2.B1 puede extenderse si hay cambios en schema de suscripción (5h extra estimado).
```

---

## 3. KPI Snapshot

### Build Success

| Plataforma | Last Build  | Status                       | Notes                      |
| ---------- | ----------- | ---------------------------- | -------------------------- |
| Backend    | [date/time] | [ ] Green [ ] Yellow [ ] Red | `go test ./...` coverage % |
| Web        | [date/time] | [ ] Green [ ] Yellow [ ] Red | `npm run test:run` pass %  |
| iOS        | [date/time] | [ ] Green [ ] Yellow [ ] Red | Xcode build success        |
| Android    | [date/time] | [ ] Green [ ] Yellow [ ] Red | `./gradlew assembleDebug`  |

### Test Coverage (si aplica)

```
Backend:
  - Handlers coverage: _%
  - Models coverage: _%
  - Overall: _%

Web:
  - EventForm tests: _%
  - Overall: _%
```

### P0/P1 Open Count

| Severity | Count | Trend             | Notes         |
| -------- | ----- | ----------------- | ------------- |
| P0       | \_\_  | [ ] ↑ [ ] → [ ] ↓ | [list if any] |
| P1       | \_\_  | [ ] ↑ [ ] → [ ] ↓ | [list if any] |

---

## 4. Riesgos Actualizados

| Riesgo                          | Probabilidad | Impacto | Estado | Mitigación                                    |
| ------------------------------- | :----------: | :-----: | ------ | --------------------------------------------- |
| E1.W1 refactor toma más de 12h  |    Media     |  Alto   | Yellow | Agregar 4h buffer, reducir scope si necesario |
| E2.B1 schema cambios en payment |     Baja     |  Alto   | Green  | Validar schema viernes, documentar cambios    |
| Android tablet navigation crash |     Baja     |  Medio  | Green  | Testing en Samsung Galaxy tab antes de cierre |

---

## 5. Evidencia Adjunta

```
┌─ OpenAPI Spec (si E2.B1 avanzó)
│  └─ backend/docs/openapi.yaml → wc -l, git diff
├─ Test Output (si tests corrieron)
│  └─ go test ./... -v output
├─ Code Diffs
│  └─ git log --oneline wip/* (commits locales)
└─ Videos/Screenshots
   └─ EventForm refactor antes/después (si E1.W1 avanzó)
```

**Ejemplo adjuntos:**

```bash
# Backend
cd backend && go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html

# Web
cd web && npm run test:run -- EventForm

# Commits
git log main..super-plan --oneline > weekly-commits.txt
```

---

## 6. Decisión de Go/No-Go

### Para seguir a Next Week:

- [ ] Cero P0 bloqueadores
- [ ] E1.B1 o E2.B1 iniciado (preferiblemente en progreso)
- [ ] Riesgos identificados y con mitigación
- [ ] Builds green en 3+ de 4 plataformas

**Recomendación**: [ ] Go [ ] Yellow (caution) [ ] Red (hold)

---

## 7. Próxima Semana (Preview)

```
Semana [N+1] (Fechas):

- E1.B1 continuación: agregar /products, /inventory, /payments
- E1.B2 tests: TestEventUpdate_WithItems, TestEventCreate_Limits
- E1.W1: Web EventForm Paso 2 y 3 funcionales
- [Si Week 2] E1.I1 comienza, E1.A1 comienza
- [Si Week 2] E2.C1 web start audit

Riesgos a mitigar:
  - XXX
```

---

## 8. Notas Finales

```
Observaciones generales de la semana:

[Puedo escrbir lo que quiera aquí - decisiones, learnings, cambios de scope, etc.]

Ejemplo:
- Encontré que Event schema tiene más complejidad de la esperada (nested items).
  → Ampliación de E1.B1 scope estimada +2h (total 6h ahora).
- Los handlers ya tienen validación: puedo reutilizar en tests.
- Mobile testing en emulador es más lento de lo esperado → considerar device cloud para Week 2.
```

---

## Rituales Fijos

**Viernes 5:00pm**: Rellenas este template (15-20 min)
**Viernes 5:30pm**: OST (Optional Standoff Time) — 10 min de 1:1 si hay riesgos

---

## Cómo Usar Este Template

1. **Copia este archivo** cada viernes: `cp 18_WEEKLY_CLOSE_TEMPLATE.md 18_WEEKLY_CLOSE_W[N]_[DATES].md`
2. **Relleña los blancos** (estado, % done, evidencia, comentarios)
3. **Commit en super-plan** (sin push):
   ```bash
   git add obsidian/Solennix/SUPER_PLAN/18_WEEKLY_CLOSE_W1_Apr10-16.md
   git commit -m "docs(weekly-close): Wave 1 Week 1 (Apr 10-16) — status snapshot"
   ```
4. **Share con stakeholders** (si los hay)
5. **Archive en carpeta** `SUPER_PLAN/archive/` si quieres mantener histórico

---

## Links

- [[13_MASTER_TRACEABILITY_TABLE]] — T-01/T-02 oficial
- [[14_WAVE_1_BREAKDOWN]] — Detalle de epics y stories
- [[17_DAY_1_KICKOFF]] — Qué hiciste hoy
- [[07_WAVE_PLAN_12_WEEKS]] — Visión de 6 ondas

#super-plan #weekly #template #reporting
