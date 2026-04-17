# Testing

#web #testing #calidad

> [!abstract] Resumen
> Vitest para unit tests, Playwright para E2E, MSW para mocking de API. Estructura por componente con archivos `.test.tsx` colocados junto al archivo que testean.

---

## Stack de Testing

| Herramienta | Versión | Uso |
|------------|---------|-----|
| **Vitest** | 4.0 | Unit tests, component tests |
| **Playwright** | 1.58 | E2E tests |
| **MSW** | 2.12 | Mock Service Worker para interceptar requests |
| **Testing Library** | (via Vitest) | Render y query de componentes React |

## Estructura

```
web/src/
├── components/
│   ├── ToastContainer.tsx
│   └── ToastContainer.test.tsx    # Test junto al componente
├── pages/
│   └── Events/
│       └── components/
│           ├── EventEquipment.tsx
│           └── EventEquipment.test.tsx
```

## Estado de Tests — 2026-04-05

### Tests nuevos (todos pasan)

| Archivo | Tests | Cobertura |
|---------|-------|-----------|
| `usePagination.test.ts` | 8 | Paginación, sorting, toggle, empty data |
| `queryKeys.test.ts` | 13 | Key factories, hierarchical invalidation |
| `finance.test.ts` | 8 | Tax, total, net sales, never-negative |
| `EventEquipment.test.tsx` | 31 | Selección, conflictos, sugerencias, drag |
| **Total nuevos** | **60** | **Todos pasando** |

### Tests pre-existentes (necesitan migración)

> [!warning] 304 tests rotos por migración a React Query
> Los componentes migraron de `useState` + `useEffect` a React Query hooks. Los tests esperan el patrón anterior:
> - `logError` inline en vez de `QueryCache.onError`
> - `setItems(filter)` en vez de cache invalidation
> - Loading via `useState` en vez de `isLoading` del hook

**Wrapper disponible**: `tests/customRender.tsx` provee `QueryClientProvider` — los tests ya lo importan pero necesitan actualizar sus assertions.

## Ejecutar Tests

```bash
# Unit tests (todos)
cd web && npx vitest run

# Solo tests nuevos (garantizado que pasan)
cd web && npx vitest run src/hooks/ src/lib/finance.test.ts

# E2E tests
cd web && npx playwright test
```

## Relaciones

- [[Arquitectura General]] — Herramientas del stack
- [[Roadmap Web]] — Deuda técnica de tests documentada
