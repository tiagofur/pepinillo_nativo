# Secret handling

Pepinillo keeps privileged credentials outside Git. A value committed to Git must be
treated as compromised even after it is removed from the current branch.

## Key classification

- RevenueCat platform-specific SDK keys are public identifiers intended for client apps.
- RevenueCat secret API keys use the `sk_` prefix and are server-only credentials with
  privileged API access. Never place them in an app, documentation, issue, or log.
- Webhook authorization tokens, signing keys, database URLs, and provider API keys are
  also secrets, regardless of whether a scanner recognizes their format.

See RevenueCat's [API key documentation](https://www.revenuecat.com/docs/projects/authentication)
for the public/secret distinction.

## Approved storage

| Runtime | Storage |
| --- | --- |
| GitHub Actions | Repository or environment secrets |
| Backend/VPS | Restricted runtime environment or secret manager |
| iOS local development | Untracked `ios/Config/Secrets.xcconfig` |
| Android local development | Untracked `local.properties` or environment variables |

Commit only documented placeholders in templates. Do not copy a production value into a
sample file to test configuration.

## Automated prevention

`Secret Scan` checks the complete tracked tree and the committed bytes of every path changed
by each commit in a pull request or push, including merge resolutions and binary blobs. It
emits detector IDs and paths only; it never prints the matching value. Run it locally before committing:

```bash
python3 scripts/check_secrets.py --self-test
python3 scripts/check_secrets.py
```

The repository owner should additionally enable GitHub Secret Protection and push
protection. CI is defense in depth, not a substitute for provider-side detection.

## Exposure response

1. Revoke or rotate the credential at its provider immediately.
2. Update the authorized runtime secret and redeploy without logging the new value.
3. Verify the old credential is rejected and the application still works.
4. Remove the value from the current tree.
5. Decide whether a coordinated history rewrite is required. Rewriting shared history is
   destructive and requires all contributors to discard or carefully repair old clones.

The RevenueCat server credential found by issue #613 remains present in Git history from
commit `d6d98eee`. Treat it as compromised until an owner confirms revocation. Historical
cleanup must not be hidden behind a broad scanner allowlist.

Generated Xcode/App Store distribution logs can contain short-lived tokens and personal
data. Untracked generated `.log` files are ignored and tracked changes are scanned for
credential patterns, but legacy logs may still contain personal data. Remove them in a
dedicated cleanup before treating the repository as safe to share.
