#ios #calidad #testing

# Testing

> [!abstract] Resumen
> Estado actual: **sin cobertura de tests**. No hay unit tests, UI tests, ni snapshot tests.

---

## Estado Actual

| Tipo de test | Cobertura | Herramienta |
|-------------|-----------|-------------|
| Unit tests | ❌ 0% | — |
| UI tests | ❌ 0% | — |
| Snapshot tests | ❌ 0% | — |
| Performance tests | ❌ 0% | — |

> [!warning] Riesgo
> Sin tests, refactors y features nuevas pueden romper funcionalidad existente silenciosamente.

---

## Infraestructura Recomendada

| Tipo | Herramienta | Target |
|------|-----------|--------|
| Unit tests | XCTest + Swift Testing | ViewModels, managers, lógica |
| Async tests | Swift concurrency testing | APIClient, AuthManager |
| UI tests | XCUITest | Flujos críticos |
| Snapshot | swift-snapshot-testing | Regresión visual |
| Mocking | Manual protocols / Swift Testing | Dependencias |

---

## Prioridades

| Prioridad | Qué testear | Por qué |
|-----------|-------------|---------|
| P0 | `AuthManager` | Seguridad, tokens, biometric state |
| P0 | `APIClient` | Retry logic, token injection |
| P0 | `KeychainHelper` | Storage seguro |
| P1 | ViewModels clave | Lógica de presentación |
| P1 | PDF generators | Output correcto |
| P2 | UI flujos críticos | Login → dashboard → crear evento |
| P3 | Widgets | Datos correctos |

---

## Relaciones

- [[Arquitectura General]] — SPM facilita testing por paquete
- [[Manejo de Estado]] — @Observable ViewModels como target principal
- [[Capa de Red]] — APIClient actor testeable
- [[Roadmap iOS]] — testing como prioridad
