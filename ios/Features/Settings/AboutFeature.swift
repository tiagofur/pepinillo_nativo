// AboutFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the About screen.
// Displays app version, subscription status, and legal links.

import Foundation
import ComposableArchitecture

@Reducer
struct AboutFeature {

    @ObservableState
    struct State: Equatable {
        var isProUser: Bool = false
        var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        var buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    enum Action: Equatable {
        case privacyPolicyTapped
        case termsOfServiceTapped
    }

    @Dependency(\.openURL) var openURL

    private enum URLs {
        static let privacyPolicy = URL(string: "https://creapolis.dev/privacy-policy/")!
        static let termsOfService = URL(string: "https://creapolis.dev/terms-of-use/")!
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .privacyPolicyTapped:
                return .run { _ in
                    await openURL(URLs.privacyPolicy)
                }

            case .termsOfServiceTapped:
                return .run { _ in
                    await openURL(URLs.termsOfService)
                }
            }
        }
    }
}
