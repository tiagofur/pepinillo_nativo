# Pepinillo — App Store Launch Checklist

This guide ensures you have everything ready for a successful submission to Apple.

## 1. Technical Readiness (Xcode)

- [x] **Bundle ID**: `com.pepinillo.app` is set in `project.yml`.
- [x] **Version**: Marketing Version is `1.0.0` (Build `2`).
- [x] **Signing**: `DEVELOPMENT_TEAM` is set to `T5SKULSP2M` in `Config/Shared.xcconfig`.
- [x] **Push Notifications**: Dynamic environment switching (Dev/Staging/Production) is configured.
- [x] **Privacy Info**: `PrivacyInfo.xcprivacy` is included in the project.

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

Refer to [app-store-listing.md](file:///Users/tiagofur/dev/pepinillo_nativo/ios/docs/app-store-listing.md) for the exact text to copy-paste.

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

When Apple asks about data collection, use these answers:

- **Health & Fitness**: 
  - Data Type: `Health`
  - Linked to Identity: `No`
  - Used for Tracking: `No`
  - Purpose: `App Functionality`
- **Other Data**: Select **"Data Not Collected"**.

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
