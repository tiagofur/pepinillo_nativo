# Arquitectura General

#web #arquitectura

> [!abstract] Resumen
> SPA (Single Page Application) con React 19, comunicándose con un backend Go vía REST API. Autenticación por cookies httpOnly. Sin SSR.

---

## Stack Tecnológico

| Capa | Tecnología | Versión |
|------|-----------|---------|
| UI Framework | React | 19.2 |
| Lenguaje | TypeScript | 5.9 |
| Estilos | Tailwind CSS | 4.2 |
| Build Tool | Vite | 7.3 |
| Routing | React Router | 7.13 |
| Forms | React Hook Form + Zod | 7.71 / 4.3 |
| Server State | TanStack React Query | 5.96 |
| Estado Global | Zustand | 5.0 |
| Gráficos | Recharts | 3.7 |
| PDFs | jsPDF + autoTable | 4.2 |
| Iconos | Lucide React | 0.575 |
| Drag & Drop | @dnd-kit | 6.3 / 10.0 |
| PWA | vite-plugin-pwa + Workbox | 1.2 |
| Testing | Vitest + Playwright + MSW | — |

## Diagrama de Capas

```mermaid
graph TB
    subgraph Frontend["Frontend (React SPA)"]
        Pages["Pages<br/>EventList, ClientList, Dashboard..."]
        Components["Componentes Compartidos<br/>Layout, Modal, Skeleton..."]
        Hooks["Hooks<br/>useAuth, usePagination..."]
        Contexts["Contexts<br/>AuthContext, ThemeContext"]
        Stores["Stores<br/>useToast (Zustand)"]
        Services["Servicios<br/>eventService, clientService..."]
        Lib["Lib/Utils<br/>api.ts, pdfGenerator, finance..."]
    end

    subgraph API["API Client (lib/api.ts)"]
        Fetch["fetch() + httpOnly cookies"]
        Refresh["Token refresh automático"]
        Logout["Auto-logout en 401"]
    end

    subgraph Backend["Backend (Go)"]
        Handlers["Handlers"]
        DB["PostgreSQL"]
    end

    Pages --> Components
    Pages --> Hooks
    Pages --> Services
    Hooks --> Contexts
    Hooks --> Stores
    Services --> API
    API --> Backend
    Handlers --> DB

    style Frontend fill:#F5F0E8,stroke:#C4A265,color:#1A1A1A
    style API fill:#1B2A4A,stroke:#C4A265,color:#F5F0E8
    style Backend fill:#2D6A4F,stroke:#C4A265,color:#F5F0E8
```

## Flujo de Datos

```mermaid
sequenceDiagram
    participant U as Usuario
    participant P as Page/Component
    participant S as Service
    participant A as api.ts
    participant B as Backend Go

    U->>P: Interacción (click, form submit)
    P->>S: Llama servicio tipado
    S->>A: fetch() con cookies
    A->>B: HTTP Request + httpOnly cookie
    B-->>A: JSON Response
    A-->>S: Datos tipados
    S-->>P: Actualiza estado local
    P-->>U: Re-render UI
```

## Estructura de Directorios

```
web/src/
├── components/        # Componentes compartidos/reutilizables
├── contexts/          # React Contexts (Auth, Theme)
├── hooks/             # Custom hooks
├── lib/               # Utilidades (API client, PDFs, finanzas)
├── pages/             # Páginas organizadas por dominio
│   ├── Admin/
│   ├── Calendar/
│   ├── Clients/
│   ├── Events/
│   │   └── components/   # Sub-componentes del formulario
│   ├── Inventory/
│   └── Products/
├── services/          # Capa de servicios (API wrappers)
├── types/             # Definiciones de tipos TypeScript
├── index.css          # Design tokens + Tailwind config
├── App.tsx            # Router y providers raíz
└── main.tsx           # Entry point
```

## Principios Arquitectónicos

1. **Service Layer Pattern** — Cada dominio tiene su servicio que encapsula las llamadas API
2. **Type-First** — Tipos definidos en `entities.ts`, todas las capas son type-safe
3. **Composición** — Pages compuestas de componentes más pequeños (EventForm → 6 sub-componentes)
4. **Hooks como lógica reutilizable** — `usePagination`, `usePlanLimits`, etc.
5. **Error handling centralizado** — `logError()` en toda la app, toasts para feedback al usuario
6. **PDF-First exports** — Presupuesto, contrato, factura, checklist exportables como PDF con branding

## Relaciones

- [[Design System]] — Sistema visual completo
- [[Capa de Servicios]] — Detalle de cada servicio
- [[Routing y Guards]] — Estructura de navegación
- [[Manejo de Estado]] — Estrategia de estado
