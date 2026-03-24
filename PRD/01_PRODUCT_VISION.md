# Pepinillo — Unified Product Document: Deep Work Platform for Multi-Platform

**Version:** 1.0  
**Last Updated:** 2026-03-24  
**Author:** Tiago David + Claude Code  
**Status:** Active  
**Platforms:** iOS, Android, watchOS, Wear OS  
**Update Cadence:** Per-feature

---

## 1. Problem

Knowledge workers, students, and creatives lose an average of **2.1 hours per day** to context switching and interruptions. The market's response has been fragmented:

- **Pomodoro timers** (Forest, Focus Keeper, Brain Focus) offer a single rigid technique.
- **Task managers** (Things 3, Todoist) don't integrate focus time.
- **Time-blocking apps** (Structured) lack flexible timer methods.

**No app combines multiple focus techniques + task management + deep analytics in one experience.** The market competes on price ($2-5) with single-technique apps. There is no premium solution that offers:

1. **4 focus techniques** in one app
2. **Integrated task management** with energy levels and recurrence
3. **Complete ecosystem** on both platforms (Apple: widgets, Dynamic Island, watchOS, Siri; Android: widgets, Wear OS, Quick Settings, Google Assistant)
4. **Mode-specific analytics** to discover which technique works best
5. **LATAM-first pricing** that's accessible

Pepinillo started as a Flutter Pomodoro app. While functional, it had two critical limitations: (1) it was locked to Pomodoro as the only focus method, and (2) Flutter's abstraction blocked access to native platform APIs that are essential for a premium experience.

**The opportunity:** Reposition Pepinillo from "another Pomodoro timer" (saturated market, low price ceiling) to **"the multi-platform deep work platform"** — a premium productivity tool that offers multiple focus techniques, integrated task management, and the deepest possible integration with Apple and Android ecosystems. This moves us from competing with $3.99 apps to the premium tier of $30-60/year.

---

## 2. Vision

> **"Pepinillo is your command center for deep work."**
>
> An app where you plan what to work on, choose how to focus, track your progress, and build lasting productivity habits — all integrated natively into your Apple and Android devices.

The name "Pepinillo" (pickle/gherkin) is a playful contrast with the seriousness of deep work — memorable, accessible, and distinctive in a market full of generic names like "Focus Timer Pro" and "Session."

### Platform Availability

| Platform            | Native Stack                       | Status         |
| ------------------- | ---------------------------------- | -------------- |
| **iOS (iPhone)**    | Swift + TCA + SwiftData            | In Development |
| **Android (Phone)** | Kotlin + MVI (Circuit) + Room      | In Development |
| **watchOS**         | SwiftUI native                     | In Development |
| **Wear OS**         | Jetpack Compose                    | In Development |
| **iPad**            | SwiftUI (NavigationSplitView)      | Planned        |
| **macOS**           | SwiftUI native                     | Planned        |
| **Android Tablets** | Jetpack Compose (adaptive layouts) | Planned        |

---

## 3. Objetivos

| #      | Objetivo                                                                                                           | Métrica                                                                                                                              |
| ------ | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| **G1** | **Ser LA app de trabajo profundo** — Pepinillo debe sentirse como si la hubiera hecho Apple/Google respectivamente | App Store rating >= 4.7; Play Store rating >= 4.5; featured editorial en ambas tiendas dentro de 6 meses                             |
| **G2** | **Enfoque multi-modo** — Los usuarios eligen la técnica que les funciona, no la que la app les impone              | >= 3 modos usados en la base de usuarios; Pomodoro representa < 60% de las sesiones (probando que los usuarios quieren variedad)     |
| **G3** | **Conversión premium a través de valor innegable** — Los usuarios pagan porque el tier gratuito ya los impresionó  | Conversión premium >= 8% (vs. industria avg 3-5% para timer apps); ARPU >= $3.50/mes                                                 |
| **G4** | **Profundidad de ecosistema como moat competitivo** — Ningún competidor iguala nuestra amplitud de integración     | >= 60% de sesiones de enfoque iniciadas fuera de la app principal (widgets, Watch/Wear, Siri/Assistant, Dynamic Island/Notification) |
| **G5** | **Dominar el mercado LATAM** — Primera app de productividad premium con pricing y localización LATAM-first         | Top 10 Productividad en Brasil y México dentro de 12 meses; 40%+ de la base de usuarios de LATAM                                     |
| **G6** | **Construir hábitos duraderos, no solo uso** — Los usuarios desarrollan mejora real de productividad               | >= 40% retención D30; streak promedio >= 14 días entre usuarios retenidos                                                            |
| **G7** | **Paridad cross-platform** — Mismas features, misma calidad, todas las plataformas                                 | 100% de features P0 disponibles en iOS y Android simultáneamente; bugs corregidos en una plataforma verificados en la otra           |

---

## 4. No-Objetivos

| #       | No-Objetivo                                        | Razón                                                                                                          |
| ------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **NG1** | **Sin features de equipo/colaboración**            | Trabajo profundo individual primero; B2B es una iniciativa separada                                            |
| **NG2** | **Sin toma de notas / editor de documentos**       | Complementamos apps como Craft, Notion y Google Docs, no las reemplazamos                                      |
| **NG3** | **Sin desglose de tareas por IA**                  | La IA es solo para insights y análisis (Mode Intelligence, Weekly Review); el flujo de trabajo es human-driven |
| **NG4** | **Sin creación de música ambiental / marketplace** | Soundscapes curados pre-incluidos son suficientes; no somos una app de música                                  |
| **NG5** | **Sin paridad de web app**                         | La web (Next.js) tiene su propio roadmap separado                                                              |
| **NG6** | **Sin reemplazo de calendario**                    | Nos integramos con Apple Calendar y Google Calendar, no competimos con Fantastical ni Google Calendar          |

> **Nota:** El antiguo NG1 de iOS ("Android se queda en Flutter") es **obsoleto**. Android ahora es nativo Kotlin con paridad completa.

---

## 5. Usuarios Objetivo

### P0 — Core (Lanzamiento)

| Segmento                 | Descripción                                                                                   | Plataformas  |
| ------------------------ | --------------------------------------------------------------------------------------------- | ------------ |
| **Power Users**          | Usuarios Apple (iPhone/Watch) y Samsung/Pixel que buscan productividad premium                | iOS, Android |
| **Estudiantes LATAM**    | Necesitan precio accesible, español/portugués, técnicas de estudio variadas                   | iOS, Android |
| **Trabajadores Remotos** | Necesitan estructura diaria, Pomodoro + Time Blocks, tracking de productividad                | iOS, Android |
| **Knowledge Workers**    | Profesionales que hacen trabajo profundo regularmente (escritores, analistas, investigadores) | iOS, Android |

### P1 — Expansión

| Segmento                    | Descripción                                                                   | Plataformas      |
| --------------------------- | ----------------------------------------------------------------------------- | ---------------- |
| **Comunidad ADHD**          | Múltiples técnicas para diferentes estados mentales; la flexibilidad es clave | iOS, Android     |
| **Usuarios de reloj**       | Quieren controlar el timer desde la muñeca sin sacar el teléfono              | watchOS, Wear OS |
| **Lectores de Cal Newport** | Ya convencidos del trabajo profundo; buscan la herramienta que lo implemente  | iOS, Android     |

### P2 — Futuro

| Segmento                        | Descripción                                                | Plataformas           |
| ------------------------------- | ---------------------------------------------------------- | --------------------- |
| **Usuarios de tablet**          | Productividad en pantalla grande, split-screen, multitarea | iPad, Samsung Tablets |
| **Desarrolladores / Creativos** | Sesiones largas de código o diseño; prefieren Flowtime     | iOS, Android          |

---

## 6. Modos de Enfoque — El Diferenciador

A diferencia de las apps puras de Pomodoro, Pepinillo ofrece **cuatro técnicas de enfoque** entre las que los usuarios pueden alternar libremente. Este es el mayor diferenciador frente a toda la competencia. **Los cuatro modos son idénticos en comportamiento y UX en todas las plataformas.**

### 6.1 Modo Pomodoro (GRATUITO)

| Aspecto            | Detalle                                                                                                         |
| ------------------ | --------------------------------------------------------------------------------------------------------------- |
| **Mecánica**       | Ciclos clásicos 25/5/15 con personalización completa de duraciones                                              |
| **Comportamiento** | Auto-avance a través de ciclos trabajo -> descanso -> trabajo. Muestra número de Pomodoro actual (ej. "3 de 4") |
| **Ideal para**     | Estudio, tareas administrativas, cualquier trabajo que se beneficie de estructura rígida                        |
| **Tier**           | Gratuito                                                                                                        |

### 6.2 Modo Flowtime (PRO)

| Aspecto            | Detalle                                                                                                                         |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| **Mecánica**       | Sesión de enfoque abierta. Sin intervalos forzados. El usuario toca para tomar descanso cuando sienta que la concentración baja |
| **Comportamiento** | La app sugiere duración de descanso basada en tiempo enfocado (10 min enfoque -> 2 min descanso, 50 min -> 10 min descanso)     |
| **Ideal para**     | Trabajo creativo, escritura, programación — cualquier actividad donde interrumpir el flujo es contraproducente                  |
| **Tier**           | Pro                                                                                                                             |

> **Por qué importa:** Muchos expertos en productividad (incluyendo Cal Newport) argumentan que los bloques forzados de 25 minutos interrumpen los estados de flujo. Flowtime captura la audiencia que probó Pomodoro y lo abandonó.

### 6.3 Modo Time-Block (PRO)

| Aspecto            | Detalle                                                                                                                     |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| **Mecánica**       | Bloque de enfoque fijo (ej. "2 horas de escritura"). Una cuenta regresiva continua con check-ins opcionales a la mitad      |
| **Comportamiento** | Rastrea cuántos bloques se completan por día. Se integra con Apple Calendar / Google Calendar para mostrar tiempo bloqueado |
| **Ideal para**     | Usuarios de la técnica de time-blocking; planificación de jornada completa                                                  |
| **Tier**           | Pro                                                                                                                         |

> **Por qué importa:** Time-blocking es la técnica #1 recomendada por Cal Newport en "Deep Work." Actualmente ninguna app importante la implementa como modo de timer de primera clase.

### 6.4 Modo Cronómetro / Stopwatch (GRATUITO)

| Aspecto            | Detalle                                                                                               |
| ------------------ | ----------------------------------------------------------------------------------------------------- |
| **Mecánica**       | Timer abierto que cuenta hacia arriba. Sin presión, sin metas. Solo rastrea cuánto tiempo trabajas    |
| **Comportamiento** | Toca para pausar. Toca para detener. Sin notificaciones de interrupción                               |
| **Ideal para**     | Días donde solo quieres sentarte y trabajar sin que una técnica te diga cuándo parar; tracking casual |
| **Tier**           | Gratuito                                                                                              |

### 6.5 Mode Intelligence (P1)

Después de **2+ semanas de datos**, Pepinillo sugiere qué modo funciona mejor para diferentes tipos de tarea basándose en las tasas de completación y patrones de interrupción del usuario.

> _"Completas 80% más tareas de escritura con Flowtime. ¿Quieres probarlo para el blog post de hoy?"_

**Disponible en:** iOS y Android (misma lógica, datos por plataforma).

---

## 7. Historias de Usuario

### 7.1 Experiencia de Sesión de Enfoque

| ID    | Historia                                                                                                                                                                                               | Plataforma        |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------- |
| US-1  | Como desarrollador entrando a una sesión de código, quiero elegir modo Flowtime y empezar a enfocarme con un tap para que mi concentración no sea interrumpida artificialmente por intervalos rígidos. | [Todas]           |
| US-2  | Como estudiante preparando exámenes, quiero usar modo Pomodoro 25/5 desde mi widget de pantalla de bloqueo para comenzar a estudiar sin desbloquear mi teléfono.                                       | [Todas]           |
| US-3a | Como escritor bloqueando 3 horas para su novela, quiero configurar un Time-Block y verlo en mi Dynamic Island para siempre saber cuánto de mi bloque queda.                                            | [iOS]             |
| US-3b | Como escritor bloqueando 3 horas para su novela, quiero configurar un Time-Block y verlo en mi notificación persistente para siempre saber cuánto de mi bloque queda.                                  | [Android]         |
| US-4a | Como trabajador remoto que solo quiere rastrear tiempo de enfoque, quiero iniciar un Cronómetro desde mi Apple Watch y olvidarme hasta que termine.                                                    | [iOS/watchOS]     |
| US-4b | Como trabajador remoto que solo quiere rastrear tiempo de enfoque, quiero iniciar un Cronómetro desde mi reloj Wear OS y olvidarme hasta que termine.                                                  | [Android/Wear OS] |
| US-5a | Como usuario de Focus Modes de Apple, quiero que Pepinillo active automáticamente mi modo "Deep Work" cuando inicio cualquier sesión de enfoque.                                                       | [iOS]             |
| US-5b | Como usuario de Android, quiero que Pepinillo active el modo Focus / No Molestar cuando inicio cualquier sesión de enfoque.                                                                            | [Android]         |
| US-6a | Como alguien que prefiere comandos de voz, quiero decir "Hey Siri, inicia un bloque de 2 horas de deep work en Pepinillo."                                                                             | [iOS]             |
| US-6b | Como alguien que prefiere comandos de voz, quiero decir "Hey Google, inicia un bloque de 2 horas de deep work en Pepinillo."                                                                           | [Android]         |
| US-7  | Como usuario que ha probado múltiples técnicas, quiero que Pepinillo me muestre qué modo de enfoque me da los mejores resultados para diferentes tipos de tarea.                                       | [Todas]           |

### 7.2 Gestión de Tareas

| ID     | Historia                                                                                                                                                            | Plataforma |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| US-8   | Como freelancer con múltiples clientes, quiero crear tareas con subtareas y asignar tiempo estimado de enfoque a cada una para planificar mi día de forma realista. | [Todas]    |
| US-9   | Como power user, quiero etiquetar tareas con niveles de energía (deep work, shallow work, admin) para agrupar trabajo similar.                                      | [Todas]    |
| US-10  | Como alguien con responsabilidades recurrentes, quiero tareas recurrentes que aparezcan automáticamente cada día/semana.                                            | [Todas]    |
| US-11a | Como usuario de Apple Reminders, quiero importar tareas desde Reminders para tener una vista consolidada.                                                           | [iOS]      |
| US-11b | Como usuario de Google Tasks, quiero importar tareas desde Google Tasks para tener una vista consolidada.                                                           | [Android]  |
| US-12  | Como estudiante, quiero arrastrar tareas para reordenar por prioridad y ver el tiempo total estimado de enfoque para mi día.                                        | [Todas]    |

### 7.3 Analítica y Crecimiento

| ID     | Historia                                                                                                                                                                           | Plataforma |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| US-13  | Como alguien optimizando mi productividad, quiero ver qué modo de enfoque uso más, cuál me da la mejor tasa de completación, y cuándo soy más productivo (hora, día de la semana). | [Todas]    |
| US-14a | Como profesional consciente de la salud, quiero que mi tiempo de enfoque se registre en Apple Health como Mindful Minutes.                                                         | [iOS]      |
| US-14b | Como profesional consciente de la salud, quiero que mi tiempo de enfoque se registre en Google Health Connect como Mindful Minutes.                                                | [Android]  |
| US-15  | Como usuario revisando mi semana, quiero un "Weekly Review" que compare mis horas de enfoque, tareas completadas y racha contra la semana pasada — con flechas de tendencia.       | [Todas]    |
| US-16  | Como alguien motivado por la consistencia, quiero una racha de enfoque (días consecutivos con >= 1 sesión completada) con hitos a los 7, 30, 100 y 365 días.                       | [Todas]    |

### 7.4 Multi-Dispositivo y Sync

| ID     | Historia                                                                                                                                           | Plataforma       |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| US-17a | Como alguien que inicia tareas en Mac y continúa en iPhone, quiero sync CloudKit en segundos.                                                      | [iOS]            |
| US-17b | Como alguien que usa múltiples dispositivos Android, quiero sync via backend en segundos.                                                          | [Android]        |
| US-18a | Como usuario de Apple Watch, quiero ver mi lista de tareas, iniciar cualquier modo de enfoque y recibir feedback háptico cuando termine mi sesión. | [watchOS]        |
| US-18b | Como usuario de Wear OS, quiero ver mi lista de tareas, iniciar cualquier modo de enfoque y recibir feedback háptico cuando termine mi sesión.     | [Wear OS]        |
| US-19a | Como usuario de iPad, quiero Pepinillo en Split View junto a mi app de escritura con atajos de teclado para control rápido del timer.              | [iOS/iPad]       |
| US-19b | Como usuario de tablet Samsung, quiero Pepinillo en split-screen junto a mi app de trabajo.                                                        | [Android/Tablet] |

### 7.5 Personalización

| ID     | Historia                                                                                                                                                                               | Plataforma |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| US-20a | Como alguien que valora la estética, quiero múltiples temas incluyendo un tema Liquid Glass para iOS 26.                                                                               | [iOS]      |
| US-20b | Como alguien que valora la estética, quiero theming Material You dinámico basado en mi wallpaper.                                                                                      | [Android]  |
| US-21  | Como usuario que trabaja de noche, quiero soundscapes ambientales (lluvia, café, ruido blanco) que suenen durante sesiones de enfoque y se detengan automáticamente durante descansos. | [Todas]    |

### 7.6 Ecosistema

| ID     | Historia                                                                                                              | Plataforma |
| ------ | --------------------------------------------------------------------------------------------------------------------- | ---------- |
| US-22a | Como power user de iOS, quiero iniciar sesiones rápidas desde el Quick Settings tile del Control Center.              | [iOS]      |
| US-22b | Como power user de Android, quiero iniciar sesiones rápidas desde el Quick Settings tile del panel de notificaciones. | [Android]  |
| US-23a | Como usuario de calendario, quiero que mis Time-Blocks aparezcan en Apple Calendar.                                   | [iOS]      |
| US-23b | Como usuario de calendario, quiero que mis Time-Blocks aparezcan en Google Calendar.                                  | [Android]  |

### 7.7 Casos Edge

| ID     | Historia                                                                                                                                    | Plataforma        |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| US-24  | Como usuario que recibe una llamada a mitad de sesión, quiero que el timer maneje la interrupción de forma elegante (pausar o registrarla). | [Todas]           |
| US-25  | Como usuario que hace force-quit de la app, quiero que mi timer continúe y me alerte cuando se complete.                                    | [Todas]           |
| US-26a | Como usuario cambiando de dispositivo, quiero que mi sesión activa en iPhone aparezca en mi Watch inmediatamente.                           | [iOS/watchOS]     |
| US-26b | Como usuario cambiando de dispositivo, quiero que mi sesión activa en mi teléfono Android aparezca en mi reloj Wear OS.                     | [Android/Wear OS] |

---

## 8. Principio de Paridad Cross-Platform

### Regla Obligatoria

La paridad cross-platform es **MANDATORIA** en este proyecto. Esto significa:

> **Cada feature construida en una plataforma DEBE ser construida en la otra. Cada bug corregido en una plataforma DEBE ser verificado y corregido en la otra.**

### Matriz de Paridad

| Cambio en...      | Debe verificarse y aplicarse en... |
| ----------------- | ---------------------------------- |
| Android phone     | iOS phone, Wear OS, watchOS        |
| iOS phone         | Android phone, Wear OS, watchOS    |
| Wear OS           | watchOS, Android phone, iOS phone  |
| watchOS           | Wear OS, Android phone, iOS phone  |
| Android + Wear OS | iOS + watchOS                      |
| iOS + watchOS     | Android + Wear OS                  |

### Implementación de la Paridad

| Aspecto                 | iOS / watchOS                  | Android / Wear OS                              |
| ----------------------- | ------------------------------ | ---------------------------------------------- |
| **Lenguaje**            | Swift                          | Kotlin                                         |
| **UI Framework**        | SwiftUI                        | Jetpack Compose                                |
| **Arquitectura**        | TCA (Composable Architecture)  | MVI (Circuit/Orbit)                            |
| **Base de datos local** | SwiftData                      | Room                                           |
| **Sync**                | CloudKit                       | Backend Go (REST API)                          |
| **Widgets**             | WidgetKit                      | Glance (Jetpack Compose)                       |
| **Actividad en vivo**   | Live Activity + Dynamic Island | Rich Ongoing Notification (Foreground Service) |
| **Reloj**               | watchOS (SwiftUI nativo)       | Wear OS (Compose)                              |
| **Asistente de voz**    | Siri Shortcuts (App Intents)   | Google Assistant App Actions                   |
| **Control rápido**      | Control Center Widget          | Quick Settings Tile                            |
| **Salud**               | Apple HealthKit                | Google Health Connect                          |
| **Pagos**               | StoreKit 2                     | Google Play Billing 7                          |
| **Modo enfoque del OS** | Apple Focus Filters            | Android Focus Mode / DND                       |
| **Theming**             | Temas manuales + Liquid Glass  | Material You (Dynamic Color)                   |

### Proceso de Verificación

1. **Al corregir un bug:** Antes de cerrar el issue, verificar si el mismo bug puede existir en la otra plataforma. Si sí, corregirlo.
2. **Al implementar una feature:** La feature no se considera completa hasta que exista en ambas plataformas con comportamiento equivalente.
3. **En code review:** Siempre preguntar: "¿Tiene esto equivalente en la otra plataforma? ¿Está actualizado?"

### Excepciones Aceptables

Las únicas diferencias aceptables son las **impuestas por la plataforma**:

- Dynamic Island (solo iOS) vs. Ongoing Notification (solo Android)
- CloudKit sync (iOS) vs. Backend REST sync (Android)
- Material You dynamic theming (solo Android) vs. Liquid Glass (solo iOS)
- Apple Reminders import (iOS) vs. Google Tasks import (Android)
- Siri (iOS) vs. Google Assistant (Android)

En todos estos casos, la **funcionalidad equivalente** debe existir aunque la implementación técnica difiera.

---

_Este documento unifica y reemplaza los PRDs individuales de plataforma (`PRD_IOS/01_PRD_PEPINILLO_NATIVE.md` y `PRD_ANDROID/01_PRD_PEPINILLO_ANDROID.md`) como la fuente de verdad para la visión del producto._
