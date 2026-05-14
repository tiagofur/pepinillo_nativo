// PaywallView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Two-tier paywall: Pepinillo+ (one-time) and Everywhere/AI+ (subscription).
// Enhanced with Liquid Glass design and Apple compliance features.

import SwiftUI
import ComposableArchitecture

// MARK: - PaywallView

struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>
    @Namespace private var glassNS

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    PaywallHeaderSection()
                        .readableContent(maxWidth: 672)

                    // Feature tier cards
                    LazyVGrid(columns: adaptiveCardColumns, spacing: 20) {
                        PaywallPepinilloPlusSection()
                    }
                    .contentMaxWidth(900)

                    PaywallProductCardsSection(store: store, glassNamespace: glassNS)
                        .readableContent(maxWidth: 672)

                    VStack(spacing: 20) {
                        PaywallPurchaseButton(store: store, glassNamespace: glassNS)
                        PaywallLegalFooter(store: store)
                    }
                    .readableContent(maxWidth: 672)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .withAmbientBackground()
            .navigationTitle(String(localized: "Upgrade to Pepinillo+"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
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
                    ? String(localized: "Welcome to Pepinillo+! 🎉")
                    : String(localized: "Purchase Status"),
                isPresented: Binding(
                    get: { store.purchaseResult != nil },
                    set: { if !$0 { store.send(.alertDismissed) } }
                )
            ) {
                Button(String(localized: "OK")) { store.send(.alertDismissed) }
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentColor, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .opacity(0.3)
                
                Text("🧠✨")
                    .font(.system(size: 64))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 10)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(String(localized: "Master Your Focus"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(String(localized: "Join thousands of users using Apple Intelligence to reach their peak productivity."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 10)
        .offset(y: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            if !appeared {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Features Sections

struct PaywallPepinilloPlusSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(String(localized: "Pepinillo+"), systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                Spacer()
                
                Text(String(localized: "Lifetime"))
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.2), in: Capsule())
                    .foregroundStyle(.green)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "sparkles", title: "Apple Intelligence", subtitle: "AI-powered productivity insights")
                FeatureRow(icon: "rectangle.split.3x1", title: "All Focus Modes", subtitle: "Pomodoro, Flowtime, Time Block")
                FeatureRow(icon: "checklist", title: "Unlimited Tasks", subtitle: "Smart lists & recurring tasks")
                FeatureRow(icon: "apple.logo", title: "Ecosystem Pro", subtitle: "All widgets & Watch companion")
            }
        }
        .padding(20)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.hero)
    }
}


struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Product Cards

struct PaywallProductCardsSection: View {
    @Bindable var store: StoreOf<PaywallFeature>
    let glassNamespace: Namespace.ID

    var body: some View {
        VStack(spacing: 12) {
            ForEach(store.products) { product in
                PaywallProductCard(
                    product: product,
                    isSelected: store.selectedProductID == product.id,
                    glassNamespace: glassNamespace
                ) {
                    store.send(.productSelected(product.id))
                }
            }
        }
    }
}

struct PaywallProductCard: View {
    let product: ProductInfo
    let isSelected: Bool
    let glassNamespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if product.isFeatured {
                            Text(String(localized: "Popular"))
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if product.billingPeriod != "once" {
                        Text("/ \(product.billingPeriod)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(18)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: GlassCornerRadius.card)
                            .fill(Color.accentColor.opacity(0.08))
                            .matchedGeometryEffect(id: "selection-bg-\(product.id)", in: glassNamespace)
                    }
                }
            )
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: GlassCornerRadius.card)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Purchase Button

struct PaywallPurchaseButton: View {
    @Bindable var store: StoreOf<PaywallFeature>
    let glassNamespace: Namespace.ID

    private var buttonLabel: String {
        if store.subscriptionState.isPro {
            return String(localized: "Subscription Active")
        }
        let selected = store.products.first { $0.id == store.selectedProductID }
        if let product = selected {
            if product.billingPeriod == "once" {
                return String(localized: "Get Lifetime Access")
            }
            return String(localized: "Start My Free Trial")
        }
        return String(localized: "Continue")
    }

    var body: some View {
        Button {
            store.send(.purchaseTapped)
        } label: {
            HStack {
                if store.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonLabel)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .paywallPrimaryActionGlass(glassNamespace: glassNamespace)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .buttonStyle(.pressable)
        .disabled(store.isLoading || store.subscriptionState.isPro)
        .padding(.top, 10)
    }
}

private extension View {
    @ViewBuilder
    func paywallPrimaryActionGlass(glassNamespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .foregroundStyle(.primary)
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint(Color.accentColor.opacity(0.2)),
                    in: .rect(cornerRadius: GlassCornerRadius.card)
                )
                .glassEffectID("paywall-action", in: glassNamespace)
                .overlay {
                    RoundedRectangle(cornerRadius: GlassCornerRadius.card)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                }
        } else {
            self
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: GlassCornerRadius.card)
                )
                .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 6)
        }
    }
}

// MARK: - Legal Footer

struct PaywallLegalFooter: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        VStack(spacing: 16) {
            Button(String(localized: "Restore Purchases")) {
                store.send(.restoreTapped)
            }
            .font(.subheadline.bold())
            .foregroundStyle(Color.accentColor)
            
            Text(String(localized: "Payment will be charged to your Apple ID account. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period."))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            
            HStack(spacing: 24) {
                Button(String(localized: "Terms of Use")) {
                    store.send(.termsOfServiceTapped)
                }
                
                Text("•")
                    .foregroundStyle(.secondary.opacity(0.5))
                
                Button(String(localized: "Privacy Policy")) {
                    store.send(.privacyPolicyTapped)
                }
            }
            .font(.subheadline.bold())
            .foregroundStyle(Color.accentColor)
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView(
        store: Store(initialState: PaywallFeature.State(
            products: PepinilloProduct.currentProducts.map { product in
                switch product {
                case .lifetime:
                    return ProductInfo(id: product.rawValue, displayName: "Pepinillo+",
                                       description: "One-time purchase for life.", displayPrice: "$19.99",
                                       billingPeriod: "once")
                default:
                    return ProductInfo(id: product.rawValue, displayName: "Unknown", description: "", displayPrice: "", billingPeriod: "")
                }
            }
        )) { PaywallFeature() }
    )
}
