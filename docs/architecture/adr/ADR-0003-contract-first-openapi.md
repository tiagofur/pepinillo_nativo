# ADR-0003: Contract-First OpenAPI 3.1 and RFC 9457 Error Standard

- **Status**: Accepted
- **Date**: 2026-10-29
- **Deciders**: Software Factory Architecture Core

---

## 1. Context

In an Agentic Software Factory where parallel bounded writers (`implementer` subagents) work simultaneously on the Go backend (`backend/`) and client surfaces (`apps/web`, `apps/desktop-tauri`, `apps/ios-native`, `apps/android-native`), ad-hoc JSON payloads are the #1 source of integration bugs and wasted rework tokens.

If the backend agent invents response fields in Go structs while the frontend agent guesses TypeScript interfaces, their work units fail at integration time.

---

## 2. Decision

1. **Single Source of Truth (`contracts/openapi.yaml`)**:
   - Every HTTP endpoint, request body, query parameter, header, and response schema MUST be declared in `contracts/openapi.yaml` (**OpenAPI 3.1.0**) **before** or **in the same atomic work unit as** backend/client implementation (`Checkpoint C2`).
2. **Standardized Error Format (RFC 9457 Problem Details)**:
   - Every non-2xx HTTP response across all services MUST return `Content-Type: application/problem+json` conforming to the reusable `#/components/schemas/ProblemDetails` schema (`type`, `title`, `status`, `detail`, `instance`, plus optional `errors[]` field validation items).
3. **Automated Contract Quality Gates (`contracts/Makefile`)**:
   - **Linting (`make contracts-lint`)**: Enforced via **Stoplight Spectral** (`contracts/.spectral.yaml`) plus structural schema validation. Every operation requires a unique `operationId`, `summary`, `tags`, and explicit error responses.
   - **Breaking-Change Detection (`make contracts-diff`)**: Enforced via **`oasdiff`**. Removing a field, narrowing a type, or adding a required request property without a version bump or an explicit human-approved `contract-break` PR label fails `Checkpoint C2` and CI.
4. **Deterministic Code Generation**:
   - Go server stubs/models (`oapi-codegen`), TypeScript types (`openapi-typescript`), Swift models (`swift-openapi-generator`), and Kotlin models (`openapi-generator`) derive directly from `contracts/openapi.yaml`. Hand-editing generated contract files is forbidden.

---

## 3. Consequences

### Positive
- Enables true **Parallel Writer Delegation**: Once `contracts/openapi.yaml` is updated and passes `make contracts-lint`, one `implementer` can build the Go handler while a second `implementer` builds the React/Tauri/Native UI against the exact same schema with zero coordination drift.
- Native iOS (SwiftUI) and Android (Jetpack Compose) clients (`ADR-0002` Tier 3) consume generated models and API clients directly, drastically reducing token expenditure on boilerplate networking code.
- Clients only need a single unified error interceptor for RFC 9457 `ProblemDetails`.

### Negative / Tradeoffs
- Every API change requires editing `contracts/openapi.yaml` first and running `make contracts-lint` before writing handler code.
