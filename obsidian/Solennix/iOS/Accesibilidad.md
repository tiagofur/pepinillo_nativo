#ios #calidad #accesibilidad

# Accesibilidad

> [!abstract] Resumen
> SwiftUI provee un buen baseline de accesibilidad por default. Se usan haptics para feedback. No hay auditoría formal ni labels explícitos en la mayoría de componentes custom.

---

## Estado Actual

| Aspecto | Estado |
|---------|--------|
| VoiceOver | ⚠️ No testeado formalmente |
| Dynamic Type | ⚠️ Parcial — system fonts lo soportan, custom fonts pueden no |
| Contraste | ⚠️ No auditado (colores custom dorado/navy) |
| Touch targets | ✅ SwiftUI minimum 44pt |
| Reduce Motion | ⚠️ No verificado |
| Haptic feedback | ✅ HapticsHelper para acciones clave |
| Bold Text | ✅ System fonts respetan |
| Focus management | ⚠️ Default de SwiftUI |

---

## Oportunidades

| Prioridad | Acción |
|-----------|--------|
| P1 | Agregar `.accessibilityLabel()` a componentes custom |
| P1 | Auditar contraste WCAG AA con paleta dorado/navy |
| P1 | Testear flujos principales con VoiceOver |
| P2 | Verificar Dynamic Type con Cinzel (custom font) |
| P2 | Respetar `@Environment(\.accessibilityReduceMotion)` |
| P3 | `.accessibilityHint()` en acciones no obvias |

---

## Relaciones

- [[Design System]] — colores y tipografía custom
- [[Componentes Compartidos]] — labels de accesibilidad
- [[Roadmap iOS]] — auditoría planificada
