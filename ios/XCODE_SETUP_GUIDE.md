# Pepinillo iOS Nativa — Guía de Creación del Proyecto Xcode

**Fecha:** Marzo 2026
**Prerrequisitos:** Xcode 16+, macOS 14+, Apple Developer Account, `brew` instalado
**Estado del código:** 63+ archivos Swift listos. Stages 1–5 completos.

---

## Opción A: XcodeGen (RECOMENDADO — 10 minutos)

Ya tienes un `project.yml` listo que define los 5 targets + esquema + dependencias.

### Paso 1 — Instalar XcodeGen

```bash
brew install xcodegen
```

Verifica con `xcodegen --version` (necesitas 2.38+).

### Paso 2 — Poner tu Team ID

Abre `pepinillo_ios/project.yml` y busca la línea:

```yaml
DEVELOPMENT_TEAM: ""  # ← Fill in your Apple Developer Team ID
```

Reemplaza con tu Team ID real (lo encuentras en [developer.apple.com](https://developer.apple.com/account) → Membership → Team ID). Ejemplo:

```yaml
DEVELOPMENT_TEAM: "ABC123XYZ"
```

### Paso 3 — Generar el proyecto

```bash
cd ~/Desktop/creapolis/pepinillo/apps/ios_nativa
xcodegen generate
```

Deberías ver:
```
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at Pepinillo.xcodeproj
```

Esto genera `Pepinillo.xcodeproj` con **6 targets** preconfigurados:

| Target | Tipo | Bundle ID |
|--------|------|-----------|
| Pepinillo | App iOS | `com.pepinillo.app` |
| PepinilloWidgetExtension | Widget Extension | `com.pepinillo.app.widget` |
| PepinilloWatch | watchOS App | `com.pepinillo.app.watch` |
| PepinilloControlCenter | App Extension | `com.pepinillo.app.controlcenter` |
| PepinilloTests | Unit Test Bundle | `com.pepinillo.tests` |

### Paso 4 — Abrir en Xcode

```bash
open Pepinillo.xcodeproj
```

**⚠️ IMPORTANTE:** Xcode te pedirá resolver los paquetes SPM (TCA + SnapshotTesting). Dale **Resolve** y espera a que descargue (~2 minutos).

---

## Opción B: Creación Manual en Xcode (si no quieres usar XcodeGen)

### Paso 1 — Crear el proyecto base

1. Xcode → **File → New → Project**
2. Elegir **App** (bajo iOS)
3. Configurar:
   - Product Name: `Pepinillo`
   - Team: Tu equipo de desarrollo
   - Organization Identifier: `com.pepinillo`
   - Bundle Identifier: `com.pepinillo.app`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (usamos SwiftData manualmente)
   - ❌ Desmarcar "Include Tests" (los agregaremos manualmente)
4. Guardar en: `pepinillo_ios/`

### Paso 2 — Eliminar archivos template y agregar los reales

1. En el Navigator, elimina los archivos generados por Xcode (ContentView.swift, PepinilloApp.swift del template)
2. **File → Add Files to "Pepinillo"** → selecciona estas carpetas:
   - `App/`
   - `Features/`
   - `Domain/`
   - `Shared/`
   - `PepinilloIntents/`
3. Asegúrate de que **"Create groups"** esté seleccionado y el target **Pepinillo** esté marcado

### Paso 3 — Agregar los targets de extensiones

Para cada extensión, haz **File → New → Target**:

**Widget Extension:**
1. Buscar "Widget Extension" → Next
2. Product Name: `PepinilloWidgetExtension`
3. ❌ Desmarcar "Include Live Activity" y "Include Configuration App Intent" (ya los tenemos)
4. Finish → **Delete** los archivos template generados
5. Agrega los archivos de `PepinilloWidget/` y `PepinilloLiveActivity/` a este target

**Watch App:**
1. Buscar "Watch App" → Next
2. Product Name: `PepinilloWatch`
3. Watch-only App
4. Finish → **Delete** los archivos template
5. Agrega los archivos de `PepinilloWatch/` a este target
6. También agrega al target Watch: `Domain/Models/`, `Domain/Clients/`, `Features/Focus/FocusModels.swift`, `Shared/Design/`

**Unit Test Bundle:**
1. **File → New → Target → Unit Testing Bundle**
2. Product Name: `PepinilloTests`
3. Target to be Tested: `Pepinillo`
4. Agrega los archivos de `Tests/` a este target

### Paso 4 — Agregar TCA via SPM

1. **File → Add Package Dependencies**
2. URL: `https://github.com/pointfreeco/swift-composable-architecture`
3. Dependency Rule: **Up to Next Major** → `1.17.0`
4. Add to targets: `Pepinillo`, `PepinilloWidgetExtension`, `PepinilloWatch`, `PepinilloTests`

Repetir para SnapshotTesting:
1. URL: `https://github.com/pointfreeco/swift-snapshot-testing`
2. Version: `1.17.0`
3. Add to target: `PepinilloTests` solamente

---

## Configuración Post-Generación (AMBAS OPCIONES)

Estos pasos se hacen en Xcode independientemente de cómo creaste el proyecto.

### 5. Configurar Signing & Capabilities

Para **CADA target**, ve a **Signing & Capabilities**:

1. **Pepinillo (main app):**
   - Team: Selecciona tu equipo
   - Bundle Identifier: `com.pepinillo.app`
   - Signing: Automatic
   - Click **+ Capability** y agrega:
     - ✅ App Groups → `group.com.pepinillo.app`
     - ✅ iCloud → marca CloudKit → Container: `iCloud.com.pepinillo.app`
     - ✅ HealthKit
     - ✅ Siri
     - ✅ Push Notifications
     - ✅ Background Modes → marca "Background fetch" y "Remote notifications"

2. **PepinilloWidgetExtension:**
   - Team: Selecciona tu equipo
   - Bundle Identifier: `com.pepinillo.app.widget`
   - Click **+ Capability**:
     - ✅ App Groups → `group.com.pepinillo.app`

3. **PepinilloWatch:**
   - Team: Selecciona tu equipo
   - Bundle Identifier: `com.pepinillo.app.watch`
   - Click **+ Capability**:
     - ✅ App Groups → `group.com.pepinillo.app`

4. **PepinilloControlCenter (si lo usas):**
   - Team: Selecciona tu equipo
   - Bundle Identifier: `com.pepinillo.app.controlcenter`
   - Click **+ Capability**:
     - ✅ App Groups → `group.com.pepinillo.app`

### 6. Crear el iCloud Container

Si al agregar CloudKit Xcode no encuentra el container:

1. Ve a [developer.apple.com/account](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles → Identifiers**
3. Click **+** → **iCloud Containers**
4. Nombre: `iCloud.com.pepinillo.app`
5. Vuelve a Xcode → Signing & Capabilities → iCloud → Refresh → selecciona el container

### 7. Crear el App Group

Similar al paso anterior, si no existe:

1. Developer Portal → **Identifiers → App Groups**
2. Click **+** → `group.com.pepinillo.app`
3. En Xcode, refresh en cada target que lo necesite

### 8. StoreKit Configuration File

1. **File → New → File → StoreKit Configuration File**
2. Nombre: `Pepinillo.storekit`
3. Guardar en la raíz del proyecto (`pepinillo_ios/`)
4. Agrega 3 productos:

| Tipo | Product ID | Nombre | Precio |
|------|-----------|--------|--------|
| Auto-Renewable Subscription | `com.pepinillo.pro.monthly` | Pro Monthly | $2.99 |
| Auto-Renewable Subscription | `com.pepinillo.pro.annual` | Pro Annual | $14.99 |
| Non-Consumable | `com.pepinillo.pro.lifetime` | Pro Lifetime | $29.99 |

5. Para las subscriptions, crea un **Subscription Group** llamado `Pepinillo Pro`
6. **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration** → selecciona `Pepinillo.storekit`

### 9. Localización

1. Click en el **proyecto** (ícono azul arriba del Navigator)
2. Pestaña **Info**
3. Sección **Localizations** → click **+**
4. Agrega: **Spanish (es)** y **Portuguese (pt-BR)**
5. Cuando pregunte qué archivos localizar, selecciona `Localizable.xcstrings`

### 10. Deployment Targets

Verifica en **Build Settings** de cada target:

| Target | iOS Deployment Target | watchOS Deployment Target |
|--------|----------------------|--------------------------|
| Pepinillo | 17.0 | — |
| PepinilloWidgetExtension | 17.0 | — |
| PepinilloWatch | — | 10.0 |
| PepinilloControlCenter | 18.0 | — |
| PepinilloTests | 17.0 | — |

### 11. Agregar Audio Files para Soundscapes

Necesitas 8 archivos de audio (los puedes bajar de freesound.org o pixabay.com/music):

| Archivo | Descripción |
|---------|-------------|
| `rain.mp3` | Lluvia ambiente (loop) |
| `forest.mp3` | Bosque con pájaros (loop) |
| `cafe.mp3` | Café ambiente (loop) |
| `white_noise.mp3` | Ruido blanco (loop) |
| `ocean.mp3` | Olas del mar (loop) — Pro |
| `fireplace.mp3` | Chimenea (loop) — Pro |
| `binaural.mp3` | Binaural beats 40Hz (loop) — Pro |
| `lofi.mp3` | Lo-fi música (loop) — Pro |

1. Crea una carpeta `Shared/Sounds/Audio/` en el proyecto
2. Arrastra los 8 archivos ahí
3. Asegúrate de que estén en **Target Membership → Pepinillo** (main app solamente)

### 12. Assets (App Icon)

1. Abre `Shared/Resources/Assets.xcassets`
2. Click en **AppIcon**
3. Arrastra tu icono de 1024x1024 al slot principal
4. Xcode 15+ genera automáticamente todos los tamaños

---

## Verificación Final — Checklist

Después de completar todo, verifica:

- [ ] `Cmd+B` compila sin errores el target **Pepinillo**
- [ ] `Cmd+B` compila el target **PepinilloWatch**
- [ ] `Cmd+B` compila el target **PepinilloWidgetExtension**
- [ ] `Cmd+U` corre los tests de **PepinilloTests**
- [ ] Selecciona un simulador iPhone 16 → `Cmd+R` → la app abre
- [ ] Selecciona un simulador Apple Watch → verifica que compila
- [ ] En el simulador: verifica que aparece el widget en la galería
- [ ] En el simulador: verifica que Siri reconoce "Start deep work in Pepinillo"

---

## Troubleshooting Común

**"No such module 'ComposableArchitecture'"**
→ File → Packages → Resolve Package Versions. Espera a que termine.

**"Signing requires a development team"**
→ Selecciona tu Team en cada target → Signing & Capabilities.

**Widget muestra datos vacíos**
→ Verifica que App Group `group.com.pepinillo.app` esté en AMBOS targets (main + widget).

**Watch app no aparece en simulador**
→ En el scheme selector, elige el target PepinilloWatch y un simulador de Watch pareado.

**"Cannot find 'FocusModels' in scope" en Watch target**
→ Verifica que `Features/Focus/FocusModels.swift` esté en Target Membership de PepinilloWatch.

**CloudKit sync no funciona en simulador**
→ Normal. CloudKit necesita un dispositivo real con iCloud activo.

---

## Siguiente Paso: TestFlight

Una vez que todo compile y funcione en simulador:

1. **Product → Archive** (con un dispositivo real seleccionado)
2. En el Organizer → **Distribute App → TestFlight**
3. Sigue el wizard de firma y sube
4. En App Store Connect, agrega testers al build

---

*Generado desde PRD_IOS/ y DEVELOPMENT.md — Marzo 2026*
