# Convenciones de código

Aplica a todas las superficies. Complementa la metodología estructural en
[`agent-first-methodology.md`](agent-first-methodology.md).

---

## 1. Presupuesto cognitivo

- **~500 líneas** por archivo de producción (blando). >500 líneas exige
  verificación de cohesión antes de añadir lógica; si mezcla transporte,
  política de dominio y persistencia, se divide por responsabilidades.
- **Anti-fragmentación**: no crear veinte archivos de 15 líneas que obliguen a
  abrir diez archivos para trazar una llamada. Agrupa tipos cohesivos.
- **≤400 líneas cambiadas por PR** (`size:l` exige `chained-pr`).
- Al tocar un monolito existente: extrae la costura tocada en un commit
  mecánico separado; no "reescribas el mundo".

## 2. Nombres y organización

- Organización vertical-slice por capacidad de dominio; prohibidos los
  catch-all (`utils.go`, `helpers.swift`, `Common.kt`, `misc.py`). Nombra por
  responsabilidad concreta (`rfc9457_error.ts`, `money_format.go`).
- Símbolos exportados greppables y sin sobrecarga genérica (`CreateInvoiceCommand`
  > `Manager`). Preferencia explícita en los errores que puede lanzar una
  función/firma.

## 3. Por superficie

### Go (`backend/`)
- Capas con dependencia hacia adentro (`adapters → services → domain/ports`);
  `internal/domain` **nunca** importa Fiber, GORM drivers ni Redis.
- Todo método I/O recibe `ctx context.Context` primero y respeta cancelación.
- Errores: envolver con `fmt.Errorf("contexto: %w", err)`; centinelas de
  dominio con `errors.Is/As`; handlers mapean a la envolvente documentada en
  `contracts/openapi.yaml` (`ErrorEnvelope` / `ERR_TIER_INSUFFICIENT`).
- SQL siempre parametrizado (GORM placeholders); prohibida la concatenación.
- Logs `log/slog` JSON con `request_id` cuando aplique; 5xx a Sentry.
- Tests: unitarios con fakes en `*_test.go` del paquete; integración contra
  Postgres/Redis reales en CI (`.github/workflows/test.yml`).

### Swift (`ios/`)
- **TCA**: reducers puros y testeables con `TestStore`; efectos como
  `DependencyKey` inyectables; acciones granulares.
- Swift 6 strict concurrency: `@ModelActor` para SwiftData off-main; tipos
  `Sendable` en los DTOs que cruzan actors; sin `@MainActor` innecesario.
- Vistas SwiftUI puras guiadas por `StoreOf<Feature>`; sin lógica de negocio en
  vistas. Dynamic Type y símbolos SF.
- Strings siempre vía `Localizable.xcstrings` (EN/ES/PT) — nunca hardcodeadas.
- Tests: Swift Testing (`import Testing`), suites `.serialized` cuando tocan
  `AppGroupDefaults` (`AppGroupDefaultsSerialTrait`).

### Kotlin (`android/`)
- UDF: `StateFlow<UiState>` hacia abajo, lambdas/eventos tipados hacia arriba;
  ViewModels con `viewModelScope`, sin lógica en Composables.
- Hilt para DI (`@HiltViewModel`, módulos en `di/`); Room con migraciones
  numeradas y schemas exportados (`android/app/schemas/`).
- Coroutines estructuradas; Flow para streams; sin `GlobalScope`.
- Strings en `res/values{,-es,-pt}`; Material 3 Expressive y tokens de tema.

## 4. Errores y contratos

- Ante cambio HTTP: `contracts/openapi.yaml` primero (`C2`); luego handler y
  clientes. Los payloads/errores deben coincidir con el contrato (campo por
  campo, `json:"..."`/`CodingKeys`/`@SerializedName`).
- Códigos de error estables y greppables (`email_not_verified`,
  `ERR_TIER_INSUFFICIENT`, `purchase_token_claimed`).

## 5. Commits y revisión

- Conventional Commits en **inglés** (`feat:`, `fix:`, `refactor:`, `test:`,
  `docs:`, `chore:`), atómicos (código + tests + docs de la unidad), **sin**
  trailers de co-autoría IA.
- Cierre de unidad con línea `Risk:` (`CHECKPOINTS.md` C3).
- Cualquier PR que toque `contracts/**`, `scripts/**`, migraciones o >400
  líneas dispara `judgment-day` automático.
