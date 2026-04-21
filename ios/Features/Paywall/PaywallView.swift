// PaywallView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Two-tier paywall: Pepinillo+ (one-time) and Everywhere/AI+ (subscription).
// Apple Intelligence is the hero differentiator.
// Transparency: Pepinillo+ is explicitly "Not a subscription."

import SwiftUI
import ComposableArchitecture

// MARK: - PaywallView

struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PaywallHeaderSection()
                    PaywallPepinilloPlusSection()
                    PaywallEverywhereSection()
                    PaywallProductCardsSection(store: store)
                    PaywallPurchaseButton(store: store)
                    PaywallLegalFooter(store: store)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle(String(localized: "Choose Your Plan"))
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
                    ? String(localized: "Welcome to Pepinillo+!")
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

// MARK: - Header

struct PaywallHeaderSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            Text("🧠✨")
                .font(.system(size: 52))
                .scaleEffect(appeared ? 1 : 0.5)
                .accessibilityHidden(true)

            Text(String(localized: "Unlock Your Deep Focus"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(String(localized: "Apple Intelligence meets deep work. Get AI-powered insights, all focus modes, and a productivity system that learns how you work best."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
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

// MARK: - Pepinillo+ Features (One-Time)

struct PaywallPepinilloPlusSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let features: [(String, String, String)] = [
        ("Apple Intelligence", "AI-powered productivity reports & insights", "sparkles"),
        ("All 4 Focus Modes", "Pomodoro, Flowtime, Time Block, Stopwatch", "rectangle.split.3x1"),
        ("Unlimited Tasks", "subtasks, recurring tasks, energy levels", "checklist"),
        ("Advanced Analytics", "30-day, 1-year views, weekly & monthly reviews", "chart.bar.xaxis"),
        ("Apple Ecosystem", "iCloud sync, all widgets, Apple Watch companion", "apple.logo"),
        ("Premium Themes", "Forest, Ocean, Sunset, Liquid Glass", "paintpalette"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Tier header
            HStack {
                Text(String(localized: "Pepinillo+"))
                    .font(.headline)
                Spacer()
                Text(String(localized: "One purchase. Yours forever."))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.green)
            }

            // Not a subscription badge
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                Text(String(localized: "NOT a subscription — pay once, own it for life"))
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.secondary)

            // Features
            ForEach(Array(features.enumerated()), id: \.element.0) { index, feature in
                let (title, subtitle, icon) = feature
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
                .offset(x: appeared ? 0 : -20)
                .opacity(appeared ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(0.1 + Double(index) * 0.05),
                    value: appeared
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .onAppear { appeared = true }
    }
}

// MARK: - Everywhere/AI+ Features (Subscription)

struct PaywallEverywhereSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let availableFeatures: [(String, String, String)] = [
        ("Everything in Pepinillo+", "All Apple features included", "plus.circle"),
    ]

    private let comingSoonFeatures: [(String, String, String)] = [
        ("AI Coach", "personalized productivity coaching", "person.wave.2"),
        ("Advanced AI Insights", "predictive windows, burnout detection", "brain"),
        ("AI Task Scheduling", "smart scheduling based on your patterns", "calendar.badge.clock"),
        ("AI Subtask Generation", "auto-decompose complex tasks", "list.bullet.indent"),
        ("Cross-Platform Sync", "iOS + Android + Web (when available)", "arrow.triangle.2.circlepath"),
        ("100 AI Credits/month", "for cloud-powered AI workflows", "bolt.horizontal"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Tier header
            HStack {
                Text(String(localized: "Everywhere/AI+"))
                    .font(.headline)
                Spacer()
                Text(String(localized: "Subscription"))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }

            // Available features
            ForEach(Array(availableFeatures.enumerated()), id: \.element.0) { _, feature in
                let (title, subtitle, icon) = feature
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }

            Divider()
                .padding(.vertical, 2)

            // Coming soon section
            Text(String(localized: "Coming Soon"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(Array(comingSoonFeatures.enumerated()), id: \.element.0) { index, feature in
                let (title, subtitle, icon) = feature
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(String(localized: "Soon"))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                .offset(x: appeared ? 0 : -15)
                .opacity(appeared ? 0.7 : 0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(0.3 + Double(index) * 0.04),
                    value: appeared
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { appeared = true }
    }
}

// MARK: - Product Cards

struct PaywallProductCardsSection: View {
    @Bindable var store: StoreOf<PaywallFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(store.products.enumerated()), id: \.element.id) { index, product in
                PaywallProductCard(
                    product: product,
                    isSelected: store.selectedProductID == product.id
                ) {
                    store.send(.productSelected(product.id))
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(0.5 + Double(index) * 0.08),
                    value: appeared
                )
            }
        }
        .onAppear { appeared = true }
    }
}

struct PaywallProductCard: View {
    let product: ProductInfo
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
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
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        if product.billingPeriod == "once" {
                            Text(String(localized: "ONE-TIME"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green, in: Capsule())
                        } else if product.isFeatured {
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

// MARK: - Purchase Button

struct PaywallPurchaseButton: View {
    @Bindable var store: StoreOf<PaywallFeature>

    private var buttonLabel: String {
        if store.subscriptionState.isPro {
            return String(localized: "You're Pepinillo+ ✓")
        }
        let selected = store.products.first { $0.id == store.selectedProductID }
        if let product = selected, product.billingPeriod == "once" {
            return String(localized: "Get Pepinillo+ — One Time")
        }
        return String(localized: "Continue")
    }

    var body: some View {
        Button {
            store.send(.purchaseTapped)
        } label: {
            Text(buttonLabel)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .disabled(store.isLoading || store.subscriptionState.isPro)
        .accessibilityLabel(store.subscriptionState.isPro
            ? String(localized: "You already have Pepinillo+")
            : String(localized: "Continue with purchase"))
        .overlay {
            if store.subscriptionState.isPro {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.green)
                Text(String(localized: "You're Pepinillo+ ✓"))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Legal Footer

struct PaywallLegalFooter: View {
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
                    return ProductInfo(id: product.rawValue, displayName: "Everywhere/AI+",
                                       description: "Monthly subscription.", displayPrice: "$4.99",
                                       billingPeriod: "month")
                case .annual:
                    return ProductInfo(id: product.rawValue, displayName: "Everywhere/AI+",
                                       description: "Best value — save 42%.", displayPrice: "$34.99",
                                       billingPeriod: "year", isFeatured: true)
                case .lifetime:
                    return ProductInfo(id: product.rawValue, displayName: "Pepinillo+",
                                       description: "One purchase. Yours forever.", displayPrice: "$19.99",
                                       billingPeriod: "once")
                }
            }
        )) { PaywallFeature() }
    )
}
