# Performance

#web #performance #calidad

> [!abstract] Resumen
> Build con Vite (fast HMR, optimized production). Sin SSR. Áreas de mejora en lazy loading, caching, y bundle optimization.

---

## Estado Actual — 2026-04-05

| Aspecto | Estado |
|---------|--------|
| **Vite** | Build optimizado, tree-shaking, code splitting automático |
| **Tailwind CSS 4** | Purge automático de clases no usadas |
| **TanStack React Query** | Cache (2min stale, 10min GC), deduplicación, refetch on focus |
| **Lazy Loading** | 28 páginas code-split via `React.lazy()` + `Suspense` |
| **Image Optimization** | `loading="lazy"` en imágenes de listas y detalles |
| **PWA / Service Worker** | Workbox caching de assets estáticos, imágenes (30 días), fonts (1 año) |
| **Skeleton shimmer** | Gradiente shimmer en vez de pulse genérico |
| **httpOnly cookies** | Sin overhead de token en cada request |

## Áreas de Mejora Restantes

> [!info] Oportunidades futuras
> 
> ### Recharts Bundle
> Recharts es una dependencia pesada (~200KB). Solo se usa en Dashboard y Admin. Ya se lazy-loadea la página, pero el chunk es grande.
> 
> ### Image CDN
> Thumbnails, srcSet, WebP/AVIF requieren backend/CDN. No necesario aún con el volumen actual.
> 
> ### React.memo()
> RowActionMenu y StatusDropdown podrían beneficiarse de memoización en tablas grandes.

## Relaciones

- [[Roadmap Web]] — Mejoras priorizadas
- [[Arquitectura General]] — Stack y decisiones técnicas
