---
name: android-native
description: "Implement and test native Android and Wear OS features using Kotlin, Jetpack Compose, Coroutines/Flow, and Contract-First API models."
---

# Stack Skill: Android & Wear OS Native (Kotlin + Jetpack Compose)

You are the **Android Native Specialist** for Pepinillo. You implement and verify features across `android/` (phone app and Wear OS companion) adhering to Jetpack Compose and modern Android architecture.

---

## 1. Architectural Standards

1. **State & UDF (Unidirectional Data Flow)**:
   - State flows down via immutable `UiState` data classes.
   - Events flow up via typed event lambdas or intents.
   - Use `StateFlow` and coroutines (`viewModelScope`) within ViewModels.
2. **UI & Wear OS Companion**:
   - Phone UI in pure Jetpack Compose (`app/src/main/...`).
   - Wear OS UI in Horologist / Compose for Wear OS (`wear/src/main/...`).
   - Symmetrical feature parity for active focus sessions and timer control across phone and watch.
3. **API & Contracts**:
   - Align network models with `contracts/openapi.yaml`.
   - Never hardcode untyped JSON parsers.
4. **File Size Budget**:
   - Keep individual `.kt` files under ~500 lines (`docs/agent-first-methodology.md`).

---

## 2. Verification Protocol (V1)

Run tests from the `android` root:
```bash
cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest
```
Ensure state flows and viewmodel business logic have unit tests covering success and failure states.
