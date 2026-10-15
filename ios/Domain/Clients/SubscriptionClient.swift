// SubscriptionClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency wrapping RevenueCat SDK.
// Manages subscription products, purchases, and entitlement verification.
//
// Products:
//   - Pepinillo+ (one-time): local premium + iCloud sync + Apple Intelligence
//   - Everywhere/AI+ Monthly/Annual (subscription): everything + backend sync + account recovery
//
// Legacy products (grandfathered):
//   - Pro Monthly/Annual → mapped to Everywhere/AI+
//   - Pro Lifetime → grandfathered to Pepinillo+

import Foundation
import OSLog
import ComposableArchitecture

#if canImport(RevenueCat)
import RevenueCat
#endif

private let subscriptionLogger = Logger(subsystem: "com.pepinillo.app", category: "subscription")

// MARK: - Subscription Product IDs

enum PepinilloProduct: String, CaseIterable, Sendable {
    // Active products (configured in App Store Connect + RevenueCat)
    case monthly  = "com.pepinillo.app.pro.monthly"
    case annual   = "com.pepinillo.app.pro.annual"
    case lifetime = "com.pepinillo.app.pro.lifetime"

    var isSubscription: Bool { self != .lifetime }

    /// Products shown in paywall.
    static var currentProducts: [PepinilloProduct] {
        [.lifetime, .monthly, .annual]
    }
}

// MARK: - Subscription State

struct SubscriptionState: Equatable, Sendable {
    var capabilities: UserCapabilities = .free
    var activeProductID: String? = nil
    var expirationDate: Date? = nil

    // MARK: Backward-compatible computed properties

    /// True if user has any paid tier (Pepinillo+ or Everywhere/AI+).
    var isPro: Bool { capabilities.hasAnyPremium }

    /// True if user has the Everywhere subscription.
    var isEverywhere: Bool { capabilities.isEverywhere }

    /// Human-readable tier name.
    var tierName: String { capabilities.tierDisplayName }

    /// Exact canonical tier identity persisted for extension-side authorization.
    var canonicalTierIdentifier: String? {
        capabilities == .free ? "free" : capabilities == .pepinilloPlus ? "pepinillo_plus"
            : capabilities == .everywherePlus ? "everywhere_plus" : nil
    }

    // MARK: Static presets

    static let free = SubscriptionState(capabilities: .free)
    static let pepinilloPlus = SubscriptionState(capabilities: .pepinilloPlus)
    static let everywherePlus = SubscriptionState(capabilities: .everywherePlus)

    /// Legacy convenience — use .pepinilloPlus or .everywherePlus instead.
    static let pro = SubscriptionState(capabilities: .pepinilloPlus)
}

// MARK: - Product Info (value type for UI)

struct ProductInfo: Equatable, Sendable, Identifiable {
    var id: String
    var displayName: String
    var description: String
    var displayPrice: String
    var billingPeriod: String    // "month" | "year" | "once"
    var isFeatured: Bool = false
}

// MARK: - Purchase Result

enum PurchaseResult: Equatable, Sendable {
    case success(productID: String)
    case pending
    case cancelled
    case failed(message: String)
}

// MARK: - Subscription Client

@DependencyClient
struct SubscriptionClient: Sendable {
    /// Configure RevenueCat with API key and user ID.
    var configure: @Sendable (_ apiKey: String, _ userID: String?) async -> Void = { _, _ in }

    /// Fetch available RevenueCat offerings/packages.
    var fetchProducts: @Sendable () async -> [ProductInfo] = { [] }

    /// Purchase a RevenueCat package by product ID.
    var purchase: @Sendable (_ productID: String) async -> PurchaseResult = { _ in .cancelled }

    /// Restore previous purchases via RevenueCat.
    var restorePurchases: @Sendable () async throws -> SubscriptionState = { .free }

    /// Check current entitlement (call on launch + after purchase).
    var checkEntitlement: @Sendable () async throws -> SubscriptionState = { .free }

    /// Listen to customer info changes via RevenueCat.
    var listenForTransactionUpdates: @Sendable () -> AsyncStream<SubscriptionState> = { .finished }

    /// Identify user with backend user ID.
    var logIn: @Sendable (_ userID: String) async throws -> SubscriptionState = { _ in .free }

    /// Reset to anonymous (logged out).
    var logOut: @Sendable () async -> Void = { }

    /// Whether RevenueCat finished configuration (false when API key missing).
    var isPurchasesAvailable: @Sendable () async -> Bool = { false }
}

// MARK: - Dependency Keys

extension SubscriptionClient: DependencyKey {
    static let liveValue = SubscriptionClient.live
    static let testValue = SubscriptionClient(
        configure: { _, _ in },
        fetchProducts: { PepinilloProduct.currentProducts.map(\.mockProductInfo) },
        purchase: { _ in .success(productID: PepinilloProduct.annual.rawValue) },
        restorePurchases: { .pepinilloPlus },
        checkEntitlement: { .free },
        listenForTransactionUpdates: { .finished },
        logIn: { _ in .free },
        logOut: { },
        isPurchasesAvailable: { true }
    )
}

extension DependencyValues {
    var subscriptionClient: SubscriptionClient {
        get { self[SubscriptionClient.self] }
        set { self[SubscriptionClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension SubscriptionClient {
    static let live: SubscriptionClient = {
#if canImport(RevenueCat)
        let manager = SubscriptionManager()
        return SubscriptionClient(
            configure: { apiKey, userID in await manager.configure(apiKey: apiKey, userID: userID) },
            fetchProducts: { await manager.fetchProducts() },
            purchase: { id in await manager.purchase(productID: id) },
            restorePurchases: { try await manager.restorePurchases() },
            checkEntitlement: { try await manager.checkEntitlement() },
            listenForTransactionUpdates: { manager.customerInfoStream() },
            logIn: { userID in try await manager.logIn(userID: userID) },
            logOut: { await manager.logOut() },
            isPurchasesAvailable: { await manager.isPurchasesAvailable() }
        )
#else
        // RevenueCat is not available on every platform target (e.g. watch simulator).
        // Keep a functional no-op implementation so builds remain cross-target compatible.
        return SubscriptionClient(
            configure: { _, _ in },
            fetchProducts: { PepinilloProduct.currentProducts.map(\.mockProductInfo) },
            purchase: { _ in .failed(message: "Purchases unavailable on this platform") },
            restorePurchases: { .free },
            checkEntitlement: { .free },
            listenForTransactionUpdates: { .finished },
            logIn: { _ in .free },
            logOut: { },
            isPurchasesAvailable: { false }
        )
#endif
    }()
}

// MARK: - Subscription Manager (actor)

#if canImport(RevenueCat)
private actor SubscriptionManager {
    private var isConfigured = false
    private var isUnavailable = false
    private var configurationWaiters: [CheckedContinuation<Void, Never>] = []

    func configure(apiKey: String, userID: String?) async {
        guard !isConfigured && !isUnavailable else { return }

        guard !apiKey.isEmpty, !apiKey.contains("$(REVENUECAT_API_KEY)") else {
            subscriptionLogger.warning("RevenueCat API key not configured — purchases unavailable")
            markUnavailable()
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey, appUserID: userID)
        isConfigured = true

        resumeConfigurationWaiters()
    }

    func isPurchasesAvailable() async -> Bool {
        await ensureConfigured()
        return !isUnavailable
    }

    func fetchProducts() async -> [ProductInfo] {
        await ensureConfigured()
        guard !isUnavailable else { return [] }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                subscriptionLogger.warning("No current RevenueCat offering found — returning empty products list")
                return []
            }

            var productInfos: [ProductInfo] = []
            for pepProduct in PepinilloProduct.currentProducts {
                if let package = offering.package(identifier: pepProduct.rawValue) ?? offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == pepProduct.rawValue }) {
                    let productInfo = ProductInfo(
                        id: pepProduct.rawValue,
                        displayName: package.storeProduct.localizedTitle,
                        description: package.storeProduct.localizedDescription,
                        displayPrice: package.localizedPriceString,
                        billingPeriod: billingPeriodString(for: package),
                        isFeatured: pepProduct == .annual
                    )
                    productInfos.append(productInfo)
                }
            }

            if productInfos.isEmpty {
                subscriptionLogger.warning("No matching packages found in current offering — returning empty products list")
                return []
            }

            return productInfos.sorted { a, b in
                let order = ["month": 0, "year": 1, "once": 2]
                return (order[a.billingPeriod] ?? 0) < (order[b.billingPeriod] ?? 0)
            }
        } catch {
            subscriptionLogger.error("Failed to fetch offerings from RevenueCat: \(error.localizedDescription)")
            return []
        }
    }

    func purchase(productID: String) async -> PurchaseResult {
        await ensureConfigured()
        guard !isUnavailable else {
            return .failed(message: String(localized: "Purchases are unavailable. Please try again later."))
        }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                return .failed(message: "No offerings available")
            }

            guard let package = offering.package(identifier: productID) ?? offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) else {
                return .failed(message: "Package not found")
            }

            let result = try await Purchases.shared.purchase(package: package)

            // Check for active entitlement (supports new "pepinillo_plus"/"everywhere_plus" and legacy "premium"/"pro")
            let entitlements = result.customerInfo.entitlements
            let hasActiveEntitlement = entitlements["everywhere_plus"]?.isActive == true
                || entitlements["pepinillo_plus"]?.isActive == true
                || entitlements["premium"]?.isActive == true
                || entitlements["pro"]?.isActive == true

            if hasActiveEntitlement {
                return .success(productID: productID)
            } else {
                return .failed(message: "Purchase completed but entitlement not active")
            }
        } catch let error as ErrorCode {
            switch error {
            case .purchaseCancelledError:
                return .cancelled
            default:
                return .failed(message: error.localizedDescription)
            }
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    func restorePurchases() async throws -> SubscriptionState {
        await ensureConfigured()
        guard !isUnavailable else { return .free }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let state = subscriptionStateFromCustomerInfo(customerInfo)
            AppGroupDefaults.lastVerifiedDate = Date()
            return state
        } catch {
            return try SubscriptionOfflineGraceChecker.check(
                error: error,
                cachedCapabilities: AppGroupDefaults.userCapabilities,
                lastVerifiedDate: AppGroupDefaults.lastVerifiedDate
            )
        }
    }

    func checkEntitlement() async throws -> SubscriptionState {
        await ensureConfigured()
        guard !isUnavailable else { return .free }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let state = subscriptionStateFromCustomerInfo(customerInfo)
            AppGroupDefaults.lastVerifiedDate = Date()
            return state
        } catch {
            return try SubscriptionOfflineGraceChecker.check(
                error: error,
                cachedCapabilities: AppGroupDefaults.userCapabilities,
                lastVerifiedDate: AppGroupDefaults.lastVerifiedDate
            )
        }
    }

    nonisolated func customerInfoStream() -> AsyncStream<SubscriptionState> {
        AsyncStream { continuation in
            let task = Task {
                let unavailable = await self.isUnavailableAfterConfigure()
                guard !unavailable else {
                    continuation.finish()
                    return
                }
                for await customerInfo in Purchases.shared.customerInfoStream {
                    let state = self.subscriptionStateFromCustomerInfo(customerInfo)
                    continuation.yield(state)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func isUnavailableAfterConfigure() async -> Bool {
        await ensureConfigured()
        return isUnavailable
    }

    func logIn(userID: String) async throws -> SubscriptionState {
        await ensureConfigured()
        guard !isUnavailable else { return .free }
        do {
            let result = try await Purchases.shared.logIn(userID)
            let state = subscriptionStateFromCustomerInfo(result.customerInfo)
            AppGroupDefaults.lastVerifiedDate = Date()
            return state
        } catch {
            return try SubscriptionOfflineGraceChecker.check(
                error: error,
                cachedCapabilities: AppGroupDefaults.userCapabilities,
                lastVerifiedDate: AppGroupDefaults.lastVerifiedDate
            )
        }
    }

    func logOut() async {
        await ensureConfigured()
        guard !isUnavailable else { return }
        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            // Log error but don't fail — logOut failure is non-fatal.
            subscriptionLogger.error("RevenueCat logOut failed: \(error, privacy: .private)")
        }
    }

    private func ensureConfigured() async {
        if isConfigured || isUnavailable { return }
        await withCheckedContinuation { continuation in
            configurationWaiters.append(continuation)
        }
    }

    private func markUnavailable() {
        isUnavailable = true
        resumeConfigurationWaiters()
    }

    private func resumeConfigurationWaiters() {
        for waiter in configurationWaiters {
            waiter.resume()
        }
        configurationWaiters.removeAll()
    }

    private nonisolated func subscriptionStateFromCustomerInfo(_ customerInfo: CustomerInfo) -> SubscriptionState {
        func info(_ key: String) -> ResolvedEntitlement? {
            guard let entitlement = customerInfo.entitlements[key] else { return nil }
            return ResolvedEntitlement(isActive: entitlement.isActive, expirationDate: entitlement.expirationDate)
        }

        return SubscriptionCapabilityResolver.resolve(
            everywhere: info("everywhere_plus"),
            pepinilloPlus: info("pepinillo_plus"),
            legacyPremium: info("premium"),
            legacyPro: info("pro"),
            activeSubscriptionID: customerInfo.activeSubscriptions.first,
            purchasedProductID: customerInfo.allPurchasedProductIdentifiers.first
        )
    }

    private nonisolated func billingPeriodString(for package: RevenueCat.Package) -> String {
        if let period = package.storeProduct.subscriptionPeriod {
            switch period.unit {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            case .year: return "year"
            @unknown default: return "month"
            }
        }
        return "once"
    }
}
#endif

// MARK: - Offline Grace Period Checker (Task 1.3, 1.4)

struct SubscriptionOfflineGraceChecker {
    static func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }
        if (error as? URLError) != nil {
            return true
        }
        #if canImport(RevenueCat)
        if let rcError = error as? RevenueCat.ErrorCode {
            return rcError == .networkError || rcError == .offlineConnectionError
        }
        #endif
        return false
    }

    static func check(
        error: Error,
        cachedCapabilities: UserCapabilities?,
        lastVerifiedDate: Date?,
        now: Date = Date()
    ) throws -> SubscriptionState {
        guard isNetworkError(error) else {
            throw error
        }
        
        guard let cachedCapabilities = cachedCapabilities else {
            throw error
        }
        
        // Pepinillo+ (lifetime) remains active indefinitely offline.
        if cachedCapabilities.localPremium && !cachedCapabilities.backendSync {
            return SubscriptionState(capabilities: cachedCapabilities)
        }
        
        // Everywhere/AI+ (subscription) remains active offline for a grace period of exactly 7 days
        if cachedCapabilities.backendSync {
            if let lastVerified = lastVerifiedDate {
                let elapsed = now.timeIntervalSince(lastVerified)
                if elapsed < 7 * 24 * 3600 {
                    return SubscriptionState(capabilities: cachedCapabilities)
                }
            }
        }
        
        throw error
    }
}

// MARK: - Entitlement resolution (issue #211)

struct ResolvedEntitlement: Equatable, Sendable {
    var isActive: Bool
    var expirationDate: Date?
}

enum SubscriptionCapabilityResolver {
    static func resolve(
        everywhere: ResolvedEntitlement?,
        pepinilloPlus: ResolvedEntitlement?,
        legacyPremium: ResolvedEntitlement?,
        legacyPro: ResolvedEntitlement?,
        activeSubscriptionID: String?,
        purchasedProductID: String?
    ) -> SubscriptionState {
        if let everywhere, everywhere.isActive {
            return SubscriptionState(
                capabilities: .everywherePlus,
                activeProductID: activeSubscriptionID,
                expirationDate: everywhere.expirationDate
            )
        }

        if let pepinilloPlus, pepinilloPlus.isActive {
            return SubscriptionState(
                capabilities: .pepinilloPlus,
                activeProductID: purchasedProductID,
                expirationDate: nil
            )
        }

        let legacy = legacyPremium ?? legacyPro
        if let legacy, legacy.isActive {
            if legacy.expirationDate == nil {
                return SubscriptionState(
                    capabilities: .pepinilloPlus,
                    activeProductID: purchasedProductID,
                    expirationDate: nil
                )
            }
            return SubscriptionState(
                capabilities: .everywherePlus,
                activeProductID: activeSubscriptionID,
                expirationDate: legacy.expirationDate
            )
        }

        return .free
    }
}

// MARK: - Mock helpers for previews / tests

private extension PepinilloProduct {
    var mockProductInfo: ProductInfo {
        switch self {
        case .monthly:
            return ProductInfo(id: rawValue, displayName: "Everywhere/AI+ Monthly",
                               description: "Everything in Pepinillo+ plus Pepinillo account sync and recovery.", displayPrice: "$4.99",
                               billingPeriod: "month")
        case .annual:
            return ProductInfo(id: rawValue, displayName: "Everywhere/AI+ Annual",
                               description: "Best value — save 42% vs monthly.", displayPrice: "$34.99",
                               billingPeriod: "year", isFeatured: true)
        case .lifetime:
            return ProductInfo(id: rawValue, displayName: "Pepinillo+",
                               description: "One purchase. Yours forever. Not a subscription.", displayPrice: "$19.99",
                               billingPeriod: "once")
        }
    }
}
