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
        ]
        for url in urls {
            #expect(url.scheme == "https" || url.scheme == "mailto")
            if url.scheme == "https" {
                #expect(url.host?.isEmpty == false)
            }
        }
    }
}
