---
tags:
  - backend
  - integraciones
  - infraestructura
  - stripe
  - revenuecat
  - resend
---

# Integraciones del Backend

Parent: [[Backend MOC]] | Related: [[Autenticación]] | [[Módulo Suscripciones]] | [[Módulo Uploads]]

Visión general de todos los servicios externos con los que interactúa el backend de Solennix.

```mermaid
graph TB
    subgraph Clientes
        WEB[Web App<br/>React]
        IOS[iOS App<br/>Expo]
        AND[Android App<br/>Expo]
    end

    subgraph Backend["Backend Go"]
        API[Chi Router<br/>/api/*]
        SH[Subscription<br/>Handler]
        UH[Upload<br/>Handler]
        ES[Email<br/>Service]
        RS[RevenueCat<br/>Service]
        SS[Stripe<br/>Service]
    end

    subgraph Externos
        STRIPE[Stripe<br/>Payments & Subs]
        RC[RevenueCat<br/>Mobile Subs]
        RESEND[Resend<br/>Transactional Email]
        DISK[Local Disk<br/>File Storage]
    end

    WEB -->|Checkout / Portal| API
    IOS -->|In-App Purchase| RC
    AND -->|In-App Purchase| RC

    API --> SH
    API --> UH
    SH --> SS
    SH --> RS
    SH --> ES
    SS -->|REST API| STRIPE
    RS -->|REST API v1| RC
    ES -->|REST API| RESEND
    UH -->|Read/Write| DISK

    STRIPE -.->|Webhook| SH
    RC -.->|Webhook v2| SH

    style STRIPE fill:#635bff,color:#fff
    style RC fill:#1ba954,color:#fff
    style RESEND fill:#000,color:#fff
    style DISK fill:#f59e0b,color:#000
```

---

## Stripe (Payments & Subscriptions)

> [!abstract] Resumen
> Stripe maneja las suscripciones SaaS (plan Pro). Toda la comunicación es server-to-server vía la librería `stripe-go/v81`. La app no intermediar pagos entre organizadores y sus clientes.

### Archivos

| Archivo | Rol |
|---------|-----|
| `handlers/stripe_service.go` | Wrapper sobre el SDK de Stripe (checkout sessions, billing portal, subscription lookups). Implementa la interfaz `StripeService` para testing. |
| `handlers/subscription_handler.go` | Orquesta el flujo completo: checkout, portal, webhooks de Stripe y RevenueCat, status endpoint. |

### Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/api/subscriptions/checkout-session` | Crea una Checkout Session de suscripción Pro |
| `POST` | `/api/subscriptions/portal-session` | Crea una sesión del Customer Portal |
| `GET` | `/api/subscriptions/status` | Devuelve el plan actual y detalles de la suscripción |
| `POST` | `/api/subscriptions/webhook/stripe` | Webhook de Stripe (sin auth — firma verificada) |

### Flujo de Suscripción Web

```mermaid
sequenceDiagram
    participant U as Usuario
    participant B as Backend
    participant S as Stripe
    participant RC as RevenueCat

    U->>B: POST /checkout-session
    B->>S: Crear Checkout Session
    S-->>B: Session URL
    B-->>U: { url }
    U->>S: Redirige a Stripe Checkout
    S-->>B: Webhook: checkout.session.completed
    B->>B: UpdatePlanAndStripeID → "pro"
    B->>RC: GrantPromotionalEntitlement("pro_access")
    B->>B: Upsert subscription record
    Note over B: Si el customer ID estaba stale,<br/>reintenta sin customer ID
```

### Eventos de Webhook Manejados

| Evento Stripe | Acción |
|---------------|--------|
| `checkout.session.completed` | Upgrade a Pro + sync RevenueCat + upsert subscription. |
| `customer.subscription.updated` | Mapear status: `active` → mantener Pro, `past_due` → marcar subscription, `canceled` → marcar subscription, `unpaid` → downgrade a basic + revoke RC. |
| `customer.subscription.deleted` | Downgrade a basic + revoke RevenueCat entitlement. |
| `invoice.payment_failed` | Marcar subscription como `past_due`. |

> [!tip] Retry inteligente
> Si la creación de la checkout session falla con un `customer_id` guardado (IDs de test mode en live mode), el handler reintenta automáticamente sin customer ID, usando solo el email.

### Variables de Entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `STRIPE_SECRET_KEY` | API key secreta de Stripe | — |
| `STRIPE_WEBHOOK_SECRET` | Secreto para verificar firma del webhook | — |
| `STRIPE_PRO_PRICE_ID` | Price ID del plan Pro | — |
| `STRIPE_PORTAL_CONFIG_ID` | ID de configuración del Billing Portal (opcional) | — |

---

## RevenueCat (Mobile Subscriptions)

> [!abstract] Resumen
> RevenueCat sincroniza las compras de iOS/Android con el backend. Además, cuando un usuario se suscribe vía Stripe (web), el backend **grants** un entitlement promocional en RevenueCat para que las apps móviles vean el acceso Pro.

### Archivos

| Archivo | Rol |
|---------|-----|
| `services/revenuecat_service.go` | Cliente REST para RevenueCat API v1. Grant/Revoke de entitlements promocionales. |
| `handlers/subscription_handler.go` | Recibe webhooks de RevenueCat, actualiza plan del usuario en la DB. |

### Sync Stripe → RevenueCat (Web → Mobile)

```mermaid
sequenceDiagram
    participant S as Stripe Webhook
    participant B as Backend
    participant RC as RevenueCat API

    Note over S: Usuario se suscribe vía web
    S->>B: checkout.session.completed
    B->>RC: POST /subscribers/{userID}/entitlements/pro_access/promotional
    Note over RC: duration = "monthly" o "yearly"<br/>según interval de Stripe
    RC-->>B: 200 OK
    Note over B: Ahora iOS/Android ven pro_access

    Note over S: Usuario cancela suscripción web
    S->>B: customer.subscription.deleted
    B->>RC: POST /subscribers/{userID}/entitlements/pro_access/revoke_promotionals
    RC-->>B: 200 OK
```

### RevenueCat Webhook → Backend

```mermaid
sequenceDiagram
    participant RC as RevenueCat
    participant B as Backend

    RC->>B: POST /api/subscriptions/webhook/revenuecat
    Note over B: Verifica Authorization header<br/>con constant-time compare

    alt INITIAL_PURCHASE / RENEWAL / UNCANCELLATION
        B->>B: UpdatePlan("pro") + Upsert subscription
    else CANCELLATION / EXPIRATION / BILLING_ISSUE
        B->>B: UpdatePlan("basic") + Update subscription status
    else PRODUCT_CHANGE
        B->>B: Log, sin cambios de plan
    end
```

### Eventos de Webhook Manejados

| Evento RC | Acción |
|-----------|--------|
| `INITIAL_PURCHASE` | Upgrade a Pro + upsert subscription |
| `RENEWAL` | Mantener Pro + actualizar período |
| `UNCANCELLATION` | Reactivar Pro |
| `CANCELLATION` | Downgrade a basic |
| `EXPIRATION` | Downgrade a basic |
| `BILLING_ISSUE` | Downgrade a basic + status `past_due` |
| `PRODUCT_CHANGE` | Log informativo, sin cambio de plan |

> [!warning] Degradación graciosa
> Si `REVENUECAT_API_KEY` no está configurada, **todos** los métodos de `RevenueCatService` son no-ops (`return nil`). El sistema funciona normalmente sin sincronizar con RevenueCat. Esto permite desarrollo local sin configurar el servicio.

### Mapeo de Stores

| RevenueCat Store | Provider en DB |
|------------------|---------------|
| `APP_STORE` | `apple` |
| `PLAY_STORE` | `google` |
| `STRIPE` | `stripe` |

### Variables de Entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `REVENUECAT_API_KEY` | API key secreta para server-to-server | — |
| `REVENUECAT_WEBHOOK_SECRET` | Secreto para verificar webhook v2 (header Authorization) | — |

---

## Resend (Transactional Email)

> [!abstract] Resumen
> Resend es el proveedor de email transaccional. Se usa para múltiples tipos de emails automatizados con branding Solennix (tema dorado #C4A265).

### Archivo

| Archivo | Rol |
|---------|-----|
| `services/email_service.go` | Servicio de email con template HTML reutilizable. Usa `resend-go/v3`. |

### Emails Implementados

| Email | Trigger | Template |
|-------|---------|----------|
| Password Reset | `POST /api/auth/forgot-password` | Link de reset con expiración 1h |
| Welcome | `POST /api/auth/register` | Bienvenida al registrarse |
| Event Reminder | Background job (24h antes) | Recordatorio de evento próximo |
| Payment Receipt | `POST /api/payments` | Recibo de pago registrado |
| Subscription Confirmation | Webhook Stripe/RevenueCat | Confirmación de upgrade a Pro |

### Emails Planificados (Etapa 2)

| Email | Trigger | Estado |
|-------|---------|--------|
| Resumen semanal | Cron cada lunes | ⬜ Pendiente |
| Cotización sin confirmar | Cron diario (7+ días sin confirmar) | ⬜ Pendiente |
| Notificación al cliente del usuario | Acciones de evento | ⬜ Pendiente |

> [!tip] Preferencias del usuario (Etapa 2)
> En la Etapa 2 se agregará una tabla de preferencias para que el usuario pueda activar/desactivar cada tipo de email. Ver [[13_POST_MVP_ROADMAP|Roadmap Post-MVP]].

### Características del Email

- **Template HTML reutilizable** con estilos embebidos (compatible con todos los clientes)
- **Branding Solennix**: logo dorado `#C4A265`, botón CTA, footer
- **Link fallback**: texto plano del enlace para clientes que no renderizan HTML
- **From default**: `Solennix <noreply@solennix.com>`

> [!warning] Degradación graciosa
> Si `RESEND_API_KEY` no está configurada, el servicio loguea un warning (`"Resend not configured, email not sent"`) y devuelve un error. Los flujos no fallan — degradan graciosamente.

### Variables de Entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `RESEND_API_KEY` | API key de Resend | — |
| `RESEND_FROM_EMAIL` | Email remitente | `Solennix <noreply@solennix.com>` |
| `FRONTEND_URL` | URL base del frontend (para generar links) | `http://localhost:5173` |

---

## File Uploads

> [!abstract] Resumen
> Sistema de uploads de imágenes con almacenamiento en disco local, thumbnails automáticos, y límites por plan.

### Archivo

| Archivo | Rol |
|---------|-----|
| `handlers/upload_handler.go` | Handler de upload con validación de tipo, límites por plan, generación de thumbnails. |

### Arquitectura de Storage

```mermaid
graph LR
    subgraph Upload Flow
        REQ[POST /api/uploads/image] --> AUTH[Auth Middleware]
        AUTH --> LIMIT[Check Plan Limit]
        LIMIT --> VALID[Validate Magic Bytes]
        VALID --> SAVE[Save to Disk]
        SAVE --> THUMB[Generate Thumbnail<br/>200x200 max]
        THUMB --> RESP[Return URLs]
    end

    subgraph Disk["{UPLOAD_DIR}/"]
        U1["{userID}/<br/>├── uuid.jpg<br/>├── uuid.png<br/>└── thumbnails/<br/>    └── thumb_uuid.jpg"]
    end

    SAVE --> U1
```

### Formatos Soportados

| Extensión | Magic Bytes Check | Thumbnail Output |
|-----------|-------------------|-----------------|
| `.jpg` / `.jpeg` | `image/*` via `http.DetectContentType` | `.jpg` (quality 80) |
| `.png` | `image/*` via `http.DetectContentType` | `.jpg` (quality 80) |
| `.gif` | `image/*` via `http.DetectContentType` | `.jpg` (quality 80) |
| `.webp` | `image/*` via `http.DetectContentType` | `.jpg` (quality 80) |

> [!tip] Validación de seguridad
> El handler **no confía** en el header `Content-Type` del cliente. Lee los primeros 512 bytes del archivo y usa `http.DetectContentType()` para verificar que es una imagen real.

### Límites por Plan

| Plan | Máx. Uploads | Tamaño Máx. por Archivo |
|------|-------------|------------------------|
| Basic | 50 archivos | 10 MB |
| Pro | 200 archivos | 10 MB |

### Endpoints y Configuración

| Método | Ruta | Auth | Rate Limit | Descripción |
|--------|------|------|------------|-------------|
| `POST` | `/api/uploads/image` | JWT | 5 req/min | Subir imagen (multipart/form-data) |
| `GET` | `/api/uploads/*` | No | — | Servir archivos estáticos (Cache: 1 año) |

### Response de Upload

```json
{
  "url": "/api/uploads/{userID}/{uuid}.jpg",
  "thumbnail_url": "/api/uploads/{userID}/thumbnails/thumb_{uuid}.jpg",
  "filename": "uuid.jpg"
}
```

### Variables de Entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `UPLOAD_DIR` | Directorio base para archivos subidos | `./uploads` |

---

## Diagrama de Integraciones — Vista Completa

```mermaid
graph TB
    subgraph Webhooks Entrantes
        SW[Stripe Webhook<br/>/api/subscriptions/webhook/stripe]
        RW[RevenueCat Webhook<br/>/api/subscriptions/webhook/revenuecat]
    end

    subgraph Handler Layer
        SH[SubscriptionHandler]
        UH[UploadHandler]
        AH[AuthHandler]
    end

    subgraph Service Layer
        SS[StripeService<br/>stripe-go/v81]
        RCS[RevenueCatService<br/>REST API v1]
        EMS[EmailService<br/>resend-go/v3]
    end

    subgraph Storage
        DB[(PostgreSQL)]
        DISK[(Local Disk<br/>UPLOAD_DIR)]
    end

    subgraph External APIs
        STRIPE[Stripe API]
        RC_API[RevenueCat API]
        RESEND[Resend API]
    end

    SW --> SH
    RW --> SH
    SH --> SS
    SH --> RCS
    AH --> EMS

    SS --> STRIPE
    RCS --> RC_API
    EMS --> RESEND

    SH --> DB
    AH --> DB
    UH --> DISK
    UH --> DB

    style STRIPE fill:#635bff,color:#fff
    style RC_API fill:#1ba954,color:#fff
    style RESEND fill:#000,color:#fff
    style DISK fill:#f59e0b,color:#000
    style DB fill:#336791,color:#fff
```

---

## Integration Gaps

> [!warning] Brechas actuales

| Gap | Estado | Notas |
|-----|--------|-------|
| ~~**Push Notifications**~~ | ✅ Implementado | FCM + APNs activos con PushService + NotificationService |
| ~~**Email limitado**~~ | ✅ Implementado | Welcome, reminder, receipt, subscription. Ver Resend sección |
| **SMS / WhatsApp** | No implementado | Etapa 2: WhatsApp deep links (P0), WhatsApp Business API (P3) |
| **Calendar Sync** | No implementado | Etapa 2: iCal feed + Google Calendar + Apple Calendar (P2) |
| **Cloud Storage** | ⚠️ Interface lista | StorageProvider con Local + S3. Presigned URLs pendientes |
| **Portal del Cliente** | No implementado | Etapa 2: endpoints públicos con token de acceso (P1) |
| **Analytics/Tracking** | No implementado | Diferido hasta usuarios en producción |
| **Notificaciones al cliente del organizador** | No implementado | Etapa 2: emails automáticos al cliente final (P1) |

> [!tip] Ver [[13_POST_MVP_ROADMAP|Roadmap Post-MVP (Etapa 2)]] para el plan completo de implementación.

---

## Configuración Rápida (Desarrollo Local)

> [!tip] Mínimo indispensable
> Para correr el backend localmente, solo necesitas `DATABASE_URL` y `JWT_SECRET`. Todas las integraciones degradan graciosamente si no están configuradas.

```bash
# Requerido
DATABASE_URL=postgres://user:pass@localhost:5432/solennix
JWT_SECRET=your-32-byte-minimum-secret-here

# Opcional — degradación graciosa si no están
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRO_PRICE_ID=price_...
STRIPE_PORTAL_CONFIG_ID=bpc_...
REVENUECAT_API_KEY=sk_...
REVENUECAT_WEBHOOK_SECRET=rc_wh_...
RESEND_API_KEY=re_...
RESEND_FROM_EMAIL=Solennix <noreply@solennix.com>
FRONTEND_URL=http://localhost:5173
UPLOAD_DIR=./uploads
```
