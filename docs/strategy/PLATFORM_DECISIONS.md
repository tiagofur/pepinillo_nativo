# Decisiones de plataformas

## Plataformas activas

El foco de producto activo es:

- iOS + watchOS + macOS (`PepinilloMac`) — ecosistema Apple.
- Android + Wear OS — ecosistema Google.
- Backend Go — infraestructura requerida por la funcionalidad actual
  (sync Everywhere+, IA cloud, push).

Estas superficies concentran la mayor probabilidad de validar el negocio.

## Windows

Estado: exploración en pausa.

La implementación (`windows/`) probó viabilidad técnica (W0–W15 mergeados) y
sigue siendo valiosa como referencia futura. No forma parte del roadmap de
ejecución actual porque la adopción móvil debe validarse primero. Pendientes
históricas si se reanuda: smoke WinUI (#575) y Partner Center (#568).

## Web

Estado: exploración en pausa.

El companion web (`web/`) permanece documentado (shell offline W1, auth/sync
W2 explorados). Debe regresar solo cuando haya una necesidad de usuario clara
o justificación de negocio.

## Principio de decisión

Toda inversión futura en plataformas debe responder:

- ¿Aumenta adquisición?
- ¿Aumenta retención?
- ¿Aumenta ingresos?

Si la respuesta es no, la plataforma permanece experimental.
