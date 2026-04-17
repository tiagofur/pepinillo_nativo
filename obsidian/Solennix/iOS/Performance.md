#ios #calidad #performance

# Performance

> [!abstract] Resumen
> La app tiene buenas bases (async/await, SwiftData caché, actor para red), pero hay oportunidades en paginación, background refresh, y optimización de Views.

---

## Fortalezas

| Aspecto | Implementación |
|---------|---------------|
| Concurrencia | async/await nativo, sin bloqueo de main thread |
| Red thread-safe | APIClient como actor |
| Caché local | SwiftData para datos offline |
| Haptics | CoreHaptics para feedback |
| Skeleton loading | Placeholders durante carga |
| Adaptive layouts | Window Size Classes |

---

## Oportunidades de Mejora

### P0 — Crítico

| Issue | Impacto | Solución |
|-------|---------|----------|
| Sin paginación real | Listas grandes cargan todo | `.task` con infinite scroll |
| Sin background refresh | Datos pueden estar stale | Background App Refresh + URLSession background |

### P1 — Importante

| Issue | Impacto | Solución |
|-------|---------|----------|
| Modelos no Sendable en algunos ViewModels | Potenciales data races | Hacer todos los modelos `Sendable` |
| Sin lazy loading de imágenes optimizado | Scroll puede lagear con fotos | Verificar Coil/async image caching |
| Views complejas (EventForm 5 steps) | Potencial jank | Extraer sub-views, `@State` granular |

### P2 — Nice to Have

| Issue | Impacto | Solución |
|-------|---------|----------|
| Sin App Launch profiling | Startup no medido | Instruments Time Profiler |
| Sin metrics tracking | No sabemos si hay problemas | MetricKit integration |

---

## Relaciones

- [[Caché y Offline]] — SwiftData como caché
- [[Manejo de Estado]] — @Observable vs redraws
- [[Roadmap iOS]] — optimizaciones planificadas
