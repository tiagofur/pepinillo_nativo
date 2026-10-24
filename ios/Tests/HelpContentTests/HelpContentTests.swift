// HelpContentTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Guards the help content contract: the shared FAQ catalog stays compact
// but covers every troubleshooting topic users actually hit, and every
// outbound link is a well-formed https/mailto URL. Topic coverage is
// pinned with the locale-independent `FAQItem.Topic` tags so the contract
// holds regardless of the test host's language.

import Testing
import Foundation
@testable import Pepinillo

@Suite("HelpContent")
struct HelpContentTests {

    @Test("FAQ covers every topic at least once")
    func faqCoversEveryTopicOnce() {
        let topics = Set(FAQItem.all.map(\.topic))
        #expect(topics == Set(FAQItem.Topic.allCases))
    }

    @Test("FAQ catalog stays compact — useful, not overwhelming")
    func faqCatalogStaysCompact() {
        #expect(FAQItem.all.count >= 7)
        #expect(FAQItem.all.count <= 10)
        #expect(FAQItem.all.allSatisfy { !$0.question.isEmpty && !$0.answer.isEmpty })
    }

    @Test("Every help link is a valid https or mailto URL")
    func helpLinksAreValid() {
        let urls = [
            HelpLinks.quickStartGuide,
            HelpLinks.focusTips,
            HelpLinks.emailSupport,
            HelpLinks.feedback,
            HelpLinks.xProfile,
            HelpLinks.privacyPolicy,
        ]
        for url in urls {
            #expect(url.scheme == "https" || url.scheme == "mailto")
            if url.scheme == "https" {
                #expect(url.host?.isEmpty == false)
            }
        }
    }

    @Test("Privacy card stays a short honest summary backed by the published policy")
    func privacySummaryStaysShort() {
        #expect(!PrivacyContent.title.isEmpty)
        #expect(!PrivacyContent.intro.isEmpty)
        #expect(PrivacyContent.points.count >= 3)
        #expect(PrivacyContent.points.count <= 5)
        #expect(PrivacyContent.points.allSatisfy { !$0.isEmpty })
        #expect(!PrivacyContent.policyLinkTitle.isEmpty)
        #expect(HelpLinks.privacyPolicy.host?.contains("creapolis.dev") == true)
    }
}
