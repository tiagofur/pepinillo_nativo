#android #calidad #testing

# Testing

> [!abstract] Resumen
> Estado actual: **sin cobertura de tests**. No hay unit tests, instrumented tests ni UI tests en el proyecto.

---

## Estado Actual

| Tipo de test | Cobertura | Herramienta |
|-------------|-----------|-------------|
| Unit tests | ❌ 0% | — |
| Integration tests | ❌ 0% | — |
| UI tests (Compose) | ❌ 0% | — |
| Screenshot tests | ❌ 0% | — |

> [!warning] Riesgo alto
> Sin tests, cualquier refactor o feature nueva puede romper funcionalidad existente sin que nadie se entere hasta que un usuario lo reporte.

---

## Infraestructura Recomendada

| Tipo | Herramienta | Uso |
|------|-----------|-----|
| Unit tests | JUnit 5 + MockK | ViewModels, Repositories, lógica pura |
| Coroutines | Turbine | Testing de Flows y StateFlows |
| Compose UI | `createComposeRule()` | Interacciones de UI |
| Screenshot | Paparazzi o Roborazzi | Regresión visual |
| Integration | Hilt Test + Room in-memory | Repositorios end-to-end |

---

## Prioridades para Testing

| Prioridad | Qué testear | Por qué |
|-----------|-------------|---------|
| P0 | `AuthManager` | Seguridad, tokens, estado de auth |
| P0 | Repositories (sync logic) | Lógica de datos offline-first |
| P1 | ViewModels (state computation) | Lógica de presentación |
| P1 | Type converters | Serialización Room ↔ Domain |
| P2 | Compose screens | Flujos de usuario críticos |
| P3 | Widgets | Datos mostrados correctamente |

---

## Relaciones

- [[Arquitectura General]] — la separación en módulos facilita el testing
- [[Manejo de Estado]] — ViewModels son el target principal de unit tests
- [[Base de Datos Local]] — Room in-memory para integration tests
- [[Roadmap Android]] — testing como prioridad en el roadmap
