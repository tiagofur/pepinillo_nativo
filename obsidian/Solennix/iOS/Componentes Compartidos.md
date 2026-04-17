#ios #componentes #ui

# Componentes Compartidos

> [!abstract] Resumen
> 11 componentes reutilizables en `SolennixDesign/Components/` más helpers de UX en `SolennixFeatures/Common/`. Establecen la identidad visual de la marca.

---

## Componentes de Diseño

| Componente | Props principales | Uso |
|-----------|------------------|-----|
| `SolennixTextField` | text, label, error, keyboardType | Campos de formulario con validación |
| `Avatar` | name, imageUrl, size | Foto o iniciales con color por hash |
| `StatusBadge` | status: EventStatus | Badge coloreado por estado |
| `SkeletonView` | shape, size | Placeholder animado shimmer |
| `PremiumButton` | action, label, isPremium | Botón con badge premium |
| `UpgradeBannerView` | plan, features | CTA para upgrade de plan |
| `ToastOverlay` | — (via ToastManager) | Notificación temporal flotante |
| `ConfirmDialog` | title, message, onConfirm | Confirmación de acciones destructivas |
| `EmptyStateView` | icon, title, message, action | Pantalla sin datos |
| `AdaptiveLayout` | content | Helper para responsive layout |

---

## Helpers de UX

| Helper | Responsabilidad |
|--------|----------------|
| `ToastManager` | Cola de toasts, auto-dismiss |
| `HapticsHelper` | Feedback háptico (success, warning, error, selection) |
| `StoreReviewHelper` | Prompt de review en momentos óptimos |
| `SentryHelper` | Error reporting (referenciado pero pendiente) |
| `PlanLimitsManager` | Feature gating por plan |

---

## Patrón de Vista Estándar — Lista

```swift
struct EntityListView: View {
    @Environment(EntityListViewModel.self) var viewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                SkeletonView()
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "Sin entidades",
                    message: "Creá tu primera entidad",
                    action: { /* navegar a form */ }
                )
            } else {
                List(viewModel.items) { item in
                    EntityRow(item: item)
                }
            }
        }
        .task { await viewModel.fetchItems() }
    }
}
```

---

## Patrón de Vista Estándar — Detalle

```swift
struct EntityDetailView: View {
    @Environment(EntityDetailViewModel.self) var viewModel
    @Environment(ToastManager.self) var toast

    var body: some View {
        ScrollView {
            // Content sections
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Editar") { /* edit */ }
                    Button("Eliminar", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .confirmationDialog("¿Eliminar?", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) {
                Task { await viewModel.delete() }
            }
        }
    }
}
```

---

## Relaciones

- [[Design System]] — tokens de color, tipografía, spacing
- [[Manejo de Estado]] — ViewModels proveen datos
- [[Módulo Eventos]] — usa la mayoría de componentes
- [[Módulo Dashboard]] — StatusBadge, KPI display
