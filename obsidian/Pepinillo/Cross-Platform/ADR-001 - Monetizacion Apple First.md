---
tags:
  - adr
  - arquitectura
  - decision
aliases:
  - ADR-001
  - Monetizacion Apple First
platform: cross-platform
type: adr
status: accepted
adr-number: "001"
date: 2026-04-21
updated: 2026-04-21
---

# 📋 ADR-001: Adoptar monetizacion Apple-first con premium local separado de sync e IA

**Estado:** `accepted`
**Plataforma:** cross-platform
**Fecha:** 2026-04-21

---

## Contexto

El modelo comercial vigente mezclaba en un solo `Pro` tres cosas distintas: premium local, sync con costo recurrente y funciones de IA con costo variable. A la vez, iOS ya tiene iCloud/CloudKit como capacidad nativa, mientras que backend sync y creditos IA todavia requieren trabajo de enforcement y ledger. Tambien existe una restriccion comercial clara: no vender valor de Windows, Web o Linux antes de que esos clientes existan.

---

## Decision

**Decidimos:** lanzar una estrategia Apple-first con dos capas pagas.

- `Apple Unlock`: compra unica para premium local Apple + iCloud.
- `Pepinillo Everywhere`: suscripcion recurrente para backend sync + creditos IA.

`Everywhere` sera superconjunto de `Apple Unlock` en Apple. El lifetime legacy se grandfather a `Apple Unlock`, pero no otorga sync o IA perpetuos.

---

## Opciones consideradas

| Opcion | Pros | Contras |
|---|---|---|
| **Apple Unlock + Everywhere (elegida)** | separa costo local de costo recurrente, crea entry point mas accesible en Apple, hace sustentable sync e IA | agrega complejidad de rollout y capability split |
| Una sola suscripcion para todo | mensaje simple, menos complejidad tecnica al inicio | cobra recurrente por valor local Apple, reduce atractivo de compra unica |
| Apple Unlock + sync + add-on IA separado | maximiza monetizacion por capas | demasiado complejo para usuario y para enforcement inicial |

---

## Consecuencias

### Positivas

- La compra unica en Apple queda alineada con expectativa de usuarios del ecosistema.
- Sync e IA quedan financiados por una capa recurrente sostenible.
- iCloud deja de inflar la promesa de sync cross-platform.

### Negativas / Trade-offs

- Hay asimetria temporal con Android/Wear durante el rollout.
- Backend necesita capability model y ledger de creditos IA.
- watchOS/Wear OS necesitan nueva propagacion de entitlement.

### Neutrales / Notas

- RevenueCat sigue siendo valido como stack, pero el naming `pro` / `premium` pasa a ser legacy.
- La expansion comercial a desktop/web queda explicitamente postergada hasta tener clientes reales.

---

## Referencias

- [[Monetizacion y Entitlements]]
- [[../iOS/Arquitectura General]]
- [[../Backend/Autenticacion & Suscripciones]]
