# Módulo Formularios Compartibles

#web #formularios #dominio

> [!abstract] Resumen
> Dos caras: (1) **Pagina publica** `/form/:token` donde el cliente potencial llena datos de su evento y selecciona productos sin ver precios, y (2) **UI de gestion** `/event-forms` donde el organizador crea, comparte y administra sus enlaces.

---

## Paginas

| Pagina | Ruta | Auth | Descripcion |
|--------|------|------|-------------|
| **PublicEventFormPage** | `/form/:token` | No | Formulario publico branded del organizador |
| **EventFormLinksPage** | `/event-forms` | Si | Gestion de enlaces (crear, copiar, revocar) |

---

## Pagina Publica (`/form/:token`)

### Estructura

```
PublicEventFormPage.tsx
├── PublicProductCard.tsx      — Card de producto (nombre, categoria, imagen, qty picker)
├── PublicFormExpired.tsx      — Estado: link expirado/usado
└── PublicFormSuccess.tsx      — Estado: envio exitoso (agradecimiento)
```

### Comportamiento

1. Extrae `token` de URL params
2. Fetch `GET /api/v1/public/event-forms/{token}` (fetch standalone, no el `api` client con auth)
3. Token invalido → `PublicFormExpired`
4. Token valido → formulario con branding del organizador:
   - **Header**: logo, business_name, brand_color del organizador
   - **Seccion 1**: Datos del cliente (nombre, telefono, email)
   - **Seccion 2**: Datos del evento (fecha, tipo servicio, personas, ubicacion, notas)
   - **Seccion 3**: Catalogo de productos (grid responsive, sin precios, qty picker)
   - **Seccion 4**: Resumen y boton enviar
5. Submit → `POST /api/v1/public/event-forms/{token}`
6. Exito → `PublicFormSuccess`
7. 409 (ya usado) → `PublicFormExpired`

### Consideraciones UI

- **Sin Layout wrapper** — no usa Sidebar/Header del app
- **Responsive** — el cliente probablemente abre en mobile
- **Branding** — usa `brand_color` del organizador como accent
- **Validacion** — React Hook Form + Zod
- **Sin precios** — productos muestran solo nombre, categoria, imagen
- **Dark/Light** — respeta `prefers-color-scheme` del sistema

### Datos que NO se exponen al cliente

- `base_price` de productos
- `recipe` de productos
- `user_id` del organizador
- Cualquier dato financiero

---

## Pagina de Gestion (`/event-forms`)

### Funcionalidades

- **Generar enlace** — Dialog con label opcional + selector TTL (1-30 dias, default 7)
- **Lista de enlaces** — Tabla/cards con status badges:
  - `Activo` (verde) — link disponible
  - `Usado` (azul) — cliente ya envio
  - `Expirado` (gris) — TTL vencido
- **Copiar al portapapeles** — Click en URL → copia + toast
- **Compartir** — Web Share API (mobile) o fallback a copiar
- **Revocar** — Elimina link activo con confirmacion
- **Ver resultado** — Links "usados" tienen link al evento/cliente creado

### Componentes

| Componente | Funcion |
|-----------|---------|
| `GenerateLinkDialog` | Modal para crear enlace nuevo |
| `LinkStatusBadge` | Badge coloreado por status |
| `LinkCard` / `LinkRow` | Item de la lista con acciones |

---

## Servicio API

```
services/eventFormService.ts
```

| Metodo | Endpoint | Descripcion |
|--------|----------|-------------|
| `generateLink(label?, ttlDays?)` | POST /event-forms | Crear enlace |
| `listLinks()` | GET /event-forms | Listar enlaces del usuario |
| `deleteLink(id)` | DELETE /event-forms/{id} | Revocar enlace |

Para la pagina publica (fetch directo sin auth client):
| Metodo | Endpoint | Descripcion |
|--------|----------|-------------|
| fetch | GET /public/event-forms/{token} | Datos del formulario |
| fetch | POST /public/event-forms/{token} | Enviar formulario |

---

## Tipo

```typescript
interface EventFormLink {
  id: string;
  user_id: string;
  token: string;
  label?: string;
  status: 'active' | 'used' | 'expired';
  submitted_event_id?: string;
  submitted_client_id?: string;
  url: string;
  expires_at: string;
  used_at?: string;
  created_at: string;
  updated_at: string;
}
```

---

## React Query Hooks

```
hooks/queries/useEventFormQueries.ts
```

| Hook | Tipo | Descripcion |
|------|------|-------------|
| `useEventFormLinks()` | Query | Lista de links del usuario |
| `useGenerateLink()` | Mutation | Crear enlace, invalida lista |
| `useDeleteLink()` | Mutation | Revocar enlace, invalida lista |

---

## Navegacion

- Ruta publica `/form/:token` — al nivel de `/login`, `/register` (sin ProtectedRoute/Layout)
- Ruta protegida `/event-forms` — dentro de Layout, nuevo item en sidebar
- Sidebar icon: `Link2` de lucide-react
- Label sidebar: "Formularios"

---

> [!tip] Navegacion
> Ver [[Módulo Eventos]] para el flujo completo de eventos. Los productos seleccionados en el form publico se crean como `EventProduct` records. El cliente creado aparece en [[Módulo Clientes]].
