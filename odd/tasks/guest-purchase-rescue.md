# Guest Purchase Rescue (B-suave)

Guest-mode buyers strand their entitlement in an anonymous RevenueCat ID until they log in (confirmed live: MXN 169 lifetime, anonymous, 9 days unclaimed). Fix without purchase friction:

- U-A Android: post-purchase nudge (guest only) offering one-tap sign-in; verify/restore-on-login when RC-active but server-free; restore entry points verified.
- U-B iOS: same nudge (appeared-isGuest via keychain), restore visibility.
- U-C Backend: handle SUBSCRIBER_ALIAS — resolve alias to user, apply current entitlement via RC subscriber API (VerifyViaRevenueCat). Closes the iOS anonymous-transfer loop server-side with zero iOS client changes beyond the nudge.
- Copy in en/es/pt (Android strings.xml x3, iOS Localizable).

Deliberately NOT doing: hard-gating paywall behind accounts (conversion risk without data); iOS client-side verify path (new endpoint + StoreKit plumbing — separate epic if webhooks prove insufficient).

## Specs

- S1: "¿Cómo resolvemos las compras de invitados?" → "B suave primero (recomendado)"

## Tasks

| ID | Spec | Task | Route | Commit |
| ---- | ---- | ---- | ---- | ------ |
| T1 | S1 | Feature doc + Engram mirror + todos | inline | — |
| T2 | S1 | Backend SUBSCRIBER_ALIAS resolution + tests | inline | — |
| T3 | S1 | Android nudge + verify-on-login + restore + copy | inline/worker | — |
| T4 | S1 | iOS nudge + restore + copy | inline/worker | — |
| T5 | S1 | Full suites + report + PR | inline | — |

## Log

- L1: User chose B (soft first) for guest purchases after live anonymous lifetime sale.
- L2: Baseline: main includes #650 (Android), #652 (backend), #656 (timer), #654 (versions), #660 (API36). Android guest mode exists (continueAsGuest); verifyWithServerIfNeeded early-returns for guests; no post-login re-verify exists. iOS has no client-side server verify at all (RC-local + webhooks only).

## Close-out

- U-C backend: merged pattern (deduped entry, monotonic apply, no downgrade on alias). 3 new tests green; full backend suite green.
- U-A Android: nudge dialog (guest-only) + sign-in CTA → login; post-login reconcile (silent restore+verify, failure-isolated) wired into all three post-auth terminals; restore kept on paywall. 6 new tests green.
- U-B iOS: nudge alert instead of welcome for guests; signInRequested delegate → paywall dismiss + auth sheet; EN/ES/PT strings added surgically (no reformat of user's active file). iOS tests mirror existing passing patterns; cannot compile locally (no Xcode) — CI is the gate.
- Deferred: iOS direct server-verify path (webhook+alias covers it); Android restore-in-Settings extra entry (paywall entry suffices).

## Close-out

- CI green on all gates (secret-scan + 3 test jobs, incl. iOS in 20m59s).
- iOS note: the appeared tests initially failed on effect ordering (keychain resolves after the entitlement check despite starting earlier — nondeterministic across runs). Fixed by collapsing to a single sequential effect (products -> guest -> entitlement) + PaywallFeatureTests added to the PR fast-gate (it never ran them).
