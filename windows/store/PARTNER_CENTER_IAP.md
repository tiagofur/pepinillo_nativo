# Partner Center — In-app products (IAP)

Manual steps. **Requires Partner Center credentials** (not available in-repo).

## Product IDs (must match app code)

| Store product ID | Type | Display purpose | Code constant |
| ---------------- | ---- | --------------- | ------------- |
| `pepinillo_plus_windows` | **Durable** (lifetime-style unlock) | Pepinillo+ on Windows | `ProductCatalog.PepinilloPlusStoreId` |
| `everywhere_plus_monthly` | **Subscription** | Everywhere monthly | `ProductCatalog.EverywhereMonthlyStoreId` |
| `everywhere_plus_annual` | **Subscription** | Everywhere annual | `ProductCatalog.EverywhereAnnualStoreId` |

Source of truth in code:

- `windows/Pepinillo.Core/Models/ProductCatalog.cs` — IDs + placeholder display prices
- `windows/Pepinillo.Core/Services/StoreCommerceService.cs` — commerce orchestration
- `windows/Pepinillo.WinUI/Services/WindowsStoreCommerceService.cs` — `Windows.Services.Store` / StoreContext

**Decision D2 (open):** confirm whether Windows durable ID stays `pepinillo_plus_windows` vs a shared `pepinillo_plus` resolved only via backend entitlement.

---

## Prices — **D1 RESOLVED** (see LAUNCH_CHECKLIST.md)

| Product | Store price (default market) | Global mobile | Notes |
| ------- | ---------------------------- | ------------- | ----- |
| Pepinillo+ durable (Windows) | **$9.99** | $19.99 | Platform-scoped Windows unlock; intentional lower entry |
| Everywhere monthly | **$4.99/mo** | $4.99/mo | **Must match mobile** — cross-device entitlement |
| Everywhere annual | **$34.99/yr** | $34.99/yr | **Must match mobile** — prevents Windows arbitrage |

> **D1 rationale:** Selling Everywhere cheaper only on Windows would let users unlock iOS/Android cheaper via PC. Pepinillo+ durable can differ because it unlocks Windows-local features.  
> Partner Center market overrides (LATAM, etc.) still allowed. Code UI: `ProductCatalog`.

---

## Steps to create products in Partner Center

1. Open [Partner Center](https://partner.microsoft.com/dashboard) → your **Pepinillo** app (reserve name first if needed).
2. Go to **Monetization** → **Add-ons** (or **In-app products**).
3. **Create durable**
   - Product ID: `pepinillo_plus_windows` (immutable after create — double-check D2)
   - Type: Durable
   - Lifetime: Forever (or as product defines)
   - Price: set only after **D1**
   - Description: “Unlock Pepinillo+ features on Windows”
4. **Create subscription — monthly**
   - Product ID: `everywhere_plus_monthly`
   - Billing period: 1 month
   - Free trial: optional (product decision)
   - Price: after **D1**
5. **Create subscription — annual**
   - Product ID: `everywhere_plus_annual`
   - Billing period: 12 months
   - Price: after **D1**
6. Submit add-ons for certification together with or after the app package.
7. Enable **sandbox** test accounts; purchase each SKU on a non-dev Microsoft account.
8. Verify app:
   - Paywall shows Store prices when StoreContext works
   - Entitlement unlocks Pepinillo+ features
   - Backend sync of entitlement when account linked (if implemented)

---

## Sandbox testing checklist

- [ ] Sandbox Microsoft account added in Partner Center
- [ ] Durable purchase → durable entitlement retained after restart
- [ ] Monthly sub active → Everywhere features gated correctly
- [ ] Cancel / expire path returns free tier
- [ ] Offline free tier still works without Store
- [ ] Restore / query products does not crash when Store unavailable

---

## Backend alignment

- Mobile uses RevenueCat + App Store / Play; Windows uses **Microsoft Store** receipts.
- Backend should accept Store verification (or map Store product IDs → shared entitlements).
- Until backend Windows verify is live, app may keep free-default + local Store entitlement cache (see P2 commerce path).

---

## Do not

- Commit Partner Center secrets, client secrets, or PFX store certs
- Change product IDs in Partner Center after customers purchase
- Ship paywall copy that implies free unlimited Pro features
