#android #calidad #performance

# Performance

> [!abstract] Resumen
> La app tiene buenas bases de rendimiento (offline-first, Coil para imágenes, skeleton loading), pero hay oportunidades de mejora en paginación, recomposiciones y consumo de batería.

---

## Fortalezas Actuales

| Aspecto | Implementación |
|---------|---------------|
| Carga offline | Room como caché → datos instantáneos |
| Imágenes | Coil 3 con cache en disco y memoria |
| Skeleton loading | Placeholders animados durante carga |
| Layouts adaptativos | Window Size Classes para responsive |
| Background sync | WorkManager con constraints de red |

---

## Oportunidades de Mejora

### P0 — Crítico

| Issue | Impacto | Solución |
|-------|---------|----------|
| Sin paginación en listas | Listas grandes cargan todo en memoria | Implementar Paging 3 con RemoteMediator |
| Sync cada 15 min | Consumo de batería/datos | Ajustar intervalo o usar sync inteligente |

### P1 — Importante

| Issue | Impacto | Solución |
|-------|---------|----------|
| Recomposiciones innecesarias | Jank en UI complejas | `remember`, `derivedStateOf`, keys estables |
| Flows sin memoización | Múltiples combine sin buffer | Agregar `distinctUntilChanged()` |
| Sin lazy loading indicators | UX de carga en listas largas | Footer loading item en LazyColumn |

### P2 — Nice to Have

| Issue | Impacto | Solución |
|-------|---------|----------|
| Sin baseline profiles | App startup más lento | Generar baseline profiles |
| Sin R8 full mode | APK más grande | Habilitar R8 full mode |
| Sin image compression | Subida de fotos lenta | Comprimir antes de upload |

---

## Métricas Sugeridas

| Métrica | Herramienta | Target |
|---------|-----------|--------|
| App startup | Macrobenchmark | < 1s cold start |
| Frame rate | Composition tracing | 60fps consistente |
| APK size | `bundletool` | < 15MB |
| Memory | Android Studio Profiler | Sin leaks |

---

## Relaciones

- [[Sincronización Offline]] — intervalo de sync afecta batería
- [[Manejo de Estado]] — Flows y recomposiciones
- [[Base de Datos Local]] — paginación desde Room
- [[Roadmap Android]] — optimizaciones planificadas
