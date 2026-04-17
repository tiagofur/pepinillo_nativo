#android #dominio #settings

# Módulo Settings

> [!abstract] Resumen
> Configuración del usuario: perfil, negocio, defaults de contrato, tema visual, suscripción, biometría, y páginas legales.

---

## Pantallas

| Pantalla | Archivo | Descripción |
|----------|---------|-------------|
| `SettingsScreen` | `feature/settings/ui/` | Pantalla principal de configuración |
| `ProfileScreen` | `feature/settings/ui/` | Edición de perfil |
| `BusinessSettingsScreen` | `feature/settings/ui/` | Configuración del negocio |
| `ContractDefaultsScreen` | `feature/settings/ui/` | Defaults para contratos |
| `PricingScreen` | `feature/settings/ui/` | Planes y precios |
| `ChangePasswordScreen` | `feature/settings/ui/` | Cambiar contraseña |

---

## Secciones

### Perfil de Usuario

| Campo | Editable |
|-------|----------|
| Nombre | Sí |
| Email | Solo lectura |
| Foto de perfil | Parcialmente (avatar generado, upload incompleto) |

### Configuración del Negocio

| Campo | Descripción |
|-------|-------------|
| Nombre del negocio | Aparece en PDFs y contratos |
| Logo | Imagen del negocio |
| Color de marca | Color personalizado para documentos |
| Template de contrato | Texto base para contratos |

### Defaults de Contrato

| Campo | Default | Descripción |
|-------|---------|-------------|
| Depósito % | Configurable | Porcentaje de anticipo |
| Días de cancelación | Configurable | Días antes para cancelar sin penalidad |
| Reembolso % | Configurable | Porcentaje de reembolso por cancelación |

### Apariencia

| Opción | Valores |
|--------|---------|
| Tema | Claro / Oscuro / Sistema |

### Suscripción

| Plan | Precio | Features |
|------|--------|----------|
| Básico | Gratis | Features limitadas |
| Pro | — | Features extendidas |
| Premium | — | Todas las features |

> [!warning] Play Billing incompleto
> RevenueCat SDK está configurado pero el flujo de compra no está implementado. `PricingScreen` tiene `onClick = { /* TODO: Implement Play Billing */ }`.

### Seguridad

| Opción | Descripción |
|--------|-------------|
| Cambiar contraseña | Flujo con validación de password actual |
| Bloqueo biométrico | Toggle para requerir biometría al abrir app |

### Legal

| Enlace | URL |
|--------|-----|
| Términos de uso | `https://creapolis.dev/terms-of-use/` |
| Política de privacidad | `https://creapolis.dev/privacy-policy/` |
| Acerca de | Versión de la app e info de Creapolis |

---

## Archivos Clave

| Archivo | Ubicación |
|---------|-----------|
| `SettingsScreen.kt` | `feature/settings/ui/` |
| `SettingsViewModel.kt` | `feature/settings/viewmodel/` |

---

## Relaciones

- [[Autenticación]] — cambio de password, biometría, logout
- [[Design System]] — selección de tema
- [[Módulo Eventos]] — defaults de contrato usados en EventForm
- [[Sistema de PDFs]] — datos del negocio en documentos generados
