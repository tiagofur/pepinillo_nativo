# Monetización — Pepinillo (iOS + Android)

**Versión:** 1.0
**Fecha:** 2026-03-20
**Alcance:** Documento unificado de monetización para ambas plataformas
**Fuente autoritativa de precios:** `PLAN_FREE_PRO_TIERS.md`

---

## 1. Modelo de Negocio

**Freemium con suscripción.** El mismo modelo aplica en ambas plataformas (iOS y Android).

El usuario obtiene una experiencia funcional y útil en el tier gratuito — suficiente para validar el valor de la app — pero con limitaciones estratégicas que motivan la conversión a Pro. No se busca frustrar al usuario, sino demostrar el valor premium.

**Posicionamiento de precio:** Tier premium de productividad ($25-50/año), no el mercado de timers gratis ($2-5). Competimos en la liga de Things 3, Fantastical y Craft.

---

## 2. Tier FREE (Gratuito)

| Feature | Límite Free | Justificación |
|---------|-------------|---------------|
| Modos de enfoque | Pomodoro + Chrono/Stopwatch (2 de 4) | Los 2 más básicos; cubren el caso de uso casual |
| Tareas activas | 3 tareas máximo | Suficiente para probar, insuficiente para usuarios activos |
| Subtareas | NO disponible | Alto valor percibido, bajo costo de desarrollo |
| Tareas recurrentes | NO disponible | Solo Pro |
| Soundscapes | 4 básicos: Rain, Forest, Café, White Noise | Suficiente para experimentar el valor |
| Analytics | Solo hoy + últimos 7 días | Motiva upgrade para historial completo |
| Widgets | 1 widget básico (timer) | Los demás son Pro |
| Temas | Solo tema Default | Restricción estética que motiva upgrade |
| Sesiones diarias | Ilimitadas | NO limitar sesiones — frustra sin convertir |
| Historial | 7 días | Después se pierde; motiva Pro para retención de datos |
| Sync/Cloud | NO disponible (solo local) | Sync como diferenciador Pro |
| Watch/Wear OS | NO disponible | Diferenciador fuerte para power users |
| Export de datos | NO disponible | Solo Pro |

---

## 3. Tier PRO

| Feature | Pro |
|---------|-----|
| Modos de enfoque | Todos: Pomodoro, Flowtime, Time Block, Chrono/Stopwatch |
| Tareas | Ilimitadas + subtareas + recurrencia |
| Soundscapes | 8 total: Rain, Forest, Café, White Noise + Binaural Beats, Lo-fi, Ocean, Fireplace |
| Analytics | Historial completo + Weekly Review + Monthly Review + AI Reports |
| Widgets | Todos (Timer, Stats, Tasks, Lock Screen, Quick Settings) |
| Temas | Todos los temas disponibles (incluido Liquid Glass en iOS 26, Material You en Android) |
| Sync/Cloud | Sync completo entre dispositivos (CloudKit en iOS, Backend Go en Android) |
| Watch/Wear OS | App completa en Apple Watch y Wear OS |
| Export de datos | CSV y PDF |
| Streak Protection | 1 skip gratuito por semana |

---

## 4. Precios (DEFINITIVOS)

> **Fuente autoritativa:** `PLAN_FREE_PRO_TIERS.md` — estos precios reemplazan cualquier otra referencia.

### Mercado Global (US/EU/Tier 1)

| Plan | Precio | Equivalente mensual | Ahorro |
|------|--------|---------------------|--------|
| Monthly | **$3.99/mes** | $3.99 | — |
| Annual | **$24.99/año** | $2.08 | 48% |
| Lifetime | **$49.99** | — | — |

### LATAM (MX/CO/AR/BR/CL/PE)

| Plan | Precio | Equivalente mensual | Ahorro |
|------|--------|---------------------|--------|
| Monthly | **$1.99/mes** | $1.99 | — |
| Annual | **$12.99/año** | $1.08 | 46% |
| Lifetime | **$29.99** | — | — |

### Justificación de precios

- **$3.99 vs $4.99**: Barrera psicológica menor. $3.99 está en el sweet spot para apps de productividad.
- **Annual a 48% descuento**: Fuerte incentivo para suscripción anual (mayor LTV).
- **Lifetime a $49.99**: Razonable para early adopters; no tan bajo que canibalice suscripciones.
- **LATAM ~50% del global**: Paridad de poder adquisitivo. Ambas tiendas soportan precios regionalizados.

### Discrepancias a corregir

| Plataforma | Precios actuales (implementados) | Precios objetivo |
|------------|----------------------------------|------------------|
| iOS (StoreKit) | Monthly $2.99, Annual $14.99, Lifetime $29.99 | Monthly $3.99, Annual $24.99, Lifetime $49.99 |
| Android | No implementado aún | Monthly $3.99, Annual $24.99, Lifetime $49.99 |

**Acción requerida:** Actualizar StoreKit configuration en iOS para alinear con los precios definitivos.

---

## 5. Implementación por Plataforma

### 5.1 iOS

| Aspecto | Detalle |
|---------|---------|
| Framework | RevenueCat SDK v5+ (wrapping StoreKit 2 nativo) |
| Productos | `monthly`, `annual`, `lifetime` via RevenueCat Offerings/Packages |
| Entitlement | `pro` (unificado en RevenueCat) |
| User ID | Integrado con Sign in with Apple flow via `logIn(userId)` |
| Verificación | Server-side via Go backend (`POST /billing/verify-receipt` y RevenueCat REST API) |
| Restore | RevenueCat `logIn()` + `entitlements` property |
| Cache local | RevenueCat SDK cachea entitlements automáticamente |
| Grace period | Automáticamente manejado por RevenueCat según configuración en App Store Connect |
| Webhooks | Backend recibe eventos via `POST /api/v1/webhooks/revenuecat` |

### 5.2 Android

| Aspecto | Detalle |
|---------|---------|
| Framework | Google Play Billing Library 7 (BillingClient 7.x) |
| Singleton | `SubscriptionManager` con retry logic |
| Verificación | Server-side via Go backend (`POST /billing/verify-receipt`) |
| Restore | `queryPurchases(BillingClient.ProductType.SUBS + INAPP)` |
| Cache local | DataStore con `isPro`, `tier`, `expirationDate` (confiar en cache por 7 días sin internet) |
| State | `StateFlow<SubscriptionState>` observable |
| DI | Hilt module (`@Singleton` scope) |

### 5.3 Product IDs

**iOS (StoreKit):**
```
com.pepinillo.app.pro.monthly
com.pepinillo.app.pro.annual
com.pepinillo.app.pro.lifetime
```

**Android (Google Play):**
```
com.pepinillo.app.pro.monthly    → $3.99/mes
com.pepinillo.app.pro.annual     → $24.99/año
com.pepinillo.app.pro.lifetime   → $49.99 (in-app product, no subscription)
```

### 5.4 Backend

- **Endpoint de verificación:** `POST /billing/verify-receipt`
  - Soporta verificación de Google Play, App Store, y RevenueCat
  - Mapeo de tiers: `free`, `pro_monthly`, `pro_yearly`, `lifetime`
  - Actualiza el tier del usuario en base de datos tras verificación exitosa

- **RevenueCat integration:**
  - Webhook endpoint: `POST /api/v1/webhooks/revenuecat` (recibe eventos de ciclo de vida de suscripción)
  - REST API client: verifica entitlements via RevenueCat API
  - Eventos soportados: purchase, renewal, cancellation, expiration, billing issues

- **Fallback:** Direct App Store/Google Play verification si RevenueCat no disponible

---

## 6. Feature Gating (Enforcement)

### 6.1 Mecanismos de gating

| Mecanismo | Descripción |
|-----------|-------------|
| Lock icons | Icono de candado en features Pro (modos Flowtime/TimeBlock, soundscapes premium) |
| Task counter | Contador visible "2/3 tareas" para usuarios Free; bloquear botón "+" al llegar a 3 |
| Blur overlay | Datos de analytics >7 días con blur/overlay y CTA "Desbloquea historial completo" |
| Upgrade prompts | Prompts contextuales en puntos naturales de fricción |
| Free trial | 7 días de prueba gratuita de Pro |

### 6.2 Gating por pantalla

| Pantalla | Restricción Free |
|----------|-----------------|
| Focus Screen | Lock en modos Flowtime y TimeBlock; lock en soundscapes premium |
| Tasks Screen | Máximo 3 tareas; sin subtareas; sin recurrencia; upgrade prompt contextual |
| Dashboard/Analytics | Solo últimos 7 días; blur en historial antiguo; Weekly/Monthly Review bloqueado |
| Settings | Mostrar tier actual; botón "Upgrade to Pro"; bloquear temas extra |
| Widgets | Solo widget de timer disponible; otros muestran "Upgrade to Pro" |
| Watch/Wear OS | Mensaje de upgrade si usuario Free abre app en reloj |

### 6.3 Problemas actuales de gating (a corregir)

**iOS — Features anunciadas como Pro pero NO gateadas:**

| Feature | Estado actual | Acción requerida |
|---------|---------------|------------------|
| Analytics >7 días | Accesible para todos | Agregar gate en `AnalyticsFeature` |
| iCloud Sync | Funciona para todos | Agregar gate en sync logic |
| Widgets adicionales | Accesibles sin restricción | Agregar gate en widget configuration |
| Temas | Todos disponibles | Agregar gate en theme selector |
| Subtareas | Accesibles para todos | Agregar gate en task creation |
| Recurrencia | Accesible para todos | Agregar gate en task creation |

**Android — Sin feature gating implementado:**

| Componente | Estado |
|------------|--------|
| FeatureGate service | No existe |
| Paywall screen | No existe |
| SubscriptionManager | No existe |
| UI locks/restrictions | No existen |

---

## 7. Flujos de Compra

### 7.1 Flujo de compra (aplica a ambas plataformas)

```
 1. Usuario toca feature Pro o botón "Upgrade"
 2. Se muestra Paywall con lista de beneficios Pro
 3. Paywall carga productos desde la tienda (StoreKit 2 / Google Play)
 4. Usuario selecciona plan (Monthly / Annual / Lifetime)
 5. Badge "MEJOR VALOR" destacado en plan Annual
 6. Usuario confirma compra
 7. Tienda muestra diálogo de pago nativo
 8. App recibe confirmación de compra
 9. App envía token/recibo al backend → POST /billing/verify-receipt
10. Backend verifica con la API de la tienda correspondiente
11. Feature se desbloquea inmediatamente; UI se actualiza
```

### 7.2 Flujo de restauración

```
1. Usuario toca "Restaurar Compras" en Paywall o Settings
2. App consulta compras activas en la tienda
3. Para cada compra activa → verificar con backend
4. Actualizar estado de suscripción localmente
```

### 7.3 Flujo de expiración

```
1. App inicia → consulta compras activas en la tienda
2. Si no hay compras activas Y cache local dice isPro:
3.   Verificar con backend
4.   Si backend confirma expirado → downgrade a Free
5.   Grace period: 3 días después de expiración antes de revocar acceso
```

### 7.4 Elementos requeridos en Paywall

- Lista de 6+ beneficios Pro
- Selector de plan (Monthly / Annual / Lifetime)
- Badge "MEJOR VALOR" en plan Annual
- Botón de compra con loading state
- Link "Restaurar Compras"
- Links a Terms of Use y Privacy Policy (requerido por ambas tiendas)
  - Terms: https://creapolis.dev/terms-of-use/
  - Privacy: https://creapolis.dev/privacy-policy/

---

## 8. Hooks de Conversión

Triggers psicológicos que motivan el upgrade de Free a Pro:

| Hook | Mecanismo | Impacto esperado |
|------|-----------|------------------|
| **Solo 2 de 4 modos gratis** | "Desbloquea Flowtime y Time Block" es el trigger principal de conversión | Alto — Flowtime atrae a usuarios que rebotaron de Pomodoro |
| **Límite de 3 tareas** | Presión natural de upgrade para usuarios activos que necesitan más organización | Alto — crea fricción diaria |
| **Stats básicas vs completas** | Ver solo 7 días crea FOMO del historial; blur en datos antiguos con CTA | Medio-alto — usuarios data-driven quieren ver tendencias |
| **Watch/Wear OS como aspiración** | "Controla tu focus desde tu reloj" — feature aspiracional para power users | Medio — nichos pero alto intent de compra |
| **Variedad de temas** | Un solo tema vs todos los temas (Liquid Glass, Material You, etc.) | Medio — motivación estética |
| **Sin subtareas ni recurrencia** | Usuarios que organizan proyectos complejos necesitan estructura | Medio-alto — diferenciador funcional |
| **Sin sync/cloud** | Riesgo de perder datos motiva backup; multi-device requiere sync | Medio — crece con el tiempo |
| **Sin export** | Usuarios profesionales necesitan reportes CSV/PDF | Bajo-medio — nicho pero valioso |

### Estrategia de prompts

- **No intrusivos**: Mostrar upgrade solo cuando el usuario intenta usar una feature Pro
- **Contextuales**: El prompt explica el beneficio específico que se desbloquea
- **Frecuencia controlada**: Máximo 1 prompt por sesión (no spamear)
- **Free trial**: Ofrecer 7 días gratis de Pro en el primer intento de upgrade

---

## 9. Métricas de Monetización

### 9.1 Objetivos de conversión

| Métrica | Target (30 días) | Target (90 días) | Stretch |
|---------|-------------------|-------------------|---------|
| Conversión Free → Pro | >= 6% | >= 8% | >= 10% |
| Trial-to-Paid | — | >= 40% | >= 50% |
| Churn mensual | — | < 8% | < 5% |
| ARPU (usuarios de pago) | >= $3.50/mes | >= $3.50/mes | >= $4.50/mes |

### 9.2 Proyecciones de revenue (conservadoras)

| Escenario | MAU | Conversión | ARPU | MRR |
|-----------|-----|-----------|------|-----|
| Base (Mes 6) | 8K | 6% | $3.50 | $1,680 |
| Bueno (Mes 6) | 15K | 8% | $3.80 | $4,560 |
| Stretch (Mes 12) | 30K | 10% | $4.00 | $12,000 |

### 9.3 Métricas a trackear

| Métrica | Herramienta |
|---------|-------------|
| Conversión por plan (monthly/annual/lifetime) | Backend analytics |
| Revenue por región (Global vs LATAM) | App Store Connect / Google Play Console |
| Paywall view-to-purchase rate | In-app analytics |
| Feature más intentada por Free users (trigger de conversión) | In-app analytics |
| Tiempo promedio Free → Pro | Backend analytics |
| Churn por cohorte | Backend analytics |
| LTV por plan | Calculado (ARPU / churn rate) |

---

## Apéndice: Comparativa de Competidores

| App | Monthly | Annual | Lifetime |
|-----|---------|--------|----------|
| Forest | — | $19.99/yr | $3.99 (one-time) |
| Focus Bear | $4.99/mo | $29.99/yr | — |
| Tide | $2.99/mo | $14.99/yr | $49.99 |
| Be Focused Pro | — | — | $4.99 |
| Session | $4.99/mo | $29.99/yr | $79.99 |
| **Pepinillo** | **$3.99/mo** | **$24.99/yr** | **$49.99** |

Pepinillo se posiciona competitivamente: más barato que Session y Focus Bear, pero con más features que Tide y Forest. El pricing LATAM (~50% del global) es un diferenciador único en el mercado.
