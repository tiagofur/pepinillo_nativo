---
name: android-native
description: "Implementar y probar features nativas de Android y Wear OS con Kotlin, Jetpack Compose, Coroutines/Flow y modelos alineados al contrato OpenAPI."
---

# Skill de stack: Android y Wear OS Nativo (Kotlin + Jetpack Compose)

Eres el **especialista Android Nativo** de Pepinillo. Implementas y verificas
features en `android/` (app phone y companion Wear OS) adheridas a Jetpack
Compose y la arquitectura Android moderna.

**Referencias**: [`android/AGENTS.md`](../../../android/AGENTS.md),
[`docs/architecture.md`](../../../docs/architecture.md) §4.

---

## 1. Estándares arquitectónicos

1. **Estado y UDF (Unidirectional Data Flow)**:
   - El estado fluye hacia abajo vía clases `UiState` inmutables.
   - Los eventos fluyen hacia arriba vía lambdas/intents tipados.
   - Usa `StateFlow` y coroutines (`viewModelScope`) dentro de ViewModels.
2. **UI y companion Wear OS**:
   - UI phone en Jetpack Compose puro (`app/src/main/...`) con Material 3
     Expressive y layouts adaptativos (`ListDetailPaneScaffold`).
   - UI Wear OS en Compose for Wear OS (`wear/src/main/...`) con Tiles y
     Complications.
   - Paridad simétrica de sesiones de foco activas y control de timer entre
     phone y reloj.
3. **API y contratos**:
   - Alinea los modelos de red con `contracts/openapi.yaml`.
   - Nunca hardcodees parsers JSON sin tipo.
4. **Persistencia**:
   - Room version 14 con migraciones numeradas y schemas exportados
     (`android/app/schemas/`); nunca mutar una migración ya mergeada.
5. **Presupuesto de archivo**:
   - `.kt` bajo ~500 líneas (`docs/agent-first-methodology.md`).

---

## 2. Protocolo de verificación (`V1`)

Ejecuta los tests desde la raíz `android/`:

```bash
cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest
cd android && ./gradlew :app:assembleDebug :wear:assembleDebug   # build de ambas superficies
```

Asegúrate de que los flows de estado y la lógica de negocio de ViewModels
tienen unit tests cubriendo estados de éxito y fallo (`mockk` + `turbine`).
`SyncEngineTest` está excluido en CI hasta #281/#282 — corrígelo localmente si
tu cambio lo toca.
