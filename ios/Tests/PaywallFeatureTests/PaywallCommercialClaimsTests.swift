// PaywallCommercialClaimsTests.swift
// Pepinillo — Deep Work Companion for Apple

import Foundation
import Testing
@testable import Pepinillo

@Suite("Paywall commercial claims")
struct PaywallCommercialClaimsTests {
    @Test("Tier claim identifiers match the independently approved set")
    func exactApprovedClaims() {
        let pepinilloPlusIDs = PaywallCommercialClaims.pepinilloPlus.map(\.id)
        let everywhereIDs = PaywallCommercialClaims.everywhere.map(\.id)

        #expect(pepinilloPlusIDs.count == 4)
        #expect(Set(pepinilloPlusIDs) == Set([
            .appleCloudSync,
            .onDeviceAI,
            .fullLocalApp,
            .exportAccess,
        ]))
        #expect(everywhereIDs.count == 3)
        #expect(Set(everywhereIDs) == Set([
            .pepinilloCloudSync,
            .accountRecovery,
            .pepinilloPlusIncluded,
        ]))
    }

    @Test("Production paywall copy excludes undelivered value")
    func productionCopyExcludesForbiddenClaims() {
        let copy = PaywallCommercialClaims.productionPaywallSourceCopy
            .joined(separator: "\n")
            .lowercased()
        let phrases = [
            "cloud ai",
            "server ai",
            "ai credit",
            "cross-platform",
            "cross platform",
            "beyond apple",
            "every platform",
        ]
        let words = Set(copy.split(whereSeparator: { !$0.isLetter }).map(String.init))

        for phrase in phrases {
            #expect(!copy.contains(phrase))
        }
        for word in ["mac", "web", "windows", "vps"] {
            #expect(!words.contains(word))
        }
    }

    @Test("StoreKit IAP descriptions fit App Store Connect's 45-character limit")
    func storeKitDescriptionLimits() throws {
        let configuration = try Data(contentsOf: iosRoot.appendingPathComponent("Pepinillo.storekit"))
        let json = try JSONSerialization.jsonObject(with: configuration)
        var descriptions: [String] = []

        func collectDescriptions(from value: Any) {
            if let dictionary = value as? [String: Any] {
                if let description = dictionary["description"] as? String {
                    descriptions.append(description)
                }
                dictionary.values.forEach(collectDescriptions)
            } else if let array = value as? [Any] {
                array.forEach(collectDescriptions)
            }
        }

        collectDescriptions(from: json)
        #expect(descriptions.count == 9)
        for description in descriptions {
            #expect(description.count <= 45)
        }
    }

    @Test("Documented IAP descriptions fit App Store Connect's 45-character limit")
    func documentedDescriptionLimits() throws {
        let listing = try String(
            contentsOf: iosRoot.appendingPathComponent("docs/app-store-listing.md"),
            encoding: .utf8
        )
        let iapSection = try #require(
            listing.components(separatedBy: "## In-App Purchases").last?
                .components(separatedBy: "## Pricing & Availability").first
        )
        let descriptions = iapSection.components(separatedBy: .newlines).compactMap { line in
            line.hasPrefix("- Description: ")
                ? String(line.dropFirst("- Description: ".count))
                : nil
        }

        #expect(descriptions.count == 9)
        for description in descriptions {
            #expect(description.count <= 45)
        }
    }

    private var iosRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
