# Guía de Configuración de RevenueCat para Pepinillo

**Para:** Tiago, desarrollador de Pepinillo
**Fecha:** Marzo 2026
**Idioma:** Español
**Objetivo:** Completar la configuración manual de RevenueCat y App Store Connect para monetización iOS

---

## Resumen Ejecutivo

La integración de RevenueCat está parcialmente completa. Este documento guía los pasos manuales necesarios para:

1. Generar y configurar credenciales de App Store Connect
2. Registrar la app iOS en RevenueCat
3. Vincular productos y entitlements
4. Configurar precios y metadata
5. Activar facturación y webhooks
6. Testing en Sandbox

**Tiempo estimado:** 45-60 minutos
**Requisitos:** Acceso administrativo a App Store Connect y RevenueCat

---

## Estado Actual

### Ya Completado

| Componente | Estado |
|-----------|--------|
| SDK RevenueCat iOS (v5+) | ✅ Integrado vía SPM |
| SubscriptionClient.swift | ✅ Reescrito |
| PaywallFeature/PaywallView | ✅ Adaptado |
| AppFeature (inicialización) | ✅ Configura RC al lanzar |
| Backend Go (webhook endpoint) | ✅ POST /api/v1/webhooks/revenuecat |
| Backend Go (cliente API RC) | ✅ Implementado |
| Entitlement identifier | ✅ "premium" (alineado) |
| Product IDs en código | ✅ com.pepinillo.app.pro.* |
| Subscription Group (ASC) | ✅ "Pepinillo Pro" (ID: 21984205) |
| Products (ASC) | ✅ Creados, falta metadata |
| Build 1.0.0 (build 2) | ✅ Subido a ASC |

### Falta Completar

| Componente | Paso |
|-----------|------|
| In-App Purchase Key (.p8) | PASO 1 |
| App iOS en RevenueCat | PASO 2 |
| API Key en código | PASO 3 |
| Productos en RevenueCat | PASO 4 |
| Entitlement vinculado | PASO 5 |
| Offering actualizado | PASO 6 |
| Metadata (precios, descripciones) | PASO 7 |
| Billing Grace Period | PASO 8 |
| Secret API Key (backend) | PASO 9 |
| Webhook configurado | PASO 10 |
| Testing en Sandbox | PASO 11 |

---

## PASO 1: Generar In-App Purchase Key en App Store Connect

Esta es la credencial criptográfica que RevenueCat usará para acceder a tu información de productos en App Store Connect.

### Instrucciones

1. **Abre App Store Connect:**
   - Ve a https://appstoreconnect.apple.com/access/integrations/api/subs
   - Esto te lleva directamente a "In-App Purchase API Keys"

2. **Genera una nueva clave:**
   - Haz clic en el botón **"Generate In-App Purchase Key"** (botón azul)

3. **Configura la clave:**
   - **Name:** `RevenueCat` (o tu nombre preferido)
   - **Active:** Deja activado (recomendado)

4. **Descarga el archivo .p8:**
   - Una vez generada, haz clic en el botón de descarga
   - Guarda el archivo de forma segura: `AuthKey_XXXXXXXXXX.p8`
   - ⚠️ **Importante:** Este archivo solo se puede descargar una vez. Si lo pierdes, deberás generar una nueva clave.

5. **Anota dos valores cruciales:**
   - **Key ID:** Se muestra en la página (ej: `ABCD1234KL`)
   - **Issuer ID:** Aparece en la parte superior de la página "API Keys" (ej: `69a6de7e-...`, formato UUID)
   - Guarda estos en un lugar seguro (bloc de notas, gestor de contraseñas, etc.)

### Referencia Visual

```
[App Store Connect] → Integrations & API → In-App Purchase Keys
                     └─ Generate In-App Purchase Key
                        ├─ Name: RevenueCat
                        ├─ Key ID: XXXXXXXXXX (anota)
                        ├─ Issuer ID: UUID (anota)
                        └─ Download .p8 file (guarda)
```

---

## PASO 2: Completar Configuración de App iOS en RevenueCat

RevenueCat necesita conectarse a tu app iOS en App Store Connect usando la clave generada en PASO 1.

### Instrucciones

1. **Ve a RevenueCat dashboard:**
   - URL: https://dashboard.revenuecat.com/
   - Proyecto: "Pepinillo" (d317b1b6)

2. **Accede al formulario de nueva app iOS:**
   - Ya debería tener un formulario iniciado con:
     - Name: `Pepinillo iOS`
     - Bundle ID: `com.pepinillo.app`
   - Si no lo ves, ve a **Settings > Apps** y haz clic en "Add new app" → iOS

3. **Sube la clave .p8:**
   - Busca el campo "In-App Purchase Key" o "Upload Key"
   - Selecciona el archivo `AuthKey_XXXXXXXXXX.p8` descargado en PASO 1
   - El archivo se cargará automáticamente

4. **Ingresa los identificadores:**
   - **Key ID:** Pega el Key ID anotado en PASO 1
   - **Issuer ID:** Pega el Issuer ID (UUID) anotado en PASO 1

5. **Opcional - Apple Small Business Program:**
   - Si tu cuenta está inscrita en el programa de pequeñas empresas:
     - ☑️ Marca "Apple Small Business Program" (comisión 15% en lugar de 30%)
   - Si no, deja desmarcado

6. **Guarda los cambios:**
   - Haz clic en **"Save changes"** (botón azul)
   - RevenueCat validará la conexión con Apple
   - Espera a que se complete (puede tardar 10-30 segundos)

7. **Anota la API Key pública de iOS:**
   - Una vez guardada, aparecerá en la página:
     - **Public API Key (iOS):** `xxxxxxxxxxxxxxxx` (larga cadena)
   - Cópiala y guárdala — la necesitarás en PASO 3

### Qué Hace RevenueCat

Ahora RevenueCat tiene autorización para:
- Leer tus productos de App Store Connect (monthly, annual, lifetime)
- Ver precios y configuración
- Detectar cambios automáticamente

---

## PASO 3: Actualizar API Key en el Código iOS

La app necesita conocer el Public API Key de RevenueCat para enviar requests.

### Instrucciones

1. **Abre tu proyecto Xcode:**
   - Ruta típica: `ios/Domain/Clients/SubscriptionClient.swift`
   - O busca donde inicializas RevenueCat (probablemente en AppFeature)

2. **Busca el placeholder de API Key:**
   ```swift
   let apiKey = "YOUR_REVENUECAT_API_KEY"  // ← busca esto
   ```
   o similar

3. **Reemplaza con la clave de PASO 2:**
   ```swift
   let apiKey = "xxxxxxxxxxxxxxxx"  // ← API Key pública iOS de RevenueCat
   ```

4. **Medida de seguridad (IMPORTANTE):**
   - ⚠️ **NO commits esta clave a git**
   - La clave pública es segura incluir en el código compilado
   - Pero buena práctica: usa `.xcconfig` o variables de entorno en production
   - Por ahora, está bien incluirla en código si es la clave pública

5. **Verifica la configuración de Purchases:**
   ```swift
   Purchases.configure(withAPIKey: apiKey)
   ```
   Debería estar llamado en AppFeature o app delegate

### Alternativa Segura (Recomendado para Production)

Si prefieres no tener la clave en código:

1. Crea un archivo `.xcconfig` en `ios/`:
   ```
   // Pepinillo.xcconfig
   REVENUECAT_API_KEY = xxxxxxxxxxxxxxxx
   ```

2. En Xcode: Build Settings → Set this .xcconfig
3. En código:
   ```swift
   let apiKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String
   ```

Por ahora, la opción simple (reemplazar directamente) está bien para development.

---

## PASO 4: Registrar Productos iOS en RevenueCat

RevenueCat necesita conocer los 3 productos iOS. Actualmente están en App Store Connect, pero no están registrados en RevenueCat.

### Instrucciones

1. **Ve a RevenueCat Product Catalog:**
   - Dashboard → **Products** (o Product Catalog)

2. **Haz clic en "Add new product" (o "+"):**

3. **Crea el primer producto (Monthly):**
   - **Platform:** App Store (iOS)
   - **Product ID:** `com.pepinillo.app.pro.monthly`
   - **Type:** Subscription
   - Haz clic en "Save" o "Create"

4. **Crea el segundo producto (Annual):**
   - **Platform:** App Store (iOS)
   - **Product ID:** `com.pepinillo.app.pro.annual`
   - **Type:** Subscription
   - Haz clic en "Save"

5. **Crea el tercero (Lifetime):**
   - **Platform:** App Store (iOS)
   - **Product ID:** `com.pepinillo.app.pro.lifetime`
   - **Type:** Non-Consumable (o Non-Subscription)
   - Haz clic en "Save"

### Resultado Esperado

En Product Catalog > Products deberías ver:

```
✅ com.pepinillo.app.pro.monthly (App Store)
✅ com.pepinillo.app.pro.annual (App Store)
✅ com.pepinillo.app.pro.lifetime (App Store)
```

Más abajo también deberías ver los 2 productos Android antiguos (de Flutter):
```
✅ month_premium:month (Google Play)
✅ year_premium:year (Google Play)
```

---

## PASO 5: Vincular Productos al Entitlement "premium"

Los entitlements son características lógicas (ej: "premium"). Los productos son SKUs físicas. Necesitamos vincularlos.

### Instrucciones

1. **Ve a RevenueCat Entitlements:**
   - Dashboard → **Entitlements** (o Product Catalog > Entitlements)

2. **Abre el entitlement "premium":**
   - Debería existir (creado previamente)
   - Haz clic para editarlo

3. **Vincula los productos iOS:**
   - Busca la sección "Products" o "Link Products"
   - Selecciona / agrega:
     - ☑️ `com.pepinillo.app.pro.monthly`
     - ☑️ `com.pepinillo.app.pro.annual`
     - ☑️ `com.pepinillo.app.pro.lifetime`
   - Deja los productos Android existentes (no los quites)

4. **Guarda:**
   - Haz clic en "Save" o "Update"

### Resultado Esperado

El entitlement "premium" ahora vincula:

```
Entitlement: premium
├─ com.pepinillo.app.pro.monthly (App Store)
├─ com.pepinillo.app.pro.annual (App Store)
├─ com.pepinillo.app.pro.lifetime (App Store)
├─ month_premium:month (Google Play) [antiguo]
└─ year_premium:year (Google Play) [antiguo]
```

Cuando un usuario compre cualquiera de estos productos, obtendrá el entitlement "premium".

---

## PASO 6: Actualizar el Offering "default"

Los Offerings son colecciones de productos mostrados juntos. El offering "default" es el principal.

### Instrucciones

1. **Ve a RevenueCat Offerings:**
   - Dashboard → **Offerings** (o Product Catalog > Offerings)

2. **Abre "default":**
   - Debería existir (creado previamente)
   - Verás 2 packages antiguas: `$rc_monthly` y `$rc_annual`

3. **Actualiza $rc_monthly:**
   - Haz clic en editar ($rc_monthly)
   - Busca "Products" o "Platforms"
   - **Añade** (no reemplaces):
     - ☑️ `com.pepinillo.app.pro.monthly` (App Store - nuevo)
   - Deja el producto Android antiguo si está
   - Guarda

4. **Actualiza $rc_annual:**
   - Haz clic en editar ($rc_annual)
   - Busca "Products"
   - **Añade** (no reemplaces):
     - ☑️ `com.pepinillo.app.pro.annual` (App Store - nuevo)
   - Deja el producto Android antiguo
   - Guarda

5. **Crea una nueva package para lifetime (si no existe):**
   - Haz clic en "Add new package"
   - **ID:** `$rc_lifetime`
   - **Type:** One-time purchase (o Non-subscription)
   - **Platforms:**
     - ☑️ `com.pepinillo.app.pro.lifetime` (App Store)
   - Guarda

### Resultado Esperado

Offering "default" ahora contiene:

```
$rc_monthly
├─ com.pepinillo.app.pro.monthly (App Store) ← nuevo
└─ month_premium:month (Google Play)

$rc_annual
├─ com.pepinillo.app.pro.annual (App Store) ← nuevo
└─ year_premium:year (Google Play)

$rc_lifetime (nuevo)
└─ com.pepinillo.app.pro.lifetime (App Store)
```

---

## PASO 7: Completar Metadata en App Store Connect

Ahora los productos existen en RevenueCat, pero App Store Connect necesita precios, descripciones e imágenes de review.

### 7A. Suscripción Monthly

1. **Ve a App Store Connect:**
   - Selecciona app "Pepinillo — Timer de Enfoque"
   - **In-App Purchases > Subscriptions > Pepinillo Pro > Pro Monthly**

2. **Configura precios:**
   - Haz clic en "Pricing"
   - **USD:** $3.99 / mes
   - **México (MXN):** $79 / mes (ajusta según tu estrategia LATAM)
   - **Argentina (ARS):** $799 / mes
   - **Otros países:** Usa la opción "Automatic" si prefieres
   - Guarda

3. **Añade localización (Español):**
   - Haz clic en "Localization"
   - Selecciona "Español" (o agrégalo si no está)
   - **Display Name:** `Pepinillo Pro Mensual`
   - **Description:** `Acceso ilimitado a todas las características premium de Pepinillo. Renovación automática cada mes.`
   - Guarda

4. **Añade localización (Inglés, si no está):**
   - **Display Name:** `Pepinillo Pro Monthly`
   - **Description:** `Unlimited access to all Pepinillo premium features. Auto-renews monthly.`
   - Guarda

5. **Añade localización (Portugués Brasileño, opcional):**
   - **Display Name:** `Pepinillo Pro Mensal`
   - **Description:** `Acesso ilimitado a todos os recursos premium do Pepinillo. Renovação automática mensalmente.`
   - Guarda

6. **Screenshot de Review:**
   - Haz clic en "Review Information"
   - Sube una captura de pantalla mostrando:
     - Pantalla del paywall o confirmación de compra
     - O interfaz de la app con features premium habilitados
   - 1080×1920 px (portrait, iPhone)
   - Formato: JPG o PNG

7. **Estado:**
   - Asegúrate de que el estado es "Ready to Submit" o "Approved"
   - No debe tener advertencias en rojo

### 7B. Suscripción Annual

Repite los pasos de 7A para **Pro Annual**, pero con:

- **USD:** $24.99 / año
- **México (MXN):** $450 / año (aproximadamente)
- **Argentina (ARS):** $4500 / año
- **Display Name:** `Pepinillo Pro Anual` / `Pepinillo Pro Annual`
- **Description:** `Acceso ilimitado durante un año. Renovación automática anualmente.` / `Unlimited access for one year. Auto-renews annually.`

### 7C. In-App Purchase Lifetime

1. **Ve a App Store Connect:**
   - **In-App Purchases > Non-Consumable > Pro Lifetime**

2. **Configura precios:**
   - **USD:** $49.99 (compra única)
   - **México (MXN):** $999 (único)
   - **Argentina (ARS):** $9999 (único)
   - Guarda

3. **Localización (Español):**
   - **Display Name:** `Pepinillo Pro de por Vida`
   - **Description:** `Acceso de por vida a todas las características premium de Pepinillo. Compra única, sin renovaciones.`
   - Guarda

4. **Localización (Inglés):**
   - **Display Name:** `Pepinillo Pro Lifetime`
   - **Description:** `Lifetime access to all Pepinillo premium features. One-time purchase, no renewals.`
   - Guarda

5. **Screenshot:**
   - Sube captura de pantalla similar a las suscripciones
   - Mismo formato: 1080×1920 px, JPG/PNG

### Sugerencias de Precios

Si necesitas ajustar los precios, considera:

| Región | Monthly | Annual | Lifetime |
|--------|---------|--------|----------|
| **USA** | $3.99 | $24.99 | $49.99 |
| **México** | $79 MXN | $450 MXN | $999 MXN |
| **Argentina** | $799 ARS | $4500 ARS | $9999 ARS |
| **España** | €3,99 | €24,99 | €49,99 |
| **Colombia** | $16.900 COP | $99.900 COP | $199.900 COP |

App Store Connect tiene opciones de "Automatic" pricing que ajusta por país automáticamente.

---

## PASO 8: Activar Billing Grace Period

El Billing Grace Period permite que los usuarios tengan acceso durante X días si su pago falla.

### Instrucciones

1. **Ve a App Store Connect:**
   - Selecciona app "Pepinillo"
   - **General > Billing Settings** (o busca "Subscription Settings")

2. **Busca "Billing Grace Period":**
   - Si no está configurado, verás un botón "Set Up Billing Grace Period"
   - Haz clic en él

3. **Activa el período:**
   - ☑️ Enable Billing Grace Period

4. **Configura duración (recomendado):**
   - **Para Monthly:** 6 días (da tiempo pero no demasiado)
   - **Para Annual:** 16 días (más generoso para compras anuales)
   - O usa el mismo valor para ambas (ej: 7 días)

5. **Guarda:**
   - Haz clic en "Save" o "Done"

### Ventajas

- Los usuarios reciben notificación de pago fallido
- Mantienen acceso mientras solucionan el pago
- Reduce churning (cancelaciones)
- Apple incrementa el retry automático después del período

---

## PASO 9: Crear Secret API Key en RevenueCat (para Backend)

Tu backend Go necesita una clave privada para validar entitlements y recibir webhooks sin confiar solo en los datos del cliente.

### Credenciales de RevenueCat

**iOS Public API Key (ya configurada):**
```
appl_xnChlVXXtUFhusIfJyNrNDcMGLj
```

**Secret API Key (V2) para Backend:**
```
sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ
Label: "Pepinillo Backend"
```

### Instrucciones

1. **Ve a RevenueCat API Keys:**
   - Dashboard → **Settings > API Keys** (o Settings > Developer)
   - Busca sección "Secret API Keys" o "Server Tokens"

2. **Crea una nueva Secret Key (si aún no existe):**
   - Haz clic en "New secret API key" o "Create new key"

3. **Configura:**
   - **Label:** `Backend Server` (o Backend Go)
   - **Description:** `Production server for Pepinillo, validates entitlements and receives webhooks`
   - Deja las opciones por defecto

4. **Copia la clave:**
   - Una vez creada, aparecerá una larga cadena
   - ⚠️ **Cópiala inmediatamente** — solo se muestra una vez
   - Guárdala en un gestor de secretos o .env

5. **Añade a tu backend:**
   - En tu servidor Go, configura la variable de entorno `REVENUECAT_SECRET_KEY`:
     ```bash
     export REVENUECAT_SECRET_KEY="sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ"
     ```
   - O en tu archivo `.env`:
     ```
     REVENUECAT_SECRET_KEY=sk_namFzNibPWRnKGIOqmwHfPVQrbfyZ
     ```
   - En el código Go, se carga vía `config.Load()` en `backend/internal/config/config.go`

### Cómo Usar en Backend

En tu código Go (`billing_service.go` o similar):

```go
// La clave se carga en config.go:
// RevenueCatSecretKey string (cargada de env REVENUECAT_SECRET_KEY)

// Para validar que un usuario tiene el entitlement "premium"
func CheckEntitlement(userID string, cfg *config.Config) error {
    // Llamada a RevenueCat API con cfg.RevenueCatSecretKey
    // https://docs.revenuecat.com/docs/getting-started
}
```

---

## PASO 10: Configurar Webhook en RevenueCat

RevenueCat enviará eventos (compra, renovación, cancelación) a tu backend para actualizar la base de datos.

### Endpoint del Webhook (ya implementado)

**URL del endpoint en el backend:**
```
POST /api/v1/webhooks/revenuecat
```

**Webhook URL completa (pending deployment):**
```
https://{YOUR_DOMAIN}/api/v1/webhooks/revenuecat
```

### 10A. Generar Webhook Secret (Opcional pero Recomendado)

1. **En tu backend:**
   - Genera un token secreto aleatorio (ej: UUID v4, 32+ caracteres)
   - Guárdalo como `REVENUECAT_WEBHOOK_AUTH_TOKEN`
   ```bash
   REVENUECAT_WEBHOOK_AUTH_TOKEN="sk_webhook_xxxxxxxxxxxxxxxxxxxxxxxx"
   ```

2. **En tu código, valida el header:**
   ```go
   // Valida el header X-RevenueCat-Signature (si RevenueCat lo envía)
   // O personaliza según tu implementación de autorización
   signature := r.Header.Get("X-RevenueCat-Signature")
   expectedSig := hmac(WEBHOOK_AUTH_TOKEN, payload)
   if signature != expectedSig {
       http.Error(w, "Unauthorized", http.StatusUnauthorized)
       return
   }
   ```
   - Nota: La variable se carga en `config.go` como `RevenueCatWebhookAuthToken`

### 10B. Configurar Webhook en RevenueCat

1. **Ve a RevenueCat Integrations:**
   - Dashboard → **Integrations** (o Integrations > Webhooks)

2. **Añade nuevo Webhook:**
   - Haz clic en "Add webhook" o "New integration"
   - Selecciona "Webhook" o "Custom integration"

3. **Configura URL y headers:**
   - **Webhook URL:** `https://{YOUR_DOMAIN}/api/v1/webhooks/revenuecat`
     - ⚠️ Reemplaza `{YOUR_DOMAIN}` con tu dominio real (ej: `api.pepinillo.app`)
     - Debe ser HTTPS (no HTTP)
     - Ejemplo: `https://api.pepinillo.app/api/v1/webhooks/revenuecat`

4. **Opcionales - Headers de autorización:**
   - **Header name:** `Authorization`
   - **Header value:** `Bearer YOUR_WEBHOOK_SECRET`
   - O personaliza según tu implementación

5. **Selecciona eventos:**
   - ☑️ **INITIAL_PURCHASE** (primer pago)
   - ☑️ **RENEWAL** (renovación de suscripción)
   - ☑️ **CANCELLATION** (cancelación)
   - ☑️ **EXPIRATION** (expiración de suscripción)
   - ☑️ **BILLING_ISSUE_DETECTED** (problema de pago)
   - ☑️ **SUBSCRIBER_ALIAS** (vinculación de cuentas)
   - ☑️ **PRODUCT_CHANGE** (cambio de plan)

6. **Guarda:**
   - Haz clic en "Save" o "Create webhook"

### 10C. Estructura del Webhook en tu Backend

Tu endpoint debe procesar JSON como este:

```json
{
  "event": {
    "type": "INITIAL_PURCHASE",
    "timestamp": "2026-03-21T14:30:00Z"
  },
  "data": {
    "subscriber": {
      "subscriber_id": "rc_subscriber_123",
      "original_app_user_id": "user_123_or_email",
      "entitlements": {
        "premium": {
          "expires_date": "2026-04-21T14:30:00Z"
        }
      }
    }
  }
}
```

Pseudocódigo Go:

```go
func HandleRevenueCatWebhook(w http.ResponseWriter, r *http.Request) {
    // 1. Valida firma (si implementaste)
    // 2. Parsea JSON
    // 3. Actualiza DB del usuario (set entitlement "premium", expires_date)
    // 4. Retorna HTTP 200 para confirmar
}
```

---

## PASO 11: Testing en Sandbox

Antes de lanzar a production, prueba todo en Apple's Sandbox testing environment.

### 11A. Crear Sandbox Tester en App Store Connect

1. **Ve a Usuarios y Acceso:**
   - App Store Connect → **Users and Access > Sandbox > Sandbox Testers**
   - (O: Settings > Testers > Sandbox)

2. **Haz clic en "+" para crear nuevo tester:**
   - **First Name:** `Test`
   - **Last Name:** `User`
   - **Email:** `test+sandbox-pepinillo@example.com` (use a real email you control)
   - **Password:** Genera una contraseña fuerte (mínimo 8 caracteres, mayúscula, número)
   - **Date of Birth:** Cualquier fecha válida (ej: 01/01/1990)
   - Haz clic en "Save"

3. **Anota las credenciales:**
   ```
   Email: test+sandbox-pepinillo@example.com
   Password: [tu contraseña segura]
   ```

### 11B. Configurar Device para Testing

En el **dispositivo de prueba** (iPhone físico o simulador):

1. **Cierra la sesión de tu cuenta personal:**
   - Settings → [Tu nombre] → Sign Out

2. **Inicia sesión con la cuenta de Sandbox:**
   - Settings → [Tu nombre]
   - Sign in with Apple ID
   - Email: `test+sandbox-pepinillo@example.com`
   - Password: [la contraseña de sandbox]

3. **Habilita "Sandbox Data" en RevenueCat:**
   - En tu app iOS, busca un toggle o setting para "Sandbox mode"
   - O en RevenueCat dashboard, ve a Settings > Testing y copia el Sandbox API key
   - Úsala en lugar de la clave de production para testing

### 11C. Prueba la Compra

1. **Abre tu app en el dispositivo:**
   - Debería estar compilada con el API key de RevenueCat

2. **Navega al paywall:**
   - Haz clic en "Upgrade", "Pro", o donde sea el paywall

3. **Selecciona un producto (ej: Monthly):**
   - Haz clic en "Subscribe"

4. **Confirma la compra:**
   - App Store te pedirá confirmar con Face ID / Touch ID / Contraseña
   - Usa las credenciales del Sandbox tester
   - ⚠️ **No se cobrará dinero real** — es simulado en Sandbox

5. **Espera confirmación:**
   - Tu app debería recibir la confirmación de RevenueCat
   - El entitlement "premium" debería activarse
   - Verifica en la UI que el acceso premium está habilitado

### 11D. Prueba Restaurar Compras

1. **En el paywall o settings, busca "Restore Purchases":**
   - Haz clic en "Restore"
   - RevenueCat debería recuperar tu compra anterior

2. **Verifica:**
   - El entitlement "premium" sigue activo
   - Sin necesidad de pagar de nuevo

### 11E. Verifica el Webhook (si tienes servidor)

1. **En tu backend, log de webhooks:**
   ```go
   log.Printf("Received webhook event: %+v", event)
   ```

2. **Realiza una compra de Sandbox:**
   - Deberías ver el evento `INITIAL_PURCHASE` en los logs
   - Verifica que la base de datos se actualiza con `entitlement: premium`

3. **Monitorea en RevenueCat:**
   - Dashboard → Subscribers → Busca tu Sandbox tester ID
   - Deberías ver eventos y entitlements activos

### 11F. Prueba Cancelación

1. **En App Store Settings:**
   - Settings → [Sandbox User] → Subscriptions → Pepinillo Pro Monthly
   - Haz clic en "Cancel subscription"

2. **Verifica:**
   - En RevenueCat, recibirás evento `CANCELLATION`
   - Tu backend debería actualizar la base de datos (set entitlement "premium" expired)
   - En la app, el acceso premium se desactiva

### Checklist de Testing

- [ ] Sandbox tester creado y credenciales anotadas
- [ ] App compila sin errores
- [ ] API key de RevenueCat está en código (o .xcconfig)
- [ ] Paywall se muestra correctamente
- [ ] Compra de Monthly funciona (sin cobro real)
- [ ] Compra de Annual funciona (sin cobro real)
- [ ] Compra de Lifetime funciona (sin cobro real)
- [ ] Entitlement "premium" se activa después de compra
- [ ] Restore Purchases funciona
- [ ] Cancelación se refleja en la app
- [ ] Webhook llega al backend (verificar logs)
- [ ] Base de datos se actualiza con entitlements

---

## VERIFICACIÓN FINAL

Antes de lanzar a App Store (TestFlight → Production), verifica este checklist:

### App Store Connect

- [ ] Producto Monthly: metadata (nombre, descripción, precio) completo
- [ ] Producto Annual: metadata completo
- [ ] Producto Lifetime: metadata completo
- [ ] Billing Grace Period habilitado (6-16 días)
- [ ] Build 1.0.0 (build 2) subido y en estado "Ready to Submit"
- [ ] Screenshots de review añadidos para cada IAP
- [ ] No hay advertencias rojas en la página del producto

### RevenueCat Dashboard

- [ ] Proyecto "Pepinillo" (d317b1b6) visible
- [ ] App iOS "Pepinillo iOS" (com.pepinillo.app) creada
- [ ] Productos iOS registrados:
  - [ ] com.pepinillo.app.pro.monthly
  - [ ] com.pepinillo.app.pro.annual
  - [ ] com.pepinillo.app.pro.lifetime
- [ ] Entitlement "premium" vinculado a los 3 productos iOS
- [ ] Offering "default" actualizado con packages $rc_monthly, $rc_annual, $rc_lifetime
- [ ] Public API key iOS configurada en app settings
- [ ] Secret API key creada para backend
- [ ] Webhook configurado y apuntando a tu servidor

### Código iOS

- [ ] SubscriptionClient.swift usa Public API key correcto
- [ ] AppFeature inicializa Purchases.configure(...) al lanzar
- [ ] PaywallView muestra los 3 productos correctamente
- [ ] Entitlement check usa identifier "premium"
- [ ] No hay tokens hardcodeados en git (usar .xcconfig si es necesario)

### Backend Go

- [ ] Endpoint POST /api/v1/webhooks/revenuecat implementado
- [ ] Valida firma de webhook (si configuraste)
- [ ] Parsea JSON y actualiza base de datos
- [ ] Retorna HTTP 200 en éxito
- [ ] Secret API key guardado en variable de entorno
- [ ] Logs disponibles para debugging

### Testing

- [ ] Compra de Sandbox funciona (Monthly, Annual, Lifetime)
- [ ] Entitlements se activan en la app
- [ ] Cancelación actualiza entitlements
- [ ] Restore Purchases funciona
- [ ] Webhook recibido en backend (verificar logs)
- [ ] Base de datos muestra entitlements activos para usuario

### Documentación y Secretos

- [ ] Key ID (.p8), Issuer ID guardados de forma segura
- [ ] REVENUECAT_SECRET_KEY configurado en servidor
- [ ] REVENUECAT_WEBHOOK_SECRET configurado (si aplica)
- [ ] Sandbox tester credentials almacenadas de forma segura
- [ ] No hay secretos en git (revisar .gitignore)

---

## Próximos Pasos (Post-Setup)

Una vez que este setup esté completo y probado en Sandbox:

1. **Envía la app a TestFlight:**
   - En App Store Connect, haz clic en "Submit for Review"
   - Asegúrate de que todos los IAPs están aprobados

2. **Prueba en TestFlight:**
   - Invita Sandbox testers a TestFlight build
   - Verifica compras nuevamente en ambiente Sandbox

3. **Monitorea en Production (después del lanzamiento):**
   - RevenueCat Dashboard → Subscribers
   - Verifica que los eventos se registran
   - Observa métricas de conversion, retention, etc.

4. **Soporta múltiples plataformas:**
   - Cuando hagas parity en Android/Wear OS/watchOS, sigue el mismo proceso
   - Crea apps Android/Wear OS en RevenueCat
   - Vincula productos a los mismos entitlements

---

## Contacto y Soporte

- **RevenueCat Docs:** https://docs.revenuecat.com/docs/getting-started
- **App Store Connect Help:** https://support.apple.com/app-store-connect
- **RevenueCat Support:** support@revenuecat.com

---

## Notas Importantes

### Seguridad

- ⚠️ **Nunca commits secret keys a git**
- ⚠️ **Guarda el archivo .p8 en lugar seguro** (descargable solo una vez)
- ⚠️ **Usa variables de entorno o .xcconfig para production**

### Testing

- Siempre prueba en Sandbox antes de production
- Las compras de Sandbox nunca cobran dinero
- Usa cuentas de Sandbox testers separadas

### Monitoreo

- RevenueCat dashboard muestra:
  - Eventos en tiempo real (compras, renovaciones, cancelaciones)
  - Métricas de MRR, churn, LTV
  - Validación de entitlements
- Revisa logs de webhook regularmente para detectar errores

---

**Última actualización:** Marzo 2026
**Escrito por:** Pepinillo Development Team
