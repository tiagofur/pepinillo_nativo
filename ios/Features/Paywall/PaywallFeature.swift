// PaywallFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer for the paid subscription tiers.
// Loads StoreKit products, handles purchase flow, and emits .proUnlocked on success.

import Foundation
import ComposableArchitecture

// MARK: - Entitlement mapping (#212)

enum PaywallEntitlementMapper {
    /// Maps a purchased product identifier to the correct subscription entitlement.
    /// Everywhere/AI+ (monthly/annual) → everywherePlus; Pepinillo+ lifetime → pepinilloPlus.
    static func subscriptionState(forProductID productID: String) -> SubscriptionState {
        isLifetimeProduct(productID) ? .pepinilloPlus : .everywherePlus
    }

    /// Whether the purchase button should be enabled for the selected product
    /// given the user's current entitlement (upgrade path for Pepinillo+ → Everywhere).
    static func canPurchase(selectedProductID: String, current: SubscriptionState) -> Bool {
        if current.isEverywhere {
            return false
        }
        if current.capabilities.hasPepinilloPlus {
            // Lifetime owners may upgrade to Everywhere, but not re-buy lifetime.
            return !isLifetimeProduct(selectedProductID)
        }
        return true
    }

    static func isLifetimeProduct(_ productID: String) -> Bool {
        if productID == PepinilloProduct.lifetime.rawValue { return true }
        if productID == "lifetime" { return true }
        if let product = PepinilloProduct(rawValue: productID) {
            return product == .lifetime
        }
        return productID.lowercased().hasSuffix(".lifetime")
            || productID.lowercased().contains("lifetime")
    }
}

// MARK: - Legal compliance copy (#215)

enum PaywallLegalCopy {
    /// App Store Guideline 3.1.2 auto-renewal disclosure for the selected product.
    static func autoRenewalDisclosure(product: ProductInfo?) -> String {
        guard let product else {
            return String(localized: "Pepinillo+ is a one-time purchase. Everywhere/AI+ is an auto-renewing subscription. Payment is charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Manage or cancel in App Store Account Settings.")
        }

        if product.billingPeriod == "once" || PaywallEntitlementMapper.isLifetimeProduct(product.id) {
            return String(
                localized: "Pepinillo+ (\(product.displayPrice)) is a one-time purchase, not a subscription. Payment will be charged to your Apple ID account at confirmation of purchase."
            )
        }

        let periodLabel: String
        switch product.billingPeriod {
        case "year":
            periodLabel = String(localized: "one year")
        case "month":
            periodLabel = String(localized: "one month")
        default:
            periodLabel = product.billingPeriod
        }

        return String(
            localized: "Everywhere/AI+ is an auto-renewing subscription for \(periodLabel) at \(product.displayPrice). Payment will be charged to your Apple ID account at confirmation of purchase. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your Account Settings in the App Store after purchase."
        )
    }
}

// MARK: - PaywallFeature

@Reducer
struct PaywallFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var products: [ProductInfo] = []
        var selectedProductID: String = PepinilloProduct.annual.rawValue
        var isLoading: Bool = false
        var purchaseResult: PurchaseResultAlert? = nil
        var subscriptionState: SubscriptionState = .free
        /// Shown after a guest purchase/restore: without an account the
        /// entitlement lives only in the anonymous RevenueCat ID. Creating one
        /// transfers it (RC alias) and the post-login reconcile syncs it.
        var showCreateAccountNudge = false
        /// Whether the presenting user is a guest (no backend session).
        /// Resolved on appear via the keychain; guests get the nudge instead
        /// of the plain welcome alert so the entitlement can follow them.
        var isGuest = false

        /// Whether the primary purchase action should be enabled for the current selection.
        var isPurchaseEnabled: Bool {
            !isLoading && !products.isEmpty && PaywallEntitlementMapper.canPurchase(
                selectedProductID: selectedProductID,
                current: subscriptionState
            )
        }

        var selectedProduct: ProductInfo? {
            products.first { $0.id == selectedProductID }
        }

        struct PurchaseResultAlert: Equatable {
            var message: String
            var isSuccess: Bool
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case appeared
        case guestStatusLoaded(Bool)
        case productsLoaded([ProductInfo])
        case productSelected(String)
        case purchaseTapped
        case restoreTapped
        case purchaseFinished(PurchaseResult)
        case subscriptionStateLoaded(SubscriptionState)
        case alertDismissed
        case closeTapped
        case createAccountTapped
        case createAccountDismissed
        case privacyPolicyTapped
        case termsOfServiceTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case proUnlocked(SubscriptionState)
            /// User tapped the close (X) button. The paywall is presented by AppFeature
            /// via `.sheet(isPresented: store.focus.showPaywall)`, so `@Dependency(\.dismiss)`
            /// cannot close it (dismiss only works for `sheet(item:)` or NavigationStack
            /// paths). The parent owns the boolean and must flip it to false.
            case closeRequested
        /// Guest tapped "Create account" on the post-purchase nudge: the
        /// parent dismisses the paywall and presents auth. RC transfers the
        /// entitlement on sign-in; the server side converges on next sync.
        case signInRequested
        }
    }

    // MARK: - Dependencies

    @Dependency(\.subscriptionClient) var subscriptionClient
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.openURL) var openURL

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appeared:
                state.isLoading = true
                return .merge(
                    .run { send in
                        guard await subscriptionClient.isPurchasesAvailable() else {
                            await send(.productsLoaded([]))
                            await send(.purchaseFinished(.failed(
                                message: String(localized: "Purchases are unavailable. Please try again later.")
                            )))
                            return
                        }
                        let products = await subscriptionClient.fetchProducts()
                        await send(.productsLoaded(products))
                    },
                    .run { send in
                        // Resolve guest status for the post-purchase nudge: no
                        // backend tokens means the buyer is anonymous, and the
                        // entitlement would strand on the RC anonymous ID.
                        let hasTokens = await keychain.hasTokens()
                        await send(.guestStatusLoaded(!hasTokens))
                    },
                    .run { send in
                        // Do not silently coerce network failures to .free (#214).
                        do {
                            let sub = try await subscriptionClient.checkEntitlement()
                            await send(.subscriptionStateLoaded(sub))
                        } catch {
                            // Preserve whatever entitlement is already in state.
                        }
                    }
                )

            case .guestStatusLoaded(let isGuest):
            state.isGuest = isGuest
            if !isGuest {
                // An authenticated user never needs the nudge (e.g. paywall
                // reopened after signing in elsewhere).
                state.showCreateAccountNudge = false
            }
            return .none

        case .createAccountTapped:
            state.showCreateAccountNudge = false
            return .send(.delegate(.signInRequested))

        case .createAccountDismissed:
            state.showCreateAccountNudge = false
            return .none

        case .productsLoaded(let products):
                state.isLoading = false
                state.products = products
                if let featured = products.first(where: { $0.isFeatured }) {
                    state.selectedProductID = featured.id
                } else {
                    state.selectedProductID = products.first?.id ?? state.selectedProductID
                }
                return .none

            case .productSelected(let id):
                state.selectedProductID = id
                return .none

            case .purchaseTapped:
                state.isLoading = true
                let id = state.selectedProductID
                return .run { send in
                    let result = await subscriptionClient.purchase(id)
                    await send(.purchaseFinished(result))
                }

            case .restoreTapped:
                state.isLoading = true
                return .run { send in
                    do {
                        let sub = try await subscriptionClient.restorePurchases()
                        await send(.subscriptionStateLoaded(sub))
                        if sub.isPro {
                            await send(.purchaseFinished(.success(productID: sub.activeProductID ?? "")))
                        } else {
                            await send(.purchaseFinished(.failed(message: String(localized: "No active subscription found."))))
                        }
                    } catch {
                        // Surface error; do not demote existing entitlement to free (#214).
                        let message = error.localizedDescription.isEmpty
                            ? String(localized: "Could not restore purchases. Please try again.")
                            : error.localizedDescription
                        await send(.purchaseFinished(.failed(message: message)))
                    }
                }

            case .purchaseFinished(let result):
                state.isLoading = false
                switch result {
                case .success(let productID):
                    // Map product → entitlement immediately (Everywhere ≠ Pepinillo+) (#212).
                    // Empty productID is the restore path — subscriptionState was already
                    // applied via subscriptionStateLoaded; do not remap empty → Everywhere.
                    let mapped: SubscriptionState
                    if productID.isEmpty {
                        mapped = state.subscriptionState
                    } else {
                        mapped = PaywallEntitlementMapper.subscriptionState(forProductID: productID)
                        state.subscriptionState = mapped
                    }
                    let welcomeMessage = mapped.isEverywhere
                        ? String(localized: "Welcome to Everywhere/AI+! 🎉")
                        : String(localized: "Welcome to Pepinillo+! 🎉")
                    if state.isGuest {
                        // Guest purchase/restore: skip the welcome alert — the
                        // create-account nudge carries the celebration plus the
                        // keep-premium CTA. The unlock path below still runs.
                        state.showCreateAccountNudge = true
                    } else {
                        state.purchaseResult = State.PurchaseResultAlert(
                            message: welcomeMessage,
                            isSuccess: true
                        )
                    }
                    return .run { [mapped, productID] send in
                        // Restore path already has authoritative state; unlock if pro.
                        if productID.isEmpty {
                            if mapped.isPro {
                                await send(.delegate(.proUnlocked(mapped)))
                            }
                            return
                        }
                        do {
                            let sub = try await subscriptionClient.checkEntitlement()
                            await send(.subscriptionStateLoaded(sub))
                            if sub.isPro {
                                await send(.delegate(.proUnlocked(sub)))
                            } else if mapped.isPro {
                                // Recheck returned free/unexpected — keep product mapping.
                                await send(.delegate(.proUnlocked(mapped)))
                            }
                        } catch {
                            // Purchase already succeeded; unlock with product-mapped entitlement.
                            if mapped.isPro {
                                await send(.delegate(.proUnlocked(mapped)))
                            }
                        }
                    }
                case .pending:
                    state.purchaseResult = State.PurchaseResultAlert(
                        message: String(localized: "Purchase is pending approval."),
                        isSuccess: false
                    )
                case .cancelled:
                    break
                case .failed(let message):
                    state.purchaseResult = State.PurchaseResultAlert(
                        message: message,
                        isSuccess: false
                    )
                }
                return .none

            case .subscriptionStateLoaded(let sub):
                state.isLoading = false
                state.subscriptionState = sub
                return .none

            case .alertDismissed:
                state.purchaseResult = nil
                return .none

            case .closeTapped:
                // Delegate to the parent, which owns the `showPaywall` boolean that
                // drives the sheet. The previous `await dismiss()` was a no-op for a
                // sheet presented via `isPresented: Bool`, which is why the X button
                // did nothing and only the swipe-down gesture closed the paywall.
                return .send(.delegate(.closeRequested))

            case .privacyPolicyTapped:
                return .run { _ in await openURL(URL(string: "https://creapolis.dev/privacy-policy/")!) }

            case .termsOfServiceTapped:
                return .run { _ in await openURL(URL(string: "https://creapolis.dev/terms-of-use/")!) }

            case .delegate:
                return .none
            }
        }
    }
}
