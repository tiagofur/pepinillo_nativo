#ios #siri #appintents #shortcuts

# Siri Shortcuts

> [!abstract] Resumen
> Integración con **AppIntents** (iOS 17+) para acciones rápidas via Siri, Shortcuts app, y Spotlight. 5 intents definidos para consultas rápidas del negocio.

---

## Intents Disponibles

| Intent | Frase ejemplo | Resultado |
|--------|--------------|-----------|
| Eventos de hoy | "Solennix, ¿qué eventos tengo hoy?" | Lista de eventos del día |
| Próximos eventos | "Solennix, ¿qué viene?" | Próximos 5 eventos |
| Revenue del mes | "Solennix, ¿cuánto vendí este mes?" | Total de ingresos |
| Conteo de eventos | "Solennix, ¿cuántos eventos tengo?" | Conteo por status |
| Stock bajo | "Solennix, ¿qué me falta?" | Items bajo stock mínimo |

---

## Spotlight Integration

| Tipo indexado | Campos | Deep link |
|--------------|--------|-----------|
| Eventos | nombre, tipo, fecha | Route.eventDetail(id:) |
| Clientes | nombre, teléfono | Route.clientDetail(id:) |
| Productos | nombre, categoría | Route.productDetail(id:) |

> [!tip] CoreSpotlight
> Los datos se indexan en CoreSpotlight para que aparezcan en la búsqueda del sistema.

---

## Archivos Clave

| Archivo | Ubicación |
|---------|-----------|
| App Intents | `SolennixIntents/` |

---

## Relaciones

- [[Navegación]] — deep links desde Spotlight
- [[Widgets y Live Activities]] — comparten infraestructura de intents
- [[Módulo Dashboard]] — datos de KPIs para intents
