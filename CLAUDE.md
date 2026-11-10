# CLAUDE.md — Puntero

Instrucciones del proyecto para agentes: lee [`AGENTS.md`](AGENTS.md) (mapa de
navegación y fuentes canónicas) y, según tu tarea, la tabla de enrutamiento en
[`docs/README.md`](docs/README.md).

Reglas resumidas:

- GitHub Issues (`status:ready` / `status:approved`) es la única cola de trabajo.
- Respeta los checkpoints `C1`–`C5` ([`CHECKPOINTS.md`](CHECKPOINTS.md)).
- Commits atómicos con Conventional Commits en inglés, sin trailers de
  co-autoría de IA. No uses `git stash` como depósito entre sesiones.
- La paridad funcional obligatoria cubre iOS, watchOS, macOS, Android y Wear OS;
  `web/` y `windows/` están en pausa.
- No reviertas ni ediciones archivos bajo `docs/legacy/` para "actualizarlos":
  son archivo histórico; corrige la fuente canónica correspondiente en `docs/`.
