// PaywallView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pro subscription paywall. Shows product options and handles purchase flow.

import SwiftUI
import ComposableArchitecture

// MARK: - PaywallView

struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ProHeaderSection()
                    ProFeaturesSection()
                    ProductCardsSection(store: store)
                    PurchaseButton(store: store)
                    LegalFooter(store: store)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle(String(localized: "Pepinillo Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Close")) { store.send(.closeTapped) }
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .accessibilityLabel(String(localized: "Loading purchase options"))
                }
            }
            .alert(
                store.subscriptionState.isPro
                    ? String(localized: "You're Pro!")
                    : String(localized: "Purchase Status"),
                isPresented: Binding(
                    get: { store.purchaseResult != nil },
                    set: { if !$0 { store.send(.alertDismissed) } }
                )
            ) {
                Button(String(localized: "OK")) { store.send(.alertDismissed) }
                if store.purchaseResult?.isSuccess == true {
                    Button(String(localized: "Start Focusing")) { store.send(.closeTapped) }
                        .keyboardShortcut(.defaultAction)
                }
            } message: {
                Text(store.purchaseResult?.message ?? "")
            }
            .task { store.send(.appeared) }
        }
    }
}

// MARK: - Sub-Views

private struct ProHeaderSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            Text("🧠")
                .font(.system(size: 56))
                .scaleEffect(appeared ? 1 : 0.5)
                .accessibilityHidden(true)

            Text(String(localized: "Unlock Deep Focus"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(String(localized: "Get access to all focus modes, premium soundscapes, and advanced analytics."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
        .offset(y: appeared ? 0 : 15)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }
}

private struct ProFeaturesSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var features: [(String, String, String)] {[
        (String(localized: "All focus modes"),      String(localized: "flowtime, time blocks, and stopwatch"),       "rectangle.split.3x1"),
        (String(localized: "Premium soundscapes"),  String(localized: "binaural beats, lo-fi, ocean, fireplace"),   "music.note"),
        (String(localized: "Advanced analytics"),   String(localized: "detailed charts, weekly reviews"),           "chart.bar.xaxis"),
        (String(localized: "iCloud sync"),          String(localized: "seamlessly across all your Apple devices"),  "icloud"),
        (String(localized: "Widget customization"), String(localized: "choose what you see on your home screen"),   "widget.small"),
        (String(localized: "Streak protection"),    String(localized: "one free skip per week"),                    "flame"),
    ]}

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(features.enumerated()), id: \.element.0) { index, feature in
                let (title, subtitle, icon) = feature
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .offset(x: appeared ? 0 : -20)
                .opacity(appeared ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(0.15 + Double(index) * 0.06),
                    value: appeared
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            appeared = true
        }
    }
}

private struct ProductCardsSection: View {
    @Bindable var store: StoreOf<PaywallFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(store.products.enumerated()), id: \.element.id) { index, product in
                ProductCard(
                    product: product,
                    isSelected: store.selectedProductID == product.id
                ) {
                    store.send(.productSelected(product.id))
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(0.4 + Double(index) * 0.08),
                    value: appeared
                )
            }
        }
        .onAppear { appeared = true }
    }
}

private struct ProductCard: View {
    let product: ProductInfo
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(product.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        if product.isFeatured {
                            Text(String(localized: "BEST VALUE"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    if product.billingPeriod != "once" {
                        Text("/ \(product.billingPeriod)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.systemBackground))
                    .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(product.displayName), \(product.description), \(product.displayPrice)\(product.billingPeriod != "once" ? " per \(product.billingPeriod)" : "")")
        .accessibilityAddTraits([.isButton])
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct PurchaseButton: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        Button {
            store.send(.purchaseTapped)
        } label: {
            Text(String(localized: "Continue"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .disabled(store.isLoading || store.subscriptionState.isPro)
        .accessibilityLabel(store.subscriptionState.isPro
            ? String(localized: "You are already a Pro subscriber")
            : String(localized: "Continue with purchase"))
        .overlay {
            if store.subscriptionState.isPro {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.green)
                Text(String(localized: "You're Pro ✓"))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct LegalFooter: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        VStack(spacing: 8) {
            Button(String(localized: "Restore Purchases")) {
                store.send(.restoreTapped)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityHint(String(localized: "Restores previously purchased subscriptions"))

            Text(String(localized: "Payment will be charged to your Apple ID. Subscriptions auto-renew unless cancelled 24 hours before the end of the current period."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView(
        store: Store(initialState: PaywallFeature.State(
            products: PepinilloProduct.allCases.map { product in
                switch product {
                case .monthly:
                    return ProductInfo(id: product.rawValue, displayName: "Pro Monthly",
                                       description: "All features.", displayPrice: "$2.99",
                                       billingPeriod: "month")
                case .annual:
                    return ProductInfo(id: product.rawValue, displayName: "Pro Annual",
                                       description: "Best value — save 50%.", displayPrice: "$14.99",
                                       billingPeriod: "year", isFeatured: true)
                case .lifetime:
                    return ProductInfo(id: product.rawValue, displayName: "Pro Lifetime",
                                       description: "Pay once, own forever.", displayPrice: "$29.99",
                                       billingPeriod: "once")
                }
            }
        )) { PaywallFeature() }
    )
}
