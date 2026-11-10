# ios/AGENTS.md — Apple Nativo (iOS, iPadOS, watchOS, macOS)

Mapa rápido para agentes que tocan `ios/**`. Arquitectura y gaps actuales:
[`../docs/architecture.md`](../docs/architecture.md) §3. Contrato de diseño
macOS: [`docs/macos-design-contract.md`](docs/macos-design-contract.md).

---

## Proyecto XcodeGen (fuente de verdad: `project.yml`)

- `Pepinillo.xcodeproj` **se genera** con `xcodegen generate` (está en
  `.gitignore`). Nunca editar el `.xcodeproj` a mano ni commitearlo.
- **8 targets**: `Pepinillo` (iOS 17+), `PepinilloMac` (macOS 15+),
  `PepinilloWidgetExtension`, `PepinilloWidgetMacExtension`, `PepinilloWatch`
  (watchOS 10+), `PepinilloWatchWidgetExtension`, `PepinilloControlCenter`
  (iOS 18+), `PepinilloTests`.
- **6 schemes**: `Pepinillo Dev/Staging/Production` (test target `PepinilloTests`)
  y `PepinilloMac Dev/Staging/Production` (sin test target; la lógica Mac se
  prueba en el simulador iOS).
- Configs por xcconfig en `Config/` (`Shared.xcconfig` contiene
  `DEVELOPMENT_TEAM`; `Secrets.xcconfig` local y gitignored con
  `REVENUECAT_API_KEY`). `xcodeVersion: 16.2`, `SWIFT_VERSION: 6.0`.

## Arquitectura

- **TCA** (`swift-composable-architecture` 1.26.x): `AppFeature` (4 tabs
  `.focus/.plan/.dashboard/.account`) compone `FocusFeature`,
  `TaskListFeature`, `AnalyticsFeature`, `SettingsFeature`, `PaywallFeature`
  + sheets (`CalendarFeature`, `AuthFeature`, `ProfileFeature`,
  `EmailVerificationFeature`).
- **Persistencia** (`Shared/Persistence/`): SwiftData `PepinilloMigrationPlan`
  `SchemaV1..V6` (V6 = `AchievementRecord`; 8 `@Model`). `AppGroupContainer`
  (grupo `group.com.pepinillo.app`) administra `PepinilloLocal.sqlite`,
  `PepinilloAppleCloud.sqlite` y legacy de recuperación.
  `PersistenceStoreRouter.reconcile(capabilities:)` conmuta `.local` /
  `.appleCloud` (Pepinillo+) / `.backend` (Everywhere/AI+).
  **Gap conocido**: `MacAppBootstrap` aún no cablea `syncModeClient.reconcile`.
- **Puente procesos**: `AppGroupDefaults` (`userCapabilities`,
  `activeSyncMode`, comandos `external*Requested`) + Darwin notification
  `com.pepinillo.app.externalCommand`. Las vistas observan `SessionReconcilePolicy`.
- **macOS** (`Mac/`): AppKit para presencia — `MacStatusBarController`
  (`NSStatusItem`+`NSPopover`, pulso 1 Hz; `MenuBarExtra` NO re-renderiza su
  label), `MacDockTileView` (redibujar con `-[NSDockTile display]`, no
  `setNeedsDisplay`), panel Notch (`MacNotchPanelController`), Quick Capture
  `⌃⌥T`, `MacSpotlightIndexer`, sampler opt-in de app foreground. Atajos:
  `⌃⌥Space`, `⌃⌥T`, `⌃⌥→`, `⌃⌥X`, `⌃⌥P`, `⌘4` estadísticas.
- **Red/contratos**: modelos alineados con `contracts/openapi.yaml`;
  `AIReportClient` on-device (Foundation Models iOS/macOS 26+ → plantilla).
- **Monetización**: `SubscriptionClient` + `SubscriptionCapabilityResolver`
  (`everywhere_plus` > `pepinillo_plus` > legacy `premium`/`pro`); gracia
  offline 7 días para everywhere_plus.

## Docs dentro de ios/

- `docs/app-store-listing.md` — **protegido por tests**
  (`PaywallCommercialClaimsTests.documentedDescriptionLimits` exige 9
  descripciones IAP ≤45 chars bajo `## In-App Purchases`): editar solo con
  StoreKit/SubscriptionClient en mano.
- `docs/launch-checklist.md` — checklist de envío (mantener versión al día).
- `docs/terms-of-use-{en,es}.md` — texto legal publicado en creapolis.dev;
  actualizar tiers solo con decisión comercial.
- `docs/macos-design-contract.md` — contrato de diseño/estructura de
  `PepinilloMac`.

## Verificación

```bash
cd ios && xcodegen generate
xcodebuild -scheme "Pepinillo Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -scheme "PepinilloMac Dev" -destination 'platform=macOS' build
```

- Tests: Swift Testing (923 `@Test`, 95 suites). Suites que tocan
  `AppGroupDefaults` usan `.serialized` + `AppGroupDefaultsSerialTrait`.
- CI ejecuta subconjuntos `-only-testing:` (fast/full); local puedes correr la
  suite completa. Cuarentena conocida:
  `spotlightTaskDeepLinkOpensTaskDetail` (issue #634).
