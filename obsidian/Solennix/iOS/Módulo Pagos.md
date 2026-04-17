#ios #dominio #pagos

# Módulo Pagos

> [!abstract] Resumen
> Registro de pagos parciales y totales vinculados a eventos. Seguimiento de saldo pendiente, métodos de pago, y generación de reporte PDF.

---

## Campos del Pago

| Campo | Tipo | Requerido |
|-------|------|-----------|
| Evento | Selector | Sí |
| Monto | Decimal | Sí |
| Fecha de pago | DatePicker | Sí |
| Método de pago | Picker (efectivo, transferencia, tarjeta, otro) | No |
| Notas | TextArea | No |

---

## Cálculos Financieros

| Métrica | Fórmula |
|---------|---------|
| Total del evento | Σ(productos × precio - descuento) + Σ(extras) + impuesto |
| Total pagado | Σ(pagos del evento) |
| Saldo pendiente | Total - Pagado |
| Depósito requerido | Total × depositPercent% |

---

## Flujo

Los pagos se registran desde el detalle del evento:

```mermaid
sequenceDiagram
    participant UI as EventDetailView
    participant VM as EventDetailViewModel
    participant API as APIClient

    UI->>VM: addPayment(amount, date, method)
    VM->>API: POST /payments
    API-->>VM: Payment creado
    VM-->>UI: Actualiza saldo y lista de pagos
```

---

## Relaciones

- [[Módulo Eventos]] — pagos vinculados a eventos
- [[Módulo Dashboard]] — KPIs financieros
- [[Sistema de PDFs]] — reporte de pagos
