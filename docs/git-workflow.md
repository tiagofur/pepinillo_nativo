# Flujo Git

Complementa `CHECKPOINTS.md` (C1 workspace limpio, C3 commits, C5 PR) y
`docs/strategy/` para decisiones.

---

## 1. Ramas

- Nombres por convención: `feat/<tema>`, `fix/<tema>`, `docs/<tema>`,
  `chore/<tema>`, `test/<tema>`; para issues de factoría,
  `factory/issue-<n>-<slug>`; para trabajo entre sesiones, `wip/<tema>`.
- **Prohibido** `git stash` como depósito entre sesiones: usa `wip/<tema>` con
  push, o commitea con `wip:` y rebaja el mensaje al cerrar.
- Un escritor por issue; nunca commitear directo a `main`.
- Mantén `main` sincronizada (`git fetch origin` antes de ramificar; verificar
  que tu rama base está realmente en `origin/main`).

## 2. Commits

- Conventional Commits en **inglés**: `feat:`, `fix:`, `refactor:`, `test:`,
  `docs:`, `chore:` (scopes de plataforma cuando aplique: `fix(mac):`,
  `feat(android):`).
- Atómicos por unidad de trabajo: código + su test + su doc en el mismo commit
  cuando forman la unidad. Commit mecánico separado para extracciones de
  monolitos.
- **Sin** trailers de co-autoría IA (`Co-Authored-By`, etc.).
- Mensajes claros: qué cambió y por qué en una línea; detalles en el PR.

## 3. Pull Requests

- Plantilla obligatoria: `.github/PULL_REQUEST_TEMPLATE.md`; validada fail-closed
  por `python3 scripts/check_pr_metadata.py --body-file <pr.md>` (C5):
  línea 1 `Closes/Fixes/Resolves #N` (o `Refs #N` si `Delivery: partial`),
  línea 2 `Delivery:`, secciones `## Summary`, `## Decisions Made Without
  Asking`, `## Verification Evidence`, `## Clean-Context Review Handoff`,
  `## Risk` con `Risk: none` o `Risk: item N (<reason>)`, y veredicto
  `APPROVED` del reviewer independiente con SHAs reales + scope digest.
- ≤400 líneas cambiadas; si se supera, trocear con `chained-pr` o justificar.
- CI verde en superficies tocadas antes de pedir merge; merge **solo** con
  instrucción humana explícita (`leader` devuelve `PR_READY_FOR_HUMAN_MERGE`).
- Tras merge: borrar la rama (local y remota). No acumular ramas muertas ni
  stashes.

## 4. Recuperación entre sesiones

1. `progress/current.md` + `progress/history.md` (estado vivo y bitácora).
2. `odd/tasks/<issue>-<slug>.md` para Delegated Direct (specs, surfaces, log).
3. Dif como fuente de verdad: `git status` + `git diff` + `git log` de la rama.
4. Si la sesión murió a mitad de unidad: commitea el estado con prefijo
   `wip:` en la rama del tema y documenta el siguiente paso en
   `progress/current.md` — nunca en stash.
