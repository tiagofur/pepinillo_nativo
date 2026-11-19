# 936 — feat(guides): manuales Android + Wear OS — catálogo completo 6/6
Objective: Última tanda de guías: Android (10 secciones) y Wear OS (7 secciones) con capturas reales en español. Al cerrar, el índice /guides queda 6/6 plataformas listas y la cross-nav completa macOS → iPhone → watchOS → Android → Wear OS → Web.
Branch: `feat/guides-android-wear` (apilada sobre `feat/guides-iphone-watch-934` / PR #935 — retarget a main al mergear) | Delivery: `complete` | Test runners: `pnpm check` + `pnpm build` (landing/)

## Specs

- **S1** — `landing/static/guides/android.html` (10 secciones: instalación, flujo, modos, sesión, plan con energía, dashboard, widgets/notificación persistente, Assistant, cuenta/ajustes, tips/FAQ).
- **S2** — `landing/static/guides/wearos.html` (7 secciones: instalación/emparejamiento, foco, tareas, estadísticas, tiles/complications, sync, tips/FAQ).
- **S3** — Capturas reales ES: android-01..05 (foco idle limpio, corriendo 24:37 con tarea, Inbox con tareas, dashboard, Más) + wearos-01..03 (timer, tareas, estadísticas — assets ES existentes).
- **S4** — Índice 6/6 ready:true con mini-capturas y bodies es/en/pt; sitemap con las 2 URLs.
- **S5** — Showcase: cards Android y Wear OS enlazan a sus guías.
- **S6** — Cross-nav completa: macOS → iPhone → watchOS → Android → Wear OS → Web (watchos.next=android; web.prev=wearos).
- **S7** — Regresión cero: markup balanceado (divs/sections) en los 6 manuales, svelte-check 0/0, build verde.

## Allowed edit surfaces

- `landing/static/guides/android.html`, `wearos.html` (nuevos), `watchos.html`/`web.html` (solo cross-nav)
- `landing/static/guides/img/android-*.jpg`, `img/wearos-*.jpg` (nuevos)
- `landing/src/routes/guides/+page.svelte`, `landing/src/lib/i18n/messages.ts` (bodies de índice)
- `landing/src/lib/components/landing/PlatformShowcase.svelte` (links de guías)
- `landing/static/sitemap.xml`
- `odd/tasks/936-guides-android-wear.md`

## Execution notes

- Capturas Android vía emulador Pixel 10 Pro + ui automation (locale es del sistema, tarea "Comprar café de avena" vinculada, sesión corriendo 24:37). El banner de hold post-sesión se descarta con el diálogo Detener para capturar el foco idle limpio.
- Las capturas Wear OS reutilizan los assets ES existentes (454×454, UI redonda) — sin sesión de captura nueva necesaria.
- Gotcha heredado: cerrar `</section>` de #tips en los HTML nuevos (mismo defecto que en #934, corregido antes de commit).
- Falso positivo documentado: el chequeo de imágenes "broken" cuenta lazy-load no iniciado como roto; el archivo real existe en build/.
- El prerender enlaza android.html/wearos.html — requieren que iphone.html/watchos.html existan (por eso la rama apila sobre #935).

## Log

- **L2 (2026-11-19 noche, review round)**: C4 + Juez 1 + Juez 2 → CHANGES_REQUESTED con hallazgos quirúrgicos (verificaron claims contra el código Android real: TaskAppFunctionService.kt solo registra createTask; strings.xml de energía es Ligera/Regular/Trabajo profundo; las tarjetas del dashboard se llaman Resumen Semanal/Mensual). Fixes: §8 reescrito a "Gemini, App Functions y atajos" (solo crear tareas — quitar el comando de voz inexistente y el picker; "App Actions" → App Functions/Connected Apps); wearos §6 sin "o el Assistant" (⚠️ este replace falló en la primera pasada por el <strong> en el matcheo — corregido en L3); energía con labels Android reales; "Resumen Semanal/Mensual"; "Sincro en la Nube" (figcaption); captions alineados a lo que muestra cada captura (android-03 chip de energía sin barra, android-05, wearos-03 sin racha); **web.html figure-row de #plan cerrado con </figure> reparado (preexistente desde el manual original — divs 34/34)**; claves guides.list.generic.body huérfanas eliminadas ×3 catálogos + union. Gate determinista de balance añadido a la verificación (script de stack-parser sobre los 6 HTML). out_of_scope=24 del paquete: mismo falso positivo del parser que #934 (0 archivos reales fuera — verificado con diff --name-only contra superficies).
- **L3 (2026-11-19 noche, re-review acotada)**: 9/10 pass. Últimos fixes: wearos §6 "o el Assistant" eliminado (había quedado por el matcheo fallido); android.html alt/figcaption de android-04 y bullet FAQ con "Resúmenes" y "Sincro en la Nube". **Desviación de capturas Wear registrada**: wearos-01/02/03 son capturas de un build anterior con strings desactualizados ("Pomodoro #4"/"Trabajando" — hoy el código usa "Enfoque #%1$d") y chrome parcial EN ("Today", "Focus time", "Sessions"; los títulos de tareas sí son ES); los strings ES actuales existen en android/wear/src/main/res/values-es/strings.xml — recapturar con el emulador Wear_OS_Large_Round pareado al teléfono queda como follow-up. Claim de Suscripción con rewording seguro (visible con sesión iniciada / Play Store). out_of_scope=24: falso positivo del parser confirmado nuevamente.
- **L1 (2026-11-19 noche)**: Issue #936 + worktree apilado sobre c79765af. Emulador boot + app ES (locale del sistema ya es). Capturas: foco idle limpio (tras descartar el hold con el diálogo Detener), Plan Inbox con 3 tareas ES, Más ES; reutilizados foco corriendo 24:37 y dashboard del run anterior. 8 imágenes convertidas. Manuales escritos, índice 6/6 con thumbs, sitemap +2 URLs, cross-nav 6 guías verificada por script (prev/next en ambas direcciones), markup balanceado, svelte-check 0/0, build verde.
