# Routing y Guards

#web #routing #navegación

> [!abstract] Resumen
> React Router 7 con rutas agrupadas por acceso: públicas, protegidas (auth requerida), y admin. Guards implementados como componentes wrapper.

---

## Mapa de Rutas

```mermaid
graph TD
    subgraph Public["Públicas (sin auth)"]
        L["/"] --> Landing
        LI["/login"] --> Login
        RE["/register"] --> Register
        FP["/forgot-password"] --> ForgotPassword
        RP["/reset-password"] --> ResetPassword
        AB["/about"] --> About
        PR["/privacy"] --> Privacy
        TE["/terms"] --> Terms
    end

    subgraph Protected["Protegidas (auth requerida)"]
        D["/dashboard"] --> Dashboard
        SE["/search"] --> Search
        CA["/calendar"] --> CalendarView
        QQ["/cotizacion-rapida"] --> QuickQuote
        ST["/settings"] --> Settings
        PC["/pricing"] --> Pricing

        subgraph Events["/events"]
            EL["/events"] --> EventList
            EN["/events/new"] --> EventForm
            EE["/events/:id/edit"] --> EventFormEdit["EventForm (edit)"]
            ES["/events/:id/summary"] --> EventSummary
            EP["/events/:id/payment-success"] --> PaymentSuccess
        end

        subgraph Clients["/clients"]
            CL["/clients"] --> ClientList
            CN["/clients/new"] --> ClientForm
            CD["/clients/:id"] --> ClientDetails
            CE["/clients/:id/edit"] --> ClientFormEdit["ClientForm (edit)"]
        end

        subgraph Products["/products"]
            PL["/products"] --> ProductList
            PN["/products/new"] --> ProductForm
            PD["/products/:id"] --> ProductDetails
            PE["/products/:id/edit"] --> ProductFormEdit["ProductForm (edit)"]
        end

        subgraph Inventory["/inventory"]
            IL["/inventory"] --> InventoryList
            IN["/inventory/new"] --> InventoryForm
            ID["/inventory/:id"] --> InventoryDetails
            IE["/inventory/:id/edit"] --> InventoryFormEdit["InventoryForm (edit)"]
        end
    end

    subgraph Admin["Admin (auth + rol admin)"]
        AD["/admin"] --> AdminDashboard
        AU["/admin/users"] --> AdminUsers
    end

    NF["/*"] --> NotFound

    style Public fill:#F5F0E8,stroke:#C4A265
    style Protected fill:#1B2A4A,stroke:#C4A265,color:#F5F0E8
    style Admin fill:#C4A265,stroke:#1B2A4A
```

## Guards

### ProtectedRoute

```
components/ProtectedRoute.tsx
```

- Verifica `user !== null && !loading`
- Si no hay user → redirect a `/login`
- Mientras `loading` → muestra spinner
- Wrappea el `<Layout>` completo (sidebar, topbar, toasts)

### AdminRoute

```
components/AdminRoute.tsx
```

- Requiere auth primero (ProtectedRoute parent)
- Verifica `user.role === 'admin'`
- Si no es admin → redirect a `/dashboard`

## Estructura del Router (App.tsx)

```
<ThemeProvider>
  <AuthProvider>
    <Routes>
      {/* Públicas */}
      <Route path="/" element={<Landing />} />
      <Route path="/login" element={<Login />} />
      ...

      {/* Protegidas */}
      <Route element={<ProtectedRoute />}>
        <Route element={<Layout />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/events" element={<EventList />} />
          ...

          {/* Admin */}
          <Route element={<AdminRoute />}>
            <Route path="/admin" element={<AdminDashboard />} />
            <Route path="/admin/users" element={<AdminUsers />} />
          </Route>
        </Route>
      </Route>

      <Route path="*" element={<NotFound />} />
    </Routes>
  </AuthProvider>
</ThemeProvider>
```

## Navegación en la UI

| Elemento | Ubicación | Tipo |
|----------|-----------|------|
| **Sidebar** | Desktop (left) | Links permanentes: Dashboard, Eventos, Clientes, Productos, Inventario, Calendario |
| **Bottom Tab Bar** | Mobile (bottom) | Mismos links principales |
| **Breadcrumb** | Top de cada page | Navegación contextual |
| **Command Palette** | `Cmd+K` / `Ctrl+K` | Búsqueda global + acciones rápidas |
| **Quick Actions FAB** | Bottom-right (mobile) | Nuevo evento/cliente/producto/inventario |

## Relaciones

- [[Autenticación]] — Guards y flujo de auth
- [[Arquitectura General]] — Estructura completa
- [[Componentes Compartidos]] — Layout, Sidebar, BottomTabBar
