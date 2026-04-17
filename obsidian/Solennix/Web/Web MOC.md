# Web App — Map of Content

> [!info] Plataforma
> **Stack**: React 19 + TypeScript + Tailwind CSS 4 + Vite
> **Estado**: Producción (MVP completo) — Google & Apple SSO ✅
> **Última actualización**: 2026-04-12 — Refactored Google One Tap + paridad documentada

---

## Arquitectura

- [[Arquitectura General]] — Vista de alto nivel, capas, flujo de datos
- [[Design System]] — Tokens, colores, tipografía, dark mode
- [[Autenticación]] — Flujo de login, SSO, cookies httpOnly, refresh tokens
- [[Manejo de Estado]] — Context, Zustand, React Hook Form, local state
- [[Routing y Guards]] — Rutas protegidas, admin guards, estructura de navegación

## Módulos por Dominio

- [[Módulo Eventos]] — CRUD, formulario multi-paso, cotización, resumen, PDFs
- [[Módulo Clientes]] — CRUD, foto, historial, estadísticas
- [[Módulo Productos]] — Catálogo, recetas/ingredientes, imágenes
- [[Módulo Inventario]] — Stock, alertas, equipamiento/insumos
- [[Módulo Pagos]] — Registro de pagos, Stripe checkout, reportes
- [[Módulo Calendario]] — Vista mensual, fechas bloqueadas
- [[Módulo Admin]] — Dashboard admin, gestión de usuarios, suscripciones
- [[Módulo Formularios Compartibles]] — Formulario publico para clientes + gestion de enlaces

## Infraestructura

- [[Capa de Servicios]] — API client, servicios por dominio
- [[Sistema de PDFs]] — jsPDF, tipos de documento, branding
- [[Componentes Compartidos]] — Layout, modales, skeletons, toasts, paginación, navegación mobile solo en smartphones
- [[Hooks Personalizados]] — useAuth, usePagination, usePlanLimits, useToast, useTheme
- [[Sistema de Tipos]] — Entidades, tipos de inserción/actualización

## Calidad

- [[Testing]] — Vitest, Playwright, MSW, estructura de tests
- [[Accesibilidad]] — ARIA, focus, contraste, screen readers
- [[Performance]] — Lazy loading, bundle size, CLS

## Roadmap

- [[Roadmap Web]] — Mejoras priorizadas para llevar la app a nivel premium

---

> [!tip] Navegación
> Cada nota enlaza con `[[wikilinks]]` a sus dependencias. Usá el **Graph View** de Obsidian para ver las relaciones entre módulos.

#web #moc #solennix
