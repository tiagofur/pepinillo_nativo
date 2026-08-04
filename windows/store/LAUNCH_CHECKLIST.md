# Pepinillo Windows — Launch checklist

Ordered path from “code ready” to Microsoft Store flight.  
Related: [RELEASE_RUNBOOK.md](RELEASE_RUNBOOK.md) · [CERTIFICATION_CHECKLIST.md](CERTIFICATION_CHECKLIST.md) · [PARTNER_CENTER_IAP.md](PARTNER_CENTER_IAP.md) · [STORE_LISTING.md](STORE_LISTING.md)

**Branch:** `feat/windows-native-app`  
**In-repo status:** P0–P3 coded + packaging kit (2026-08).

---

## Phase A — Product decisions (before Store SKUs)

| ID | Decision | Resolution |
| -- | -------- | ---------- |
| **D1** Pricing | See § D1 below | **Resolved (recommended default)** |
| **D2** Product IDs | Keep Windows durable ID separate | `pepinillo_plus_windows` durable; Everywhere IDs shared intent via backend |
| **D3** Auth | Email/password first | Already coded; Microsoft OAuth later |
| **D4** Widgets | Post-GA | Deferred |
| **D5** Min OS | Win10 19041+ / Win11 | Manifest targets 10.0.19041.0 |

### D1 — Pricing (resolved recommendation)

| Product | Store price | Rationale |
| ------- | ----------- | --------- |
| **Pepinillo+** (Windows durable) | **$9.99** one-time | Platform-scoped unlock (desktop power features). Can differ from mobile Pepinillo+ ($19.99). |
| **Everywhere / AI+** monthly | **$4.99/mo** | **Must match global mobile** — entitlement is cross-platform; cheaper Windows price would be arbitraged. |
| **Everywhere / AI+** annual | **$34.99/yr** | Same as global mobile. |

LATAM market pricing can still use Partner Center market overrides; do not undercut Everywhere only on Windows in default market.

Code display strings: `ProductCatalog` in Core (updated to match this table).

---

## Phase B — Windows machine smoke (you / CI agent)

Run on **Windows 10 19041+ or Windows 11** (x64 or ARM64).

### B1 Build & pack

```powershell
cd <repo>\windows
dotnet test Pepinillo.Core.Tests\Pepinillo.Core.Tests.csproj -c Release
.\scripts\pack-msix.ps1 -Runtime win-x64
# optional:
.\scripts\create-dev-cert.ps1
# sign + sideload for manual QA
```

Or download **pepinillo-windows-msix** from GitHub Actions on this branch.

### B2 Functional smoke (P0–P2)

- [ ] App launches; nav Focus / Tasks / Analytics / Soundscapes / Account / Paywall / Settings
- [ ] Pomodoro cycle + Stopwatch complete → session in Analytics
- [ ] Flowtime / Time Block start & complete
- [ ] Journal note saves after session
- [ ] Tasks: create, priority/energy, complete, subtask
- [ ] Settings persist after restart
- [ ] Theme Light/Dark/System
- [ ] Tray: Start/Pause, Show, Exit; close-to-tray if enabled
- [ ] Mini timer Compact Overlay from Focus + hotkey
- [ ] Hotkeys Win+Shift+P/S/M (or note conflict)
- [ ] Toasts on phase complete (if permitted)
- [ ] Account login/register fails gracefully offline
- [ ] Paywall opens; free tier works offline
- [ ] Privacy / Terms links open browser
- [ ] **Schema:** if upgrading old DB, delete `%LocalAppData%\...\pepinillo.db` once

### B3 Certification dry-run

Complete every item in [CERTIFICATION_CHECKLIST.md](CERTIFICATION_CHECKLIST.md).

### B4 Assets for Store

- [ ] Real screenshots (replace `screenshots/*-placeholder.png`) — see `screenshots/README.md`
- [ ] Optional: soundscape MP3s under `Pepinillo.WinUI/Assets/Soundscapes/`

---

## Phase C — Partner Center (account)

1. [ ] Create/access Partner Center developer account  
2. [ ] Reserve app name (match package identity `Pepinillo.DeepWork` or update manifest + code)  
3. [ ] Create app → associate Store identity  
4. [ ] Set **Publisher CN** from Partner Center cert → replace `CN=PepinilloDev` in `Package.appxmanifest` for release builds  
5. [ ] Age rating questionnaire (productivity / Everyone)  
6. [ ] Paste listing from [STORE_LISTING.md](STORE_LISTING.md)  
7. [ ] Privacy URL: https://creapolis.dev/privacy-policy/  
8. [ ] Support contact (confirm `support@creapolis.dev` or real inbox)  
9. [ ] Create IAP products per [PARTNER_CENTER_IAP.md](PARTNER_CENTER_IAP.md) with **D1 prices above**  
10. [ ] Sandbox Microsoft accounts for IAP  
11. [ ] Upload MSIX (x64 + ARM64 if available)  
12. [ ] Attach screenshots  
13. [ ] Submit **Internal flight**  
14. [ ] Install from Internal → re-smoke IAP  
15. [ ] Promote **Private audience** (beta)  
16. [ ] Fix cert failures if any  
17. [ ] Promote **Public** when green  

---

## Phase D — Post-launch

- [ ] Monitor Partner Center health / crash analytics  
- [ ] Support inbox triage  
- [ ] Backend: map Store entitlements ↔ Everywhere/Pepinillo+ if not fully live  
- [ ] Plan post-GA: real soundscape audio, full i18n, onboarding, AI reports  

---

## Owners (fill in)

| Area | Owner |
| ---- | ----- |
| Product / D1–D2 | |
| Windows smoke | |
| Partner Center | |
| Backend entitlements | |
| Support inbox | |
