# What's New — 1.2.3 (9)

> Copia lista para pegar en App Store Connect. **Notas ACUMULATIVAS desde
> 1.2.0(6)**: la ola 1.2.2 se publicó en Mac el 19-nov (adopción mínima aún) y
> en iOS sigue Waiting for Review — el usuario que salta a 1.2.3 solo ve estas
> notas, así que deben vender TODO lo que no tiene (1.2.0 → 1.2.3). Verificado
> contra la matriz de plataformas: nada que la app no haga en el archive
> Release (Live Activities Mac es Debug-only y NO se menciona).

## iPhone / Apple Watch

ES:
```
Novedades en 1.2.3

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
What's new in 1.2.3

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
Novidades na 1.2.3

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
Novedades en 1.2.3

• Corregido: Iniciar sesión con Apple ahora funciona en Mac
• Toca tu Mac: dial giratorio en el anillo de foco, pausa al toque y Zen con pellizco
• Siri: crea tareas por voz, márcalas como hechas o pregunta qué tienes hoy
• Canjea códigos promocionales de Pepinillo+ sin salir de la app, desde el paywall
• Lleva tu compra a la web: vincula tu cuenta con el código de 6 dígitos de app.pepinillo.app (Cuenta)
• Soundscapes: ambiente sonoro para tus sesiones de foco
• Captura rápida ⌃⌥T desde cualquier app; ⌘→ salta de fase y ⌘N crea una tarea
• Huerto y celebraciones compartidos con iPhone: hitos y florecimiento al completar
```

EN:
```
What's new in 1.2.3

• Fixed: Sign in with Apple now works on Mac
• Touch your Mac: rotary dial on the focus ring, tap to pause, pinch for Zen
• Siri: create tasks by voice, mark them done, or ask what you have today
• Redeem Pepinillo+ promo codes without leaving the app, right from the paywall
• Bring your purchase to the web: link your account with the 6-digit code from app.pepinillo.app (Account)
• Soundscapes: ambient audio for your focus sessions
• ⌃⌥T quick capture from any app; ⌘→ skips a phase and ⌘N starts a task
• Garden and celebrations shared with iPhone: milestones and completion bloom
```

PT:
```
Novidades na 1.2.3

• Corrigido: entrar com Apple agora funciona no Mac
• Toque no seu Mac: dial giratório no anel de foco, toque para pausar, pinça para Zen
• Siri: crie tarefas pela voz, marque como feitas ou pergunte o que você tem hoje
• Resgate códigos promocionais do Pepinillo+ sem sair do app, direto no paywall
• Leve sua compra para a web: vincule sua conta com o código de 6 dígitos de app.pepinillo.app (Conta)
• Soundscapes: ambiente sonoro para suas sessões de foco
• Captura rápida ⌃⌥T de qualquer app; ⌘→ pula de fase e ⌘N cria uma tarefa
• Horta e celebrações compartilhadas com o iPhone: marcos e florescer ao concluir
```

## Notas de verificación (internas — no van a ASC)

- **Notas acumulativas**: la ficha muestra solo las notas de la versión a la
  que el usuario salta; con la ola 1.2.2 sin adopción (Mac salió 19-nov) y iOS
  1.2.2 aún en revisión, la base real de usuarios está en 1.2.0(6).
- **Sign in with Apple (Mac)**: #966 — doble causa raíz (glassEffect tragaclics
  + entitlement `applesignin` ausente en ambos entitlements de Mac, incluida la
  1.2.2 publicada). QA E2E firmado por Tiago: ventana nativa →
  `didCompleteWithAuthorization`. NO aplica a iPhone/watch (ahí siempre funcionó).
- **Canje in-app**: #958 — botón en `PaywallLegalFooter`, `OfferCodeRedemptionSheet`
  (UIWindowScene iOS / NSWindow macOS), sigue los caminos existentes de
  bienvenida/alerta/nudge de `syncPurchases`. iOS 16+ (rama `in:` compatible con
  todos los SDK). No funciona con `.storekit` local: codes sandbox/producción.
- **Vinculación web**: #968 — "Bring your purchase to the web": la web (/account,
  PR #965 mergeado) muestra un código de 6 dígitos; la app (Ajustes → Cuenta)
  abre el sheet, llama claim → `Purchases.logIn` → `linkSubscriptionIdentity`
  (SUBSCRIBER_ALIAS, soft-sync). Éxito visible con email vinculado; 404 (código
  inválido/expirado) y 409 (ya usado) con mensajes de usuario.
- **Live Activities Mac NO se menciona**: el port es Debug-only
  (`MAC_LIVE_ACTIVITIES`, compila solo con SDK 27.3); el archive Release no lo
  lleva hasta que 27.3 sea final (decisión vigente de #746/#834).
- **iOS/watch**: si se envía iOS 1.2.3, hay que retirar la 1.2.2 de revisión
  (una versión pendiente por plataforma) y pegar estas notas acumulativas.
