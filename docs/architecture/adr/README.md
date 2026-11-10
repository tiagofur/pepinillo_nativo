# Architecture Decision Records (ADRs)

Registro de decisiones arquitectónicas vigentes para Pepinillo. Un ADR `Accepted` es vinculante para cualquier implementador o revisor; cualquier cambio estructural requiere proponer un ADR nuevo o superceder el vigente.

| ID | Título | Estado | Alcance |
| :--- | :--- | :--- | :--- |
| `ADR-0001` | [Backend Go, Fiber v2, GORM y matriz de persistencia](ADR-0001-go-backend-and-db-matrix.md) | Accepted | `backend/**` |
| `ADR-0002` | [Superficies cliente nativas (Apple / Android) y clientes en pausa](ADR-0002-client-surfaces-and-mobile-matrix.md) | Accepted | `ios/**`, `android/**`, `web/**`, `windows/**` |
| `ADR-0003` | [Contratos OpenAPI 3.1 y evolución de envolvente de errores](ADR-0003-contract-first-openapi.md) | Accepted | `contracts/**`, `backend/**`, clientes |
