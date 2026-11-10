---
name: ux-brief
description: "Disparador: issues etiquetadas `ux:shape`, o una petición del brief UX de una pantalla o flujo. Handoff de factoría unattended que produce un brief UX y lo publica como comentario de issue ANTES de implementar. Nunca escribe código de producto."
---

## Contrato de activación

Carga este skill cuando una issue lleva la etiqueta `ux:shape` y no tiene brief
vigente, o cuando se pide el brief UX de una pantalla/flujo. Es un paso
cognitivo ejecutado por el rol `explorer` (no un agente separado). El método de
diseño en sí es de nivel proyecto/usuario (por ejemplo un skill de diseño);
este skill define el contrato de handoff de la factoría alrededor.

## Reglas duras

- **Unattended**: nunca preguntes al usuario. Toda suposición se escribe como
  suposición explícita.
- **Cero código**: sin implementación ni archivos de mockup. El único
  entregable es un comentario de issue.
- Publica con `gh issue comment N --body-file <file>`; un brief que solo vive
  en chat no existe.
- Respeta los docs de diseño del proyecto (`docs/design.md`,
  `.impeccable.md`, `ios/docs/macos-design-contract.md`) y la Jerarquía de
  Verdad en `AGENTS.md`.
- Si la issue contradice un ADR, una invariante de dominio (`AGENTS.md` §3) o
  los docs de diseño: NO diseñes. Comenta la contradicción y marca
  `status:blocked` + `needs-human`.

## Compuertas de decisión

| Condición | Acción |
| :--- | :--- |
| Ya existe un brief vigente para la superficie | Extiéndelo; la adición hereda su mundo visual |
| Superficie nueva dentro de un mundo visual establecido | Shape completo; el mundo se hereda y queda fijo |
| No existe mundo visual aún (producto o identidad nueva) | Entrega el brief con suposiciones y señala que se requiere una sesión de diseño atendida |
| Falta contexto para una decisión material | Suposición marcada, nunca invención silenciosa |

## Pasos de ejecución

1. Lee la issue y sus comentarios, los docs de producto relevantes
   (`docs/prd-v2.md`, `docs/product-map.md`), los docs de diseño, cualquier
   brief previo y el código actual de la pantalla.
2. Produce un brief mínimo: modo/meta del visitante, tesis de composición,
   estados (empty/loading/error/offline), interacciones clave, notas de
   accesibilidad y el momento memorable.
3. Publícalo como comentario de issue con encabezado `## UX Brief` y una lista
   final `### Assumptions`.
4. Retorna al orquestador: URL del comentario, resumen de 3 líneas, lista de
   suposiciones y si se requiere sesión de diseño atendida.

## Contrato downstream

- `implementer` honra el brief y adjunta **Visual Evidence** en el PR
  (`## Visual Evidence`): screenshots por clase de dispositivo, nombrando qué
  archivo prueba qué y enlazando el brief.
- `reviewer` verifica la fidelidad al brief y la presencia de evidencia visual;
  la falta de evidencia en un PR `ux:shape` es un `P1`.
