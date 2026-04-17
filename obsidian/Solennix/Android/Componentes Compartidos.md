#android #componentes #ui

# Componentes Compartidos

> [!abstract] Resumen
> Componentes reutilizables en `core/designsystem/` que establecen la identidad visual de Solennix. Incluye componentes de marca, adaptativos, de feedback y de estado.

---

## Inventario de Componentes

### Marca y Layout

| Componente | Props principales | Uso |
|-----------|------------------|-----|
| `SolennixTopAppBar` | title, onBack, actions | Barra superior en todas las pantallas |
| `SolennixTextField` | value, onValueChange, label, error | Campos de formulario |
| `Avatar` | name, imageUrl, size | Foto de perfil o iniciales generadas |
| `AdaptiveCenteredContent` | maxWidth, content | Centra contenido en pantallas anchas |
| `AdaptiveFormRow` | content | Campos lado a lado en tablet |
| `AdaptiveDetailLayout` | content | Layout de detalle responsivo |
| `AdaptiveCardGrid` | columns, content | Grid adaptativo de cards |

### Estado y Feedback

| Componente | Props principales | Uso |
|-----------|------------------|-----|
| `StatusBadge` | status: EventStatus | Badge coloreado con texto del estado |
| `KPICard` | icon, value, label, color | Card de métrica en dashboard |
| `SkeletonLoading` | modifier | Placeholder animado |
| `EmptyState` | icon, title, message, action | Pantalla sin datos |
| `ToastOverlay` | message, type | Notificación temporal |
| `ConfirmDialog` | title, message, onConfirm, onDismiss | Confirmación de acciones destructivas |

### Premium/Monetización

| Componente | Props principales | Uso |
|-----------|------------------|-----|
| `UpgradeBanner` | plan, features | Invita a subir de plan |
| `PremiumButton` | onClick, isPremium | Botón con badge de premium |

---

## Patrones de Uso

### Pantalla Estándar de Lista

```kotlin
@Composable
fun EntityListScreen(
    viewModel: EntityListViewModel = hiltViewModel(),
    onNavigateToDetail: (Int) -> Unit,
    onNavigateToForm: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = { SolennixTopAppBar(title = "Entidades") },
        floatingActionButton = {
            FloatingActionButton(onClick = onNavigateToForm) {
                Icon(Icons.Default.Add, "Agregar")
            }
        }
    ) { padding ->
        when {
            uiState.isLoading -> SkeletonLoading()
            uiState.items.isEmpty() -> EmptyState(
                icon = Icons.Default.Entity,
                title = "Sin entidades",
                message = "Creá tu primera entidad",
                action = { onNavigateToForm() }
            )
            else -> LazyColumn { /* items */ }
        }
    }
}
```

### Pantalla Estándar de Formulario

```kotlin
@Composable
fun EntityFormScreen(
    viewModel: EntityFormViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is UiEvent.NavigateBack -> onNavigateBack()
                is UiEvent.ShowToast -> /* show snackbar */
            }
        }
    }

    Scaffold(
        topBar = {
            SolennixTopAppBar(
                title = if (uiState.isEditing) "Editar" else "Crear",
                onBack = onNavigateBack
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            SolennixTextField(/* fields */)
            Button(onClick = { viewModel.save() }) {
                Text("Guardar")
            }
        }
    }
}
```

---

## Relaciones

- [[Design System]] — tema, colores y tipografía base
- [[Manejo de Estado]] — ViewModels proveen el estado a los componentes
- [[Módulo Eventos]] — usa la mayoría de los componentes compartidos
- [[Módulo Dashboard]] — KPICard, StatusBadge
