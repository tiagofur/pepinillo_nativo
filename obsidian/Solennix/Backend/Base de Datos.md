# Base de Datos

#backend #database #infraestructura

> [!abstract] Resumen
> **PostgreSQL 15** con **pgx/v5** connection pool. Sistema de migraciones custom con `go:embed` — sin herramientas externas. 29 migraciones que evolucionaron el schema desde usuarios hasta OAuth, push tokens y nullable passwords. Sin ORM: queries SQL directas con control total.

---

## Connection Pool

```mermaid
graph LR
    App["Go App"] --> Pool["pgxpool.Pool"]
    Pool --> C1["Conn 1"]
    Pool --> C2["Conn 2"]
    Pool --> CDots["..."]
    Pool --> C20["Conn 20"]
    C1 --> PG[("PostgreSQL 15")]
    C2 --> PG
    CDots --> PG
    C20 --> PG

    style App fill:#1B2A4A,stroke:#C4A265,color:#F5F0E8
    style Pool fill:#2D6A4F,stroke:#C4A265,color:#F5F0E8
    style PG fill:#C4A265,stroke:#1B2A4A,color:#1A1A1A
```

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `MaxConns` | 20 | Máximo conexiones simultáneas |
| `MinConns` | 2 | Conexiones idle mínimas (warm) |
| `MaxConnLifetime` | 30 min | Rotación de conexiones |
| `MaxConnIdleTime` | 5 min | Cleanup de conexiones inactivas |
| `ConnectTimeout` | 10 s | Timeout al conectar |

> [!tip] Ping verification
> `database.go:31` — Luego de crear el pool, se ejecuta `pool.Ping(ctx)`. Si falla, se hace `pool.Close()` y se retorna error. El servidor no arranca sin DB.

**Archivo**: `internal/database/database.go`

> [!warning] Pool config hardcoded
> Los valores del pool están hardcodeados en `Connect()` — no son configurables via variables de entorno. Para diferentes workloads (dev vs prod), esto debería externalizarse.

## Flujo de Conexión

```mermaid
sequenceDiagram
    participant Main as cmd/server/main.go
    participant DB as database.Connect()
    participant Pool as pgxpool.Pool
    participant PG as PostgreSQL

    Main->>DB: Connect(databaseURL)
    DB->>DB: pgxpool.ParseConfig(databaseURL)
    DB->>DB: Configurar pool (MaxConns, MinConns, etc.)
    DB->>Pool: pgxpool.NewWithConfig(ctx, config)
    DB->>PG: pool.Ping(ctx)
    alt Ping OK
        PG-->>DB: OK
        DB->>DB: slog.Info("Connected to database")
        DB-->>Main: *pgxpool.Pool, nil
        Main->>DB: database.Migrate(pool)
    else Ping FAIL
        PG-->>DB: Error
        DB->>Pool: pool.Close()
        DB-->>Main: nil, error
    end
```

---

## Sistema de Migraciones

```mermaid
graph TD
    subgraph Build["Build Time"]
        Embed["//go:embed migrations/*.up.sql<br/>embed.FS"]
    end

    subgraph Startup["Server Startup"]
        Migrate["database.Migrate(pool)"]
        Track["CREATE TABLE IF NOT EXISTS<br/>schema_migrations"]
        Read["Leer schema_migrations<br/>ya aplicadas"]
        Filter["Filtrar .up.sql pendientes"]
        Sort["Ordenar alfabéticamente"]
    end

    subgraph Apply["Por cada migración pendiente"]
        TX["BEGIN transaction"]
        Exec["EXEC migration SQL"]
        Record["INSERT INTO schema_migrations"]
        Commit["COMMIT"]
        Rollback["ROLLBACK on error"]
    end

    Embed --> Migrate
    Migrate --> Track
    Track --> Read
    Read --> Filter
    Filter --> Sort
    Sort --> TX
    TX --> Exec
    Exec -->|OK| Record
    Record --> Commit
    Exec -->|Error| Rollback

    style Build fill:#2D6A4F,stroke:#C4A265,color:#F5F0E8
    style Startup fill:#1B2A4A,stroke:#C4A265,color:#F5F0E8
    style Apply fill:#C4A265,stroke:#1B2A4A,color:#1A1A1A
```

### Características

| Propiedad | Detalle |
|-----------|---------|
| **Embedding** | `//go:embed migrations/*.up.sql` → binario único, sin archivos externos |
| **Tracking** | Tabla `schema_migrations` (version PK + applied_at) |
| **Idempotente** | Solo aplica migraciones que NO están en `schema_migrations` |
| **Transaccional** | Cada migración corre en una transacción — rollback automático on failure |
| **Auto-apply** | Se ejecuta en `main.go` antes de arrancar el server |
| **Solo up** | Down migrations existen como archivos pero NO se ejecutan automáticamente |
| **Naming** | `{NNN}_{description}.up.sql` / `{NNN}_{description}.down.sql` |

> [!important] Down migrations
> Los archivos `.down.sql` existen para rollback manual, pero el sistema NO los ejecuta automáticamente. Rollback es manual contra la DB.

**Archivo**: `internal/database/migrate.go`

---

## Las 29 Migraciones

```mermaid
timeline
    title Evolución del Schema
    section Fundacionales (001-007)
        001_create_users : Users table
        002_create_clients : Clients (user_id FK)
        003_create_events : Events con finanzas
        004_create_products : Productos/servicios
        005_create_inventory : Inventario (ingredientes, equipo, insumos)
        006_create_junction_tables : event_products, event_extras, product_ingredients
        007_create_payments_subscriptions : Pagos + suscripciones
    section Branding (008-012)
        008_add_client_logo : logo_url en clients
        009_move_logo : Logo de clients → users
        010_add_user_brand_color : brand_color en users
        011_add_show_business_name : show_business_name_in_pdf
        012_extend_subscriptions : RevenueCat fields
    section Correctivas (013-014)
        013_fix_plan_constraint : Fix plan constraint
        014_add_indexes_and_cascade : Índices + CASCADE en FKs
    section Features (015-024)
        015_add_image_fields : Imágenes en productos
        016_create_event_equipment : event_equipment table
        017_add_contract_template_to_users : Contratos
        018_add_role_to_users : Role (user/admin)
        019_add_plan_expires_at : Planes regalados
        020a_add_discount_type_to_events : Descuento % o fijo
        020b_add_equipment_capacity : Capacidad en product_ingredients
        021_add_bring_to_event : bring_to_event
        022_create_unavailable_dates : Fechas bloqueadas
        023_add_supply_type_and_table : Insumos + event_supplies
        024_add_exclude_cost_to_event_supplies : Excluir del costo
    section OAuth & Push (025-029)
        025_add_oauth_user_ids : google_user_id, apple_user_id
        026_create_device_tokens : Push notification tokens
        027_add_subscription_provider_unique : Unique constraint
        028_add_include_in_checklist : Checklist de productos
        029_make_password_hash_nullable : Cuentas OAuth-only
```

### Detalle Completo

| # | Nombre | Propósito | Tablas/Columnas Afectadas |
|---|--------|-----------|--------------------------|
| 001 | `create_users` | Tabla base de usuarios | `users` |
| 002 | `create_clients` | Clientes con FK a user | `clients` (user_id FK) |
| 003 | `create_events` | Eventos con campos financieros | `events` |
| 004 | `create_products` | Productos y servicios | `products` |
| 005 | `create_inventory` | Inventario de ingredientes, equipo, insumos | `inventory_items` |
| 006 | `create_junction_tables` | Relaciones N:M | `event_products`, `event_extras`, `product_ingredients` |
| 007 | `create_payments_subscriptions` | Pagos y suscripciones | `payments`, `subscriptions` |
| 008 | `add_client_logo` | Logo URL en clientes | `clients.logo_url` |
| 009 | `move_logo` | Logo pasa de clients a users | `users.logo_url` |
| 010 | `add_user_brand_color` | Color de marca del usuario | `users.brand_color` |
| 011 | `add_show_business_name` | Mostrar nombre en PDFs | `users.show_business_name_in_pdf` |
| 012 | `extend_subscriptions` | Campos RevenueCat + provider | `subscriptions` (provider, RevenueCat) |
| 013 | `fix_plan_constraint` | Corrección de constraint de plan | `users` |
| 014 | `add_indexes_and_cascade` | Índices de performance + CASCADE | Múltiples FKs |
| 015 | `add_image_fields` | Campos de imagen en productos | `products` (image fields) |
| 016 | `create_event_equipment` | Equipamiento por evento | `event_equipment` |
| 017 | `add_contract_template_to_users` | Template de contrato | `users.contract_template` |
| 018 | `add_role_to_users` | Rol de usuario | `users.role` (user/admin) |
| 019 | `add_plan_expires_at` | Expiración para planes regalados | `users.plan_expires_at` |
| 020a | `add_discount_type_to_events` | Tipo de descuento | `events.discount_type` (percent/fixed) |
| 020b | `add_equipment_capacity` | Capacidad en ingredientes | `product_ingredients.capacity` |
| 021 | `add_bring_to_event` | Traer al evento | `product_ingredients.bring_to_event` |
| 022 | `create_unavailable_dates` | Fechas bloqueadas | `unavailable_dates` |
| 023 | `add_supply_type_and_table` | Tipo insumo + tabla de supplies | `inventory_items` supply type + `event_supplies` |
| 024 | `add_exclude_cost_to_event_supplies` | Excluir del costo total | `event_supplies.exclude_cost` |
| 025 | `add_oauth_user_ids` | IDs de Google y Apple | `users.google_user_id`, `users.apple_user_id` |
| 026 | `create_device_tokens` | Tokens para push notifications | `device_tokens` |
| 027 | `add_subscription_provider_unique` | Unique por provider de suscripción | `subscriptions` unique constraint |
| 028 | `add_include_in_checklist` | Incluir en checklist | `products.include_in_checklist` |
| 029 | `make_password_hash_nullable` | Password opcional (OAuth-only) | `users.password_hash` nullable |

> [!tip] Naming con sufijo
> Las migraciones `020a` y `020b` usan sufijo alfabético para mantener orden lógico dentro del mismo número de versión. El sistema las ordena alfabéticamente así que esto funciona correctamente.

---

## Diagrama ER

```mermaid
erDiagram
    users ||--o{ clients : "posee"
    users ||--o{ events : "organiza"
    users ||--o{ products : "administra"
    users ||--o{ inventory_items : "gestiona"
    users ||--o{ payments : "registra"
    users ||--o{ subscriptions : "suscribe"
    users ||--o{ unavailable_dates : "bloquea"
    users ||--o{ device_tokens : "registra"

    clients ||--o{ events : "tiene"

    events ||--o{ event_products : "contiene"
    events ||--o{ event_extras : "agrega"
    events ||--o{ event_equipment : "usa"
    events ||--o{ event_supplies : "consume"
    events ||--o{ payments : "genera"

    products ||--o{ product_ingredients : "compuesto_por"

    event_products }o--|| products : "referencia"
    event_equipment }o--|| inventory_items : "referencia"
    event_supplies }o--|| inventory_items : "referencia"
    product_ingredients }o--|| inventory_items : "referencia"

    users {
        uuid id PK
        string email UK
        string password_hash "nullable (OAuth)"
        string business_name
        string phone
        string logo_url
        string brand_color
        boolean show_business_name_in_pdf
        string contract_template
        string role "user|admin"
        string plan "free|pro|premium"
        timestamp plan_expires_at
        string google_user_id "nullable"
        string apple_user_id "nullable"
        timestamp created_at
    }

    clients {
        uuid id PK
        uuid user_id FK
        string name
        string email
        string phone
        string notes
        timestamp created_at
    }

    events {
        uuid id PK
        uuid user_id FK
        uuid client_id FK
        string title
        timestamp event_date
        string status
        string location
        integer guest_count
        string discount_type "percent|fixed"
        numeric discount_value
        numeric total_amount
        numeric paid_amount
        text notes
        timestamp created_at
    }

    products {
        uuid id PK
        uuid user_id FK
        string name
        text description
        numeric price
        string category
        string image_url
        boolean include_in_checklist
        timestamp created_at
    }

    inventory_items {
        uuid id PK
        uuid user_id FK
        string name
        string type "ingredient|equipment|supply"
        string unit
        numeric unit_cost
        numeric stock_quantity
        timestamp created_at
    }

    event_products {
        uuid id PK
        uuid event_id FK
        uuid product_id FK
        integer quantity
        numeric unit_price
    }

    event_extras {
        uuid id PK
        uuid event_id FK
        string name
        numeric price
    }

    event_equipment {
        uuid id PK
        uuid event_id FK
        uuid inventory_item_id FK
        integer quantity
    }

    event_supplies {
        uuid id PK
        uuid event_id FK
        uuid inventory_item_id FK
        integer quantity
        boolean exclude_cost
    }

    product_ingredients {
        uuid id PK
        uuid product_id FK
        uuid inventory_item_id FK
        numeric quantity
        numeric capacity
        boolean bring_to_event
    }

    payments {
        uuid id PK
        uuid user_id FK
        uuid event_id FK
        numeric amount
        string method
        timestamp payment_date
        text notes
    }

    subscriptions {
        uuid id PK
        uuid user_id FK
        string provider "stripe|revenuecat"
        string provider_id
        string plan
        string status
        timestamp current_period_start
        timestamp current_period_end
    }

    unavailable_dates {
        uuid id PK
        uuid user_id FK
        date date
        string reason
    }

    device_tokens {
        uuid id PK
        uuid user_id FK
        string token UK
        string platform "ios|android"
        timestamp created_at
    }
```

> [!important] Multi-tenant isolation
> **Todas** las tablas principales tienen `user_id` FK. Las queries en repos SIEMPRE filtran por `user_id` extraído del JWT via middleware [[Autenticación]]. Esto garantiza aislamiento entre usuarios.

---

## Flujo de Startup (DB)

```mermaid
sequenceDiagram
    participant Main as main.go
    participant Config as config.Load()
    participant DB as database.Connect()
    participant Mig as database.Migrate()
    participant Pool as pgxpool.Pool
    participant PG as PostgreSQL

    Main->>Config: Load .env
    Config-->>Main: Config{DatabaseURL}
    Main->>DB: Connect(config.DatabaseURL)
    DB->>Pool: ParseConfig + NewWithConfig
    DB->>PG: Ping()
    PG-->>DB: OK
    DB-->>Main: pool
    Main->>Mig: Migrate(pool)
    Mig->>PG: CREATE TABLE IF NOT EXISTS schema_migrations
    Mig->>PG: SELECT version FROM schema_migrations
    Mig->>Mig: Filtrar pendientes + ordenar
    loop Por cada migración pendiente
        Mig->>PG: BEGIN
        Mig->>PG: EXEC migration SQL
        Mig->>PG: INSERT schema_migrations
        Mig->>PG: COMMIT
    end
    Mig-->>Main: nil (success)
    Main->>Main: Iniciar router + server
```

---

## Áreas de Mejora

> [!danger] P0 — Operacionales

| Gap | Impacto | Solución |
|-----|---------|----------|
| **Sin backup strategy** | Pérdida total de datos ante desastre | pg_dump automatizado + S3/GCS |
| **Sin down migrations automático** | Rollback manual, riesgoso | Comando CLI para rollback |
| **Pool config hardcoded** | No se adapta a distintos ambientes | Variables de entorno para cada parámetro |

> [!warning] P1 — Performance

| Gap | Impacto | Solución |
|-----|---------|----------|
| **UpdateEventItems: DELETE ALL + INSERT ALL** | Transacción grande, locks prolongados | UPSERT con conflictos + DELETE los removidos |
| **Índices faltantes para búsqueda** | Full table scans en search, date ranges | GIN index para texto, B-tree para fechas |
| **Sin read replicas** | Toda la carga en una instancia | Streaming replication para reads |

> [!note] P2 — Observabilidad

| Gap | Impacto | Solución |
|-----|---------|----------|
| **Sin pool metrics** | No visibilidad de saturación | Exponer `pool.Stat()` como Prometheus metrics |
| **Sin query logging** | Queries lentas invisibles | `pgx.QueryTracer` con slog |
| **Sin health check endpoint** | K8s/Docker no pueden verificar DB | `GET /health` con ping al pool |

> [!tip] Patrón alternativo para UpdateEventItems
> En vez de `DELETE FROM event_products WHERE event_id=$1` + `INSERT` de todo, considerar:
> ```sql
> INSERT INTO event_products (...) VALUES (...) ON CONFLICT (event_id, product_id) DO UPDATE SET ...
> ```
> Y luego borrar solo los que ya no están. Esto reduce locks y preserva datos no modificados.

---

## Relaciones

- [[Arquitectura General]] — Posición de la DB en las capas del backend
- [[Backend MOC]] — Hub principal del backend
- [[Seguridad]] — Multi-tenant isolation, SQL parametrizado
- [[Performance]] — Índices, pool config, queries optimizadas

#backend #database #infraestructura
