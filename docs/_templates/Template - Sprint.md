---
tags:
  - sprint
  - pepinillo
aliases:
  - "Sprint {{numero}}"
platform: all
type: sprint
status: active
sprint: "{{numero}}"
date: "{{fecha-inicio}}"
updated: "{{fecha-inicio}}"
---

# 🏁 Sprint {{numero}} — {{objetivo-corto}}

**Periodo:** {{fecha-inicio}} → {{fecha-fin}}
**Objetivo principal:** {{objetivo-largo}}

---

## 🎯 Scope del sprint

| Tarea | Plataforma | Prioridad | Estado |
|---|---|:-:|:-:|
| Tarea A | iOS | P0 | 🚧 |
| Tarea B | Android | P0 | 📋 |
| Tarea C | Backend | P1 | 📋 |

---

## ✅ Checklist de cierre

### Código
- [ ] Todas las tareas P0 completadas
- [ ] Tests escritos para cambios críticos
- [ ] No hay TODO/FIXME sin issue abierto

### Paridad
- [ ] Bug fix en iOS verificado y aplicado en Android
- [ ] Bug fix en Android verificado y aplicado en iOS
- [ ] Cambio en Backend documentado con impacto por plataforma

### Docs
- [ ] PRD actualizado si hubo cambio de feature o alcance
- [ ] Dashboard actualizado con porcentajes de progreso
- [ ] Parity Matrix actualizada si hubo cierre de brechas

### Entrega
- [ ] Build local limpio en iOS
- [ ] Build local limpio en Android
- [ ] Commit y push con conventional commits

---

## 📝 Log de cambios

> Agregar aquí links a commits relevantes o notas de lo que se hizo.

---

## 🔮 Próximo sprint

- Item pendiente 1
- Item pendiente 2

---

## Referencias
- [[../00_DASHBOARD|Dashboard]]
- [[../_views/Parity Gaps|Parity Gaps]]
- [[../_views/Pendientes por Plataforma|Pendientes]]
