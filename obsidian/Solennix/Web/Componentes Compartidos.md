# Componentes Compartidos

#web #componentes #infraestructura

> [!abstract] Resumen
> 24 componentes reutilizables que forman la infraestructura visual. Layout shell, modales, feedback, data display, y controles de acceso.

---

## Layout y Navegación

| Componente | Archivo | Función |
|-----------|---------|---------|
| **Layout** | `Layout.tsx` | Shell principal: sidebar colapsable, topbar con search, toast container, FAB |
| **BottomTabBar** | `BottomTabBar.tsx` | Navegación inferior en mobile |
| **Breadcrumb** | `Breadcrumb.tsx` | Trail de navegación contextual |
| **Logo** | `Logo.tsx` | Logo de Solennix reutilizable |

## Diálogos y Modales

| Componente | Archivo | Función |
|-----------|---------|---------|
| **Modal** | `Modal.tsx` | Wrapper genérico de modal con backdrop |
| **ConfirmDialog** | `ConfirmDialog.tsx` | Diálogo de confirmación para acciones destructivas |
| **PendingEventsModal** | `PendingEventsModal.tsx` | Lista de eventos pendientes de acción |
| **SetupRequired** | `SetupRequired.tsx` | Prompt para completar configuración faltante |
| **CommandPalette** | `CommandPalette.tsx` | `Cmd+K` — búsqueda global + acciones rápidas |

## Estado y Feedback

| Componente | Archivo | Función |
|-----------|---------|---------|
| **StatusDropdown** | `StatusDropdown.tsx` | Cambio de estado de evento inline en tabla |
| **ToastContainer** | `ToastContainer.tsx` | Renderiza toasts de `useToast()` (bottom-right) |
| **OnboardingChecklist** | `OnboardingChecklist.tsx` | Checklist de primeros pasos con progreso |
| **UpgradeBanner** | `UpgradeBanner.tsx` | Banner de upgrade cuando se alcanzan límites del plan |

## Display de Datos

| Componente | Archivo | Función |
|-----------|---------|---------|
| **Empty** | `Empty.tsx` | Estado vacío con ícono, título, descripción, y CTA opcional |
| **Pagination** | `Pagination.tsx` | Controles de paginación con jump-to-page |
| **Skeleton** | `Skeleton.tsx` | Loading states: `SkeletonTable`, `SkeletonLine`, `SkeletonCard` |
| **RowActionMenu** | `RowActionMenu.tsx` | Dropdown de acciones por fila (Ver, Editar, Eliminar) |

## Acciones Rápidas

| Componente | Archivo | Función |
|-----------|---------|---------|
| **QuickActionsFAB** | `QuickActionsFAB.tsx` | Floating button con menu: nuevo evento/cliente/producto/inventario |

## Formularios Especializados

| Componente | Archivo | Función |
|-----------|---------|---------|
| **ContractTemplateEditor** | `ContractTemplateEditor.tsx` | Editor de template de contrato con token picker y preview |

## Auth UI

| Componente | Archivo | Función |
|-----------|---------|---------|
| **GoogleSignInButton** | `GoogleSignInButton.tsx` | Botón de login con Google |
| **AppleSignInButton** | `AppleSignInButton.tsx` | Botón de login con Apple |

## Guards

| Componente | Archivo | Función |
|-----------|---------|---------|
| **ProtectedRoute** | `ProtectedRoute.tsx` | Requiere autenticación |
| **AdminRoute** | `AdminRoute.tsx` | Requiere rol admin |
| **ErrorBoundary** | `ErrorBoundary.tsx` | Captura errores de render con retry UI y reporting |

## Drag & Drop

| Componente | Archivo | Función |
|-----------|---------|---------|
| **SortableItem** | `SortableItem.tsx` | Wrapper de @dnd-kit con drag handle (GripVertical) |

## Keyboard Shortcuts

| Componente | Archivo | Función |
|-----------|---------|---------|
| **KeyboardShortcutsHelp** | `KeyboardShortcutsHelp.tsx` | Overlay de ayuda con lista de shortcuts (`?` para abrir) |

## Relaciones

- [[Design System]] — Todos los componentes implementan los tokens del design system
- [[Routing y Guards]] — ProtectedRoute y AdminRoute
- [[Hooks Personalizados]] — useToast, usePagination usados por estos componentes
