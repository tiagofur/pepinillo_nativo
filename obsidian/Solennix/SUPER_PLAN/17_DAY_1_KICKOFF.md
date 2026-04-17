---
tags:
  - super-plan
  - day-1
  - kickoff
  - execution
aliases:
  - Day 1 Kickoff
  - Día 1 Arranque
status: active
created: 2026-04-10
updated: 2026-04-10
---

# 17 - Day 1 Kickoff (Lunes 10 April 9am)

## Objetivo: Arrancar las 4 primeras horas

Definir qué sale de tu teclado **esta mañana** para que Wave 1 esté en movimiento.

---

## Timeline Day 1

### 9:00-9:15am: Preparación (15 min)

```bash
# Terminal 1: Rama y estado
cd eventosapp
git checkout super-plan
git status
git log --oneline -3
# Confirmación: HEAD → super-plan, 3 commits locales

# Terminal 2: Editor
code
```

### 9:15-9:45am: Lectura de Contexto (30 min)

**En Obsidian:**

1. Abre `SUPER PLAN MOC.md` → lee la sección "Regla de Oro"
2. Abre `14_WAVE_1_BREAKDOWN.md` → lee sección "Objetivo de Ola"
3. Abre `16_BACKEND_CONTRACT_READINESS.md` → lee sección "Checklist Pre-Ola1"
4. Abre `13_MASTER_TRACEABILITY_TABLE.md` → confirma T-01 y T-02 "In Progress"

**En Git:**

```bash
# Ver qué cambió desde main
git diff main..super-plan -- obsidian/ | wc -l
# Debe mostrar 15K+ líneas = docs bien poblados
```

### 9:45-10:15am: Board Setup (30 min)

**En tu tool de tracking (GitHub Projects, Notion, etc.):**

Crea 2 filas de tracking para Wave 1:

```
┌─────────────────────────────────────────────────────────────────────┐
│ T-01: Event Lifecycle Reliability                                   │
├──────────────┬────────────┬────────────┬───────────┬────────────────┤
│ Backend      │ Web        │ iOS        │ Android   │ Owner + Fecha  │
├──────────────┼────────────┼────────────┼───────────┼────────────────┤
│ E1.B1: 4h    │ E1.W1: 12h │ E1.I1: 8h  │ E1.A1: 8h │ Tiago, Apr 16  │
│ E1.B2: 6h    │            │            │           │                │
│ Status: TBD  │ Status:TBD │ Status:TBD │ Status:TBD│ Blocker: NONE  │
└──────────────┴────────────┴────────────┴───────────┴────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ T-02: Backend Contract Freeze                                       │
├──────────────┬───────────────────┬──────────┬────────────────────────┤
│ Backend      │ Web/iOS/Android   │ CI/Docs  │ Owner + Fecha          │
├──────────────┼───────────────────┼──────────┼────────────────────────┤
│ E2.B1: 4-6h  │ E2.C1: 6h         │ Validate │ Tiago, Apr 18-23       │
│ E2.B2: 6-8h  │                   │          │                        │
│ Status: TBD  │ Status: BLOCKED   │ TBD      │ Blocker: E2.B1 done    │
└──────────────┴───────────────────┴──────────┴────────────────────────┘
```

**Action**: Abre GitHub Projects y crea dos epics:

```bash
# En GitHub: New Project → Wave 1 Foundation Control
# Agregar 2 Épicas (T-01, T-02)
# Agregar stories como issues (E1.B1, E1.B2, E1.W1, E1.I1, E1.A1, E2.B1, E2.B2, E2.C1)
```

### 10:15-10:45am: Backend Foundation (E1.B1 Start) — 30 min

**Objetivo**: Arrancar E1.B1 (OpenAPI spec) — crear archivo esqueleto.

```bash
# Terminal
cd eventosapp/backend

# 1. Crear archivo
mkdir -p docs
touch docs/openapi.yaml

# 2. Copiar plantilla mínima
cat > docs/openapi.yaml << 'EOF'
openapi: 3.1.0
info:
  title: Solennix API
  version: 1.0.0
  description: Event management platform for Latin American organizers
servers:
  - url: http://localhost:8000
    description: Local dev
  - url: https://api.solennix.com
    description: Production
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    Event:
      type: object
      required:
        - name
        - event_date
        - client_id
      properties:
        id:
          type: string
          format: uuid
          description: Unique event ID
        user_id:
          type: string
          format: uuid
        client_id:
          type: string
          format: uuid
        name:
          type: string
          description: Event name
        event_date:
          type: string
          format: date-time
          description: Event start date (ISO 8601)
        location:
          type: string
        status:
          type: string
          enum: [draft, confirmed, completed, cancelled]
        total_price:
          type: number
          format: double
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time
    ErrorResponse:
      type: object
      properties:
        error:
          type: string
        message:
          type: string
paths:
  /api/events:
    get:
      operationId: listEvents
      summary: Get all events for authenticated user
      security:
        - bearerAuth: []
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
      responses:
        '200':
          description: List of events
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Event'
        '401':
          description: Unauthorized
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
    post:
      operationId: createEvent
      summary: Create new event
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Event'
      responses:
        '201':
          description: Event created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Event'
        '400':
          description: Validation error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '401':
          description: Unauthorized

  /api/events/{id}:
    get:
      operationId: getEvent
      summary: Get event by ID
      security:
        - bearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Event details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Event'
        '401':
          description: Unauthorized
        '404':
          description: Event not found
    put:
      operationId: updateEvent
      summary: Update event
      security:
        - bearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Event'
      responses:
        '200':
          description: Event updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Event'
        '400':
          description: Validation error
        '401':
          description: Unauthorized
        '404':
          description: Event not found
    delete:
      operationId: deleteEvent
      summary: Delete event
      security:
        - bearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '204':
          description: Event deleted
        '401':
          description: Unauthorized
        '404':
          description: Event not found
EOF

# 3. Verificar
ls -la docs/openapi.yaml
wc -l docs/openapi.yaml
```

**Output esperado**: `docs/openapi.yaml` con ~180 líneas = esqueleto funcional.

### 10:45-11:00am: Commit Checkpoint (15 min)

```bash
cd eventosapp/backend

# Ver cambios
git status
git diff docs/openapi.yaml | head -30

# Commit en rama temp
git checkout -b wip/e2b1-openapi-start
git add docs/openapi.yaml
git commit -m "chore(backend): E2.B1 OpenAPI 3.1 skeleton — events endpoints"

# Volver a super-plan (sin push)
git checkout super-plan

# Ver estado
git log --oneline -5
```

---

## Checklist Day 1 ✅

- [ ] **9:00**: super-plan branch activa, 3 commits presentes
- [ ] **9:30**: Leí contexto en Obsidian (MOC, Breakdown, Readiness, Traceability)
- [ ] **10:00**: Board setup en GitHub Projects (T-01, T-02, stories mapeadas)
- [ ] **10:30**: E1.B1 (OpenAPI) skeleton creado en `backend/docs/openapi.yaml`
- [ ] **11:00**: Commit checkpoint en rama wip (sin push a main)

---

## Si Todo Salió Bien ✅

**Salida de Day 1:**

```
eventosapp/
├── obsidian/Solennix/SUPER_PLAN/
│   ├── 13_MASTER_TRACEABILITY_TABLE.md (T-01, T-02 "In Progress")
│   ├── 14_WAVE_1_BREAKDOWN.md (2 epics definidos)
│   ├── 15_QUICK_START_EXECUTION.md (guía de 2 semanas)
│   ├── 16_BACKEND_CONTRACT_READINESS.md (readiness assessment)
│   └── 17_DAY_1_KICKOFF.md ← TÚ ESTÁS AQUÍ
├── backend/
│   ├── docs/
│   │   └── openapi.yaml ← START (180 LOC, tipos/endpoints core)
│   └── internal/handlers/*.go (ya implementados, listos para validar)
└── git log: 3 commits en super-plan + 1 wip/e2b1-openapi-start
```

**Board (GitHub Projects) Wave 1:**

```
T-01 Event Lifecycle Reliability: IN PROGRESS (0/5 stories done)
  ├─ E1.B1 Backend Contract Validation: IN PROGRESS (started)
  ├─ E1.B2 Tests: TODO
  ├─ E1.W1 Web Form: TODO
  ├─ E1.I1 iOS Navigation: TODO
  └─ E1.A1 Android Multi-Step: TODO

T-02 Backend Contract Freeze: IN PROGRESS (0/3 epics done)
  ├─ E2.B1 OpenAPI Spec: IN PROGRESS (started)
  ├─ E2.B2 Contract Tests: TODO
  └─ E2.C1 Client Validation: BLOCKED (waits E2.B1)
```

---

## Próximo Paso (Martes Morning)

Continúa E1.B1:

1. Expande OpenAPI spec: agregar clientes, productos, inventario (tipos comunes)
2. Comienza E1.B2: escribe primer test de happy path (`TestEventCreate_Success`)
3. Valida que tests compilen

---

## Rápido de Reference

- **Docs**: `[[14_WAVE_1_BREAKDOWN]]` — detalle technical
- **Readiness**: `[[16_BACKEND_CONTRACT_READINESS]]` — handlers ya listos
- **Traceability**: `[[13_MASTER_TRACEABILITY_TABLE]]` — T-01/T-02 status
- **Code**: `backend/internal/handlers/crud_handler.go` — implementación

---

## Notas

- **No pushes a main**.
- Rama `super-plan` es tu espacio seguro.
- Commits `wip/*` son locales (cherry-pick a super-plan si necesitas).
- Cierre semanal: Viernes 5pm actualiza tabla de traceabilidad con evidencia real.

#super-plan #day-1 #kickoff #execution
