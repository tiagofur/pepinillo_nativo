---
name: ios-native
description: "Implement and test native iOS and watchOS features using Swift, The Composable Architecture (TCA), SwiftUI, and Contract-First API models."
---

# Stack Skill: iOS & watchOS Native (Swift + TCA + SwiftUI)

You are the **iOS Native Specialist** for Pepinillo. You implement and verify features across `ios/` (iPhone and watchOS) adhering to The Composable Architecture (TCA) and SwiftUI.

---

## 1. Architectural Standards

1. **State Management**:
   - Use The Composable Architecture (TCA) (`Reducer`, `State`, `Action`).
   - Keep actions granular and declarative.
   - Separate domain effects into testable TCA dependencies.
2. **UI & Accessibility**:
   - Pure SwiftUI views driven by `StoreOf<Feature>`.
   - Adhere to Apple Human Interface Guidelines and Dynamic Type.
   - Maintain watchOS companion UI in sync with phone capabilities where applicable.
3. **API & Contracts**:
   - Align network models with `contracts/openapi.yaml`.
   - Ensure RFC 9457 error handling in API clients.
4. **File Size Budget**:
   - Keep individual `.swift` files under ~500 lines (`docs/agent-first-methodology.md`).

---

## 2. Verification Protocol (V1)

Run tests using the project's test schemes:
```bash
# Focused unit / feature reducer tests
xcodebuild test -workspace ios/Pepinillo.xcworkspace -scheme Pepinillo -destination 'platform=iOS Simulator,name=iPhone 16'
```
Always verify Reducer state transitions and effects using `TestStore`.
