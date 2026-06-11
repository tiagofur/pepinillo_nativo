// PaywallFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Pro subscription paywall.
// Loads StoreKit products, handles purchase flow, and emits .proUnlocked on success.

import Foundation
import ComposableArchitecture
#if os(iOS)
import UIKit
#endif

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

        struct PurchaseResultAlert: Equatable {
            var message: String
            var isSuccess: Bool
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case appeared
        case productsLoaded([ProductInfo])
        case productSelected(String)
        case purchaseTapped
        case restoreTapped
        case purchaseFinished(PurchaseResult)
        case subscriptionStateLoaded(SubscriptionState)
        case alertDismissed
        case closeTapped
        case privacyPolicyTapped
        case termsOfServiceTapped
    }

    // MARK: - Dependencies

    @Dependency(\.subscriptionClient) var subscriptionClient
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.openURL) var openURL

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // ... (keeping existing cases)
            case .appeared:
                state.isLoading = true
                return .merge(
                    .run { send in
                        let products = await subscriptionClient.fetchProducts()
                        await send(.productsLoaded(products))
                    },
                    .run { send in
                        let sub = await subscriptionClient.checkEntitlement()
                        await send(.subscriptionStateLoaded(sub))
                    }
                )

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
                    let sub = await subscriptionClient.restorePurchases()
                    await send(.subscriptionStateLoaded(sub))
                    if sub.isPro {
                        await send(.purchaseFinished(.success(productID: sub.activeProductID ?? "")))
                    } else {
                        await send(.purchaseFinished(.failed(message: String(localized: "No active subscription found."))))
                    }
                }

            case .purchaseFinished(let result):
                state.isLoading = false
                switch result {
                case .success:
                    state.subscriptionState = .pro
                    state.purchaseResult = State.PurchaseResultAlert(
                        message: String(localized: "Welcome to Pepinillo Pro! 🎉"),
                        isSuccess: true
                    )
                    // P2 item 6a: success notification haptic on purchase completion
                    return .run { _ in
                        #if os(iOS)
                        await MainActor.run {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                        #endif
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
                return .run { _ in await dismiss() }

            case .privacyPolicyTapped:
                return .run { _ in await openURL(URL(string: "https://creapolis.dev/privacy-policy/")!) }

            case .termsOfServiceTapped:
                return .run { _ in await openURL(URL(string: "https://creapolis.dev/terms-of-use/")!) }
            }
        }
    }
}
