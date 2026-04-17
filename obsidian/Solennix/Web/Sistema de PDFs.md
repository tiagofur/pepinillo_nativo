# Sistema de PDFs

#web #pdfs #infraestructura

> [!abstract] Resumen
> Generación client-side de 6 tipos de PDF usando jsPDF + autoTable. Branding personalizable (logo, color, nombre de negocio). Markdown-lite para formato en contratos.

---

## Tipos de PDF

| Tipo | Función | Contenido |
|------|---------|-----------|
| **Presupuesto** | Budget/Quote | Productos, extras, subtotales, descuento, impuesto, total |
| **Contrato** | Contract | Template personalizado con tokens sustituidos |
| **Factura** | Invoice | Ítems detallados, pagos realizados, saldo pendiente |
| **Lista de Compras** | Shopping List | Ingredientes y materiales necesarios por producto |
| **Checklist** | Event Checklist | Tareas para el día del evento |
| **Reporte de Pagos** | Payment Report | Historial completo de pagos del evento |

## Archivos

| Archivo | Responsabilidad |
|---------|----------------|
| `lib/pdfGenerator.ts` | Funciones de generación para cada tipo de PDF |
| `lib/contractTemplate.ts` | Sistema de tokens, template default, validación |
| `lib/inlineFormatting.ts` | Parser de `**bold**`, `*italic*`, `__underline__` para PDFs |

## Sistema de Templates (Contratos)

### Tokens Disponibles

| Token | Valor que sustituye |
|-------|-------------------|
| `{provider_name}` | Nombre del negocio |
| `{client_name}` | Nombre del cliente |
| `{client_phone}` | Teléfono del cliente |
| `{client_email}` | Email del cliente |
| `{event_date}` | Fecha del evento |
| `{event_time}` | Hora del evento |
| `{event_location}` | Ubicación |
| `{service_type}` | Tipo de servicio |
| `{num_people}` | Número de personas |
| `{total_amount}` | Monto total |
| `{deposit_amount}` | Monto del depósito |
| `{deposit_percent}` | Porcentaje de depósito |

### Formato Inline

El template de contrato soporta:
- `**texto**` → **bold**
- `*texto*` → *italic*
- `__texto__` → underline

Renderizado tanto en React (preview) como en jsPDF (PDF final).

## Branding

Cada PDF incluye:
- **Logo** — Si el usuario tiene `logo_url` configurado
- **Brand Color** — Color del header/acentos (`brand_color` del perfil)
- **Nombre del Negocio** — Si `show_business_name_in_pdf` está activo

## Relaciones

- [[Módulo Eventos]] — PDFs se generan desde EventSummary
- [[Componentes Compartidos]] — ContractTemplateEditor para editar templates
