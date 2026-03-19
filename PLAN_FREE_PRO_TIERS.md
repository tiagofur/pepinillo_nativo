# Plan: Free & Pro Tiers - Android con Google Play Billing

## Estado Actual

### iOS (ya implementado)
- StoreKit 2 integrado con 3 productos
- Feature gating en: modos de enfoque (Flowtime/TimeBlock bloqueados) y soundscapes premium
- Paywall UI con selección de producto
- Precios actuales en StoreKit: Monthly $2.99, Annual $14.99, Lifetime $29.99

### Android (pendiente)
- Backend billing service YA existe (verifica recibos Google Play + App Store)
- Google Play Billing 7 declarado como dependencia
- NO hay feature gating en UI
- NO hay paywall screen
- NO hay SubscriptionManager/Client

### Backend
- Endpoint `POST /billing/verify-receipt` funcional
- Mapeo de tiers: `free`, `pro_monthly`, `pro_yearly`, `lifetime`
- Soporta verificación de Google Play y App Store

---

## Análisis Crítico: Problemas con el Tier Free Actual

### El Free tier NO motiva la compra - Problemas identificados:

1. **Solo 2 modos bloqueados no es suficiente** - Pomodoro + Stopwatch cubren el 80% de los casos de uso. Un usuario casual nunca necesitará Flowtime o TimeBlock.

2. **3 tareas es demasiado generoso** - Un usuario puede funcionar indefinidamente con 3 tareas si las recicla. Necesita ser más restrictivo o tener un enfoque diferente.

3. **Analytics no están realmente bloqueados en iOS** - El código muestra que WeeklyReview y el dashboard son accesibles para todos. Solo se mencionan en el paywall pero no están gateados.

4. **iCloud sync no está gateado** - Se anuncia como Pro pero funciona para todos.

5. **Widgets no están gateados** - Mencionados como Pro pero accesibles sin restricción.

6. **Temas no están gateados** - Solo 1 tema en Free según PRD, pero no hay enforcement.

---

## Propuesta: Nuevo Modelo Free vs Pro (Alineado iOS + Android)

### FREE Tier
| Feature | Límite Free | Justificación |
|---------|-------------|---------------|
| Modos de enfoque | Pomodoro + Chrono/Stopwatch | Los 2 más básicos |
| Tareas activas | 3 tareas (sin subtareas) | Subtareas son Pro |
| Soundscapes | Rain, Forest, Café, White Noise | 4 básicos |
| Analytics | Solo hoy + últimos 7 días | Motiva upgrade para historial |
| Widgets | 1 widget básico (timer) | Los demás son Pro |
| Temas | Solo tema Default | Restricción estética |
| Sesiones diarias | Ilimitadas | NO limitar sesiones - frustra sin convertir |
| Historial | 7 días | Después se pierde, motiva Pro |
| Sync/Cloud | NO | Solo local |
| Wear OS | NO | Solo Pro |
| Recurrencia de tareas | NO | Solo Pro |
| Exportar datos | NO | Solo Pro |

### PRO Tier
| Feature | Pro |
|---------|-----|
| Modos de enfoque | Todos: Pomodoro, Flowtime, TimeBlock, Chrono |
| Tareas | Ilimitadas + subtareas + recurrencia |
| Soundscapes | Todos (8 total) incluyendo Binaural Beats, Lo-fi, Ocean, Fireplace |
| Analytics | Historial completo + Weekly Review + gráficas detalladas |
| Widgets | Todos (Timer, Stats, Tasks, Lock Screen, Quick Settings) |
| Temas | Todos los temas |
| Sync/Cloud | Sync entre dispositivos |
| Wear OS | App completa de Wear OS |
| Exportar datos | CSV/PDF export |
| Streak Protection | 1 skip gratis por semana |

### Cambios sugeridos vs. plan actual:
1. **AGREGAR**: Bloquear subtareas en Free (alto valor percibido, bajo costo dev)
2. **AGREGAR**: Bloquear recurrencia de tareas en Free
3. **AGREGAR**: Limitar analytics a 7 días realmente (no solo anunciarlo)
4. **AGREGAR**: Bloquear Wear OS en Free (diferenciador fuerte)
5. **AGREGAR**: Bloquear sync/cloud en Free (motiva upgrade para backup)
6. **AGREGAR**: Bloquear widgets adicionales (solo timer widget gratis)
7. **ENFORCAR**: Temas - realmente limitar a 1 en Free
8. **MANTENER**: 3 tareas es OK si quitamos subtareas y recurrencia

---

## Precios Sugeridos

### Análisis de mercado (competidores directos):

| App | Monthly | Annual | Lifetime |
|-----|---------|--------|----------|
| Forest | - | $19.99/yr | $3.99 (one-time) |
| Focus Bear | $4.99/mo | $29.99/yr | - |
| Tide | $2.99/mo | $14.99/yr | $49.99 |
| Be Focused Pro | - | - | $4.99 |
| Session | $4.99/mo | $29.99/yr | $79.99 |

### Precios recomendados:

**Mercado Global (US/EU/Tier 1):**
| Plan | Precio | Equivalente mensual |
|------|--------|---------------------|
| Monthly | **$3.99/mes** | $3.99 |
| Annual | **$24.99/año** | $2.08 (ahorro 48%) |
| Lifetime | **$49.99** | - |

**LATAM (MX/CO/AR/BR/CL/PE):**
| Plan | Precio | Equivalente mensual |
|------|--------|---------------------|
| Monthly | **$1.99/mes** | $1.99 |
| Annual | **$12.99/año** | $1.08 (ahorro 46%) |
| Lifetime | **$29.99** | - |

### Justificación de precios:
- **$3.99 vs $4.99**: Barrera psicológica menor. $3.99 está en el sweet spot para productividad.
- **Annual a 48% descuento**: Fuerte incentivo para suscripción anual (mayor LTV).
- **Lifetime a $49.99**: Razonable para early adopters, no tan bajo que canibalice suscripciones.
- **LATAM ~50% del global**: Paridad de poder adquisitivo. Google Play soporta precios regionalizados.
- **iOS debería ajustarse a los mismos precios** para consistencia.

### Product IDs (Google Play):
```
com.pepinillo.app.pro.monthly    → $3.99/mes
com.pepinillo.app.pro.annual     → $24.99/año
com.pepinillo.app.pro.lifetime   → $49.99 (in-app product, no subscription)
```

---

## Plan de Implementación Android

### Fase 1: Infraestructura de Billing (Core)

#### 1.1 - SubscriptionManager
**Archivo nuevo:** `android/app/src/main/java/dev/creapolis/pepinillo/core/billing/SubscriptionManager.kt`

```
- Wrapper sobre Google Play Billing Library 7
- BillingClient setup con retry logic
- queryProductDetails() para los 3 productos
- launchBillingFlow() para iniciar compra
- acknowledgePurchase() post-compra
- queryPurchases() para verificar estado actual
- PurchasesUpdatedListener para actualizaciones en tiempo real
- Verificación de recibos via backend (POST /billing/verify-receipt)
```

#### 1.2 - SubscriptionState
**Archivo nuevo:** `android/app/src/main/java/dev/creapolis/pepinillo/core/billing/SubscriptionState.kt`

```kotlin
data class SubscriptionState(
    val isPro: Boolean = false,
    val activeProductId: String? = null,
    val expirationDate: Instant? = null,
    val tier: SubscriptionTier = SubscriptionTier.FREE
)

enum class SubscriptionTier {
    FREE, PRO_MONTHLY, PRO_YEARLY, LIFETIME
}
```

#### 1.3 - SubscriptionRepository
**Archivo nuevo:** `android/app/src/main/java/dev/creapolis/pepinillo/core/billing/SubscriptionRepository.kt`

```
- Cache local en DataStore (isPro, tier, expirationDate)
- Sync con backend para verificación server-side
- StateFlow<SubscriptionState> observable
- Lógica de gracia: si no hay internet, confiar en cache por 7 días
```

#### 1.4 - Hilt Module
**Archivo nuevo:** `android/app/src/main/java/dev/creapolis/pepinillo/core/billing/BillingModule.kt`

```
- @Provides SubscriptionManager
- @Provides SubscriptionRepository
- @Singleton scope
```

### Fase 2: Feature Gating Service

#### 2.1 - FeatureGate
**Archivo nuevo:** `android/app/src/main/java/dev/creapolis/pepinillo/core/billing/FeatureGate.kt`

```kotlin
@Singleton
class FeatureGate @Inject constructor(
    private val subscriptionRepo: SubscriptionRepository
) {
    val isPro: StateFlow<Boolean>

    fun canUseMode(mode: FocusMode): Boolean
    fun canUseSoundscape(soundscape: Soundscape): Boolean
    fun canAddTask(currentCount: Int): Boolean
    fun canAddSubtask(): Boolean
    fun canUseRecurrence(): Boolean
    fun canAccessAnalytics(range: DateRange): Boolean
    fun canUseWidget(type: WidgetType): Boolean
    fun canUseTheme(theme: AppTheme): Boolean
    fun canUseWearOS(): Boolean
    fun canUseSync(): Boolean
    fun canExportData(): Boolean
}
```

#### 2.2 - Integración en FocusMode enum
**Archivo existente:** `FocusMode.kt`

```kotlin
enum class FocusMode {
    POMODORO, FLOWTIME, TIME_BLOCK, CHRONO;

    val isFreeTier: Boolean get() = this == POMODORO || this == CHRONO
}
```

#### 2.3 - Integración en Soundscape
Agregar `requiresPro` property igual que iOS.

### Fase 3: Paywall UI

#### 3.1 - PaywallScreen (Jetpack Compose)
**Archivo nuevo:** `android/app/src/main/java/dev/creapolis/pepinillo/feature/paywall/PaywallScreen.kt`

```
- Diseño Material 3 alineado con iOS
- Lista de features Pro (6 beneficios)
- Selector de plan (Monthly/Annual/Lifetime)
- Badge "MEJOR VALOR" en Annual
- Botón de compra con loading state
- Restore purchases link
- Terms & Privacy links (requerido por Google Play)
```

#### 3.2 - PaywallViewModel
**Archivo nuevo:** `android/app/src/main/java/dev/creapolis/pepinillo/feature/paywall/PaywallViewModel.kt`

```
- Carga productos de Google Play
- Maneja selección de plan
- Ejecuta compra via SubscriptionManager
- Verifica recibo con backend
- Actualiza SubscriptionRepository
- Maneja errores (billing unavailable, item already owned, etc.)
```

#### 3.3 - Navegación al Paywall
**Archivos a modificar:**
- `FocusScreen.kt` / `FocusViewModel.kt` - Al seleccionar modo Pro
- `TasksScreen.kt` / `TasksViewModel.kt` - Al exceder límite de tareas
- `DashboardScreen.kt` / `DashboardViewModel.kt` - Al intentar ver analytics >7 días
- `SettingsScreen.kt` - Botón "Upgrade to Pro"
- `Navigation.kt` - Agregar ruta `/paywall`

### Fase 4: Enforcement de Feature Gates

#### 4.1 - Focus Screen
- Lock icon en modos Flowtime y TimeBlock
- Al tap en modo bloqueado → mostrar Paywall
- Soundscape picker con locks en Pro soundscapes

#### 4.2 - Tasks Screen
- Contador visible "2/3 tareas" para Free users
- Bloquear botón "+" cuando hay 3 tareas
- Ocultar/bloquear opción de subtareas
- Ocultar/bloquear opción de recurrencia
- Mostrar upgrade prompt contextual

#### 4.3 - Dashboard Screen
- Mostrar datos de últimos 7 días para Free
- Blur/overlay en datos más antiguos con CTA "Unlock full history"
- Bloquear Weekly Review

#### 4.4 - Settings Screen
- Mostrar tier actual (Free/Pro)
- Botón prominente "Upgrade to Pro" si es Free
- Si es Pro: mostrar plan activo, fecha de renovación, manage subscription link
- Bloquear selección de temas extra

#### 4.5 - Widgets
- Solo FocusTimerWidget disponible en Free
- Otros widgets muestran "Upgrade to Pro" si se agregan

#### 4.6 - Wear OS
- Mostrar mensaje de upgrade si Free user abre Wear OS app
- Bloquear funcionalidad en watch si no es Pro

### Fase 5: Alineación iOS

#### 5.1 - Fixes necesarios en iOS
Estas features se anuncian como Pro en el paywall pero NO están gateadas:

1. **Analytics >7 días** - Agregar gate en `AnalyticsFeature`
2. **iCloud Sync** - Agregar gate en sync logic
3. **Widget customization** - Agregar gate
4. **Temas** - Agregar gate en theme selector
5. **Subtareas** - Agregar gate
6. **Recurrencia** - Agregar gate

#### 5.2 - Actualizar precios iOS
Cambiar StoreKit config para alinear con precios sugeridos:
- Monthly: $2.99 → $3.99
- Annual: $14.99 → $24.99
- Lifetime: $29.99 → $49.99

### Fase 6: Testing & QA

- Unit tests para FeatureGate
- Unit tests para SubscriptionManager (mock BillingClient)
- Integration tests con Google Play Billing test environment
- Test de upgrade/downgrade flows
- Test de grace period (suscripción expirada)
- Test de restore purchases
- Test offline behavior

---

## Flujos Críticos

### Flujo de Compra (Android)
```
1. Usuario toca feature Pro → showPaywall
2. Paywall carga productos de Google Play
3. Usuario selecciona plan → launchBillingFlow()
4. Google Play muestra purchase dialog
5. PurchasesUpdatedListener recibe resultado
6. Si OK → acknowledgePurchase()
7. Enviar token a backend → POST /billing/verify-receipt
8. Backend verifica con Google Play API
9. Backend actualiza user tier
10. App actualiza SubscriptionState
11. Feature se desbloquea inmediatamente
```

### Flujo de Restauración
```
1. Usuario toca "Restore Purchases"
2. queryPurchases(BillingClient.ProductType.SUBS + INAPP)
3. Para cada purchase activa → verify con backend
4. Actualizar SubscriptionState
```

### Flujo de Expiración
```
1. App inicia → queryPurchases()
2. Si no hay purchases activas Y cache dice isPro
3. Verificar con backend
4. Si backend confirma expirado → downgrade a Free
5. Grace period: 3 días después de expiración
```

---

## Orden de Ejecución Sugerido

1. **Fase 1** (Billing core) - Fundación necesaria
2. **Fase 2** (FeatureGate) - Lógica de negocio
3. **Fase 3** (Paywall UI) - Pantalla de conversión
4. **Fase 4** (Enforcement) - Aplicar restricciones en cada screen
5. **Fase 5** (iOS alignment) - Paridad entre plataformas
6. **Fase 6** (Testing) - Validación end-to-end

Cada fase puede implementarse y probarse independientemente.
