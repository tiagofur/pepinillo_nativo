#ios #dominio #settings

# Módulo Settings

> [!abstract] Resumen
> Configuración del usuario: perfil, negocio (logo, color de marca, plantilla de contrato), defaults de contratos, suscripción via RevenueCat, biometría, y páginas legales.

---

## Pantallas

| Pantalla | Descripción |
|----------|-------------|
| `SettingsView` | Pantalla principal de configuración |
| `EditProfileView` | Edición de nombre, email, avatar |
| `ChangePasswordView` | Cambiar contraseña |
| `BusinessSettingsView` | Nombre negocio, logo, color, facturación |
| `ContractDefaultsView` | Depósito %, cancelación, reembolso, template |
| `PricingView` | Planes y precios (RevenueCat) |
| `AboutView` | Versión, info de Creapolis |

---

## Secciones

### Perfil

| Campo | Editable |
|-------|----------|
| Nombre | Sí |
| Email | Solo lectura |
| Avatar | Generado por hash / imagen |

### Negocio

| Campo | Descripción |
|-------|-------------|
| Nombre del negocio | Para PDFs y contratos |
| Logo | Imagen del negocio |
| Color de marca | Color personalizado |
| Requiere factura | Toggle default |

### Defaults de Contrato

| Campo | Default |
|-------|---------|
| Depósito % | Configurable |
| Días de cancelación | Configurable |
| Reembolso % | Configurable |
| Template de contrato | Texto base personalizable |

### Suscripción

| Plan | Features |
|------|----------|
| Basic | Limitado (3 eventos/mes, 50 clientes, 20 productos) |
| Pro | Extendido |
| Premium | Ilimitado |
| Business | Todo + features enterprise |

> [!important] RevenueCat
> La gestión de suscripciones usa RevenueCat SDK. La key se inyecta via `REVENUECAT_PUBLIC_API_KEY` (Info.plist/build settings) y debe definirse antes de App Store submission.

### Seguridad

| Opción | Descripción |
|--------|-------------|
| Cambiar contraseña | Validación de password actual |
| Bloqueo biométrico | Toggle Face ID / Touch ID |

### Legal

| Enlace | URL |
|--------|-----|
| Términos de uso | `https://creapolis.dev/terms-of-use/` |
| Política de privacidad | `https://creapolis.dev/privacy-policy/` |

---

## Relaciones

- [[Autenticación]] — cambio password, biometría, logout
- [[Design System]] — sigue tema del sistema (no hay selector manual)
- [[Módulo Eventos]] — defaults de contrato
- [[Sistema de PDFs]] — datos del negocio en documentos
