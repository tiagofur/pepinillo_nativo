---
tags:
  - super-plan
  - wave-1
  - execution
  - breakdown
aliases:
  - Wave 1 Breakdown
  - Weeks 1-2 Detail
status: active
created: 2026-04-10
updated: 2026-04-10
---

# 14 - Wave 1 Breakdown (Weeks 1-2)

## Objetivo de Ola

**Foundation Control**: Congelar riesgos de arquitectura en flujo core, cerrar contratos API críticos y activar gates base de build/tests.

---

## Epic 1: Event Lifecycle Reliability (T-01)

### Descripción

Garantizar que el flujo de crear/editar/guardar evento funciona sin bloqueos en Web, iOS, Android y Backend. Eliminar placeholders tipo "Próximamente" o estados ambiguos que den falsa impresión de features incompletas.

### Stories por Plataforma

#### Backend: E1.B1 — Event Handler Contract Validation

- **Descripción**: Documentar contrato exacto de `POST /api/events`, `PUT /api/events/{id}`, `GET /api/events/{id}` con ejemplos de request/response.
- **Criterios**:
  - ✅ Especificación OpenAPI 3.1 de endpoints de eventos
  - ✅ Schema JSON completos (request + response)
  - ✅ Validación de campos obligatorios vs opcionales
  - ✅ Código de respuesta por escenario (201, 400, 401, 422, 500)
- **Evidencia**: `backend/docs/openapi.yaml` + `backend/internal/handlers/contract_test.go`
- **Esfuerzo**: 4h
- **Owner**: Backend
- **Status**: In Progress

#### Backend: E1.B2 — Event Create/Edit Happy Path Tests

- **Descripción**: Unit tests + integration tests de crear evento con todos los tipos de items (productos, extras, equipamiento, suministros).
- **Criterios**:
  - ✅ Test: crear evento vacío → guardar → existir en base
  - ✅ Test: crear evento + agregar 1 producto → persistir
  - ✅ Test: crear evento + agregar extra/equipo/insumo → persistir
  - ✅ Test: editar evento existente → cambios reflejados
  - ✅ Test: crear evento sin permisos → 401
  - ✅ Cobertura ≥ 85% en handler de eventos
- **Evidencia**: `crud_handler_success_test.go` + nuevos tests de `event_date` inválida y unavailable dates
- **Esfuerzo**: 6h
- **Owner**: Backend
- **Status**: In Progress

#### Web: E1.W1 — Event Form End-to-End (No Placeholders)

- **Descripción**: Reemplazar cualquier estado "Próximamente" en EventForm con versión completa:
  - Paso 1: Info general (nombre, fecha, hora, cliente, ubicación) ✅
  - Paso 2: Productos (seleccionar del catálogo, ajustar cantidades, precios) ✅
  - Paso 3: Extras (seleccionar pre-definidos) ✅
  - Paso 4: Equipamiento (si aplica, conflictos) ✅
  - Paso 5: Resumen con totales
- **Criterios**:
  - ✅ Todos los 5 pasos funcionales sin estados vacíos
  - ✅ Almacenar cambios sin refrescar página
  - ✅ Mostrar errores claros si falta campo obligatorio
  - ✅ Validar en cliente y servidor
  - ✅ Flujo E2E: crear evento vacío → llenar todos pasos → guardar → volver a abrir → datos están ahí
- **Evidencia**: Vitest tests + Playwright E2E test (TC006 o similar)
- **Esfuerzo**: 12h
- **Owner**: Web
- **Status**: Planned

#### iOS: E1.I1 — Event Form Navigation & State Persistence

- **Descripción**: Asegurar que EventFormView (5 steps) mantiene estado entre pasos y guarda cambios.
- **Criterios**:
  - ✅ Navegar entre pasos sin perder datos
  - ✅ Pull-to-refresh en lista de eventos muestra cambios guardados
  - ✅ Biometric gate funciona antes de crear evento
  - ✅ Manejo de error de red muestra retry
  - ✅ Loading states son explícitos (no ambigüedad)
- **Evidencia**: XCTest + video de flujo core en iPhone + iPad
- **Esfuerzo**: 8h
- **Owner**: iOS
- **Status**: Planned

#### Android: E1.A1 — Event Form Multi-Step Navigation

- **Descripción**: Verificar que EventFormScreen en Compose navega entre pasos sin crashes y persiste datos.
- **Criterios**:
  - ✅ Crear evento nuevo → cargar form → seleccionar productos → tocar next → no crash
  - ✅ Volver atrás conserva datos del paso anterior
  - ✅ Guardar evento → en lista aparece inmediatamente
  - ✅ Tests en debug y release builds
- **Evidencia**: Espresso tests + video en Pixel emulator + Samsung Galaxy (si disponible)
- **Esfuerzo**: 8h
- **Owner**: Android
- **Status**: Planned

### Entregables de Epic E1

- [ ] Backend: OpenAPI spec + contract tests ✅
- [ ] Backend: Event CRUD happy path tests (85%+ coverage)
- [ ] Web: EventForm sin placeholders, 5 pasos funcionales
- [ ] iOS: EventForm state persistence + video flujo core
- [ ] Android: EventForm multi-step sin crashes

### Go/No-Go Criteria

- ✅ No P0 open en crear evento por plataforma
- ✅ Crear evento → guardar → reabrirlo en todas las plataformas
- ✅ Logs sin errores críticos; P1 máximo tolerable = 0

---

## Epic 2: Backend Contract Freeze (T-02)

### Descripción

Documentar y validar los contratos API críticos (eventos, clientes, productos, inventario). Asegurar que ningún cambio breaking entra sin anulación explícita.

### Stories

#### Backend: E2.B1 — OpenAPI Spec Complete

- **Descripción**: Generar OpenAPI 3.1 con todos los endpoints core (Auth, Events, Clients, Products, Inventory, Payments).
- **Criterios**:
  - ✅ `/api/auth/*` — registro, login, refresh, forgot, reset, social
  - ✅ `/api/events` — CRUD + items + fotos
  - ✅ `/api/clients` — CRUD
  - ✅ `/api/products` — CRUD + ingredientes
  - ✅ `/api/inventory` — CRUD
  - ✅ `/api/payments` — CRUD
  - ✅ `/api/subscriptions` — status, checkout, portal, webhooks
  - ✅ Cada endpoint: métodos HTTP, parámetros, schemas, códigos de estado
- **Evidencia**: `/backend/docs/openapi.yaml` ya cubre auth, subscriptions, CRUD core, dashboard, search, uploads, devices, live-activities y unavailable-dates
- **Esfuerzo**: 8h
- **Owner**: Backend
- **Status**: In Progress

#### Backend: E2.B2 — Contract Breaking Change Detection

- **Descripción**: Crear test suite que detecte breaking changes en API (cambios de tipo, eliminación de campo, etc.).
- **Criterios**:
  - ✅ Test: cambiar type de campo `int` → `string` → test falla
  - ✅ Test: remover campo requerido → test falla
  - ✅ Test: cambiar endpoint path → test falla
  - ✅ Test: deprecar campo sin default → warning (no fulla)
- **Evidencia**: `backend/internal/handlers/contract_test.go` ya valida auth, subscriptions, events, CRUD core y endpoints operativos
- **Esfuerzo**: 6h
- **Owner**: Backend
- **Status**: In Progress

#### Web/iOS/Android: E2.C1 — Client Validation Against Contract

- **Descripción**: Verificar que clientes consumen API exactamente como spec promete (sin divergencias).
- **Criterios**:
  - ✅ Código que llama endpoint existe en cada cliente
  - ✅ Request payload matches OpenAPI spec
  - ✅ Response handling covers todos los status codes documentados
- **Evidencia**: Linter rule o audit manual con reporte
- **Esfuerzo**: 6h (distributed)
- **Owner**: Each platform
- **Status**: Planned

### Entregables de Epic E2

- [x] Backend: OpenAPI 3.1 spec base expandido
- [x] Backend: Contract breaking change tests base
- [ ] Web/iOS/Android: Validación de cliente contra spec

### Go/No-Go Criteria

- ✅ OpenAPI spec validado sin warnings
- ✅ Contract tests 100% green
- ✅ Cero breaking changes en últimos 3 commits

---

## Riesgos Wave 1

| Riesgo                                             | Probabilidad | Impacto | Mitigación                          |
| -------------------------------------------------- | :----------: | :-----: | ----------------------------------- |
| Backend API tiene breaking changes no documentadas |     Alta     |  Alto   | E2.B2: detectar antes de cierre     |
| Web/iOS/Android out of sync con contrato           |    Media     |  Alto   | E2.C1: auditar clientes             |
| Evento form complejo quebrado en tablet Android    |    Media     |  Medio  | E1.A1: testear en multiples devices |

---

## Timeline Wave 1

```
Week 1 (Apr 10-16):
  E1.B1, E1.B2, E2.B1        ← Backend contract foundation
  E1.W1 inicio               ← Web form refactor comienza

Week 2 (Apr 17-23):
  E1.W1 fin + tests
  E1.I1, E1.A1              ← Mobile validacion
  E2.B2, E2.C1              ← Contract validation

Fin Wave 1 (Apr 24):
  Go/No-Go: Todos los epics Done + tablero de riesgos amarillo/verde
```

---

## Checklist de Cierre Wave 1

- [ ] T-01 evidencia completa (videos, tests, logs)
- [ ] T-02 OpenAPI + contract tests green
- [ ] Cero P0 open en crear evento
- [ ] Scorecard KPI actualizado
- [ ] Riesgos re-evaluados (Red → Yellow o Green?)
- [ ] Acta de cierre de Wave 1 firmada

---

## Enlaces

- [[SUPER PLAN MOC]]
- [[13_MASTER_TRACEABILITY_TABLE]]
- [[07_WAVE_PLAN_12_WEEKS]]
- [[05_RELEASE_GOVERNANCE_AND_QUALITY_GATES]]
- [[09_TEAM_OPERATING_SYSTEM]]
- [[12_EXECUTION_CHECKLISTS]]
- [[04_BACKEND_AS_PRODUCT_CONTRACT]]

#super-plan #wave-1 #breakdown #execution
