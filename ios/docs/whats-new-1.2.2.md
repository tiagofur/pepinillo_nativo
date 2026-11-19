# What's New — 1.2.2 (8)

> Copia lista para pegar en App Store Connect. 1.2.2 es la primera versión
> publicada desde 1.2.0(6): las notas cubren las dos olas (1.2.1 no se
> publicó). Verificado contra la matriz de plataformas — nada que la app
> no haga.

## iPhone / Apple Watch

ES:
```
Novedades en 1.2.2

• Siri: crea tareas con tu voz, márcalas como hechas o pregunta qué tienes hoy — sin abrir la app
• Share Sheet: comparte un enlace o texto desde cualquier app y conviértelo en tarea al instante
• Apple Watch: modo always-on, complicaciones para el Smart Stack y arranque instantáneo del timer
• Live Activities: tu foco vive en la Dynamic Island y en la pantalla de bloqueo
• Celebraciones: desbloquea hitos y disfruta del florecimiento al completar
• iPad: atajo ⌘→ para saltar o avanzar de fase, y dígitos del timer a escala de reloj
• Métricas anónimas opt-in desde Ajustes — siempre es tu decisión
• Correcciones: crash de widgets al migrar, sincronización del reloj y del ciclo Pomodoro
```

EN:
```
What's new in 1.2.2

• Siri: create tasks with your voice, mark them done, or ask what you have today — no need to open the app
• Share sheet: share a link or text from any app and turn it into a task instantly
• Apple Watch: always-on mode, Smart Stack complications and an instant-start timer
• Live Activities: your focus lives in the Dynamic Island and Lock Screen
• Celebrations: unlock milestones and enjoy the completion bloom
• iPad: ⌘→ skips or advances a phase, and timer digits scale watch-face style
• Anonymous, opt-in metrics from Settings — always your call
• Fixes: widget migration crash, watch and Pomodoro cycle sync
```

PT:
```
Novidades na 1.2.2

• Siri: crie tarefas com a voz, marque como feitas ou pergunte o que você tem hoje — sem abrir o app
• Share sheet: compartilhe um link ou texto de qualquer app e transforme em tarefa na hora
• Apple Watch: modo always-on, complicações do Smart Stack e timer com início instantâneo
• Live Activities: seu foco vive na Dynamic Island e na tela de bloqueio
• Celebrações: desbloqueie marcos e aproveite o florescer ao concluir
• iPad: atalho ⌘→ pula ou avança de fase, e dígitos do timer em escala de relógio
• Métricas anônimas por opt-in nos Ajustes — sempre sua decisão
• Correções: crash de widgets na migração, sincronização do relógio e do ciclo Pomodoro
```

## macOS

ES:
```
Novedades en 1.2.2

• Siri: crea tareas por voz, márcalas como hechas o pregunta qué tienes hoy
• Toca tu Mac: dial giratorio en el anillo de foco, pausa al toque y Zen con pellizco
• ⌘→ salta o avanza de fase; ⌘N crea una tarea desde donde estés
• Soundscapes: ambiente sonoro para tus sesiones de foco
• Captura rápida ⌃⌥T desde cualquier app y acciones táctiles en todo el panel del menú
• Huerto y celebraciones compartidas con iPhone: hitos y florecimiento al completar
• Correcciones de estabilidad y sincronización
```

EN:
```
What's new in 1.2.2

• Siri: create tasks by voice, mark them done, or ask what you have today
• Touch your Mac: rotary dial on the focus ring, tap to pause, pinch for Zen
• ⌘→ skips or advances a phase; ⌘N starts a task from anywhere
• Soundscapes: ambient audio for your focus sessions
• ⌃⌥T quick capture from any app and touch actions across the menu bar panel
• Garden and celebrations shared with iPhone: milestones and completion bloom
• Stability and sync fixes
```

PT:
```
Novidades na 1.2.2

• Siri: crie tarefas pela voz, marque como feitas ou pergunte o que você tem hoje
• Toque no seu Mac: dial giratório no anel de foco, toque para pausar, pinça para Zen
• ⌘→ pula ou avança de fase; ⌘N cria uma tarefa de onde estiver
• Soundscapes: ambiente sonoro para suas sessões de foco
• Captura rápida ⌃⌥T de qualquer app e ações de toque no painel do menu
• Horta e celebrações compartilhadas com o iPhone: marcos e florescer ao concluir
• Correções de estabilidade e sincronização
```

### Notas de verificación

- **Live Activities**: headline de iPhone válido — #834 registró el widget en el bundle compartido; en Mac la feature es Debug-only (MAC_LIVE_ACTIVITIES) y NO se menciona en las notas Mac.
- **Soundscapes/touch**: Mac-only (#845–#851) ✓.
- **Siri**: disponible en iOS y macOS; las frases están en EN/ES/PT (AppShortcuts.xcstrings).
- **Share Extension**: iOS/iPadOS only — no se menciona en notas Mac.
- Cap free de 3 tareas activas aplica a TODOS los canales nuevos (Siri/Share/quick-add) — no se menciona en notas (comportamiento estándar de la app).
