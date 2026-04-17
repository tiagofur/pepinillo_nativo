---
tags:
  - super-plan
  - quick-start
  - execution
  - getting-started
aliases:
  - Quick Start
  - Comienza Aquí
status: active
created: 2026-04-10
updated: 2026-04-10
---

# 15 - Quick Start — Cómo Ejecutar Wave 1

## Arranca Aquí (Día 1)

### 1️⃣ Abre la Rama super-plan Localmente

```bash
git checkout super-plan
git pull origin super-plan  # si la rama ya existe en remote
```

### 2️⃣ Abre Obsidian y Navega por el Roadmap

1. Ve a `obsidian/Solennix/SUPER_PLAN/SUPER PLAN MOC.md`
2. Expande **"Desglose por Ola"** → haz clic en `[[14_WAVE_1_BREAKDOWN]]`
3. Lee los **2 Epics**:
   - **E1**: Event Lifecycle Reliability (crear evento sin bloqueos)
   - **E2**: Backend Contract Freeze (documentar API)

### 3️⃣ Copia el Estado de T-01 y T-02 a tu Board

Abre `[[13_MASTER_TRACEABILITY_TABLE]]` y copia las filas T-01 y T-02 a tu issue tracker (GitHub Projects, Jira, Notion, etc.):

**T-01: Event Lifecycle Reliability**

- Objetivo: crear evento end-to-end sin bloqueos en 4 plataformas
- Ola: Wave 1-2
- Criterios: 5 pasos funcionales, sin "Próximamente"
- Estados: Web ☆, iOS ☆, Android ☆, Backend ☆ (stella = start here)

**T-02: Backend Contract Freeze**

- Objetivo: documentar y validar contratos API críticos
- Ola: Wave 1
- Criterios: OpenAPI 3.1 + contract tests
- Estados: OpenAPI ☆, Tests ☆, Validation ☆

---

## Semana 1 (Apr 10-16)

### Lunes 9am — Kick-off

1. Lee [[08_RISK_REGISTER_AND_CONTINGENCIES]] — ¿cuáles son los riesgos top 3?
2. Abre [[14_WAVE_1_BREAKDOWN]] y mapea stories a tu calendar.
3. Prioriza E1.B1 (Backend contract spec) + E1.B2 (tests happy path).

### Lunes-Miércoles: Backend Foundation

**Backend Track (E1.B1 + E1.B2 + E2.B1 + E2.B2)**

1. **E1.B1** (4h): Escribe OpenAPI spec mínima de `/api/events`
   - POST /api/events — crear evento
   - PUT /api/events/{id} — editar
   - GET /api/events/{id} — obtener
   - Request/response schemas
   - Guardar en `backend/docs/openapi-events.yaml`

2. **E1.B2** (6h): Tests de happy path

   ```bash
   # Crear test file
   vim backend/internal/handler/*_test.go

   # Tests mínimos:
   # - TestEventCreate_Success
   # - TestEventCreate_WithProducts
   # - TestEventUpdate_Success
   # - TestEventGet_Success
   # - TestEventCreate_NoAuth_401

   go test ./internal/handler -v -run TestEvent
   ```

3. Verifica que tests sean > 80% coverage:
   ```bash
   go test ./... -coverprofile=coverage.out
   go tool cover -html=coverage.out
   ```

**Result**: Cuando termines, sube los cambios a rama temporary-e1b1-e2b1:

```bash
git checkout -b temporary-e1b1-e2b1
git add backend/
git commit -m "feat(backend): E1.B1 + E1.B2 + E2.B1 OpenAPI spec + happy path tests"
```

### Jueves-Viernes: Web Form Refactor

**Web Track (E1.W1)**

1. **Auditoria**: ¿Dónde están los "Próximamente"?

   ```bash
   cd web && grep -r "Proximamente\|Coming Soon" src/
   ```

   Anota en dónde aparecen.

2. **Refactor E1.W1** (12h split in 2 days):
   - Día 1 (Jue): Paso 2 (Productos) funcional desde cero
   - Día 2 (Vie): Paso 3 (Extras), Paso 4 (Equipamiento)

   Usar como referencia:
   - [[web/src/components/EventForm/]] — estructura actual
   - [[08_TECHNICAL_ARCHITECTURE_WEB|Web Architecture]] — patterns

3. **Tests mínimos**:

   ```bash
   npm run test:run -- EventForm.test.ts
   # Must pass: "renders all 5 steps without placeholders"
   ```

4. **Cierre Web**: Sube cambios temp:
   ```bash
   git checkout -b temporary-e1w1
   git add web/
   git commit -m "feat(web): E1.W1 Event Form refactor — no placeholders"
   ```

### Fin de Semana 1 (Sab-Dom)

- Revisa qué quedó done.
- Actualiza la matriz de T-01 / T-02 con progreso.
- Identifica blockers antes del lunes.

---

## Semana 2 (Apr 17-23)

### Lunes 9am — Ritmo

Abre [[13_MASTER_TRACEABILITY_TABLE]] y actualiza:

```
| T-01 | ... | Wave 1-2 | Event Lifecycle | ... | In Progress |
| T-02 | ... | Wave 1   | Backend Contract | ... | In Progress |
```

### Lunes-Miércoles: Mobile Validation

**iOS Track (E1.I1)**

1. Abre `ios/Solennix/SolennixFeatures/.../EventFormView.swift`
2. Verifica:
   - ✅ 5 steps navegan sin crashes
   - ✅ Pull-to-refresh actualiza lista
   - ✅ Los datos se guardan entre pasos
3. Agrega XCTest mínimo:
   ```swift
   func testEventFormStatePersistedAcrossSteps() {
     // navega step 1 → step 2 → step 3 → step 1
     // verifica que datos están intactos
   }
   ```
4. Sube: `git checkout -b temporary-e1i1 && git add ios/ && git commit`

**Android Track (E1.A1)**

1. Abre `android/feature/events/ui/EventFormScreen.kt`
2. Verifica:
   - ✅ No crashes en paso multi-step
   - ✅ Volver atrás = conserva datos
   - ✅ En lista aparece evento guardado
3. Tests mínimos (Espresso):
   ```kotlin
   @Test fun testEventFormNoPlaceholders() {
     // crear evento → verificar que no hay "Coming Soon"
   }
   ```
4. Build en debug y release:
   ```bash
   cd android && ./gradlew assembleDebug assembleRelease --warning-mode=all
   ```
5. Sube: `git checkout -b temporary-e1a1 && git add android/ && git commit`

### Jueves-Viernes: Contract Validation + Merge

**Contract Validation (E2.C1)**

Web, iOS, Android cada uno:

1. Verifica que las llamadas a `/api/events/*` exactamente matches OpenAPI spec (E2.B1).
2. Crea una auditoría (`checklist-contract-validation.md`) con:
   - ✅ POST /api/events — mapeado en Web EventAPI
   - ✅ PUT /api/events/{id} — mapeado en iOS EventService
   - ✅ GET /api/events — mapeado en Android EventRepository
   - ⚠️ Divergencias encontradas (si hay)

**Consolidación**

1. Ve a super-plan:

   ```bash
   git checkout super-plan
   ```

2. Actualiza Wave 1 Breakdown con estados reales:

   ```bash
   # En 14_WAVE_1_BREAKDOWN.md, cambiar story status de Planned → In Progress
   ```

3. Cherry-pick del contenido técnico (no commits raw de ramas temp):
   - Copia nuevos archivos de `temporary-e1*` a respectivas `src/` folders
   - Commit en super-plan:
     ```bash
     git commit -m "feat(wave-1): Complete E1 + E2 epics — Event Lifecycle + Contract Freeze ready"
     ```

---

## Fin de Wave 1 (Jueves 24 Apr)

### Cierre Checklist

- [ ] T-01 evidencia:
  - [ ] Backend: tests green, coverage > 80%
  - [ ] Web: E2E test sin placeholders
  - [ ] iOS: XCTest video + logs
  - [ ] Android: build debug y release success

- [ ] T-02 evidencia:
  - [ ] OpenAPI spec en `backend/docs/`
  - [ ] Contract tests all green
  - [ ] Auditoría de divergencias: cero P0

- [ ] Riesgos re-evaluados (Red → Yellow?)

- [ ] Firma Go/No-Go:
  - ¿Crear evento corre end-to-end sin crashes?
  - ¿API contract frozen y validado?
  - **Decisión**: ✅ Go Wave 2 o ⚠️ Resolve y reintent Week 2?

### Update Master Table (T-01,T-02)

```
| T-01 | Event Lifecycle | Wave 1-2 | ... | Done ✅  |
| T-02 | Backend Contract| Wave 1   | ... | Done ✅  |
| T-03 | Parity P0       | Wave 3   | ... | Planned  |
```

---

## Comandos Rápidos

### Ver status de la rama super-plan

```bash
git log --oneline super-plan | head -10
git status
git branch -v
```

### Ver diferencias entre super-plan y main

```bash
git diff main super-plan -- obsidian/
git diff main super-plan -- backend/ web/ ios/ android/
```

### Hacer un test local sin pushear

```bash
# Si hay tests
cd web && npm run test:run
cd backend && go test ./...
cd android && ./gradlew test
```

### Cuando termines Wave 1, crear PR (pero sin pushear a main)

```bash
# Preparar cambios finales en super-plan
git add -A
git commit -m "docs(wave-1): Final Wave 1 results — Go Signal"

# Ver lo que tienes
git log main..super-plan --oneline
```

---

## Arquitectura de Decisión

### ¿Por qué esta estructura?

- **T-01 (Event Lifecycle)**: si no corre crear evento, nada corre
- **T-02 (Contract Freeze)**: si el API cambia sin aviso, todas las plataformas se rompen
- **Epics por plataforma**: paralelizar trabajo sin bloqueos
- **Evidencia obligatoria**: no vale "yo creo que funciona" → tests, videos, logs

### ¿Qué pasa si algo falla?

1. Si E1.B1 falla → no puedo hacer E1.W1 o E1.I1 (dependencia clear)
2. Si E1.W1 falla → el dashboard no está listo → Yellow risk en Wave 2
3. Si E2.C1 encuentra divergencias P0 → bloquea merge a main

---

## Enlaces Útiles

- [[14_WAVE_1_BREAKDOWN]] — Detalles técnicos de cada story
- [[13_MASTER_TRACEABILITY_TABLE]] — Matrix de objetivos → KPI
- [[11_CURRENT_STATUS]] — Qué está implementado hoy
- [[04_BACKEND_AS_PRODUCT_CONTRACT]] — Filosofía de contratos
- [[12_EXECUTION_CHECKLISTS]] — Checklist de PR, release, etc.

#super-plan #quick-start #execution #wave-1
