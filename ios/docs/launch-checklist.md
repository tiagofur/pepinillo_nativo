# Pepinillo — App Store Launch Checklist

This guide ensures you have everything ready for a successful submission to Apple.

## 1. Technical Readiness (Xcode)

- [x] **Bundle ID**: `com.pepinillo.app` is set in `project.yml`.
- [x] **Version**: Marketing Version is `1.0.0` (Build `3`).
- [x] **Signing**: `DEVELOPMENT_TEAM` is set to `T5SKULSP2M` in `Config/Shared.xcconfig`.
- [x] **Push Notifications**: Dynamic environment switching (Dev/Staging/Production) is configured.
- [x] **Privacy Info**: `PrivacyInfo.xcprivacy` is included in the project. This file is build metadata, not proof that the live App Store Connect answers are current.

### ⚠️ Manual Action Required in Developer Portal
1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list/bundleId).
2. Register the Bundle ID: `com.pepinillo.app`.
3. Enable Capabilities:
   - **HealthKit**
   - **Push Notifications**
   - **Siri**
   - **App Groups** (Create `group.com.pepinillo.app` and link it).
  - **iCloud / CloudKit**: Enable for Pepinillo+ (Apple-to-Apple sync). The app uses a dual-store router: local-only at launch, then activates a separate CloudKit container for Pro users. Verify `iCloud.com.pepinillo.app` container exists and App Group `group.com.pepinillo.app` is linked on all targets (app, widget, intents, watch).

---

## 2. App Store Connect Metadata

Refer to [app-store-listing.md](app-store-listing.md) for the exact text to copy-paste.

### Key URLs
- **Privacy Policy**: `https://creapolis.dev/privacy-policy/`
- **Support URL**: `https://creapolis.dev/terms-of-use/`

### Screenshots Required
You will need to upload screenshots for these sizes:
- **iPhone 6.7" Display** (iPhone 15/14 Pro Max)
- **iPhone 6.5" Display** (iPhone 11 Pro Max / Xs Max)
- **Apple Watch** (Series 10/9/Ultra)

---

## 3. App Privacy Declaration

App Store Connect answers are maintained manually and apply at the app level, including integrated SDKs and all iOS/watchOS variants. The repository cannot verify the current live answers.

### Before submission

- [ ] Audit the release candidate's actual first-party and third-party data flows; do not copy answers from an older release.
- [ ] Archive the Production scheme and generate/review Xcode's privacy report so the app, Sentry, and RevenueCat manifests are represented.
- [ ] In App Store Connect → App Privacy, answer **Yes, we collect data from this app**.
- [ ] Configure each collected data type exactly as listed below.
- [ ] Confirm every type is set to **Used for Tracking: No**.
- [ ] Preview the product-page privacy label, then click **Publish**. Saving repository files does not publish App Store Connect changes.

### Required App Store Connect data types

| Data type | Linked | Tracking | Purpose | Condition/source |
|---|---:|---:|---|---|
| Name | Yes | No | App Functionality | Optional account/profile flow |
| Email Address | Yes | No | App Functionality | Optional account auth/recovery/profile flow |
| User ID | Yes | No | App Functionality | Pepinillo backend account and identified RevenueCat customer |
| Photos or Videos | Yes | No | App Functionality | Optional authenticated profile photo upload |
| Purchase History | Yes | No | App Functionality | RevenueCat entitlement and product state |
| Product Interaction | Yes | No | App Functionality | Synced focus-session and task-completion activity |
| Other User Content | Yes | No | App Functionality | Synced task titles, descriptions, subtasks, and imported reminder content |
| Other Data Types | Yes | No | App Functionality | Source IP retained for approximately one minute by the in-memory authentication rate limiter |
| Crash Data | No | No | App Functionality | Only when the submitted non-debug build has a non-empty Sentry DSN |
| Performance Data | No | No | App Functionality | Only when the submitted non-debug build has a non-empty Sentry DSN |
| Other Diagnostic Data | No | No | App Functionality | Only when the submitted non-debug build has a non-empty Sentry DSN |

### Confirmed exclusions under current behavior

- [ ] **Health** is not selected: Pepinillo only writes Mindful Minutes through HealthKit, requests no HealthKit read types, and does not send HealthKit data to Pepinillo or Sentry servers.
- [ ] **Payment Info** is not selected: Apple handles payment credentials; Purchase History covers the product/entitlement state received by RevenueCat.
- [ ] **Contacts** is not selected: Reminders are read on device; any imported text later sent through sync is covered by Other User Content.
- [ ] **Calendar data** does not add a collected-data type: EventKit creates/removes focus events on device and the app does not send calendar records to Pepinillo or Sentry.
- [ ] **Device ID** is not selected for the client-generated sync ID while it remains request-scoped and unretained. This does not cover the source IP: verify **Other Data Types** is selected for the short-lived authentication rate-limit key.
- [ ] **Analytics** is not selected as a purpose for focus history: current productivity analytics are user-facing app functionality.
- [ ] **Diagnostics** match the submitted archive: the repository leaves Production `SENTRY_DSN` empty. Remove the three Sentry diagnostic types from the live answers if no DSN is injected; keep them if Sentry is enabled.
- [ ] **CloudKit behavior** is explained in the privacy policy: private iCloud sync includes tasks, sessions, settings, analytics, and cached account/profile fields. Those profile fields are already covered by Name, Email Address, User ID, and Photos or Videos; the app does not send the private CloudKit database to Pepinillo's backend.

See [app-store-listing.md](app-store-listing.md#app-privacy-data-collection-declaration) for the audited inventory, behavior conditions, and official Apple references. This checklist covers the Apple submission only; Google Play remains outside this slice of [#618](https://github.com/tiagofur/pepinillo_nativo/issues/618).

---

## 4. Final Submission Steps

1. In Xcode, select the **"Pepinillo Production"** scheme.
2. Select **"Any iOS Device (arm64)"** as the run destination.
3. Go to **Product > Archive**.
4. Once the archive is complete, click **"Distribute App"**.
5. Select **"App Store Connect"** -> **"Upload"**.
6. Follow the prompts (Keep "Manage version and build number" checked).
7. Once uploaded, go to [App Store Connect](https://appstoreconnect.apple.com/), select your build, and submit for review.

---

## 5. Review Notes for Apple

> Pepinillo is a focus timer and productivity app. No login is required.
> 
> To test Pro features: The app uses StoreKit 2. In the sandbox/TestFlight environment, you can subscribe to any plan to test Pro features (Flowtime mode, Time Block mode, premium soundscapes, and advanced analytics).
> 
> Integration: Writes Mindful Minutes to Apple Health and imports tasks from Reminders. Pepinillo+ users get iCloud sync across Apple devices; Everywhere/AI+ uses Pepinillo cloud (VPS) sync. Settings → iCloud Sync shows activation status and retry for Pro users.
