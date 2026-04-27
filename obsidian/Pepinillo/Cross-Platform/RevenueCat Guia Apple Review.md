# Guía de Revisión — Apple App Store Connect + RevenueCat (Pepinillo iOS)

> **Destinatario**: Cowork.  
> **Ejecutor actual**: tiagofur.  
> **Fecha de emisión**: 2026-04-21.  
> Esta guía es un checklist de verificación antes del launch del tier model **Free / Pepinillo+ / Everywhere/AI+**.  
> Cada sección tiene checkboxes. Marcalos a medida que confirmás o corregís cada ítem.

---

## 1. Contexto del producto

- **Pepinillo** es una app de deep work y productividad (focus timer + tasks + analytics) para iOS, iPadOS, macOS, watchOS y Android.
- El modelo de monetización evolucionó de un único tier "Pro" a dos tiers pagos: **Pepinillo+** (compra única, lifetime) y **Everywhere/AI+** (suscripción mensual/anual, sync cross-platform + IA cloud).
- **Pepinillo+** usa los product IDs existentes (`com.pepinillo.app.pro.*`) — no hay productos nuevos que crear en App Store Connect, solo actualizar el metadata (nombre, descripción, precio).
- La revisión es necesaria porque los entitlements en RevenueCat deben crearse con los nuevos IDs (`pepinillo_plus`, `everywhere_plus`) que el código ya usa, y el metadata de precios en App Store Connect probablemente refleja los valores antiguos del tier Pro.
- El backend (Go) valida webhooks de RevenueCat con Bearer Token — esto debe estar configurado en el dashboard de RevenueCat antes del launch.

---

## 2. Apple App Store Connect

### 2.1 App Information (general)

#### Bundle IDs confirmados (fuente: archivos `.entitlements` del repositorio)

| Target | Bundle ID esperado |
|--------|--------------------|
| App principal | `dev.creapolis.pepinillo` *(verificar en Xcode → Signing & Capabilities)* |
| Widget Extension | mismo prefix + `.widget` |
| Watch App | mismo prefix + `.watchkitapp` |
| Control Center Extension | mismo prefix + `.controlcenter` |

> **Nota**: los entitlements del repo usan `com.pepinillo.app` como prefijo interno (App Groups, iCloud container), pero el Bundle ID del app puede ser diferente. Verificar en Xcode o App Store Connect directamente.

- [ ] Bundle ID principal en App Store Connect es `dev.creapolis.pepinillo`
- [ ] Bundle IDs de extensiones coinciden: `dev.creapolis.pepinillo.widget`, `dev.creapolis.pepinillo.watchkitapp`, `dev.creapolis.pepinillo.controlcenter`
- [ ] **Capabilities activados** en App Store Connect → App → Features:
  - [ ] iCloud (CloudKit habilitado)
  - [ ] Sign in with Apple (confirmado en `Pepinillo.entitlements`: `com.apple.developer.applesignin = ["Default"]`)
  - [ ] Push Notifications (en entitlements: `aps-environment = development` → cambiar a `production` para el build de App Store)
  - [ ] App Groups (en entitlements: `group.com.pepinillo.app` compartido entre app, widget, watch y control center)
  - [ ] HealthKit (en entitlements: `com.apple.developer.healthkit = true`)
  - [ ] Siri (en entitlements: `com.apple.developer.siri = true`)
  - [ ] Communication Notifications (`com.apple.developer.usernotifications.communication = true`)
- [ ] Soporte de idiomas en Store listing: **English, Spanish, Portuguese**
- [ ] Privacy Policy URL: `https://creapolis.dev/privacy-policy/`
- [ ] Terms of Use URL: `https://creapolis.dev/terms-of-use/`
- [ ] **App Privacy (Data Collection)** completado y veraz — declarar:
  - [ ] **CloudKit / iCloud**: datos de usuario sincronizados (linked to identity, user-provided)
  - [ ] **RevenueCat**: datos de compra y diagnóstico (linked to identity)
  - [ ] **Sign in with Apple**: nombre y email (linked to identity, si el usuario elige compartirlos)
  - [ ] **HealthKit**: Mindful Minutes (no enviados a terceros, not linked to identity)
- [ ] Minimum iOS version: **iOS 17.0**
- [ ] Categoría primaria: **Productivity**

---

### 2.2 In-App Purchases — actualizar los 3 productos existentes

> **El PRD confirma que se reusan los product IDs existentes** (`com.pepinillo.app.pro.lifetime`, `com.pepinillo.app.pro.monthly`, `com.pepinillo.app.pro.annual`). Solo cambia el metadata. No hay que crear nuevos productos.

---

#### Producto 1: Pepinillo+ (one-time lifetime)

| Campo | Valor |
|-------|-------|
| Product ID | `com.pepinillo.app.pro.lifetime` |
| Reference Name | `Pepinillo Plus Lifetime` |
| Tipo | Non-Consumable |
| Cleared for Sale | YES |
| Precio base (USD) | **$19.99** |
| Family Sharing | **Recomendado: YES** (compra única, tiene sentido compartir con familia) |

**Display Name (localizado):**

| Idioma | Display Name |
|--------|-------------|
| English | `Pepinillo+` |
| Spanish | `Pepinillo+` |
| Portuguese | `Pepinillo+` |

**Description (localizado):**

| Idioma | Description |
|--------|-------------|
| English | `Unlock the full Pepinillo experience — forever. All focus modes, unlimited tasks, Apple Intelligence reports, iCloud sync, all widgets and Apple Watch companion. One purchase. Yours for life.` |
| Spanish | `Desbloqueá la experiencia completa de Pepinillo — para siempre. Todos los modos de enfoque, tareas ilimitadas, informes con Apple Intelligence, sincronización iCloud, todos los widgets y companion para Apple Watch. Una sola compra. Tuya para siempre.` |
| Portuguese | `Desbloqueie a experiência completa do Pepinillo — para sempre. Todos os modos de foco, tarefas ilimitadas, relatórios com Apple Intelligence, sincronização iCloud, todos os widgets e companion para Apple Watch. Uma única compra. Seu para sempre.` |

**Review Information:**
- [ ] Screenshot 1290×2796 mostrando el paywall con Pepinillo+ seleccionado
- [ ] Review Notes: "Non-Consumable one-time purchase. Tap 'Pepinillo+' card in the paywall to select it, then tap 'Get Pepinillo+ — One Time'. Use sandbox account to complete purchase flow."

**Checklist:**
- [ ] Product ID: `com.pepinillo.app.pro.lifetime`
- [ ] Tipo: Non-Consumable *(no cambiar — ya está configurado así)*
- [ ] Precio actualizado a **$19.99** (antes era $49.99 o $24.99 según mock data)
- [ ] Display name y description actualizados en EN/ES/PT
- [ ] Cleared for Sale: YES
- [ ] Family Sharing: habilitado

---

#### Producto 2: Everywhere/AI+ Monthly (suscripción)

| Campo | Valor |
|-------|-------|
| Product ID | `com.pepinillo.app.pro.monthly` |
| Reference Name | `Everywhere AI Plus Monthly` |
| Tipo | Auto-Renewable Subscription |
| Cleared for Sale | YES |
| Precio base (USD) | **$4.99/mes** |
| Subscription Group | `Everywhere Plus` (ver sección 2.3) |
| Family Sharing | No (suscripción — cada usuario paga) |

**Display Name (localizado):**

| Idioma | Display Name |
|--------|-------------|
| English | `Everywhere/AI+ Monthly` |
| Spanish | `Everywhere/AI+ Mensual` |
| Portuguese | `Everywhere/AI+ Mensal` |

**Description (localizado):**

| Idioma | Description |
|--------|-------------|
| English | `Everything in Pepinillo+, plus cross-platform sync and advanced cloud AI. Includes AI Coach, predictive insights, and 100 AI credits per month. Billed monthly, cancel anytime.` |
| Spanish | `Todo lo de Pepinillo+, más sincronización cross-platform e IA cloud avanzada. Incluye AI Coach, insights predictivos y 100 créditos de IA por mes. Se cobra mensualmente, cancelá cuando quieras.` |
| Portuguese | `Tudo do Pepinillo+, mais sincronização multiplataforma e IA cloud avançada. Inclui AI Coach, insights preditivos e 100 créditos de IA por mês. Cobrado mensalmente, cancele quando quiser.` |

**Review Information:**
- [ ] Screenshot 1290×2796 mostrando paywall con Everywhere/AI+ Monthly seleccionado
- [ ] Review Notes: "Auto-renewable subscription. Select 'Everywhere/AI+ Monthly' from the paywall and proceed through the subscription flow using a sandbox account."

**Checklist:**
- [ ] Product ID: `com.pepinillo.app.pro.monthly`
- [ ] Precio actualizado a **$4.99/mes**
- [ ] Display name y description actualizados en EN/ES/PT
- [ ] Asignado al Subscription Group correcto (ver 2.3)
- [ ] Cleared for Sale: YES

---

#### Producto 3: Everywhere/AI+ Annual (suscripción)

| Campo | Valor |
|-------|-------|
| Product ID | `com.pepinillo.app.pro.annual` |
| Reference Name | `Everywhere AI Plus Annual` |
| Tipo | Auto-Renewable Subscription |
| Cleared for Sale | YES |
| Precio base (USD) | **$34.99/año** (~$2.92/mes, ahorro del 42% vs mensual) |
| Subscription Group | `Everywhere Plus` (ver sección 2.3) |
| Family Sharing | No (suscripción) |

**Display Name (localizado):**

| Idioma | Display Name |
|--------|-------------|
| English | `Everywhere/AI+ Annual` |
| Spanish | `Everywhere/AI+ Anual` |
| Portuguese | `Everywhere/AI+ Anual` |

**Description (localizado):**

| Idioma | Description |
|--------|-------------|
| English | `Everything in Pepinillo+, plus cross-platform sync and advanced cloud AI. Includes AI Coach, predictive insights, and 100 AI credits per month. Best value — save 42% compared to monthly. Billed annually.` |
| Spanish | `Todo lo de Pepinillo+, más sincronización cross-platform e IA cloud avanzada. Incluye AI Coach, insights predictivos y 100 créditos de IA por mes. Mejor precio — ahorrá un 42% frente al plan mensual. Se cobra anualmente.` |
| Portuguese | `Tudo do Pepinillo+, mais sincronização multiplataforma e IA cloud avançada. Inclui AI Coach, insights preditivos e 100 créditos de IA por mês. Melhor custo-benefício — economize 42% em relação ao plano mensal. Cobrado anualmente.` |

**Review Information:**
- [ ] Screenshot 1290×2796 mostrando paywall con Everywhere/AI+ Annual seleccionado
- [ ] Review Notes: "Auto-renewable subscription, billed annually. Select 'Everywhere/AI+ Annual' from the paywall and proceed using a sandbox account."

**Checklist:**
- [ ] Product ID: `com.pepinillo.app.pro.annual`
- [ ] Precio actualizado a **$34.99/año**
- [ ] Display name y description actualizados en EN/ES/PT
- [ ] Asignado al Subscription Group correcto (ver 2.3)
- [ ] Cleared for Sale: YES
- [ ] Marcado como "Featured" o de mayor jerarquía en el Subscription Group (es el value plan)

---

### 2.3 Subscription Group — `Everywhere Plus`

El Subscription Group agrupa los dos productos de suscripción (`monthly` y `annual`). Apple lo usa para gestionar upgrades/downgrades automáticos y mostrar al usuario su historial de suscripciones.

- [ ] Subscription Group creado o confirmado con nombre: **`Everywhere Plus`**
- [ ] Localización del grupo en EN/ES/PT:
  - EN: `Everywhere/AI+`
  - ES: `Everywhere/AI+`
  - PT: `Everywhere/AI+`
- [ ] `com.pepinillo.app.pro.monthly` dentro del grupo
- [ ] `com.pepinillo.app.pro.annual` dentro del grupo
- [ ] **Subscription Level / Rank**: Annual = nivel 1 (mayor jerarquía), Monthly = nivel 2 — así Apple gestiona el upgrade de monthly → annual automáticamente
- [ ] **Intro Offer (decisión pendiente — ver sección 6)**: Si se decide ofrecer, configurar 7 días free trial para Annual. Si no, dejar sin intro offer.
- [ ] **Promotional Offers**: Configurar al menos un promotional offer de win-back (descuento 50% por 3 meses) para usuarios cancelados — opcional pero recomendado

---

### 2.4 StoreKit Configuration (testing local)

Para probar el flujo de compra localmente antes de que Apple apruebe los productos:

- [ ] Existe archivo `ios/Pepinillo.storekit` (o similar) con los 3 productos mockeados:
  - `com.pepinillo.app.pro.lifetime` — Non-Consumable, $19.99
  - `com.pepinillo.app.pro.monthly` — Auto-Renewable, $4.99/mes
  - `com.pepinillo.app.pro.annual` — Auto-Renewable, $34.99/año
- [ ] Scheme de Xcode (Debug/Development) configurado en: **Edit Scheme → Run → Options → StoreKit Configuration** apuntando al archivo `.storekit`
- [ ] Al menos 2 **Sandbox Tester accounts** creados en App Store Connect → Users and Access → Sandbox → Testers:
  - [ ] Cuenta sin compras (free tier)
  - [ ] Cuenta con Pepinillo+ activo (`pro.lifetime` comprado)

---

### 2.5 App Review Information

Estos datos se completan en App Store Connect → App → App Review Information:

- [ ] **Demo Account**: si el reviewer necesita login, proporcionar credenciales de cuenta de prueba (Sign in with Apple no funciona en sandbox del reviewer — usar email/password si hay auth alternativa, o agregar nota explicando el flujo)
- [ ] **Test Instructions** (English, para el revisor de Apple):
  ```
  To test In-App Purchases:
  1. Launch the app and complete onboarding (or skip if shown).
  2. Navigate to Settings → Subscriptions, or tap any premium feature to trigger the paywall.
  3. The paywall shows three options: Pepinillo+ (one-time), Everywhere/AI+ Monthly, and Everywhere/AI+ Annual.
  4. Select "Pepinillo+" and tap "Get Pepinillo+ — One Time" to test the non-consumable purchase.
  5. For subscriptions, select Monthly or Annual and tap "Continue".
  6. Restore Purchases button is available at the bottom of the paywall.
  Note: The app uses Sign in with Apple as primary authentication.
  ```
- [ ] **Additional Notes** (English):
  ```
  This app requires iCloud for premium sync (CloudKit). Sign in with Apple is the primary auth method.
  HealthKit integration (Mindful Minutes) is optional and requires user permission.
  Siri integration requires Siri permissions.
  Push Notifications are used for focus session reminders (optional).
  ```
- [ ] Attachment: screenshot del paywall mostrando los tres productos

---

### 2.6 Capacidades técnicas — Apple Developer Portal

Verificar en [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles:

- [ ] **App ID** `dev.creapolis.pepinillo` tiene habilitados:
  - [ ] iCloud — CloudKit checked
  - [ ] Sign in with Apple — enabled
  - [ ] Push Notifications — certificate o key presente
  - [ ] App Groups — `group.com.pepinillo.app`
  - [ ] HealthKit
  - [ ] SiriKit
- [ ] **iCloud Container** `iCloud.com.pepinillo.app` creado y activo (coincide exactamente con `Pepinillo.entitlements` línea 15)
- [ ] **App Groups identifier** `group.com.pepinillo.app` registrado (coincide con todos los entitlements: app, widget, watch, control center)
- [ ] **APNS Key** (`.p8`) creada y presente en RevenueCat (para push notifications de RevenueCat — renewal reminders, etc.)
- [ ] **Provisioning Profiles** actualizados para incluir todas las capabilities anteriores — especialmente si se cambió algo en el App ID
- [ ] **`aps-environment` en `Pepinillo.entitlements`**: actualmente está en `development` (línea 6). Para el build de App Store **debe ser `production`** — Xcode lo maneja automáticamente en Archive builds, pero confirmarlo.

---

## 3. RevenueCat Dashboard

### 3.1 Project Setup

- [ ] Project name en RevenueCat: **Pepinillo**
- [ ] Apps creadas dentro del mismo project:
  - [ ] App iOS: Bundle ID `dev.creapolis.pepinillo`, Platform: iOS
  - [ ] App Android: Package `com.pepinillo.app` (o el que corresponda), Platform: Android
- [ ] Bundle IDs alineados exactamente con App Store Connect y Google Play Console
- [ ] APNS Key (`.p8`) subida en RevenueCat → app iOS → Push Notifications (necesario para renewal receipts y comunicaciones)

---

### 3.2 Products — importar desde App Store Connect

En RevenueCat → Products → botón **"Import from App Store"**:

- [ ] `com.pepinillo.app.pro.lifetime` importado — Type: Non-Consumable
- [ ] `com.pepinillo.app.pro.monthly` importado — Type: Auto-Renewable Subscription
- [ ] `com.pepinillo.app.pro.annual` importado — Type: Auto-Renewable Subscription

> Si el import falla porque los productos no están aprobados aún en App Store Connect, ingresar los IDs manualmente.

---

### 3.3 Entitlements — crear 2 entitlements

#### Entitlement `pepinillo_plus`

> Este es el ID que el código Swift verifica actualmente (ver `SubscriptionClient.swift`: `entitlements["pepinillo_plus"]`). Debe existir en el dashboard con este nombre exacto.

- [ ] Entitlement creado con identifier: **`pepinillo_plus`**
- [ ] Display name: `Pepinillo+`
- [ ] Products que lo otorgan:
  - [ ] `com.pepinillo.app.pro.lifetime` (one-time lifetime)
  - [ ] `com.pepinillo.app.pro.monthly` (Everywhere+ — superset de pepinillo_plus)
  - [ ] `com.pepinillo.app.pro.annual` (Everywhere+ — superset de pepinillo_plus)

#### Entitlement `everywhere_plus`

> Este es el ID que el código Swift verifica para el tier Everywhere+ (ver `SubscriptionClient.swift`: `entitlements["everywhere_plus"]`). Debe existir en el dashboard con este nombre exacto.

- [ ] Entitlement creado con identifier: **`everywhere_plus`**
- [ ] Display name: `Everywhere/AI+`
- [ ] Products que lo otorgan:
  - [ ] `com.pepinillo.app.pro.monthly`
  - [ ] `com.pepinillo.app.pro.annual`
  - [ ] **NO** otorgado por `com.pepinillo.app.pro.lifetime` — Pepinillo+ (lifetime) no incluye sync cross-platform

#### Entitlements legacy (si existen en el dashboard — NO borrar)

- [ ] `premium` — si existe, mantenerlo para grandfathering de usuarios anteriores (el código en líneas 340-360 de `SubscriptionClient.swift` los mapea automáticamente)
- [ ] `pro` — ídem

---

### 3.4 Offerings — configurar el offering `default`

- [ ] Offering creado con identifier: **`default`** (RevenueCat usa este por defecto)
- [ ] Display name: `Default Offering`
- [ ] Packages dentro del offering:

| Package Identifier | Product | Notas |
|-------------------|---------|-------|
| `$rc_lifetime` | `com.pepinillo.app.pro.lifetime` | Usar identifier reservado de RC para lifetime, o uno custom como `pepinillo_plus_lifetime` |
| `$rc_monthly` | `com.pepinillo.app.pro.monthly` | Identifier reservado de RC |
| `$rc_annual` | `com.pepinillo.app.pro.annual` | Identifier reservado de RC |

- [ ] El código en `SubscriptionClient.swift` (líneas 198-209) itera sobre `PepinilloProduct.currentProducts` y busca packages por `productIdentifier`. Los package identifiers no necesitan coincidir exactamente con los product IDs siempre que el `.product.productIdentifier` del package sí coincida.
- [ ] Confirmar que el offering `default` está marcado como **Current Offering** en el dashboard.

---

### 3.5 Webhooks

> El backend Go valida el webhook con **Bearer Token** (no HMAC). Confirmado en `backend/internal/services/revenuecat_service.go` línea 97.

- [ ] Webhook URL configurada: `https://api.ppn.creapolis.dev/api/v1/webhooks/revenuecat`
  - Verificar la URL exacta con tiagofur — el backend está en `api.ppn.creapolis.dev`
- [ ] Authorization: **Bearer Token** (el valor del token se configura en env var del backend como `REVENUECAT_WEBHOOK_SECRET`)
- [ ] Token generado y guardado en el servidor (`REVENUECAT_WEBHOOK_SECRET` en `.env` del VPS)
- [ ] **Event types habilitados**: habilitar todos los eventos (el backend filtra server-side cuáles procesar)
- [ ] **Test del webhook**: usar el botón "Send Test" en el dashboard de RC → verificar que el backend responde `200 OK`
- [ ] En caso de fallo del test: revisar que el VPS esté corriendo, la URL sea accesible públicamente, y el token coincida entre RC dashboard y la env var del servidor

---

### 3.6 API Keys

- [ ] **Public SDK Key iOS** (prefijo `appl_...`) generada → actualmente hardcoded en `ios/App/AppFeature.swift` línea 245 como `"appl_xnChlVXXtUFhusIfJyNrNDcMGLj"`. Verificar que esta key sea la correcta para la app iOS en el proyecto de RevenueCat correcto.
- [ ] **Public SDK Key Android** generada (prefijo `goog_...`) → está configurada en el código Android en `SubscriptionManager`
- [ ] **Secret REST Key** generada → para uso server-side únicamente, guardar en variables de entorno del backend, NUNCA en el código del cliente
- [ ] **CRÍTICO**: la API key de iOS está hardcoded directamente en el código (`AppFeature.swift:245`). Considerar moverla a xcconfig/Info.plist o inyectarla via CI como variable de entorno, especialmente para poder rotar la key sin un nuevo build. (Acción recomendada pero no bloqueante para el launch)

---

### 3.7 Customer Center (opcional pero recomendado)

RevenueCat tiene un "Customer Center" para manejo de suscripciones en-app:

- [ ] Decidir si habilitar el Customer Center de RevenueCat o manejar la UI de gestión de suscripciones manualmente
- [ ] Si se habilita: configurar URLs de privacy policy y terms of use en el dashboard

---

### 3.8 Analytics / Integraciones

- [ ] Apple Search Ads attribution: **deshabilitado** salvo que se vaya a usar activamente
- [ ] Amplitude/Mixpanel/Firebase integrations: **deshabilitadas** por ahora — evitar compartir datos de usuarios innecesariamente
- [ ] Charts / reporting: verificar que los eventos de compra estén llegando correctamente una vez configurados los sandbox testers

---

## 4. Alineación con el código iOS — mismatches detectados

> Esta sección documenta las discrepancias entre el estado actual del código y el estado objetivo. Algunas son bloqueantes para el launch.

### 4.1 RESUELTO — Entitlement IDs en el código (v3.1)

**Archivo**: `ios/Domain/Clients/SubscriptionClient.swift`

El código verifica estos entitlement IDs en RevenueCat (actualizados en v3.1):
- `entitlements["everywhere_plus"]` — para el tier Everywhere+
- `entitlements["pepinillo_plus"]` — para el tier Pepinillo+
- `entitlements["premium"]` y `entitlements["pro"]` — grandfathering de usuarios legacy

**Entitlement IDs vigentes**: `pepinillo_plus` y `everywhere_plus` (alineados con marketing).

**Acción requerida en RevenueCat**: crear los entitlements con estos IDs exactos (sección 3.3 de esta guía).

---

### 4.2 RESUELTO — Product IDs en `PepinilloProduct` enum

**Archivo**: `ios/Domain/Clients/SubscriptionClient.swift`

```swift
case monthly  = "com.pepinillo.app.pro.monthly"
case annual   = "com.pepinillo.app.pro.annual"
case lifetime = "com.pepinillo.app.pro.lifetime"
```

El PRD v3.1 (sección 6.3) confirma: se reusan los product IDs `com.pepinillo.app.pro.*`. El bloque `TODO: Phase 6` con IDs obsoletos fue eliminado en v3.1. **Código correcto.**

---

### 4.3 MISMATCH CRÍTICO — Mock data del paywall usa precios viejos

**Archivo**: `ios/Features/Paywall/PaywallView.swift`, líneas 475-485 (Preview)
**Archivo**: `ios/Domain/Clients/SubscriptionClient.swift`, líneas 384-398 (mockProductInfo)

Los precios en los mocks son:
- monthly: `$3.99` (precio anterior)
- annual: `$24.99` (precio anterior)
- lifetime: `$49.99` (precio anterior)

**El PRD v3.0 (sección 4) dice**:
- Pepinillo+: **$19.99**
- Everywhere/AI+ Monthly: **$4.99**
- Everywhere/AI+ Annual: **$34.99**

**Impacto**: los mocks solo se muestran en Previews de Xcode y cuando RevenueCat no está disponible. En producción, los precios reales vienen de App Store Connect vía RevenueCat. El paywall de producción mostrará los precios correctos **siempre que App Store Connect tenga los valores actualizados**.

**Acción recomendada**: actualizar los valores de mock en `mockProductInfo` para que Previews de Xcode reflejen los precios correctos. **No es bloqueante para el launch pero sí confuso en desarrollo.**

---

### 4.4 ADVERTENCIA — API Key de RevenueCat hardcoded

**Archivo**: `ios/App/AppFeature.swift`, línea 245

```swift
await subscriptionClient.configure("appl_xnChlVXXtUFhusIfJyNrNDcMGLj", userID)
```

La key pública de RevenueCat (`appl_xnChlVXXtUFhusIfJyNrNDcMGLj`) está hardcoded directamente en el código. Las Public SDK Keys de RevenueCat son públicas por diseño (solo permiten hacer compras, no acceder al dashboard), así que **no es un riesgo de seguridad crítico**. Sin embargo, si la key necesita rotarse, requiere un nuevo build y update de la app.

**Acción recomendada**: confirmar que esta key corresponde al proyecto correcto de RevenueCat y a la app iOS correcta. Si es la key de producción, está bien para el launch. Si es de dev/staging, debe reemplazarse antes de publicar.

---

### 4.5 INFO — `aps-environment` en entitlements

**Archivo**: `ios/App/Pepinillo.entitlements`, línea 6

```xml
<key>aps-environment</key>
<string>development</string>
```

Xcode cambia esto automáticamente a `production` al hacer Archive para App Store. **No es una acción manual necesaria**, pero confirmarlo si el build de TestFlight o App Store muestra problemas con Push Notifications.

---

### 4.6 INFO — iCloud Container identifier

**Archivo**: `ios/App/Pepinillo.entitlements`, línea 15

```xml
<string>iCloud.com.pepinillo.app</string>
```

El iCloud Container usa el prefijo `com.pepinillo.app`, no `dev.creapolis.pepinillo`. Esto es válido — el container identifier es independiente del bundle ID. **Confirmar** que el container `iCloud.com.pepinillo.app` está creado en el Apple Developer Portal (ver sección 2.6).

---

### 4.7 INFO — App Groups identifier

**Confirmado en todos los entitlements** (`Pepinillo.entitlements`, `PepinilloWidget.entitlements`, `PepinilloWatch.entitlements`, `PepinilloControlCenter.entitlements`):

```xml
<string>group.com.pepinillo.app</string>
```

El App Group `group.com.pepinillo.app` debe estar registrado en el Apple Developer Portal. Este grupo es el canal de comunicación entre la app principal, el widget, el watch app y la extensión de Control Center.

---

### 4.8 Archivos clave a verificar antes del launch

| Archivo | Qué confirmar |
|---------|---------------|
| `ios/App/Pepinillo.entitlements` | `iCloud.com.pepinillo.app` existe en Developer Portal; `aps-environment` → producción en el Archive |
| `ios/PepinilloWidget/PepinilloWidget.entitlements` | App Group `group.com.pepinillo.app` presente |
| `ios/PepinilloWatch/PepinilloWatch.entitlements` | App Group `group.com.pepinillo.app` presente |
| `ios/ControlCenterExtension/PepinilloControlCenter.entitlements` | App Group `group.com.pepinillo.app` presente |
| `ios/Domain/Clients/SubscriptionClient.swift` | Entitlement IDs `pepinillo_plus` y `everywhere_plus` coinciden con el dashboard de RC |
| `ios/App/AppFeature.swift` (línea 245) | API key `appl_xnChlVXXtUFhusIfJyNrNDcMGLj` corresponde al proyecto de producción en RC |
| `ios/Config/Production.xcconfig` | `DEVELOPMENT_TEAM = T5SKULSP2M` es el Team ID correcto del Apple Developer account |
| `ios/Features/Paywall/PaywallView.swift` | PaywallProductCardsSection renderiza productos reales (no mocks) en producción |
| `ios/Domain/Models/UserCapabilities.swift` | Capabilities `pepinilloPlus` y `everywherePlus` coinciden con entitlements de RC |

---

## 5. Checklist crítico pre-launch

Los siguientes ítems deben estar completados antes de enviar a revisión de Apple:

- [ ] Los 3 productos en App Store Connect tienen **Cleared for Sale: YES** y metadata actualizado (nombre, descripción, precio) en EN/ES/PT
- [ ] Subscription Group `Everywhere Plus` configurado con monthly + annual, ranks correctos
- [ ] RevenueCat: 3 productos importados y linked al offering `default`
- [ ] RevenueCat: entitlements **`pepinillo_plus`** y **`everywhere_plus`** creados y asignados a los productos correctos
- [ ] Webhook de RevenueCat respondiendo **HTTP 200** desde el VPS (`https://api.ppn.creapolis.dev/api/v1/webhooks/revenuecat`)
- [ ] API key de RevenueCat iOS (`appl_xnChlVXXtUFhusIfJyNrNDcMGLj`) verificada como key de producción en el dashboard correcto
- [ ] Paywall renderiza correctamente los 3 packages en sandbox (precios reales de App Store, no mocks)
- [ ] iCloud Container `iCloud.com.pepinillo.app` y App Group `group.com.pepinillo.app` registrados en Apple Developer Portal
- [ ] App Privacy (Data Collection) completado en App Store Connect

---

## 6. Preguntas abiertas para tiagofur

Cowork puede traer estas decisiones de vuelta al ejecutor antes o durante el proceso de revisión:

1. **Precios definitivos**: el PRD dice $19.99 / $4.99 / $34.99. ¿Se mantienen estos valores o hay ajuste de última hora? (Los precios de LATAM también deben configurarse en la pricing matrix de Apple)
2. **Intro Offer / Free Trial**: ¿Se ofrece un periodo de prueba gratuito (por ejemplo, 7 días) para Everywhere/AI+ Annual? Si sí, configurarlo en el Subscription Group antes de enviarlo a revisión de Apple.
3. **Family Sharing para Pepinillo+**: ¿Habilitar Family Sharing para el non-consumable lifetime? (Recomendado — mejora conversión y experiencia de usuario)
4. **API key hardcoded**: ¿Mover `appl_xnChlVXXtUFhusIfJyNrNDcMGLj` a xcconfig/Info.plist antes del launch, o dejarlo hardcoded para simplificar? (No es bloqueante, pero afecta mantenibilidad)
5. **Sandbox tester accounts**: ¿Tiagofur ya tiene cuentas de sandbox creadas en App Store Connect para testing del flujo completo?

---

## 7. Recursos

- **Apple App Store Connect**: https://appstoreconnect.apple.com
- **Apple Developer Portal** (Certificates, IDs & Profiles): https://developer.apple.com/account/resources
- **RevenueCat Dashboard**: https://app.revenuecat.com
- **Apple StoreKit 2 docs**: https://developer.apple.com/documentation/storekit
- **RevenueCat iOS SDK docs**: https://www.revenuecat.com/docs/getting-started/installation/ios
- **RevenueCat Entitlements docs**: https://www.revenuecat.com/docs/entitlements
- **RevenueCat Webhooks docs**: https://www.revenuecat.com/docs/integrations/webhooks
- **Apple In-App Purchase review guidelines**: https://developer.apple.com/app-store/review/guidelines/#in-app-purchase
- **Terms of Use Pepinillo**: https://creapolis.dev/terms-of-use/
- **Privacy Policy Pepinillo**: https://creapolis.dev/privacy-policy/
