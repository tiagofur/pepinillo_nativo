# Windows Store release runbook

End-to-end path from CI artifact to Microsoft Store (and rollback).

## Tracks

| Track | Audience | Purpose |
| ----- | -------- | ------- |
| **Internal flight** | Dev team / same tenant | Install from Partner Center package flight; catch crashers |
| **Private audience** | Closed beta list / group | Wider UX + IAP sandbox → production-like |
| **Public** | Everyone | GA listing |

Progress: Internal → Private → Public. Do not skip Internal for first-ever Store package.

---

## Version bump process

1. Update `windows/Directory.Build.props`:
   - `PepinilloVersion` → e.g. `1.0.1`
   - `PepinilloPackageVersion` → e.g. `1.0.1.0`
2. Update `windows/Pepinillo.WinUI/Package.appxmanifest` **Identity Version** to the same four-part value.
3. Update “What's new” in `STORE_LISTING.md` and Partner Center release notes.
4. Commit message example: `chore(windows): bump package version to 1.0.1.0`

MSIX requires each Store upload to have a **higher** version than the previous submission for that package family.

---

## Build & pack (local)

```powershell
cd windows\scripts
.\pack-msix.ps1 -Configuration Release -Runtime win-x64
.\pack-msix.ps1 -Configuration Release -Runtime win-arm64
```

Artifacts land under `windows/artifacts/msix/` (or nested AppPackages output).

### Local sideload only

```powershell
.\create-dev-cert.ps1
# Import CER to LocalMachine\TrustedPeople (elevated)
signtool sign /fd SHA256 /f ..\certs\PepinilloDev.pfx /p <password> path\to\Pepinillo.msix
```

Store submissions use Partner Center signing association — **not** the dev cert.

---

## CI → Partner Center upload

1. Push to a branch that triggers `.github/workflows/windows-build.yml`  
   (`main`/`master` paths under `windows/**`, or `feat/windows-native-app`).
2. Wait for **build-and-test** + **pack-msix** job (windows-latest).
3. Download the **msix-win-x64** (and arm64 if present) artifact from the Actions run.
4. Partner Center → Pepinillo app → **Packages** → upload MSIX.
5. Complete listing fields from `STORE_LISTING.md`.
6. Attach screenshots (replace placeholders in `screenshots/`).
7. Confirm IAP products exist (`PARTNER_CENTER_IAP.md`) — only after **D1** pricing.
8. Submit to **certification** on the chosen flight track.
9. After publish: smoke install from Store on clean PC.

### Manual steps that cannot be automated in-repo

| Step | Why manual |
| ---- | ---------- |
| Reserve app name | Partner Center account |
| Associate app with Store identity / publisher CN | Account + cert |
| Create IAP products & set prices | D1 decision + account |
| Submit age rating questionnaire | Account |
| Upload packages & screenshots | Account |
| Respond to certification failures | Human judgment |
| Promote flight → public | Product go/no-go |

---

## Flight promotion checklist

- [ ] Certification passed on Internal
- [ ] `CERTIFICATION_CHECKLIST.md` signed for this version
- [ ] IAP sandbox OK (if monetization in this release)
- [ ] Privacy/Terms URLs live
- [ ] Release notes accurate
- [ ] Promote to Private → gather feedback
- [ ] Promote to Public

---

## Rollback

| Situation | Action |
| --------- | ------ |
| Bad package in flight only | Halt flight; upload fixed higher version |
| Public discovery of critical bug | Submit hotfix package with higher version ASAP; use Partner Center to stop distribution if available for your account type |
| Bad IAP config | Disable/fix product in Partner Center; ship app update if product IDs wrong (IDs are hard to change — prefer not shipping wrong IDs) |
| Need to pull feature | Ship app update that feature-flags off; Store does not support classic “unpublish binary keep users on old” as flexibly as mobile — plan versions carefully |

Always ship a **higher** package version for the fix; you cannot re-upload the same version.

---

## Related docs

- Listing copy: `STORE_LISTING.md`
- IAP setup: `PARTNER_CENTER_IAP.md`
- Cert QA: `CERTIFICATION_CHECKLIST.md`
- Screenshots: `screenshots/README.md`
- Pack script: `../scripts/pack-msix.ps1`
- Execution plan: `PRD/12_WINDOWS_EXECUTION_PLAN.md` §7
