# Manejo de Estado

#web #estado #arquitectura

> [!abstract] Resumen
> Enfoque **híbrido y minimalista**: React Context para estado global, Zustand para notificaciones, React Hook Form para formularios, y useState local para UI.

---

## Estrategia por Tipo de Estado

```mermaid
graph TD
    subgraph Global["Estado Global"]
        Auth["AuthContext<br/>user, profile, loading"]
        Theme["ThemeContext<br/>isDark, toggleTheme"]
        Toast["useToast (Zustand)<br/>toasts[], addToast, removeToast"]
    end

    subgraph Form["Estado de Formularios"]
        RHF["React Hook Form<br/>register, handleSubmit, errors"]
        Zod["Zod Schemas<br/>validación tipada"]
    end

    subgraph Local["Estado Local (useState)"]
        UI["UI State<br/>modals, dropdowns, tabs"]
        Data["Server Data<br/>lists, single entities"]
        Pagination["Pagination<br/>currentPage, sortKey"]
    end

    style Global fill:#C4A265,stroke:#1B2A4A,color:#1A1A1A
    style Form fill:#1B2A4A,stroke:#C4A265,color:#F5F0E8
    style Local fill:#F5F0E8,stroke:#C4A265,color:#1A1A1A
```

| Tipo | Herramienta | Ejemplo |
|------|------------|---------|
| Autenticación | React Context | `useAuth()` → `{ user, profile, signOut }` |
| Tema | React Context | `useTheme()` → `{ isDark, toggleTheme }` |
| Toasts | Zustand | `useToast()` → `{ addToast, removeToast }` |
| Formularios | React Hook Form + Zod | `useForm<T>({ resolver: zodResolver(schema) })` |
| Datos del servidor | useState local | `const [events, setEvents] = useState([])` |
| UI transiente | useState local | `const [isOpen, setIsOpen] = useState(false)` |
| Paginación/Sort | Custom hook | `usePagination({ data, itemsPerPage })` |
| Límites de plan | Custom hook | `usePlanLimits()` → `{ canCreateEvent, isBasicPlan }` |

## Detalle de Cada Capa

### 1. AuthContext (Context)

```
contexts/AuthContext.tsx
```

- Provee `user`, `profile`, `loading`, `checkAuth()`, `signOut()`, `updateProfile()`
- Se inicializa en el mount llamando a `GET /auth/me`
- Escucha evento `auth:logout` para limpiar sesión

### 2. ThemeContext (Context)

```
hooks/useTheme.ts → contexts/ThemeContext.tsx
```

- Provee `isDark`, `toggleTheme()`
- Persiste en `localStorage`
- Aplica clase `.dark` / `.light` a `<html>`

### 3. useToast (Zustand)

```
hooks/useToast.ts
```

- **Único store Zustand** en la app
- `addToast(message, type)` → auto-dismiss en 3 segundos
- Tipos: `success`, `error`, `info`
- Renderizado por `ToastContainer` en el Layout

### 4. React Hook Form + Zod

Patrón estándar en todos los formularios:

```typescript
const schema = z.object({
  name: z.string().min(2, "Mínimo 2 caracteres"),
  email: z.string().email("Email inválido"),
});

type FormData = z.infer<typeof schema>;

const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
  resolver: zodResolver(schema),
});
```

Formularios que usan RHF+Zod:
- Login, Register, ForgotPassword
- ClientForm, EventForm (sub-components)
- ProductForm, InventoryForm
- Settings (password change)

### 5. Server State (TanStack React Query — migración en progreso)

> [!success] Migración iniciada — 2026-04-04
> TanStack React Query v5 instalado. Dominio de **Clientes completamente migrado**. Los demás dominios se migran progresivamente — el patrón manual (`useState` + `useCallback`) convive con React Query hasta completar la migración.

**Beneficios ya activos** (dominio Clientes):
- Cache automático (staleTime: 2min, gcTime: 10min)
- Refetch en window focus
- Deduplicación de requests
- Error handling global via QueryCache/MutationCache
- Back-navigation instantánea (datos cacheados)

**Estructura**: `hooks/queries/queryKeys.ts` + `useClientQueries.ts`, `useEventQueries.ts` (skeleton), etc.

**Dominios pendientes**: Products, Inventory, Events, Payments, Search, Admin, Dashboard, Settings

Patrón típico:
```typescript
const [data, setData] = useState<Entity[]>([]);
const [loading, setLoading] = useState(true);

const fetchData = useCallback(async () => {
  setLoading(true);
  try {
    const result = await service.getAll();
    setData(result || []);
  } catch (error) {
    logError("Error", error);
    addToast("Error al cargar", "error");
  } finally {
    setLoading(false);
  }
}, [addToast]);

useEffect(() => { fetchData(); }, [fetchData]);
```

## Flujo de Estado en una Acción Típica

```mermaid
sequenceDiagram
    participant U as Usuario
    participant P as Page (useState)
    participant RHF as React Hook Form
    participant S as Service
    participant T as useToast (Zustand)

    U->>RHF: Llena formulario
    RHF->>RHF: Validación Zod
    RHF->>P: handleSubmit(onSubmit)
    P->>P: setIsLoading(true)
    P->>S: service.create(data)
    S-->>P: Respuesta
    P->>P: setIsLoading(false)
    P->>T: addToast("Éxito", "success")
    P->>P: navigate("/list")
```

## Relaciones

- [[Autenticación]] — AuthContext en detalle
- [[Hooks Personalizados]] — Implementación de cada hook
- [[Arquitectura General]] — Contexto completo del stack
