- 2026-11-20 (C4.3 ronda 2, judge A P1): release eliminado de SetRcAppUserID —
  el UPDATE de release permitía a un claim concurrente "desvincular"
  silenciosamente el bind recién commiteado del ganador (sin duplicate-key,
  sin rollback, sin 409 → premium varado). Índice único parcial = race guard
  determinista: el perdedor recibe ports.ErrRcAppUserIDTaken → rollback del
  grant + 409. Además: rollback del grant ante CUALQUIER fallo de bind con
  log rc_link_rollback_failed; fake GetByID devuelve copias (semántica de
  producción; el aliasing enmascaraba el rollback en el test de carrera.
