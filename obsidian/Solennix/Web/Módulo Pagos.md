# Módulo Pagos

#web #pagos #dominio

> [!abstract] Resumen
> Sistema de registro de pagos vinculados a eventos. Soporte para pagos parciales con tracking de saldo pendiente. La app no intermediar pagos entre organizadores y sus clientes — los pagos son registros manuales de lo cobrado fuera de la app. Stripe se usa exclusivamente para las suscripciones Pro.

---

## Componentes

| Componente | Ubicación | Función |
|-----------|-----------|---------|
| **Payments** | `Events/components/Payments.tsx` | Formulario RHF+Zod para registrar pagos + lista de pagos existentes |

## Entidad

```typescript
interface Payment {
  id: string;
  event_id: string;
  amount: number;
  payment_date: string;
  payment_method: string;   // "Efectivo", "Transferencia", "Tarjeta", etc.
  status: string;
  notes?: string;
}
```

## Funcionalidades

- **Registro manual** — Monto, fecha, método de pago, notas
- **Depósito sugerido** — Calcula automáticamente el % de depósito configurado
- **Saldo pendiente** — Total del evento menos pagos realizados
- **Historial** — Lista de todos los pagos con fecha y método

## Servicios

### paymentService (pagos manuales)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `getByEventId(id)` | GET /payments?event_id= | Pagos de un evento |
| `create(data)` | POST /payments | Registrar pago |
| `update(id, data)` | PUT /payments/:id | Actualizar pago |
| `delete(id)` | DELETE /payments/:id | Eliminar pago |

### subscriptionService (suscripciones — solo para plan Pro del usuario)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `getStatus()` | GET /subscription/status | Estado actual de la suscripción |
| `createCheckoutSession()` | POST /subscription/checkout | Iniciar pago de suscripción |
| `createPortalSession()` | POST /subscription/portal | Abrir portal de gestión Stripe |

## Relaciones

- [[Módulo Eventos]] — Pagos vinculados a eventos
- [[Capa de Servicios]] — paymentService, subscriptionService
