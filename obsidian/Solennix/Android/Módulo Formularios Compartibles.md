# Módulo Formularios Compartibles

#android #formularios #módulo

> [!abstract] Resumen
> Permite al organizador crear enlaces compartibles desde la app Android. Genera un link, lo comparte via WhatsApp/email/etc., y su cliente potencial lo abre en el navegador para llenar datos de evento y seleccionar productos. Android solo gestiona la creacion y seguimiento de enlaces — el formulario en si es web.

---

## Modelo

**Archivo:** `android/core/model/.../EventFormLink.kt`

```kotlin
@Serializable
data class EventFormLink(
    val id: String = "",
    @SerialName("user_id") val userId: String = "",
    val token: String = "",
    val label: String? = null,
    val status: String = "active",
    @SerialName("submitted_event_id") val submittedEventId: String? = null,
    @SerialName("submitted_client_id") val submittedClientId: String? = null,
    val url: String = "",
    @SerialName("expires_at") val expiresAt: String = "",
    @SerialName("used_at") val usedAt: String? = null,
    @SerialName("created_at") val createdAt: String = "",
    @SerialName("updated_at") val updatedAt: String = ""
)
```

---

## Endpoints

| Metodo | Endpoint | Descripcion |
|--------|----------|-------------|
| GET | `/event-forms` | Listar enlaces |
| POST | `/event-forms` | Crear enlace |
| DELETE | `/event-forms/{id}` | Revocar enlace |

---

## ViewModel

**Archivo:** `android/feature/clients/.../EventFormLinksViewModel.kt`

Patron: `@HiltViewModel` con `StateFlow<UiState>`

```kotlin
sealed interface EventFormLinksUiState {
    data object Loading : EventFormLinksUiState
    data class Success(val links: List<EventFormLink>) : EventFormLinksUiState
    data class Error(val message: String) : EventFormLinksUiState
}
```

| Metodo | Descripcion |
|--------|-------------|
| `loadLinks()` | GET → actualiza StateFlow |
| `generateLink(label, ttlDays)` | POST → agrega a lista |
| `deleteLink(id)` | DELETE → remueve de lista |

---

## Screen

**Archivo:** `android/feature/clients/.../EventFormLinksScreen.kt`

### UI (Jetpack Compose)

- **Scaffold** con TopAppBar "Formularios"
- **LazyColumn** con cada link mostrando:
  - Label o "Sin etiqueta"
  - Chip de status (Activo/Usado/Expirado) con colores
  - Fecha de expiracion formateada
  - Para links usados: boton hacia el evento resultante
- **FloatingActionButton** "Generar Enlace" → BottomSheet con:
  - OutlinedTextField para label
  - Slider para TTL (1-30 dias)
  - Boton crear
- **Acciones por item:**
  - Compartir (Intent.ACTION_SEND)
  - Copiar URL (ClipboardManager)
  - Eliminar con confirmacion (AlertDialog)

### Compartir

```kotlin
val shareIntent = Intent(Intent.ACTION_SEND).apply {
    type = "text/plain"
    putExtra(Intent.EXTRA_TEXT, link.url)
    putExtra(Intent.EXTRA_SUBJECT, "Formulario de evento - ${user.businessName}")
}
context.startActivity(Intent.createChooser(shareIntent, "Compartir enlace"))
```

---

## Navegacion

Accesible desde:
- Navigation drawer / bottom nav como item dedicado
- O como accion en la seccion de Clientes

---

> [!tip] Navegacion
> El formulario que llena el cliente es web-only ([[Módulo Formularios Compartibles|Web]]). Android solo gestiona la creacion de enlaces. Cuando el cliente envia, aparece un nuevo evento en [[Módulo Eventos]] y un nuevo cliente en [[Módulo Clientes]].
