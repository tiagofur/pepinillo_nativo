#android #calidad #accesibilidad

# Accesibilidad

> [!abstract] Resumen
> Se usan los defaults de Material 3 y Compose (que proveen un baseline razonable), pero no hay implementación explícita de accesibilidad ni auditoría formal.

---

## Estado Actual

| Aspecto | Estado |
|---------|--------|
| Content descriptions | ⚠️ Parcial — muchos íconos sin `contentDescription` |
| Touch targets | ✅ Material 3 garantiza mínimo 48dp |
| Contraste de colores | ⚠️ No auditado formalmente |
| Screen reader | ⚠️ No testeado con TalkBack |
| Navegación por teclado | ⚠️ No verificado |
| Semántica de Compose | ⚠️ Sin `semantics {}` explícitos |
| Focus management | ⚠️ Default de Compose |

---

## Oportunidades de Mejora

| Prioridad | Acción | Impacto |
|-----------|--------|---------|
| P1 | Agregar `contentDescription` a todos los `Icon()` | Screen readers |
| P1 | Auditar contraste con paleta dorado/navy | Usuarios con baja visión |
| P1 | Testear flujos principales con TalkBack | Validar experiencia base |
| P2 | Agregar `Modifier.semantics {}` para agrupaciones | Mejor estructura para screen readers |
| P2 | Manejar `fontScale` para texto grande | Usuarios con texto ampliado |
| P3 | Agregar labels a campos de formulario | Contexto para inputs |

---

## Baseline de Material 3

Compose Material 3 provee por default:
- Touch targets de 48dp mínimo
- Roles semánticos en botones, checkboxes, etc.
- Focus indicators
- Color tokens con contraste WCAG AA en la paleta default

> [!tip] Buen punto de partida
> Los defaults de Material 3 cubren lo básico, pero Solennix usa colores custom (dorado, navy) que necesitan verificación de contraste.

---

## Relaciones

- [[Design System]] — colores y tipografía afectan accesibilidad
- [[Componentes Compartidos]] — componentes deben ser accesibles
- [[Roadmap Android]] — accesibilidad como mejora planificada
