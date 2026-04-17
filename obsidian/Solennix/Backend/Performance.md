---
tags:
  - backend
  - performance
  - calidad
created: 2025-04-05
updated: 2025-04-05
related:
  - "[[Backend MOC]]"
  - "[[Base de Datos]]"
  - "[[Roadmap Backend]]"
  - "[[Arquitectura General]]"
---

# Backend Performance

> [!abstract] Resumen
> Análisis del rendimiento del backend Go de Solennix: qué funciona bien, problemas identificados y mejoras priorizadas para escalar la aplicación.

## Lo Que Funciona Bien

```mermaid
graph LR
    A[Request] --> B[Chi Router]
    B --> C[Middleware Stack]
    C --> D[pgxpool]
    D --> E[(PostgreSQL)]
    
    style A fill:#4ade80,color:#000
    style D fill:#60a5fa,color:#000
    style E fill:#f472b6,color:#000
```

- **pgxpool**: Connection pooling (20 max, 2 min) evita overhead de conexión por request
- **Go**: Binario compilado, startup rápido, bajo consumo de memoria, concurrencia nativa
- **Chi**: Router liviano, sin reflection, compatible con `net/http`
- **Binary responses**: Encoding directo a JSON sin buffers intermedios
- **Migrations embebidas**: Sin lectura de archivos externos en runtime (`go:embed`)
- **Static file caching**: Uploads servidos con `Cache-Control` de 1 año

## Connection Pool Config

```mermaid
graph TD
    subgraph pgxpool
        direction TB
        MC[MaxConns: 20]
        MN[MinConns: 2]
        ML[MaxConnLifetime: 30 min]
        MI[MaxConnIdleTime: 5 min]
        CT[ConnectTimeout: 10 sec]
    end
    
    App[App Go] -->|acquire| pgxpool
    pgxpool -->|release| App

    style MC fill:#22d3ee,color:#000
    style MN fill:#4ade80,color:#000
    style ML fill:#facc15,color:#000
    style MI fill:#fb923c,color:#000
    style CT fill:#f87171,color:#000
```

| Param | Value | Description |
|-------|-------|-------------|
| `MaxConns` | 20 | Máximo de conexiones en el pool |
| `MinConns` | 2 | Mínimo de conexiones mantenidas |
| `MaxConnLifetime` | 30 min | Vida máxima de una conexión |
| `MaxConnIdleTime` | 5 min | Tiempo máximo idle antes de cerrar |
| `ConnectTimeout` | 10 sec | Timeout de conexión inicial |

## Problemas de Performance Identificados

> [!warning] N+1 Queries en Event Listing
> `GetAll()` devuelve eventos, y luego el frontend puede llamar `GetByID` por cada evento para obtener products/extras/equipment. Debería devolver datos completos en el endpoint de listado o proveer un endpoint de "detailed list".

```mermaid
sequenceDiagram
    participant FE as Frontend
    participant API as GetAll()
    participant DB as PostgreSQL

    FE->>API: GET /events
    API->>DB: SELECT * FROM events
    DB-->>API: 50 eventos
    API-->>FE: [{event1}, {event2}, ...]

    loop Por cada evento (N+1!)
        FE->>API: GET /events/:id
        API->>DB: SELECT event + JOIN products/extras/equipment
        DB-->>API: evento completo
        API-->>FE: evento con detalles
    end

    Note over FE,DB: 1 + N queries = 51 queries para 50 eventos!
```

> [!warning] UpdateEventItems es pesado
> Elimina TODOS los sub-items (products, extras, equipment, supplies) y los re-inserta. Para eventos con muchos items, esto es costoso. Mejor: updates basados en diff.

> [!warning] Sin paginación
> Todos los endpoints de listado (`GetAll`, `ListClients`, `ListEvents`, etc.) devuelven TODOS los registros. Sin paginación por cursor/offset. Se degradará con la escala.

> [!warning] Búsqueda basada en LIKE
> `Search()` usa SQL `ILIKE '%query%'` que hace un full table scan. Para datasets grandes, necesita full-text search (PostgreSQL FTS5 con GIN indexes) o búsqueda externa (Meilisearch, Elasticsearch).

> [!warning] Sin cache de queries
> Cada request hittea la base de datos. Sin cache a nivel aplicación. Considerar Redis para datos accedidos frecuentemente (perfil de usuario, estado de suscripción, stats del dashboard).

## Flujo de Request Actual vs. Ideal

```mermaid
flowchart LR
    subgraph Actual
        direction TB
        A1[Request] --> B1[DB Query]
        B1 --> C1[Full Table Scan]
        C1 --> D1[ALL rows returned]
    end

    subgraph Ideal
        direction TB
        A2[Request] --> B2[Cache Check]
        B2 -->|hit| E2[Redis Cache]
        B2 -->|miss| C2[Indexed Query]
        C2 --> D2[Paginated rows]
        D2 --> E2
    end

    Actual ~~~ Ideal

    style C1 fill:#f87171,color:#000
    style D1 fill:#f87171,color:#000
    style E2 fill:#4ade80,color:#000
    style C2 fill:#4ade80,color:#000
    style D2 fill:#4ade80,color:#000
```

## Mejoras Priorizadas

| Prioridad | Mejora | Impacto | Esfuerzo |
|-----------|--------|---------|----------|
| **P0** | Paginación en todos los list endpoints | Alto | Medio |
| **P0** | Índices compuestos para queries frecuentes | Alto | Bajo |
| **P1** | Query caching con Redis | Alto | Medio |
| **P1** | `UpdateEventItems` con diff | Medio | Medio |
| **P2** | Full-text search con GIN indexes | Alto | Medio |
| **P2** | Dashboard stats pre-calculadas | Medio | Bajo |
| **P3** | Connection pool metrics | Bajo | Bajo |
| **P3** | Query profiling y slow query log | Bajo | Bajo |

> [!tip] Priorización
> Las mejoras P0 y P1 son criticas antes de pasar a produccion con mas de 100 usuarios activos. Las P2 y P3 pueden implementarse de forma iterativa.

```mermaid
gantt
    title Roadmap de Performance
    dateFormat  YYYY-MM-DD
    section P0
    Paginacion              :p0a, 2025-04-07, 5d
    Indices compuestos      :p0b, 2025-04-07, 2d
    section P1
    Redis caching           :p1a, after p0a, 7d
    UpdateEventItems diff   :p1b, after p0a, 5d
    section P2
    Full-text search (GIN)  :p2a, after p1a, 5d
    Dashboard pre-calc      :p2b, after p1a, 3d
    section P3
    Pool metrics            :p3a, after p2a, 2d
    Slow query log          :p3b, after p2a, 2d
```

## Indices Recomendados

```sql
-- Events por rango de fechas (calendario, proximos)
CREATE INDEX idx_events_user_date ON events(user_id, event_date);
CREATE INDEX idx_events_user_status ON events(user_id, status);

-- Payments por evento
CREATE INDEX idx_payments_event_id ON payments(event_id);

-- Batch lookup de ingredientes de productos
CREATE INDEX idx_product_ingredients_product ON product_ingredients(product_id);
CREATE INDEX idx_product_ingredients_inventory ON product_ingredients(inventory_id);

-- Optimizacion de busqueda (alternativas a ILIKE)
CREATE INDEX idx_clients_name_trgm ON clients USING gin(name gin_trgm_ops);
CREATE INDEX idx_products_name_trgm ON products USING gin(name gin_trgm_ops);
```

> [!tip] Trigram Indexes
> Los indexes `gin_trgm_ops` requieren la extension `pg_trgm`. Activar con `CREATE EXTENSION IF NOT EXISTS pg_trgm;`. Soportan busquedas `ILIKE` sin full table scan.

## Arquitectura de Cache Propuesta

```mermaid
flowchart TD
    REQ[Request] --> MW[Middleware]
    MW --> CACHE{Redis Cache?}
    
    CACHE -->|HIT| RES[Response]
    CACHE -->|MISS| POOL[pgxpool]
    POOL --> DB[(PostgreSQL)]
    DB --> POOL
    POOL --> SET[Set Cache]
    SET --> RES

    RES --> MW

    style CACHE fill:#facc15,color:#000
    style DB fill:#f472b6,color:#000
    style SET fill:#4ade80,color:#000
```

**Candidatos para cache:**

| Dato | TTL | Razón |
|------|-----|-------|
| Perfil de usuario | 15 min | Poco cambio, acceso frecuente |
| Estado de suscripción | 5 min | Validado en cada request |
| Dashboard stats | 1 min | Datos agregados, acceso frecuente |
| Catálogo de productos | 10 min | Cambio infrecuente |
| Lista de clientes | 5 min | Cambio moderado |

---

**Relacionado:** [[Backend MOC]] | [[Base de Datos]] | [[Roadmap Backend]] | [[Arquitectura General]]
