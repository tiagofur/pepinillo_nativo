# What's New — 1.2.3 (9)

> Copia lista para pegar en App Store Connect. 1.2.3 es una release de
> corrección + compras: login con Apple reparado en macOS, canje de códigos
> promocionales in-app y vinculación de la compra con la cuenta web.
> Verificado contra la matriz de plataformas — nada que la app no haga.

## iPhone / Apple Watch

ES:
```
Novedades en 1.2.3

• Canjea códigos promocionales de Pepinillo+ sin salir de la app, desde el paywall
• Lleva tu compra a la web: vincula tu cuenta con el código de 6 dígitos de app.pepinillo.app (Cuenta)
• Correcciones de estabilidad
```

EN:
```
What's new in 1.2.3

• Redeem Pepinillo+ promo codes without leaving the app, right from the paywall
• Bring your purchase to the web: link your account with the 6-digit code from app.pepinillo.app (Account)
• Stability fixes
```

PT:
```
Novidades na 1.2.3

• Resgate códigos promocionais do Pepinillo+ sem sair do app, direto no paywall
• Leve sua compra para a web: vincule sua conta com o código de 6 dígitos de app.pepinillo.app (Conta)
• Correções de estabilidade
```

## macOS

ES:
```
Novedades en 1.2.3

• Corregido: Iniciar sesión con Apple ahora funciona en Mac
• Canjea códigos promocionales de Pepinillo+ sin salir de la app, desde el paywall
• Lleva tu compra a la web: vincula tu cuenta con el código de 6 dígitos de app.pepinillo.app (Cuenta)
```

EN:
```
What's new in 1.2.3

• Fixed: Sign in with Apple now works on Mac
• Redeem Pepinillo+ promo codes without leaving the app, right from the paywall
• Bring your purchase to the web: link your account with the 6-digit code from app.pepinillo.app (Account)
```

PT:
```
Novidades na 1.2.3

• Corrigido: entrar com Apple agora funciona no Mac
• Resgate códigos promocionais do Pepinillo+ sem sair do app, direto no paywall
• Leve sua compra para a web: vincule sua conta com o código de 6 dígitos de app.pepinillo.app (Conta)
```

## Notas de verificación

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
- **Stability fixes**: frase paraguas mínima para iOS (sin crash conocido nuevo
  en esta release); eliminar si se prefiere cirugía estricta.
