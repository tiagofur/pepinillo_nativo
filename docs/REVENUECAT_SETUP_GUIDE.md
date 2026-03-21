# Guía de Configuración de RevenueCat para Pepinillo

Guía paso a paso para configurar App Store Connect y el dashboard de RevenueCat para monetizar la app Pepinillo (timer de enfoque profundo).

**Última actualización:** Marzo 2026
**Plataforma:** iOS
**Desarrollador:** Tiago

---

## Parte 1: Configuración en Apple Developer / App Store Connect

### 1.1 Crear App ID (si no existe)

1. Ve a **Apple Developer** → **Certificates, Identifiers & Profiles**
2. Selecciona **Identifiers** → haz clic en **+** para crear uno nuevo
3. Elige **App IDs** y continúa
4. Selecciona **App**
5. Completa los campos:
   - **Bundle ID:** `com.pepinillo.app`
   - **Description:** Pepinillo Focus Timer
6. En la sección **Capabilities**, habilita:
   - **In-App Purchase**
   - **App Groups** (opcional, si usas compartición de datos)
7. Haz clic en **Continue** y **Register**

### 1.2 Crear Productos de Suscripción en App Store Connect

#### Paso 1: Crear el Grupo de Suscripción

1. Ve a **App Store Connect** → Accede con tu cuenta de Apple Developer
2. Selecciona la app **Pepinillo**
3. Ve a **Monetización** → **Suscripciones**
4. Haz clic en **+** para crear un nuevo grupo
5. Nombre del grupo: **Pepinillo Pro**
6. Haz clic en **Create**

#### Paso 2: Crear los Productos

Crea estos 3 productos dentro del grupo "Pepinillo Pro":

##### Producto 1: Suscripción Mensual

- **Nombre del Producto:** Pepinillo Pro Monthly
- **ID del Producto:** `com.pepinillo.app.pro.monthly`
- **Tipo:** Auto-renovable
- **Duración de la suscripción:** 1 mes
- **Precio (Estados Unidos):** $3.99 USD/mes
- **Precio (LATAM):** $1.99 USD/mes
- **Período de prueba:** Opcional (7 días recomendado)

##### Producto 2: Suscripción Anual

- **Nombre del Producto:** Pepinillo Pro Annual
- **ID del Producto:** `com.pepinillo.app.pro.annual`
- **Tipo:** Auto-renovable
- **Duración de la suscripción:** 1 año
- **Precio (Estados Unidos):** $24.99 USD/año
- **Precio (LATAM):** $12.99 USD/año
- **Período de prueba:** Opcional (7 días recomendado)

##### Producto 3: Acceso de Por Vida

- **Nombre del Producto:** Pepinillo Pro Lifetime
- **ID del Producto:** `com.pepinillo.app.pro.lifetime`
- **Tipo:** No-consumible
- **Precio (Estados Unidos):** $49.99 USD
- **Precio (LATAM):** $29.99 USD

#### Paso 3: Agregar Localizaciones

Para cada producto:

1. Haz clic en **Localización**
2. Haz clic en **+** para agregar idiomas
3. Agrega:
   - **English (US)**
   - **Spanish (Spain)** (`es`)
   - **Portuguese (Brazil)** (`pt-BR`)

Ejemplo de textos localizados:

**Inglés:**
- Título: "Pepinillo Pro Monthly"
- Descripción: "Unlock unlimited focus sessions, advanced analytics, and premium themes."

**Español:**
- Título: "Pepinillo Pro Mensual"
- Descripción: "Desbloquea sesiones de enfoque ilimitadas, análisis avanzados y temas premium."

**Portugués:**
- Título: "Pepinillo Pro Mensal"
- Descripción: "Desbloqueie sessões de foco ilimitadas, análises avançadas e temas premium."

### 1.3 Crear Clave API de App Store Connect (para RevenueCat)

Esta clave permite que RevenueCat acceda a los datos de tus transacciones.

1. En **App Store Connect**, ve a **Usuarios y Acceso** → **Integraciones**
2. Haz clic en **+** junto a "App Store Connect API"
3. Dale un nombre: `RevenueCat API Key`
4. Selecciona el rol: **Admin** o **App Manager**
5. Haz clic en **Generate**
6. Se descargará automáticamente un archivo `.p8`
   - **Guarda este archivo en un lugar seguro**
   - Necesitarás:
     - El contenido del archivo `.p8`
     - El **Key ID** (visible en App Store Connect)
     - El **Issuer ID** (visible en App Store Connect)

### 1.4 Crear Shared Secret (Secreto Compartido)

Este secreto se utiliza como respaldo para validación de recibos heredada.

1. En **App Store Connect**, ve a **Pepinillo** → **Información de la App**
2. Desplázate hasta **App-Specific Shared Secret**
3. Haz clic en **Generate** (si no existe)
4. Copia y guarda el secreto compartido generado

---

## Parte 2: Configuración del Dashboard de RevenueCat

### 2.1 Crear Cuenta en RevenueCat

1. Ve a https://app.revenuecat.com
2. Haz clic en **Sign Up**
3. Crea tu cuenta (usa tu email de desarrollador)
4. Completa la verificación por email

### 2.2 Crear Nuevo Proyecto

1. Una vez autenticado, haz clic en **Create a new project**
2. Nombre del proyecto: **Pepinillo**
3. Selecciona el país: **España** (o tu país principal)
4. Haz clic en **Create**

### 2.3 Agregar la App de iOS

1. En el dashboard de RevenueCat, ve a **Apps** en la barra lateral
2. Haz clic en **Add new app**
3. Completa el formulario:
   - **App Name:** Pepinillo
   - **Platform:** iOS
   - **Bundle ID:** `com.pepinillo.app`
   - **Currency:** USD (para precios de App Store Connect)

### 2.4 Configurar App Store Connect como Proveedor

1. En la página de la app en RevenueCat, ve a **Configuration** → **App Store Connect**
2. Sube el archivo `.p8` que descargaste en el Paso 1.3
3. Ingresa el **Key ID** de App Store Connect
4. Ingresa el **Issuer ID** de App Store Connect
5. Ingresa el **Shared Secret** del Paso 1.4
6. Haz clic en **Connect**
7. RevenueCat validará la conexión automáticamente

### 2.5 Configurar Productos en RevenueCat

RevenueCat sincroniza automáticamente los productos de App Store Connect, pero debes crear la estructura de ofertas:

#### Paso 1: Sincronizar Productos (Automático)

1. Ve a **Products** en el dashboard de RevenueCat
2. Los 3 productos deben aparecer aquí (sincronizados desde App Store Connect):
   - `com.pepinillo.app.pro.monthly`
   - `com.pepinillo.app.pro.annual`
   - `com.pepinillo.app.pro.lifetime`

#### Paso 2: Crear Offerings y Packages

1. Ve a **Offerings** en el dashboard
2. Haz clic en **Create new offering**
3. Nombre: **default**
4. Descripción: Base offering for Pepinillo Pro
5. Haz clic en **Create**

Ahora agrega los packages:

**Package 1: Monthly**
- Identifier: `$rc_monthly`
- Nombre mostrado: Monthly
- Producto: `com.pepinillo.app.pro.monthly`

**Package 2: Annual**
- Identifier: `$rc_annual`
- Nombre mostrado: Annual
- Producto: `com.pepinillo.app.pro.annual`

**Package 3: Lifetime**
- Identifier: `$rc_lifetime`
- Nombre mostrado: Lifetime
- Producto: `com.pepinillo.app.pro.lifetime`

Guarda la offering.

### 2.6 Crear Entitlements (Derechos)

Los entitlements son características que se desbloquean cuando el usuario compra.

1. Ve a **Entitlements** en el dashboard
2. Haz clic en **Create new entitlement**
3. Nombre: **pro**
4. Descripción: Pepinillo Pro subscription
5. Haz clic en **Create**

Ahora vincula los productos:

1. En la página de **Entitlements**, selecciona el entitlement **pro**
2. Haz clic en **Add products**
3. Selecciona los 3 productos:
   - `com.pepinillo.app.pro.monthly`
   - `com.pepinillo.app.pro.annual`
   - `com.pepinillo.app.pro.lifetime`
4. Haz clic en **Add**

### 2.7 Obtener Claves API de RevenueCat

Necesitarás dos claves:

**1. Public API Key (para la app iOS)**

1. Ve a **Settings** → **API Keys**
2. Busca la sección **Public API Keys**
3. Copia el key para tu app
4. Este valor reemplazará `"YOUR_REVENUECAT_API_KEY"` en tu código iOS

**2. Secret API Key (para el backend)**

1. En la misma página **Settings** → **API Keys**
2. Busca la sección **Secret API Keys**
3. Copia el key
4. Guárdalo en tu variable de entorno `REVENUECAT_API_KEY`

### 2.8 Configurar Webhooks

Los webhooks permiten que RevenueCat notifique a tu backend sobre eventos de compra.

1. Ve a **Settings** → **Webhooks**
2. Haz clic en **Add new webhook**
3. Completa los campos:

**Configuración del Webhook:**

```
URL: https://tu-dominio-backend.com/api/v1/webhooks/revenuecat
Método HTTP: POST
```

**Headers de Autenticación:**

RevenueCat enviará un header `Authorization` en cada webhook. Configura un token:

1. En la página de webhooks, haz clic en **Add authorization header**
2. Selecciona el tipo: **Bearer token**
3. Genera un token seguro (una cadena aleatoria larga)
4. Copia el valor del token y guárdalo en tu env var: `REVENUECAT_WEBHOOK_AUTH_TOKEN`

**Eventos a Habilitar:**

Habilita estos eventos para sincronizar el estado de suscripciones:

- `INITIAL_PURCHASE` — Se dispara cuando un usuario compra por primera vez
- `RENEWAL` — Se dispara cuando se renueva una suscripción
- `CANCELLATION` — Se dispara cuando se cancela una suscripción
- `EXPIRATION` — Se dispara cuando una suscripción expira
- `BILLING_ISSUE` — Se dispara cuando hay problemas con el pago
- `PRODUCT_CHANGE` — Se dispara cuando el usuario cambia de producto
- `NON_RENEWING_PURCHASE` — Se dispara en compras no renovables

4. Haz clic en **Create** para guardar el webhook

**Prueba del Webhook:**

RevenueCat proporciona un botón **Send Test Event**. Usa esto para verificar que tu backend reciba los webhooks correctamente.

---

## Parte 3: Variables de Entorno del Backend

Configura estas variables en tu backend (`.env` o en tu plataforma de hosting):

```bash
# RevenueCat API Configuration
REVENUECAT_API_KEY=sk_prod_abc123xyz789...
REVENUECAT_API_BASE_URL=https://api.revenuecat.com/v1
REVENUECAT_WEBHOOK_AUTH_TOKEN=Bearer secure_token_here_abc123xyz789...
```

**Notas:**

- `REVENUECAT_API_KEY`: Tu clave secreta de API (no expongas esto)
- `REVENUECAT_WEBHOOK_AUTH_TOKEN`: El token que configuraste en el webhook
- `REVENUECAT_API_BASE_URL`: Siempre `https://api.revenuecat.com/v1` para producción

---

## Parte 4: Configuración del Código iOS

### 4.1 Reemplazar la Clave API en el Código

En tu proyecto iOS, busca el archivo donde está definida la clave de RevenueCat:

**Archivo:** `Pepinillo/Networking/SubscriptionClient.swift` (o donde tengas tu cliente)

Busca esta línea:

```swift
private let apiKey = "YOUR_REVENUECAT_API_KEY"
```

Reemplázala con tu Public API Key de RevenueCat:

```swift
private let apiKey = "pk_prod_abc123xyz789..."
```

**Importante:**

- Esta es tu **Public API Key**, no la secreta
- La encuentras en RevenueCat dashboard → Settings → API Keys → Public API Keys
- Nunca expongas tu Secret API Key en el código del cliente

### 4.2 Verificar Configuración de RevenueCat en el Código

Busca donde se inicializa RevenueCat (probablemente en `AppDelegate.swift` o `Pepinillo.swift`):

```swift
import RevenueCat

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    RCConfiguration.Builder(withAPIKey: "YOUR_REVENUECAT_API_KEY")
        .with(usesStoreKit2IfAvailable: true)
        .build()

    return true
}
```

Asegúrate de que:

1. Se usa `RCConfiguration` correctamente
2. Se habilita StoreKit 2 para iOS 16+
3. El API key se reemplaza correctamente

### 4.3 Acceder a Entitlements desde la App

Para verificar si el usuario tiene acceso al tier "pro":

```swift
import RevenueCat

// Obtener el estado de compra del usuario
Purchases.shared.getCustomerInfo { (customerInfo, error) in
    if let error = error {
        print("Error fetching customer info: \(error)")
        return
    }

    // Verificar si el usuario tiene el entitlement "pro"
    if customerInfo?.entitlements["pro"]?.isActive == true {
        print("Usuario es Pro")
        // Desbloquear características premium
    } else {
        print("Usuario es gratis")
        // Mostrar paywall
    }
}
```

---

## Parte 5: Checklist de Pruebas

Antes de publicar la app, verifica que todo funcione en **sandbox mode**:

### 5.1 Configurar Pruebas en Sandbox

#### En Xcode

1. Ve a **Product** → **Scheme** → **Edit Scheme**
2. Selecciona **Run**
3. En **Pre-actions**, asegúrate de que el scheme usa el bundle ID correcto: `com.pepinillo.app`

#### Crear TestFlight Tester (Tester de Sandbox)

1. Ve a **App Store Connect** → **Pepinillo** → **TestFlight**
2. Crea un grupo de prueba interno
3. Agrega tu email como tester
4. Descarga la app desde TestFlight en un dispositivo de prueba

### 5.2 Usar Cuentas de Sandbox en App Store Connect

1. Ve a **App Store Connect** → **Usuarios y Acceso** → **Sandbox**
2. Crea una cuenta de prueba:
   - Email: `test+pepinillo@tu-email.com`
   - Contraseña: segura y generada
   - Edad: Mayores de 18 años
3. Guarda las credenciales

En tu dispositivo iOS:

1. Ve a **Settings** → **App Store**
2. Haz scroll hasta el final
3. Haz tap en **Sandbox Account**
4. Inicia sesión con la cuenta de prueba
5. Cuando hagas una compra de prueba, aparecerá un dialog indicando que es sandbox

### 5.3 Probar Flujo de Compra End-to-End

1. Abre la app Pepinillo en el dispositivo
2. Ve al paywall (interfaz de compra)
3. Intenta comprar el plan **Pepinillo Pro Monthly**
4. Usa las credenciales de sandbox
5. Confirma la compra
6. Verifica que el entitlement "pro" se activa en la app
7. Abre **RevenueCat dashboard** → **Analytics** y verifica que la compra aparezca

### 5.4 Probar Webhooks en Desarrollo

1. En tu máquina local, inicia el servidor backend:
   ```bash
   npm run dev  # o el comando correspondiente
   ```

2. Usa un servicio como **ngrok** para exponer tu localhost:
   ```bash
   ngrok http 3000
   ```

3. Copia la URL pública (ej: `https://abc123.ngrok.io`)

4. En **RevenueCat dashboard** → **Webhooks**, cambia temporalmente la URL a:
   ```
   https://abc123.ngrok.io/api/v1/webhooks/revenuecat
   ```

5. Haz clic en **Send Test Event** para verificar que tu backend recibe el webhook

6. Verifica los logs en tu terminal:
   ```
   POST /api/v1/webhooks/revenuecat 200
   ```

### 5.5 Crear Archivo de Configuración StoreKit (Opcional pero Recomendado)

Para simulaciones más realistas en el simulador:

1. En Xcode, ve a **Product** → **Scheme** → **Edit Scheme**
2. Selecciona **Run**
3. En **StoreKit Configuration**, haz clic en **Create Configuration**
4. Define los 3 productos con sus precios
5. Esto permite probar compras sin conectar a sandbox de Apple

---

## Parte 6: Checklist para Go-Live (Publicación en Producción)

Cuando estés listo para publicar la app:

### 6.1 Cambiar de Sandbox a Producción

#### En Xcode/Código iOS

1. Verifica que el código iOS usa:
   ```swift
   RCConfiguration.Builder(withAPIKey: "pk_prod_...")  // Public key PRODUCCIÓN
   ```

2. Desactiva cualquier flag de prueba o sandbox

#### En App Store Connect

1. Asegúrate de que los 3 productos de suscripción están en estado **Ready to Submit**
2. Los precios y localizaciones están correctamente configurados

#### En RevenueCat

1. Ve a **Settings** → **Environment**
2. Cambia a **Production** (si está disponible)
3. Verifica que los webhooks apunten a la URL de producción:
   ```
   https://tu-dominio-produccion.com/api/v1/webhooks/revenuecat
   ```

### 6.2 Configurar Variables de Entorno en Producción

En tu servidor de producción, configura:

```bash
REVENUECAT_API_KEY=sk_prod_abc123xyz789...  # Secret key PRODUCCIÓN
REVENUECAT_WEBHOOK_AUTH_TOKEN=Bearer secure_token...
REVENUECAT_API_BASE_URL=https://api.revenuecat.com/v1
```

### 6.3 Preparar Información para App Review

Para que Apple apruebe la app con IAP:

1. Ve a **App Store Connect** → **Pepinillo** → **Información de la App**
2. En **In-App Purchases**, verifica que están listadas:
   - Pepinillo Pro Monthly
   - Pepinillo Pro Annual
   - Pepinillo Pro Lifetime
3. Crea un **Promotional Image** para el paywall (opcional)
4. Agrega una descripción clara de qué incluye Pro

### 6.4 Crear Build de Producción y Submitir para Review

1. En Xcode:
   ```
   Product → Archive
   ```

2. En Organizer, haz clic en **Distribute App**
3. Selecciona **App Store Connect**
4. Elige **Manual Signing**
5. Sube el build a App Store Connect

6. Ve a **App Store Connect** → **Pepinillo** → **Compilaciones**
7. Selecciona el build que subiste
8. Haz clic en **Submit for Review**
9. Completa las preguntas sobre:
   - Características de contenido
   - Información de contacto
   - Información de compra en la app
10. Revisa y haz clic en **Submit for Review**

### 6.5 Monitorear el Dashboard de RevenueCat en Producción

Una vez aprobada la app:

1. Ve a **RevenueCat dashboard** → **Analytics**
2. Monitorea:
   - **Revenue MRR** (ingresos recurrentes mensuales)
   - **Conversión Rate** (% de usuarios que compran)
   - **Churn Rate** (% de cancelaciones)
   - **Product Mix** (cuál plan es más popular)

3. Ve a **Customers** para ver detalles de suscriptores

### 6.6 Verificar Webhooks en Producción

1. Realiza una compra real (o usa TestFlight con tester de App Store)
2. En **RevenueCat** → **Webhooks**, verifica el log
3. Confirma que tu backend recibió y procesó el webhook
4. Verifica que la base de datos se sincronizó correctamente

---

## Parte 7: Troubleshooting Común

### Problema: "Invalid App Store Connect API Key"

**Causa:** El archivo `.p8` expiró o los datos (Key ID, Issuer ID) son incorrectos.

**Solución:**
1. Ve a **App Store Connect** → **Usuarios y Acceso** → **Integraciones**
2. Revoca la clave anterior
3. Genera una nueva clave `.p8`
4. Sube el nuevo archivo a RevenueCat

### Problema: Compra en Sandbox No Se Sincroniza

**Causa:** RevenueCat tarda en sincronizar con sandbox de Apple.

**Solución:**
1. Espera 5-10 minutos
2. En la app, fuerza una actualización: `Purchases.shared.invalidateCustomerInfoCache()`
3. Verifica en RevenueCat Dashboard → Customers que el usuario aparece

### Problema: Webhook No Recibe Eventos

**Causa:** URL de webhook incorrecta o token de autenticación no coincide.

**Solución:**
1. Verifica la URL en RevenueCat → Settings → Webhooks
2. Verifica el Authorization header en tu código backend
3. Usa **Send Test Event** para probar
4. Revisa los logs de tu servidor

### Problema: "Product Not Found" al Intentar Comprar

**Causa:** El ID del producto en RevenueCat no coincide con App Store Connect.

**Solución:**
1. Ve a **RevenueCat** → **Products**
2. Verifica que los IDs sean exactos:
   - `com.pepinillo.app.pro.monthly`
   - `com.pepinillo.app.pro.annual`
   - `com.pepinillo.app.pro.lifetime`
3. Si están mal, elimina y vuelve a sincronizar desde App Store Connect

---

## Recursos Adicionales

- **RevenueCat Docs:** https://docs.revenuecat.com
- **Apple In-App Purchases Guide:** https://developer.apple.com/in-app-purchase
- **StoreKit 2 Documentation:** https://developer.apple.com/documentation/storekit
- **RevenueCat API Reference:** https://docs.revenuecat.com/reference/getting-started-with-the-revenuecat-api

---

## Notas Finales

- Siempre prueba en sandbox antes de publicar
- Mantén tus API keys seguras (nunca en control de versiones)
- Monitorea el dashboard de RevenueCat regularmente
- Responde rápidamente a problemas de billing reportados por usuarios
- Actualiza la documentación cuando cambies estructura de precios

¡Buena suerte con la monetización de Pepinillo!
