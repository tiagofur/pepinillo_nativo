# Backend Super Review

Full read-only audit of the Go REST API: payments/billing, security/auth,
data integrity, resources/concurrency, API robustness. Same standard as the
Android super review (P0/P1/P2 with file:line evidence). Fixes are a separate
scope decision after the findings report.

## Specs

- S1: "ahora un ultimo review en el backend, la parte de pagos, etc... seguridad, fugas de memoria, perdida de datos... todo lo que pueda dar prblema o bugs"

## Tasks

| ID | Spec | Task | Route | Commit |
| ---- | ---- | ---- | ---- | ------ |
| T1 | S1 | Create feature doc + Engram mirror + todo projection | inline | — |
| T2 | S1 | Parallel read-only audits: billing, security, data, resources, API | 5x gentle-ai-explore | — |
| T3 | S1 | Synthesize findings report (P0/P1/P2 with file:line evidence) | inline | — |
| T4 | S1 | Propose fix plan, agree scope with user | inline | — |

## Log

- L1: "ahora un ultimo review en el backend, la parte de pagos, etc... seguridad, fugas de memoria, perdida de datos... todo lo que pueda dar prblema o bugs"
- L2: Baseline: fix/android-super-review after PR #650 opened (issue #649 approved). Backend size: 137 Go files, ~21k LOC.

## Findings — synthesis (5 audits, 2 P0 / ~20 P1 / ~25 P2)

Spot-checked and confirmed by parent: billing P0 (billing_service.go:741 + mapProductToTier 816-833) and security P0 (oauth_service.go:260-297).

### P0
- B-P0-1 Legacy App Store path trusts client ProductID, free lifetime grant.
- S-P0-1 Apple login trusts client-supplied email, full account takeover.

### P1 clusters
Billing: token replay, webhook 200-swallow, non-monotonic tiers, pending purchases granted, /analytics fail-open, user-row Save races. Security: PUT /users/me email change, Google unverified auto-link, no refresh reuse detection. Data: FullSync TEXT cursor skips, LWW clock bias, session no-LWW resurrection, recompute race, tz bucketing mix. Resources: health-check client leaks, no graceful shutdown, no WS per-user cap, sync long-tx pool pressure. API: no Fiber recover, push fan-out abort, non-idempotent creates, AI no-refund, cursor 500, unbounded AI inputs.

Full per-finding detail with file:line evidence lives in the 5 subagent reports this turn; key P2s + verified-correct lists recorded in Engram obs 2280 context.

## Implementation — CLOSED (all 4 units, inline)

U1 auth+billing (1 commit): Apple/Google takeover guards, PUT-email rejection, refresh reuse revocation, AppStore ProductID fallback removed, purchase-token claims (migration 000015) + webhook dedupe table, pending-payment rejection, monotonic entitlements, EffectiveTier middleware fail-closed, targeted subscription writes.
U2 data (1 commit): FullSync int cursor + numeric guard, domain.ResolveSyncTimestamp, session conditional upsert (LWW WHERE + monotonic ended_at CASE), client timestamps preserved, recompute advisory lock, UTC day bucketing.
U3 ops (1 commit): health-check client reuse, graceful shutdown, WS per-user cap 8, sync chunking (200/tx), Fiber recover outermost, push continue+prune.
U4 API (1 commit): task create SyncID-idempotent, AI refund-on-failure, ErrInvalidCursor to 400, AI caps + delimiters, tracking allow-list + seconds cap, Gemini header key, push Sentry capture, BodyLimit 6MB.
Suite: go test ./... green + vet clean at each commit.
Deferred with reasons: session ID-less create dedupe (needs client contract), bulk item caps (breaks full-history InitialUpload), unpaginated lists + signed URLs (larger API changes), tombstone purge, behavior-log retention.
