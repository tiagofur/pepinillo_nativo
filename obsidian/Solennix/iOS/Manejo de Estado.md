#ios #estado #observable

# Manejo de Estado

> [!abstract] Resumen
> Estado manejado con **@Observable** (Observation framework, iOS 17+). Cada feature tiene ViewModels como clases `@Observable`. La UI accede via `@Environment`. Estado local con `@State` y `@Binding`. Preferencias con `@AppStorage`.

---

## Estrategia por Capa

| Capa | Herramienta | Patrón |
|------|-----------|--------|
| **UI local** | `@State` / `@Binding` | Campos de formulario, toggles, sheets |
| **Feature** | `@Observable` ViewModel | Estado de pantalla completo |
| **App-wide** | `@Environment` managers | Auth, plan limits, toast, network |
| **Persistencia ligera** | `@AppStorage` | Tema, preferencias visuales |
| **Caché** | SwiftData `@Model` | Datos offline |

---

## Patrón @Observable

```mermaid
graph LR
    VIEW["SwiftUI View"] -->|"@Environment"| VM["@Observable<br/>ViewModel"]
    VM -->|"async/await"| AC["APIClient<br/>(Actor)"]
    VM -->|"propiedades"| STATE["Published State"]
    STATE -->|"auto-tracking"| VIEW

    style VIEW fill:#C4A265,color:#000
    style VM fill:#1B2A4A,color:#fff
    style AC fill:#007AFF,color:#fff
```

```swift
@Observable
public final class EventListViewModel {
    var events: [Event] = []
    var isLoading = true
    var searchText = ""
    var statusFilter: EventStatus?
    var error: String?

    func fetchEvents() async {
        isLoading = true
        do {
            events = try await apiClient.get("/events")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
```

> [!tip] Auto-tracking
> Con `@Observable`, SwiftUI trackea automáticamente qué propiedades usa cada View y solo re-renderiza cuando esas propiedades específicas cambian. No se necesita `@Published`.

---

## ViewModels del Sistema

| ViewModel | Feature | Responsabilidad |
|-----------|---------|-----------------|
| `AuthViewModel` | auth | Login, registro, recovery, social auth, validación |
| `DashboardViewModel` | dashboard | KPIs, eventos próximos, alertas stock, charts |
| `EventListViewModel` | events | Lista, filtros, búsqueda, paginación |
| `EventFormViewModel` | events | Formulario multi-paso (5 steps), validación, cálculos |
| `EventDetailViewModel` | events | Detalle, productos, extras, equipo, insumos, fotos, pagos |
| `EventChecklistViewModel` | events | Checklist con mark complete |
| `ClientListViewModel` | clients | Lista, búsqueda, CRUD |
| `ClientDetailViewModel` | clients | Detalle, historial, quick quote |
| `ProductListViewModel` | products | Lista, búsqueda, categorías |
| `ProductDetailViewModel` | products | Detalle, ingredientes, demanda |
| `InventoryListViewModel` | inventory | Lista, filtros por tipo |
| `InventoryDetailViewModel` | inventory | Detalle de stock y uso |
| `CalendarViewModel` | calendar | Vista mensual, eventos por fecha |
| `SearchViewModel` | search | Búsqueda global |
| `SettingsViewModel` | settings | Perfil, negocio, suscripción |

---

## Managers Globales

| Manager | Patrón | Inyección | Responsabilidad |
|---------|--------|-----------|----------------|
| `AuthManager` | `@Observable` | `.environment()` | Estado auth, tokens, biometric |
| `PlanLimitsManager` | `@Observable` | `.environment()` | Límites del plan, feature gating |
| `SubscriptionManager` | `@Observable` | `.environment()` | RevenueCat, estado de suscripción |
| `ToastManager` | `@Observable` | `.environment()` | Notificaciones temporales |
| `NetworkMonitor` | `@Observable` | `.environment()` | Estado de conectividad |
| `CacheManager` | `@Observable` | `.environment()` | SwiftData, datos cacheados |
| `APIClient` | `actor` | `EnvironmentKey` | HTTP requests |

---

## Plan Limits (Feature Gating)

```swift
@Observable
public final class PlanLimitsManager {
    // Basic tier limits
    let maxEventsPerMonth = 3
    let maxClients = 50
    let maxProducts = 20

    func canCreateEvent() -> Bool { ... }
    func canCreateClient() -> Bool { ... }
    func canCreateProduct() -> Bool { ... }
}
```

> [!important] Upgrade Prompts
> Cuando el usuario alcanza un límite del plan, se muestra `UpgradeBannerView` en lugar de bloquear silenciosamente.

---

## Estado de Formulario Multi-Paso (Event)

```mermaid
graph LR
    S1["Step 1<br/>General"] --> S2["Step 2<br/>Productos"]
    S2 --> S3["Step 3<br/>Extras"]
    S3 --> S4["Step 4<br/>Equipo/Insumos"]
    S4 --> S5["Step 5<br/>Finanzas"]
    S5 --> SAVE["Guardar"]

    style S1 fill:#C4A265,color:#000
    style S5 fill:#2D6A4F,color:#fff
```

Cada step tiene validación independiente. El ViewModel mantiene el estado de todos los steps y calcula totales en Step 5.

---

## Relaciones

- [[Arquitectura General]] — capas y paquetes
- [[Capa de Red]] — APIClient como actor
- [[Navegación]] — ViewModels no navegan directamente
- [[Caché y Offline]] — CacheManager con SwiftData
