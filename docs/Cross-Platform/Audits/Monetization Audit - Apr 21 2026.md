---
tags:
  - cross-platform
  - audit
  - monetization
aliases:
  - Monetization Audit 2026-04-21
platform: cross-platform
type: audit
doc_role: audit
status: historical
date: 2026-04-21
updated: 2026-04-27
source: docs/Monetization Audit - Apr 21 2026.md
---

# Pepinillo – Monetization Audit
**Date:** 21 April 2026  
**Reference:** ADR-001 + Monetización y Entitlements (updated 21.04.2026)

---

## TL;DR

Hay **1 blocker crítico** que hay que resolver antes que nada (las claves de API revocadas en RevenueCat), y luego una serie de tareas de configuración pendientes para completar la migración al modelo Apple-First.

---

## 🔴 BLOCKER — RevenueCat: claves de API revocadas

**Problema:** El 7 de abril de 2026 se crearon claves nuevas en App Store Connect para ambas integraciones, pero las claves antiguas no fueron reemplazadas en RevenueCat. RevenueCat sigue usando las claves revocadas → "Credentials need attention" → todos los productos iOS muestran "Could not check".

| Tipo | Clave activa (App Store Connect) | Clave en RevenueCat (revocada) |
|------|----------------------------------|-------------------------------|
| App Store Connect API | `22YZT9D55J` ✅ activa desde hoy | `RH5C2R5T38` ❌ revocada Apr 7 |
| In-App Purchase | `Z95PS2LD73` ✅ activa desde Apr 7 | `9WUALPKPH4` ❌ revocada Apr 7 |

**Acción inmediata:**
1. Descargar el `.p8` de cada clave activa desde App Store Connect → Users and Access → Integrations → Keys (si no lo tienes guardado, las claves nuevas solo se pueden descargar una vez — si ya expiró la descarga, hay que revocar y crear de nuevo).
2. En RevenueCat → Apps → Pepinillo iOS → actualizar ambas claves con los nuevos Key IDs y archivos `.p8`.
3. Verificar que los 3 productos iOS dejen de mostrar "Could not check".

---

## 🟡 Apple Developer — Productos en Draft con Metadata incompleta

Los 3 productos existen pero están en estado **Draft** y con **Missing Metadata** — no se pueden vender hasta completarlos.

| Product ID | Nombre actual | Tipo | Estado |
|------------|--------------|------|--------|
| `com.pepinillo.app.pro.lifetime` | Pro Lifetime | Non-Consumable | Draft ❌ |
| `com.pepinillo.app.pro.monthly` | Pro Monthly | Auto-Renewable Sub (1 mes) | Missing Metadata ❌ |
| `com.pepinillo.app.pro.annual` | Pro Annual | Auto-Renewable Sub (1 año) | Missing Metadata ❌ |

**Acciones pendientes:**
- Completar localización, precio y screenshot de cada producto en App Store Connect.
- Renombrar al vocabulario canónico del ADR-001:
  - `Pro Lifetime` → **"Apple Unlock"**
  - `Pro Monthly` → **"Everywhere Monthly"**
  - `Pro Annual` → **"Everywhere Annual"**
- Enviar para revisión de Apple (necesario antes de poder vender).

> **Nota:** El Bundle ID `com.pepinillo.app` y los 3 Product IDs ya existen — no hay que crearlos de cero.

---

## 🟡 RevenueCat — Entitlements (outdated)

Actualmente solo existe 1 entitlement genérico:

| Identifier | Display Name | Productos |
|-----------|-------------|-----------|
| `premium` | Premium Suscripción | 8 productos |

Según el ADR-001, el modelo nuevo requiere entitlements granulares por capacidad:

| Entitlement nuevo | Descripción |
|------------------|-------------|
| `local_premium` | Acceso a features premium locales (Apple Unlock) |
| `apple_cloud_sync` | iCloud sync (Apple Unlock) |
| `backend_sync` | Sync backend (Everywhere) |
| `ai_credits_monthly` | Créditos IA mensuales (Everywhere) |

**Acciones:** Crear los 4 entitlements nuevos y asociar los productos correspondientes. El entitlement `premium` puede mantenerse durante la transición para compatibilidad con usuarios legacy.

---

## 🟡 RevenueCat — Offerings (legacy)

Solo existe 1 offering:

| Identifier | Display Name | Packages | Creado |
|------------|-------------|----------|--------|
| `default` | Default Offering | 3 packages | Feb 1, 2024 |

Los packages siguen usando los identificadores legacy (`$rc_lifetime`, `$rc_monthly`, `$rc_annual`).

**Acciones:** Crear offerings nuevos con el vocabulario canónico:
- **"Apple Unlock"** (package con `com.pepinillo.app.pro.lifetime`)
- **"Pepinillo Everywhere"** (packages con `.monthly` y `.annual`)

---

## 🟡 RevenueCat — Producto Android huérfano

| Product ID | Status | Entitlement |
|------------|--------|-------------|
| `pepinillo_premium:pepinillo-month` | Not published | ⚠️ Sin entitlement |

Este producto no está publicado y no tiene entitlement asignado. Es un residuo de la configuración inicial (Feb 2, 2024). Hay que eliminarlo o asignarle un entitlement si tiene algún propósito.

---

## 🟡 App Store Connect — App en "Developer Rejected"

La versión iOS 1.0 fue rechazada por el propio developer (auto-rechazo). No hay versión publicada en la App Store. Esto es independiente de la configuración de monetización, pero bloquea las ventas reales hasta que se envíe y apruebe una nueva versión.

---

## 🟡 RevenueCat — Server-to-Server Notifications

Estado: **"No notifications received"**. Sin S2S notifications, RevenueCat no puede procesar renovaciones, cancelaciones ni reembolsos automáticamente.

**Acción:** Configurar la URL de webhook de RevenueCat en App Store Connect → My Apps → App Information → App Store Server Notifications.

---

## ✅ Lo que SÍ está bien

- Los 3 Product IDs del ADR-001 **ya existen** en Apple Developer y en RevenueCat — no hay que crearlos de cero.
- La arquitectura RevenueCat como billing stack es correcta.
- Los productos Android (excl. el huérfano) están Published con entitlement asignado.
- Bundle ID `com.pepinillo.app` y App ID `6760687424` ya configurados.

---

## Orden de ejecución recomendado

```
1. [AHORA]    Actualizar claves API en RevenueCat → desbloquea "Could not check"
2. [AHORA]    Completar metadata en App Store Connect → sacar productos de Draft
3. [ESTA SEMANA] Crear entitlements nuevos en RevenueCat
4. [ESTA SEMANA] Crear offerings nuevos (Apple Unlock / Everywhere)
5. [ESTA SEMANA] Configurar S2S Notifications
6. [CUANDO ESTÉ LISTA LA APP] Enviar nueva versión iOS a App Store
7. [OPCIONAL] Limpiar producto Android huérfano
```
