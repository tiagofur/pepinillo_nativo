# Módulo Formularios Compartibles

#ios #formularios #módulo

> [!abstract] Resumen
> Permite al organizador crear enlaces compartibles desde la app iOS. El organizador genera un link, lo comparte via iMessage/WhatsApp/email, y su cliente potencial lo abre en un navegador web para llenar sus datos de evento y seleccionar productos. iOS solo gestiona la creacion y seguimiento de enlaces — el formulario en si es web.

---

## Modelo

**Archivo:** `ios/Packages/SolennixCore/Sources/SolennixCore/Models/EventFormLink.swift`

```swift
public struct EventFormLink: Codable, Identifiable, Sendable {
    public let id: String
    public let userId: String
    public let token: String
    public var label: String?
    public let status: String          // "active" | "used" | "expired"
    public var submittedEventId: String?
    public var submittedClientId: String?
    public let url: String
    public let expiresAt: String
    public var usedAt: String?
    public let createdAt: String
    public let updatedAt: String
}
```

---

## Endpoints

**Archivo:** `ios/Packages/SolennixNetwork/Sources/SolennixNetwork/Endpoints.swift`

```swift
// Event Form Links
public static let eventFormLinks = "/event-forms"
public static func eventFormLink(_ id: String) -> String { "/event-forms/\(id)" }
```

| Metodo | Endpoint | Descripcion |
|--------|----------|-------------|
| GET | `/event-forms` | Listar enlaces |
| POST | `/event-forms` | Crear enlace |
| DELETE | `/event-forms/{id}` | Revocar enlace |

---

## ViewModel

**Archivo:** `ios/.../EventForms/EventFormLinksViewModel.swift`

Patron: `@Observable` class (iOS 17+)

| Metodo | Descripcion |
|--------|-------------|
| `loadLinks()` | GET /event-forms → actualiza lista |
| `generateLink(label:ttlDays:)` | POST → agrega a lista + retorna URL |
| `deleteLink(id:)` | DELETE → remueve de lista |

---

## Vista

**Archivo:** `ios/.../EventForms/EventFormLinksView.swift`

### UI

- **NavigationStack** con titulo "Formularios"
- **List** con cada link mostrando:
  - Label o "Sin etiqueta"
  - Status badge (Activo/Usado/Expirado)
  - Fecha de expiracion
  - Para links usados: link al evento resultante
- **Toolbar button** "Generar Enlace" → sheet con:
  - TextField para label (opcional)
  - Stepper para TTL (1-30 dias)
  - Boton crear
- **Swipe actions:**
  - Compartir (UIActivityViewController)
  - Copiar URL
  - Eliminar (solo activos)
- **Context menu** con las mismas acciones

### Compartir

Usa `UIActivityViewController` / `ShareLink` (SwiftUI) para:
- iMessage
- WhatsApp
- Email
- Copiar link

---

## Navegacion

Agregar como tab o seccion accesible desde:
- Navigation sidebar (iPad) / tab o menu (iPhone)
- O como boton en la vista de Clientes (contexto: "adquirir nuevo cliente")

---

> [!tip] Navegacion
> El formulario que llena el cliente es web-only ([[Módulo Formularios Compartibles|Web]]). iOS solo gestiona la creacion de enlaces. Cuando el cliente envia el form, aparece un nuevo evento en [[Módulo Eventos]] y un nuevo cliente en [[Módulo Clientes]].
