// QuickOpenKeyDecisionTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Issue #1021: pins the keyboard decision of the Mac Quick Open picker
// (⌘K) so ⌘↩ with zero matches can never fall through to the Start/Pause
// menu item again, and keypad Enter behaves like Return.

import Testing
import Foundation
@testable import Pepinillo

@Suite("QuickOpenKeyDecision")
struct QuickOpenKeyDecisionTests {

    private let returnKey = 36        // kVK_Return
    private let keypadEnter = 76      // kVK_ANSI_KeypadEnter
    private let deleteKey = 51        // kVK_Delete

    // MARK: ⌘ + Return / keypad Enter with matches

    @Test func commandReturnWithMatchesLinksAndStarts() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: returnKey, hasCommand: true, hasMatches: true)
                == .linkAndStart
        )
    }

    @Test func commandKeypadEnterWithMatchesLinksAndStarts() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: keypadEnter, hasCommand: true, hasMatches: true)
                == .linkAndStart
        )
    }

    // MARK: Issue #1021 S1 — our keys with zero matches consume the event

    @Test func commandReturnWithoutMatchesNeverFallsThroughToStartPause() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: returnKey, hasCommand: true, hasMatches: false)
                == .consume
        )
    }

    @Test func commandKeypadEnterWithoutMatchesNeverFallsThroughToStartPause() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: keypadEnter, hasCommand: true, hasMatches: false)
                == .consume
        )
    }

    // MARK: Plain Return (no command) — the TextField path

    @Test func plainReturnWithMatchesLinks() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: returnKey, hasCommand: false, hasMatches: true)
                == .link
        )
    }

    @Test func plainKeypadEnterWithMatchesLinks() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: keypadEnter, hasCommand: false, hasMatches: true)
                == .link
        )
    }

    @Test func plainReturnWithoutMatchesDoesNothing() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: returnKey, hasCommand: false, hasMatches: false)
                == .consume
        )
    }

    // MARK: Keys the picker does not own

    @Test func otherKeysPassThrough() {
        #expect(
            QuickOpenKeyDecision.decide(keyCode: deleteKey, hasCommand: true, hasMatches: true)
                == .passThrough
        )
        #expect(
            QuickOpenKeyDecision.decide(keyCode: 13, hasCommand: false, hasMatches: true)
                == .passThrough
        )
    }
}
