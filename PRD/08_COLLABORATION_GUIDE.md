# Guia de Colaboracion con Claude Code: Pepinillo Nativo (Ambas Plataformas)

**Guia unificada para maximizar Claude Code en el desarrollo de iOS y Android nativos.**

---

## 1. Que Hace Bien Claude Code

### iOS

- **Boilerplate TCA completo** (State, Action, Reducer, View, Client) -- genera el scaffolding de cualquier feature en minutos.
- **Generacion de Focus Mode Strategies** -- el patron Strategy para modos de enfoque es formulaico; Claude Code crea nuevas estrategias rapidamente.
- **Modelos SwiftData** -- modelos con relaciones, migraciones y compatibilidad con CloudKit.
- **Vistas SwiftUI desde descripciones** -- describe visualmente lo que quieres y Claude Code lo construye.
- **Templates de Widgets y Live Activities** -- WidgetKit y ActivityKit tienen patrones especificos que Claude Code conoce.
- **Generacion de tests TCA** -- TCA hace que los tests sean formulaicos (TestStore), perfecto para generacion automatica.
- **Localizacion (EN/ES/PT)** -- extraccion de strings y creacion de traducciones en formato `.xcstrings`.
- **App Intents / Shortcuts** -- declarativos y basados en patrones, Claude Code los genera rapido.

### Android

- **Compose UI desde descripciones** -- screens y componentes a partir de descripciones textuales.
- **ViewModel + StateFlow boilerplate** -- scaffolding completo de presenters/viewmodels con flujos de estado.
- **Room Entity + DAO generation** -- entidades, DAOs, relaciones y type converters.
- **Modulos Hilt** -- inyeccion de dependencias con generacion automatica de modulos.
- **Templates de widgets Glance** -- widgets de Home Screen con Glance Compose.
- **Templates de pantallas Wear OS** -- scaffolding para la app de reloj.
- **Generacion de tests (JUnit 5)** -- tests unitarios y de integracion.
- **Localizacion (strings.xml)** -- generacion y traduccion de archivos de strings en XML.

### Ambas Plataformas

- **Implementacion del patron Strategy** -- para modos de enfoque (Pomodoro, Flowtime, Time Block, Stopwatch).
- **Diseno de modelos de datos** -- traduccion de entidades entre plataformas manteniendo paridad.
- **Servicios de logica de negocio** -- reglas compartidas que deben ser identicas en ambas plataformas.
- **Mejoras de accesibilidad** -- etiquetas semanticas, VoiceOver/TalkBack, Dynamic Type/Font Scaling.
- **Code review y refactoring** -- revision cruzada para mantener consistencia entre plataformas.

---

## 2. Que Requiere Intervencion Humana

| Area | Razon | Aplica a |
|------|-------|----------|
| Decisiones de diseno visual | Claude Code construye cualquier layout descrito, pero no toma decisiones esteticas subjetivas | Ambas |
| Debugging de CloudKit sync | Fallos silenciosos, delays de sync, conflictos de merge -- requiere dispositivos reales con cuentas reales de iCloud | iOS |
| Testing en dispositivos reales | Los simuladores no reflejan comportamiento real (hapticos, bateria, conectividad, complicaciones) | Ambas |
| Problemas especificos de OEM | Comportamiento inconsistente entre fabricantes Android (Samsung, Xiaomi, etc.) | Android |
| Submission a App Store / Play Store | Screenshots, metadata, compliance con review guidelines | Ambas |
| Profiling de rendimiento | Instruments (iOS) y Android Profiler requieren herramientas interactivas | Ambas |
| Configuracion de certificados/firma | Signing, provisioning profiles, keystores | Ambas |
| Permisos de Health/HealthConnect | Aprobacion requiere justificacion especifica ante Apple/Google | Ambas |

---

## 3. Workflow Recomendado

### Manana (Planificacion)
1. Abrir el PRD y verificar la fase/tarea actual.
2. Indicar a Claude Code que se va a construir hoy.
3. Claude Code genera el scaffolding (TCA feature + views + tests en iOS, o Presenter + Compose + tests en Android).

### Construccion (Implementacion)
4. Revisar el codigo generado, ajustar al gusto.
5. Pedir implementaciones especificas: "Agrega feedback haptico al completar el timer" o "Haz que el widget se actualice cada minuto durante sesiones activas".
6. Ejecutar tests -- si fallan, pegar el error para que Claude Code lo corrija.

### Tarde (Revision)
7. Pedir a Claude Code revision del codigo del dia: "Revisa todos los archivos cambiados hoy buscando bugs, memory leaks, y mejores practicas".
8. Actualizar tests para cualquier comportamiento nuevo.
9. Commit con mensaje descriptivo.

---

## 4. Prompts de Inicio de Sesion

### Nueva Feature
> "Estoy construyendo [Nombre de Feature] para Pepinillo Nativo. Lee el PRD en PRD/01_PRODUCT_VISION.md para contexto. Quiero implementar [requisito especifico]. Empieza creando [el feature TCA y la vista SwiftUI / el Presenter y la pantalla Compose]."

### Correccion de Bug
> "Hay un bug en Pepinillo Nativo: [describir bug]. Los archivos relevantes son [listar archivos]. Debuggea esto y propone un fix. Considera edge cases de [timer en background / sync / conectividad del Watch]."

### Sesion de Refactor
> "Revisa la implementacion actual de [feature]. Sugiere mejoras para: calidad de codigo, testabilidad, rendimiento y alineacion con las mejores practicas de [TCA / Circuit+Compose]. Luego implementa los cambios."

### Sesion de Tests
> "Escribe tests completos para [Feature]. Cubre: happy path, edge cases, estados de error, e integracion con [feature dependiente]. Usa [TCA TestStore / JUnit 5 + Turbine]."

### Sesion de Localizacion
> "Extrae todos los strings nuevos de los siguientes archivos: [listar]. Agrega traducciones en espanol (LATAM) y portugues brasileno. Usa tuteo informal para espanol y 'voce' para portugues. Mantene el tono de las localizaciones existentes."

### Verificacion de Paridad Cross-Platform
> "Acabo de implementar [feature/fix] en [iOS/Android]. Verifica que el equivalente existe en [la otra plataforma]. Si no existe o tiene diferencias, implementa la paridad."

---

## 5. Integracion con SDD (Spec-Driven Development)

El workflow SDD permite planificar y ejecutar features sustanciales de forma estructurada:

1. **`/sdd-new nombre-feature`** -- Claude Code crea una propuesta enfocada.
2. **`/sdd-ff nombre-feature`** -- Fast-forward a traves de specs, diseno y desglose de tareas.
3. **`/sdd-apply nombre-feature`** -- Claude Code implementa las tareas en lotes.
4. **`/sdd-verify nombre-feature`** -- Verificacion automatizada contra la spec.

### Cuando Usar SDD
- Features nuevas sustanciales (ej: Flowtime mode, Weekly Review, Wear OS app).
- Refactors que tocan multiples archivos o capas.
- Cualquier cambio que requiera coordinacion entre iOS y Android.

### Cuando NO Usar SDD
- Bug fixes simples.
- Cambios cosmeticos o de localizacion.
- Ajustes de configuracion.

---

## 6. Regla de Paridad Cross-Platform (OBLIGATORIA)

Este es un proyecto multi-plataforma: **Android (telefono)**, **Wear OS (reloj)**, **iOS (telefono)** y **watchOS (Apple Watch)**.

Cada vez que se corrige un bug o se implementa una feature en CUALQUIER plataforma, se DEBE verificar y aplicar el equivalente en TODAS las demas plataformas antes de considerar la tarea completa.

| Plataforma cambiada | Tambien revisar y corregir |
|---------------------|---------------------------|
| Android phone | iOS phone, Wear OS, watchOS |
| iOS phone | Android phone, Wear OS, watchOS |
| Wear OS | watchOS, Android phone, iOS phone |
| watchOS | Wear OS, Android phone, iOS phone |
| Android + Wear OS | iOS + watchOS |
| iOS + watchOS | Android + Wear OS |

**Esto no es opcional.** El objetivo es mantener todas las plataformas funcionalmente identicas y libres de los mismos bugs.

### Proceso
1. Implementar en la plataforma primaria.
2. **INMEDIATAMENTE** verificar/implementar en la plataforma contraparte.
3. Verificar ambas antes de marcar como completo.

---

## 7. Archivos Clave para Contexto

Al iniciar cualquier sesion, cargar estos archivos para contexto:

### Generales
- `PRD/01_PRODUCT_VISION.md` -- que estamos construyendo y por que.
- `PRD/10_FLUTTER_MIGRATION_REFERENCE.md` -- referencia de migracion desde Flutter.
- `CLAUDE.md` -- convenciones del proyecto y reglas del orquestador.

### iOS
- `PRD_IOS/01_PRD_PEPINILLO_NATIVE.md` -- PRD especifico iOS.
- `PRD_IOS/03_TECHNICAL_ARCHITECTURE.md` -- arquitectura tecnica iOS (TCA, SwiftData, etc.).
- Los archivos del feature especifico en `ios/`.

### Android
- `PRD_ANDROID/01_PRD_ANDROID.md` -- PRD especifico Android.
- `PRD_ANDROID/03_TECHNICAL_ARCHITECTURE.md` -- arquitectura tecnica Android (Circuit, Room, etc.).
- Los archivos del feature especifico en `android/`.

---

## 8. Efectividad Estimada de Claude Code por Fase

| Fase | % de Trabajo con Claude Code | Mejor Usado Para |
|------|------------------------------|-------------------|
| Fase 1: Fundamentos | 60-70% | Scaffolding (TCA/Circuit), modelos de datos, vistas basicas, tests |
| Fase 2: Ecosistema | 40-50% | Templates de widgets/actividades, App Intents/Assistant, Watch/Wear scaffolding (testing manual necesario) |
| Fase 3: Pulido | 30-40% | Auditoria de accesibilidad, localizacion, sugerencias de rendimiento, boilerplate de StoreKit/Play Billing |
| Fase 4: Lanzamiento | 50-60% | Contenido de marketing, landing page, implementacion de bug fixes, optimizacion ASO |

---

## 9. Tips para Maximizar el Plan Max 5x

### Estrategia de Ventana de Contexto
- Cargar multiples archivos relacionados a la vez (Feature + View + Tests + Models).
- Pedir revisiones completas a traves de multiples archivos.
- Generar features enteras (reducer/presenter + vista + tests + localizacion) en una sola sesion.

### Optimizacion de Uso
- **Agrupar trabajo relacionado** -- no cambiar de contexto entre features no relacionadas a mitad de sesion.
- **Usar sub-agentes** para tareas de investigacion (documentacion de Apple/Google, disponibilidad de APIs).
- **Dejar que Claude Code escriba lo tedioso** -- enfocar la energia creativa en decisiones de diseno y UX.
- **Sesiones diarias de code review** -- prevencion barata contra deuda tecnica acumulada.
