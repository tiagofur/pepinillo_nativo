---
tags:
  - backend
  - despliegue
  - infraestructura
aliases:
  - Backend Deployment
  - Deploy Backend
---

# Backend — Despliegue

> [!abstract] Resumen
> Documentación completa del proceso de despliegue del backend de Solennix: Docker, Docker Compose, variables de entorno, shutdown graceful, jobs en background y estado actual de la infraestructura.

**Relacionado:** [[Backend MOC]] | [[Arquitectura General]] | [[Base de Datos]] | [[Performance]]

---

## Docker (Multi-stage Build)

El backend utiliza un **multi-stage build** para producir imágenes lo más pequeñas y seguras posibles.

> [!tip] ¿Por qué multi-stage?
> El compilador de Go y las dependencias de build no se incluyen en la imagen final. Solo queda el binario estático + los certificados CA necesarios para HTTPS saliente.

```mermaid
flowchart LR
    subgraph Stage 1 — builder
        A["golang:1.24-alpine"] --> B["go mod download"]
        B --> C["CGO_ENABLED=0\ngo build -o server"]
    end
    subgraph Stage 2 — final
        D["alpine:latest"] --> E["COPY server binary"]
        E --> F["COPY CA certs"]
        F --> G["EXPOSE 8080"]
    end
    C -->|"solo binario"| D
```

### Stage 1 — `builder`

| Propiedad    | Valor                       |
| ------------ | --------------------------- |
| Imagen base  | `golang:1.24-alpine`        |
| Acciones     | `go mod download` + compile |
| Output       | Binario estático `/server`  |

### Stage 2 — `final`

| Propiedad   | Valor                                          |
| ----------- | ---------------------------------------------- |
| Imagen base | `alpine:latest`                                |
| Contenido   | Binario + CA certs (`ca-certificates`)         |
| Puerto      | `8080`                                         |
| Entry point | `./server`                                     |

### Comandos

```bash
# Build
docker build -t solennix-backend .

# Run
docker run -p 8080:8080 --env-file .env solennix-backend
```

> [!warning] Variables sensibles
> Nunca pases secrets directamente en el `docker run`. Usá siempre `--env-file` con un `.env` que **no** esté versionado (verificá que `.env` esté en `.gitignore`).

---

## Docker Compose (Desarrollo Local)

El `docker-compose.yml` levanta PostgreSQL para desarrollo local sin necesidad de instalarlo.

```mermaid
flowchart TB
    subgraph Docker Compose
        PG["PostgreSQL 15 Alpine\npuerto 5433"]
        VOL["Volumen persistente\npgdata"]
    end
    APP["Backend Go\npuerto 8080"] -->|"DATABASE_URL"| PG
    PG --- VOL
```

### Configuración de la base de datos

| Propiedad   | Valor              |
| ----------- | ------------------ |
| Imagen      | `postgres:15-alpine` |
| Puerto      | `5433` (host) → `5432` (container) |
| Usuario     | `solennix_user`    |
| Password    | `solennix_password` |
| Base de datos | `solennix`       |
| Volumen     | `pgdata` → `/var/lib/postgresql/data` |

> [!tip] Puerto 5433, no 5432
> Se usa el puerto `5433` en el host para evitar conflictos con PostgreSQL local si ya tenés uno corriendo en `5432`.

```bash
# Levantar servicios
docker compose up -d

# Ver logs
docker compose logs -f postgres

# Detener y eliminar contenedores (sin borrar datos)
docker compose down
```

---

## Variables de Entorno

> [!abstract] Referencia completa de todas las variables de entorno del backend.

### Base de datos y servidor

| Variable | Requerida | Default | Descripción |
| -------- | --------- | ------- | ----------- |
| `DATABASE_URL` | **Sí** | — | URL de conexión PostgreSQL (`postgres://user:pass@host:port/db?sslmode=disable`) |
| `PORT` | No | `8080` | Puerto del servidor HTTP |
| `ENVIRONMENT` | No | `development` | `development` o `production` |
| `TRUST_PROXY` | No | `false` | Confiar en headers `X-Forwarded-For` (activar detrás de reverse proxy) |

### Autenticación

| Variable | Requerida | Default | Descripción |
| -------- | --------- | ------- | ----------- |
| `JWT_SECRET` | **Sí** | — | Secret para firmar JWT (mínimo 32 bytes) |
| `JWT_EXPIRY_HOURS` | No | `24` | Tiempo de expiración del access token |
| `GOOGLE_CLIENT_IDS` | No | — | Client IDs de Google OAuth, separados por coma |
| `APPLE_BUNDLE_ID` | No | — | Apple Bundle ID para validación de tokens |

### CORS y Frontend

| Variable | Requerida | Default | Descripción |
| -------- | --------- | ------- | ----------- |
| `CORS_ALLOWED_ORIGINS` | No | `http://localhost:5173` | Orígenes permitidos, separados por coma |
| `FRONTEND_URL` | No | `http://localhost:5173` | URL del frontend (para links en emails) |

### Email (Resend)

| Variable | Requerida | Default | Descripción |
| -------- | --------- | ------- | ----------- |
| `RESEND_API_KEY` | No | — | API key de Resend para envío de emails |
| `RESEND_FROM_EMAIL` | No | `Solennix <noreply@solennix.com>` | Email remitente |

### Pagos — Stripe

| Variable | Requerida | Default | Descripción |
| -------- | --------- | ------- | ----------- |
| `STRIPE_SECRET_KEY` | No | — | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | No | — | Secret para verificar webhooks de Stripe |
| `STRIPE_PRO_PRICE_ID` | No | — | Price ID del plan Pro en Stripe |
| `STRIPE_PORTAL_CONFIG_ID` | No | — | ID de configuración del billing portal |

### Pagos — RevenueCat (Mobile)

| Variable | Requerida | Default | Descripción |
| -------- | --------- | ------- | ----------- |
| `REVENUECAT_WEBHOOK_SECRET` | No | — | Secret para webhooks de RevenueCat |
| `REVENUECAT_API_KEY` | No | — | API key server-to-server de RevenueCat |

### Administración y Storage

| Variable | Requerida | Default | Descripción |
| -------- | --------- | ------- | ----------- |
| `UPLOAD_DIR` | No | `./uploads` | Directorio para archivos subidos |
| `BOOTSTRAP_ADMIN_EMAIL` | No | — | Email del usuario a promover a admin al arrancar |

> [!warning] Mínimo para arrancar
> Solo `DATABASE_URL` y `JWT_SECRET` son obligatorias. El resto tiene defaults razonables para desarrollo local. En producción, configurá **todas** las de seguridad y pagos.

---

## Graceful Shutdown

El backend implementa un shutdown ordenado para no cortar conexiones activas.

```mermaid
sequenceDiagram
    participant OS as Sistema Operativo
    participant Server as HTTP Server
    participant Pool as pgxpool
    participant DB as PostgreSQL

    OS->>Server: SIGINT / SIGTERM
    Server->>Server: Deja de aceptar nuevas conexiones
    Server->>Server: Espera hasta 15s por conexiones activas
    Server->>Pool: pool.Close()
    Pool->>DB: Cierra todas las conexiones
    Server->>OS: Exit 0
```

### Pasos del shutdown

1. **Captura señales** `SIGINT` y `SIGTERM` vía `os/signal`
2. **Deja de aceptar** nuevas conexiones HTTP (`Shutdown(ctx)`)
3. **Espera** hasta **15 segundos** por conexiones activas
4. **Cierra** el pool de conexiones PostgreSQL (`pgxpool.Close()`)
5. **Sale** limpiamente con código `0`

> [!tip] Kubernetes / Docker
> Si deployás en K8s, configurá `terminationGracePeriodSeconds` a un valor mayor a 15s para que el pod no sea matado antes de que termine el graceful shutdown.

---

## Background Jobs

> [!abstract] Tareas programadas que corren en segundo plano dentro del mismo proceso.

| Job | Frecuencia | Descripción |
| --- | ---------- | ----------- |
| **Expire Gifted Plans** | Cada 1 hora | Revierte planes regalados expirados al plan básico |

```mermaid
flowchart LR
    CRON["Ticker\n1 hora"] --> CHECK["Buscar gifted plans\ncon expiry <= now()"]
    CHECK -->|"encontrados"| REVERT["Revertir a plan básico"]
    CHECK -->|"ninguno"| WAIT["Esperar próximo tick"]
    REVERT --> WAIT
```

---

## Health Check

```
GET /health
```

**Response:**

```json
{
  "status": "ok"
}
```

> [!tip] Docker healthcheck
> Podés agregarlo al Dockerfile o al docker-compose:

```yaml
healthcheck:
  test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
  interval: 30s
  timeout: 5s
  retries: 3
```

---

## Deployment Gaps

> [!warning] Brechas actuales de infraestructura
> Estos son los puntos pendientes antes de considerar el despliegue production-ready.

```mermaid
mindmap
  root((Deployment Gaps))
    CI/CD
      Sin pipeline documentado
      Sin build automation
    Orquestación
      Sin K8s / ECS
      Sin auto-scaling
    Storage
      Archivos locales
      No escala multi-instancia
    Observabilidad
      Sin endpoint DB health
      Sin métricas Prometheus
      Sin log aggregation
```

### Detalle

| Gap | Severidad | Descripción |
| --- | --------- | ----------- |
| **Sin CI/CD** | 🔴 Alta | No hay pipeline de build/test/deploy automatizado |
| **Sin orquestación** | 🔴 Alta | No hay K8s, ECS ni similar para manejar réplicas |
| **Storage local** | 🟡 Media | `UPLOAD_DIR` usa filesystem local; no funciona con múltiples instancias |
| **Sin DB health check** | 🟡 Media | `/health` solo verifica el server, no la conectividad con PostgreSQL |
| **Sin métricas** | 🟡 Media | No hay endpoint `/metrics` para Prometheus |
| **Sin log aggregation** | 🟡 Media | Logs van a stdout pero no hay centralización (ELK, Loki, etc.) |

> [!tip] Prioridad recomendada
> 1. CI/CD (GitHub Actions) — sin automatización, todo es manual y propenso a errores
> 2. DB health check en `/health` — trivial de implementar, gran impacto
> 3. Migrar uploads a S3/R2 — necesario antes de escalar
> 4. Log aggregation — esencial para troubleshooting en producción

---

## Checklist Pre-Deploy

> [!abstract] Verificar antes de cada deploy a producción.

- [ ] Todas las variables requeridas configuradas en el entorno
- [ ] `JWT_SECRET` tiene al menos 32 bytes y es único por entorno
- [ ] `DATABASE_URL` apunta a la base de datos correcta con SSL habilitado
- [ ] `CORS_ALLOWED_ORIGINS` no incluye `*`
- [ ] `ENVIRONMENT=production`
- [ ] `TRUST_PROXY=true` si hay reverse proxy (nginx, Cloudflare)
- [ ] Migraciones de DB ejecutadas
- [ ] Health check responde `200 OK`
- [ ] Secrets rotados si hubo exposición
