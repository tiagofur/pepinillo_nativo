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
            PaywallContentBody(store: store, glassNamespace: glassNS)
            .scrollContentBackground(.hidden)
            .withAmbientBackground()
            .navigationTitle(String(localized: "Choose Your Plan"))
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
            .onChange(of: store.purchaseResult) { _, result in
                // Fire success haptic in the view layer — matches CelebrationView.onAppear pattern.
                if result?.isSuccess == true {
                    HapticManager.notification(.success)
                }
            }
            .task { store.send(.appeared) }
        }
    }
}

struct PaywallContentBody: View {
    @Bindable var store: StoreOf<PaywallFeature>
    let glassNamespace: Namespace.ID

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                PaywallHeaderSection()
                    .readableContent(maxWidth: 720)

                PaywallTierComparisonSection()
                    .contentMaxWidth(980)

                PaywallProductCardsSection(store: store, glassNamespace: glassNamespace)
                    .readableContent(maxWidth: 720)

                VStack(spacing: 18) {
                    PaywallPurchaseButton(store: store, glassNamespace: glassNamespace)
                    PaywallLegalFooter(store: store)
                }
                .readableContent(maxWidth: 720)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 42)
        }
    }
}

// MARK: - Header

struct PaywallHeaderSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Pepinillo plans"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Apple-first focus. Sync when you need it."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Unlock the right kind of sync."))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(3)
                    .minimumScaleFactor(0.86)

                Text(String(localized: "Pepinillo+ keeps your Apple devices in sync with iCloud. Everywhere/AI+ adds the Pepinillo cloud so your data can travel beyond Apple and power server AI."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
        .offset(y: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            if !appeared {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.45).delay(0.05)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Features Sections

struct PaywallTierComparisonSection: View {
    var body: some View {
        LazyVGrid(columns: adaptiveCardColumns, spacing: 16) {
            PaywallTierCard(
                title: String(localized: "Pepinillo+"),
                eyebrow: String(localized: "One-time Apple unlock"),
                icon: "apple.logo",
                tint: .green,
                summary: String(localized: "Best if you live on iPhone, iPad, Mac, Apple Watch, and want private Apple sync."),
                benefits: [
                    .init(icon: "icloud.fill", title: String(localized: "iCloud sync"), subtitle: String(localized: "Tasks, sessions, settings, analytics across Apple devices.")),
                    .init(icon: "sparkles", title: String(localized: "On-device AI"), subtitle: String(localized: "Apple Intelligence / local reports without cloud AI credits.")),
                    .init(icon: "checklist", title: String(localized: "Full local app"), subtitle: String(localized: "Unlimited tasks, subtasks, recurrence, themes, widgets, Watch.")),
                    .init(icon: "square.and.arrow.up", title: String(localized: "Export access"), subtitle: String(localized: "Keep your focus history portable with data exports."))
                ]
            )

            PaywallTierCard(
                title: String(localized: "Everywhere/AI+"),
                eyebrow: String(localized: "Monthly or annual subscription"),
                icon: "network",
                tint: .blue,
                summary: String(localized: "Best if you want Pepinillo synced through the VPS and cloud AI on every platform."),
                benefits: [
                    .init(icon: "server.rack", title: String(localized: "Pepinillo cloud sync"), subtitle: String(localized: "Your VPS becomes the source of truth for future cross-platform devices.")),
                    .init(icon: "bolt.horizontal.cloud.fill", title: String(localized: "Cloud AI credits"), subtitle: String(localized: "Server AI for deeper summaries and recommendations.")),
                    .init(icon: "person.crop.circle.badge.checkmark", title: String(localized: "Account restore"), subtitle: String(localized: "Restore entitlement through your Pepinillo account.")),
                    .init(icon: "plus.circle.fill", title: String(localized: "Everything in Pepinillo+"), subtitle: String(localized: "Local premium features remain included."))
                ]
            )
        }
    }
}

struct PaywallTierCard: View {
    struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
    }

    let title: String
    let eyebrow: String
    let icon: String
    let tint: Color
    let summary: String
    let benefits: [Benefit]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(tint)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: GlassCornerRadius.tile))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.title3.weight(.bold))
                }
            }

            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 13) {
                ForEach(benefits) { benefit in
                    FeatureRow(icon: benefit.icon, title: benefit.title, subtitle: benefit.subtitle, tint: tint)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.hero)
        .overlay {
            RoundedRectangle(cornerRadius: GlassCornerRadius.hero)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = .accentColor
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(String(localized: "Choose how to unlock"))
                    .font(.title3.weight(.bold))
                Text(String(localized: "Apple handles every purchase. You can restore at any time from this screen."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

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
    @Environment(\.colorScheme) private var colorScheme
    let product: ProductInfo
    let isSelected: Bool
    let glassNamespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: product.planIcon)
                        .font(.title3.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(product.planTint)
                        .background(product.planTint.opacity(0.14), in: RoundedRectangle(cornerRadius: GlassCornerRadius.tile))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(product.planDisplayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            if product.isFeatured {
                                Text(String(localized: "Best value"))
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(Color.accentColor)
                                    .background(Color.accentColor.opacity(0.13), in: Capsule())
                            }
                        }

                        Text(product.planSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)

                        Text(product.billingLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.42))
                        .accessibilityHidden(true)

                    Text(product.complianceLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: GlassCornerRadius.card)
                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.06))
                            .matchedGeometryEffect(id: "selection-glow", in: glassNamespace)
                    }
                }
            )
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
            .overlay {
                RoundedRectangle(cornerRadius: GlassCornerRadius.card)
                    .stroke(isSelected ? Color.accentColor.opacity(0.72) : .primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: GlassCornerRadius.card))
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.smooth(duration: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Purchase Button

struct PaywallPurchaseButton: View {
    @Bindable var store: StoreOf<PaywallFeature>
    let glassNamespace: Namespace.ID

    private var buttonLabel: String {
        let selected = store.products.first { $0.id == store.selectedProductID }
        let selectedIsLifetime = selected.map {
            $0.billingPeriod == "once" || PaywallEntitlementMapper.isLifetimeProduct($0.id)
        } ?? PaywallEntitlementMapper.isLifetimeProduct(store.selectedProductID)

        if store.subscriptionState.isEverywhere {
            return String(localized: "Subscription Active")
        }

        // Pepinillo+ lifetime owners may upgrade to Everywhere (#212).
        if store.subscriptionState.capabilities.hasPepinilloPlus {
            if selectedIsLifetime {
                return String(localized: "Pepinillo+ Active")
            }
            return String(localized: "Upgrade to Everywhere/AI+")
        }

        if let product = selected {
            if product.billingPeriod == "once" {
                return String(localized: "Buy Pepinillo+")
            }
            return String(localized: "Continue with Everywhere/AI+")
        }
        return String(localized: "Continue")
    }

    private var isEnabled: Bool {
        store.isPurchaseEnabled
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
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.headline)
                        .accessibilityHidden(true)
                }
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .paywallPrimaryActionGlass(glassNamespace: glassNamespace)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .buttonStyle(PepinilloButtonStyle())
        .disabled(!isEnabled)
        .padding(.top, 4)
        .shadow(color: isEnabled ? Color.accentColor.opacity(0.20) : .clear, radius: 20, y: 10)
    }
}

private extension View {
    @ViewBuilder
    func paywallPrimaryActionGlass(glassNamespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .foregroundStyle(.white)
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint(Color.accentColor.opacity(0.55)),
                    in: .capsule
                )
                .glassEffectID("paywall-action", in: glassNamespace)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.26), lineWidth: 1)
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
                    in: Capsule()
                )
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

            // App Store Guideline 3.1.2 — price, period, auto-renewal, manage/cancel (#215).
            Text(PaywallLegalCopy.autoRenewalDisclosure(product: store.selectedProduct))
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

private extension ProductInfo {
    var isLifetime: Bool { billingPeriod == "once" || id == PepinilloProduct.lifetime.rawValue }
    var isAnnual: Bool { billingPeriod == "year" || id == PepinilloProduct.annual.rawValue }

    var planDisplayName: String {
        isLifetime ? String(localized: "Pepinillo+") : String(localized: "Everywhere/AI+")
    }

    var planIcon: String {
        isLifetime ? "apple.logo" : "network"
    }

    var planTint: Color {
        isLifetime ? .green : .blue
    }

    var planSummary: String {
        if isLifetime {
            return String(localized: "One purchase for full local features, on-device AI, export, Apple Watch, widgets, and iCloud sync.")
        }
        if isAnnual {
            return String(localized: "Everything in Pepinillo+ plus VPS sync, account restore, and cloud AI credits. Best value.")
        }
        return String(localized: "Everything in Pepinillo+ plus VPS sync, account restore, and cloud AI credits.")
    }

    var billingLabel: String {
        switch billingPeriod {
        case "once":
            return String(localized: "once")
        case "year":
            return String(localized: "per year")
        case "month":
            return String(localized: "per month")
        default:
            return billingPeriod
        }
    }

    var complianceLine: String {
        isLifetime
            ? String(localized: "Not a subscription. Apple-to-Apple sync uses your iCloud account.")
            : String(localized: "Auto-renewing subscription. VPS sync is the source of truth.")
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
