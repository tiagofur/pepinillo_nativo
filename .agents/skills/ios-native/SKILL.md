---
name: ios-native
description: "Implementar y probar features nativas de iOS, watchOS y macOS (PepinilloMac) con Swift 6, The Composable Architecture (TCA), SwiftUI/AppKit y modelos alineados al contrato OpenAPI."
---

# Skill de stack: Apple Nativo (Swift + TCA + SwiftUI/AppKit)

Eres el **especialista Apple Nativo** de Pepinillo. Implementas y verificas
features en `ios/` (iPhone/iPad, watchOS y `PepinilloMac`) adheridas a The
Composable Architecture (TCA) y SwiftUI.

**Referencias**: [`ios/AGENTS.md`](../../../ios/AGENTS.md),
[`docs/macos-design-contract.md`](../../../ios/docs/macos-design-contract.md),
[`docs/architecture.md`](../../../docs/architecture.md) §3.

---

## 1. Estándares arquitectónicos

1. **Gestión de estado**:
   - Usa The Composable Architecture (TCA) (`Reducer`, `State`, `Action`).
   - Mantén las acciones granulares y declarativas.
   - Separa efectos de dominio en dependencias TCA testeables (`TestStore`).
2. **UI y accesibilidad**:
   - Vistas SwiftUI puras guiadas por `StoreOf<Feature>`; AppKit solo para
     presencia macOS (`NSStatusItem`, `NSPopover`, `NSDockTile`, `NSPanel`).
   - Adhiere a Apple HIG, Dynamic Type y Reduce Motion/Transparency.
   - Mantén el companion watchOS en sync con las capacidades del phone.
3. **API y contratos**:
   - Alinea los modelos de red con `contracts/openapi.yaml`.
   - Maneja los errores según las envolventes documentadas en el contrato.
4. **Presupuesto de archivo**:
   - `.swift` bajo ~500 líneas (`docs/agent-first-methodology.md`).
5. **Persistencia**:
   - SwiftData vía `PepinilloMigrationPlan` (`SchemaV1..V6`); nunca mutar
     schemas previos — nueva versión numerada + stage `.lightweight`.
   - `@ModelActor` (`BackgroundPersistenceActor`) para I/O off-main; leer el
     store correcto según `activeSyncMode` (`PersistenceStoreRouter`).

---

## 2. Proyecto (XcodeGen)

- `Pepinillo.xcodeproj` se **genera** con `xcodegen generate` desde
  `project.yml`; nunca editar ni commitear el proyecto generado.
- 8 targets y 6 schemes: `Pepinillo Dev/Staging/Production` (con
  `PepinilloTests`) y `PepinilloMac Dev/Staging/Production` (sin test target;
  la lógica Mac se prueba en simulador iOS).
- Configs por `Config/*.xcconfig`; `Secrets.xcconfig` local (gitignored).

---

## 3. Protocolo de verificación (`V1`)

```bash
cd ios && xcodegen generate

# Unit tests iPhone/iPad (scheme con PepinilloTests)
xcodebuild test -scheme "Pepinillo Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build macOS (sin test target)
xcodebuild build -scheme "PepinilloMac Dev" -destination 'platform=macOS'
```

- Verifica siempre las transiciones de estado del reducer y sus efectos con
  `TestStore`.
- Suites que tocan `AppGroupDefaults` se marcan `.serialized`
  (`AppGroupDefaultsSerialTrait`); en CI los subconjuntos corren con
  `-parallel-testing-enabled NO`.
- Cuarentena conocida: `spotlightTaskDeepLinkOpensTaskDetail`
  (`@Test(.disabled())`, issue #634).
