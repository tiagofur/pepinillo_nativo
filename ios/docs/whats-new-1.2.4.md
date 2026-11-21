# What's New — 1.2.4 (10)

> Copia lista para pegar en App Store Connect. **Notas ACUMULATIVAS desde
> 1.2.0(6)**: Mac 1.2.3(9) está en revisión con adopción ~0, así que quien
> salta a 1.2.4 debe ver todo lo que no tiene. La novedad líder de 1.2.4 es la
> declaración touch-native (`NSIsTouchNative`, #747/PR #969) — verificada en
> el bundle Release compilado con Xcode 27.2 estable. Verificado contra la
> matriz de plataformas: nada que la app no haga en el archive Release (Live
> Activities Mac es Debug-only y NO se menciona).

## iPhone / Apple Watch

> Sin cambios de contenido respecto a 1.2.3 (esta versión lidera macOS). Si
> iOS envía 1.2.4 directo, usar estos bloques; si envía 1.2.3, los de
> `whats-new-1.2.3.md`.

ES:
```
Novedades en 1.2.4

• Canjea códigos promocionales de Pepinillo+ sin salir de la app, desde el paywall
• Lleva tu compra a la web: vincula tu cuenta con el código de 6 dígitos de app.pepinillo.app (Cuenta)
• Siri: crea tareas con tu voz, márcalas como hechas o pregunta qué tienes hoy — sin abrir la app
• Share Sheet: comparte un enlace o texto desde cualquier app y conviértelo en tarea al instante
• Live Activities: tu foco vive en la Dynamic Island y en la pantalla de bloqueo
• Apple Watch: modo always-on, complicaciones para el Smart Stack y arranque instantáneo del timer
• Celebraciones y huerto compartidos entre tus dispositivos: hitos y florecimiento al completar
• iPad: atajo ⌘→ para saltar o avanzar de fase, y dígitos del timer a escala de reloj
• Métricas anónimas opt-in desde Ajustes; correcciones de widgets y sincronización
```

EN:
```
What's new in 1.2.4

• Redeem Pepinillo+ promo codes without leaving the app, right from the paywall
• Bring your purchase to the web: link your account with the 6-digit code from app.pepinillo.app (Account)
• Siri: create tasks with your voice, mark them done, or ask what you have today — no need to open the app
• Share sheet: share a link or text from any app and turn it into a task instantly
• Live Activities: your focus lives in the Dynamic Island and Lock Screen
• Apple Watch: always-on mode, Smart Stack complications and an instant-start timer
• Garden and celebrations shared across your devices: milestones and completion bloom
• iPad: ⌘→ skips or advances a phase, and timer digits scale watch-face style
• Anonymous, opt-in metrics from Settings; widget and sync fixes
```

PT:
```
Novidades na 1.2.4

• Resgate códigos promocionais do Pepinillo+ sem sair do app, direto no paywall
• Leve sua compra para a web: vincule sua conta com o código de 6 dígitos de app.pepinillo.app (Conta)
• Siri: crie tarefas com a voz, marque como feitas ou pergunte o que você tem hoje — sem abrir o app
• Share sheet: compartilhe um link ou texto de qualquer app e transforme em tarefa na hora
• Live Activities: seu foco vive na Dynamic Island e na tela de bloqueio
• Apple Watch: modo always-on, complicações do Smart Stack e timer com início instantâneo
• Horta e celebrações compartilhadas entre seus dispositivos: marcos e florescer ao concluir
• iPad: atalho ⌘→ pula ou avança de fase, e dígitos do timer em escala de relógio
• Métricas anônimas por opt-in nos Ajustes; correções de widgets e sincronização
```

## macOS

ES:
```
Novedades en 1.2.4

• Touch nativo: toda la app responde al tacto en las nuevas Mac con pantalla táctil
• Toca tu Mac: gira el anillo para ajustar la duración, toca el centro para pausar, pellizca para Zen
• Corregido: Iniciar sesión con Apple ahora funciona en Mac
• Canjea códigos promocionales de Pepinillo+ sin salir de la app, desde el paywall
• Lleva tu compra a la web: vincula tu cuenta con el código de 6 dígitos de app.pepinillo.app (Cuenta)
• Siri: crea tareas por voz, márcalas como hechas o pregunta qué tienes hoy
• Soundscapes: ambiente sonoro para tus sesiones de foco
• Captura rápida ⌃⌥T desde cualquier app; ⌘→ salta de fase y ⌘N crea una tarea
```

EN:
```
What's new in 1.2.4

• Touch-native: the whole app now responds to touch on the new Macs with a touchscreen
• Touch your Mac: spin the ring to set the duration, tap the center to pause, pinch for Zen
• Fixed: Sign in with Apple now works on Mac
• Redeem Pepinillo+ promo codes without leaving the app, right from the paywall
• Bring your purchase to the web: link your account with the 6-digit code from app.pepinillo.app (Account)
• Siri: create tasks by voice, mark them done, or ask what you have today
• Soundscapes: ambient audio for your focus sessions
• ⌃⌥T quick capture from any app; ⌘→ skips a phase and ⌘N creates a task
```

PT:
```
Novidades na 1.2.4

• Toque nativo: o app inteiro responde ao toque nos novos Macs com tela sensível ao toque
• Toque no seu Mac: gire o anel para ajustar a duração, toque no centro para pausar, pinça para Zen
• Corrigido: entrar com Apple agora funciona no Mac
• Resgate códigos promocionais do Pepinillo+ sem sair do app, direto no paywall
• Leve sua compra para a web: vincule sua conta com o código de 6 dígitos de app.pepinillo.app (Conta)
• Siri: crie tarefas pela voz, marque como feitas ou pergunte o que você tem hoje
• Soundscapes: ambiente sonoro para suas sessões de foco
• Captura rápida ⌃⌥T de qualquer app; ⌘→ pula de fase e ⌘N cria uma tarefa
```

## Notas de verificación (internas — no van a ASC)

- **Touch-native (#747, PR #969)**: `NSIsTouchNative: true` en main desde
  `e315078a`. Envío verificado 20-nov: Release **BUILD SUCCEEDED con Xcode
  27.2 estable (27B52)** y `plutil` = true en el Info.plist del bundle
  Release. Gate S5 (QA táctil) por Sidecar antes del archive — checklist
  G1–G4 + C1–C8 en `odd/tasks/747-touch-native-declaration.md`; fallback
  aprobado: rollback documentado (1.2.5 sin la key — review Mac = horas).
- **Acumulativas**: Mac 1.2.3(9) en revisión con adopción ~0 → estas notas
  venden 1.2.0 → 1.2.4 de una vez, liderando con touch-native.
- **Live Activities Mac NO se menciona**: Debug-only (`MAC_LIVE_ACTIVITIES`,
  SDK 27.3); el archive Release no lo lleva hasta que 27.3 sea final.
- **iOS/watch**: decisión pendiente de 1.2.2/1.2.3 (cancelar y enviar
  1.2.3/1.2.4 directo + expedited). Una versión pendiente por plataforma: si
  iOS envía una nueva, retirar la anterior de revisión.
