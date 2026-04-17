# Mostrar Plataforma de Origen de Suscripción

## Problema

El usuario puede suscribirse desde **3 plataformas distintas**: iOS (App Store), Android (Google Play) o Web (Stripe). Cada plataforma tiene su propio flujo de cancelación:

| Plataforma | Proveedor | Cómo se cancela |
|------------|-----------|-----------------|
| iOS | Apple (App Store) | Settings > Apple ID > Suscripciones |
| Android | Google (Play Store) | Play Store > Pagos y suscripciones |
| Web | Stripe | Portal de pagos (Stripe Customer Portal) |

**Si el usuario no sabe en qué plataforma se suscribió, no sabe DÓNDE cancelar.**

Hoy el backend ya almacena y devuelve el campo `provider` (`stripe` | `apple` | `google`), pero **ninguna plataforma lo muestra al usuario**.

## Solución

En la pantalla de suscripción de CADA plataforma, mostrar:

1. **Badge/etiqueta** indicando la plataforma de origen: "Suscrito vía App Store / Google Play / Web"
2. **Instrucciones de cancelación** contextuales según el provider
3. **Botón de acción** que lleve al lugar correcto para gestionar/cancelar

## Estado Actual por Plataforma

### Backend ✅ Listo

- `GET /api/subscriptions/status` ya devuelve `provider` en el objeto `subscription`
- Valores posibles: `stripe`, `apple`, `google`
- No requiere cambios

```json
{
  "plan": "pro",
  "has_stripe_account": true,
  "subscription": {
    "status": "active",
    "provider": "stripe",
    "current_period_end": "2026-05-06T00:00:00Z",
    "cancel_at_period_end": false
  }
}
```

### Web 🔧 Cambio menor

**Archivo:** `web/src/pages/Settings.tsx`

- Ya consume `subStatus.subscription` pero NO muestra `provider`
- El botón "Gestionar" solo aparece si `has_stripe_account` — correcto para Stripe
- **Falta:** Si el provider es `apple` o `google`, mostrar instrucciones de cancelación de esa plataforma en vez del botón de Stripe Portal

**Cambios necesarios:**
1. Mostrar badge con plataforma de origen debajo del nombre del plan
2. Si `provider === 'stripe'` → botón "Gestionar" (Stripe Portal) — ya existe
3. Si `provider === 'apple'` → mensaje: "Suscripción gestionada desde App Store. Para cancelar, abrí Configuración > Apple ID > Suscripciones en tu iPhone/iPad"
4. Si `provider === 'google'` → mensaje: "Suscripción gestionada desde Google Play. Para cancelar, abrí Play Store > Pagos y suscripciones"

### iOS 🔧 Cambio menor

**Archivos:**
- `ios/Packages/SolennixFeatures/.../Settings/Views/SubscriptionView.swift`
- `ios/Packages/SolennixNetwork/.../SubscriptionManager.swift`

**Estado actual:**
- `SubscriptionView` muestra plan y botón "Administrar suscripción" que abre App Store
- NO muestra de dónde viene la suscripción
- Si el usuario se suscribió por Stripe (web), el botón de App Store no sirve para cancelar

**Cambios necesarios:**
1. Obtener `provider` del endpoint `/api/subscriptions/status`
2. Mostrar badge: "Suscrito vía App Store / Google Play / Web"
3. Si `provider === 'apple'` → botón "Administrar suscripción" (ya existe, abre App Store)
4. Si `provider === 'stripe'` → mensaje: "Tu suscripción fue realizada desde la web. Para cancelar, ingresá a solennix.com > Configuración > Suscripción"
5. Si `provider === 'google'` → mensaje: "Tu suscripción fue realizada desde Android. Para cancelar, abrí Google Play > Pagos y suscripciones"

### Android 🔧 Cambio menor

**Archivos:**
- `android/feature/settings/.../ui/SubscriptionScreen.kt`
- `android/feature/settings/.../viewmodel/SubscriptionViewModel.kt`

**Estado actual:**
- `SubscriptionScreen` muestra plan actual con badge de estado
- FAQ menciona cancelar desde Google Play
- NO muestra de dónde viene la suscripción

**Cambios necesarios:**
1. Obtener `provider` del endpoint `/api/subscriptions/status`
2. Mostrar badge: "Suscrito vía App Store / Google Play / Web"
3. Si `provider === 'google'` → botón "Administrar suscripción" (abre Google Play subscriptions)
4. Si `provider === 'stripe'` → mensaje: "Tu suscripción fue realizada desde la web. Para cancelar, ingresá a solennix.com > Configuración > Suscripción"
5. Si `provider === 'apple'` → mensaje: "Tu suscripción fue realizada desde iOS. Para cancelar, abrí Configuración > Apple ID > Suscripciones en tu iPhone/iPad"

## Diseño UI

### Badge de plataforma

Ubicación: debajo del nombre del plan, junto al badge de estado.

```
┌─────────────────────────────────────┐
│  Plan Pro                           │
│  ● Activo    📱 Suscrito vía Web    │
│  Próxima renovación: 6 mayo 2026   │
└─────────────────────────────────────┘
```

### Colores del badge por provider

| Provider | Icono | Texto | Color badge |
|----------|-------|-------|-------------|
| `apple` | 🍎 | Suscrito vía App Store | Gray subtle |
| `google` | ▶️ | Suscrito vía Google Play | Gray subtle |
| `stripe` | 🌐 | Suscrito vía Web | Gray subtle |

### Mensaje de cancelación cross-platform

Cuando el provider NO coincide con la plataforma actual, mostrar un `InfoBanner`:

```
ℹ️ Tu suscripción fue realizada desde [plataforma].
   Para gestionarla o cancelarla, [instrucciones específicas].
```

## Orden de Implementación

1. **Web** — cambio más simple, solo UI (el dato ya llega)
2. **iOS** — necesita consumir `provider` del endpoint
3. **Android** — similar a iOS

## Checklist

- [x] Web: mostrar badge de provider en tab Suscripción
- [x] Web: instrucciones de cancelación condicionales por provider
- [x] iOS: leer `provider` desde endpoint status
- [x] iOS: mostrar badge de provider en SubscriptionView
- [x] iOS: instrucciones de cancelación condicionales por provider
- [x] Android: leer `provider` desde endpoint status
- [x] Android: mostrar badge de provider en SubscriptionScreen
- [x] Android: instrucciones de cancelación condicionales por provider
- [x] PRD: actualizar 04_MONETIZATION.md y 11_CURRENT_STATUS.md
- [ ] Tests: verificar que UI muestra provider correcto en cada plataforma
