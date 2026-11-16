// FocusRingDialTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure geometry behind the touch rotary dial on the Mac focus ring (#797):
// angle of a touch around the ring centre, wrap-safe angular deltas, and the
// accumulated-rotation → minutes mapping (one turn = 60 min, 5 min detents).

import Testing
import Foundation
import CoreGraphics
@testable import Pepinillo

@Suite("FocusRingDial — geometry and minutes mapping")
struct FocusRingDialTests {
    private let size = CGSize(width: 200, height: 200)

    // MARK: Angle (clockwise from 12 o'clock, y grows downward)

    @Test func angleIsZeroAtTwelveOClock() {
        let angle = FocusRingDial.angle(at: CGPoint(x: 100, y: 0), in: size)
        #expect(abs(angle) < 1e-9)
    }

    @Test func angleGrowsClockwise() {
        let three = FocusRingDial.angle(at: CGPoint(x: 200, y: 100), in: size)
        let six = FocusRingDial.angle(at: CGPoint(x: 100, y: 200), in: size)
        let nine = FocusRingDial.angle(at: CGPoint(x: 0, y: 100), in: size)
        #expect(abs(three - .pi / 2) < 1e-9)
        #expect(abs(abs(six) - .pi) < 1e-9)
        #expect(abs(nine + .pi / 2) < 1e-9)
    }

    // MARK: Wrap-safe delta

    @Test func deltaTakesTheShortWayAcrossTheSeam() {
        // 170° → -170° is +20° clockwise, not -340°.
        let delta = FocusRingDial.delta(from: 170 * .pi / 180, to: -170 * .pi / 180)
        #expect(abs(delta - 20 * .pi / 180) < 1e-9)

        let back = FocusRingDial.delta(from: -170 * .pi / 180, to: 170 * .pi / 180)
        #expect(abs(back + 20 * .pi / 180) < 1e-9)
    }

    // MARK: Ring band hit test

    @Test func bandAcceptsTheRingAndRejectsTheInterior() {
        #expect(FocusRingDial.isOnRingBand(CGPoint(x: 100, y: 4), in: size))
        #expect(FocusRingDial.isOnRingBand(CGPoint(x: 196, y: 100), in: size))
        #expect(!FocusRingDial.isOnRingBand(CGPoint(x: 100, y: 100), in: size))
        #expect(!FocusRingDial.isOnRingBand(CGPoint(x: 100, y: 60), in: size))
    }

    @Test func interiorIsTheComplementInsideTheRing() {
        #expect(FocusRingDial.isInsideRing(CGPoint(x: 100, y: 100), in: size))
        #expect(FocusRingDial.isInsideRing(CGPoint(x: 100, y: 4), in: size))
        // Corner of the bounding square is outside the circle.
        #expect(!FocusRingDial.isInsideRing(CGPoint(x: 2, y: 2), in: size))
    }

    // MARK: Minutes

    @Test func fullClockwiseTurnAddsSixtyMinutes() {
        let minutes = FocusRingDial.minutes(base: 60, rotation: 2 * .pi, range: 5...480)
        #expect(minutes == 120)
    }

    @Test func eachThirtyDegreesIsAFiveMinuteDetent() {
        #expect(FocusRingDial.minutes(base: 60, rotation: 30 * .pi / 180, range: 5...480) == 65)
        #expect(FocusRingDial.minutes(base: 60, rotation: -30 * .pi / 180, range: 5...480) == 55)
        // Under half a detent does not move the value.
        #expect(FocusRingDial.minutes(base: 60, rotation: 10 * .pi / 180, range: 5...480) == 60)
    }

    @Test func resultIsAlwaysAMultipleOfFiveEvenFromAnOffGridBase() {
        // Settings allows 1 min granularity; the dial snaps to the 5 min grid.
        #expect(FocusRingDial.minutes(base: 47, rotation: 0, range: 5...480) == 45)
        #expect(FocusRingDial.minutes(base: 47, rotation: 30 * .pi / 180, range: 5...480) == 50)
    }

    @Test func clampsToTimeBlockRange() {
        #expect(FocusRingDial.minutes(base: 470, rotation: 2 * .pi, range: 5...480) == 480)
        #expect(FocusRingDial.minutes(base: 10, rotation: -2 * .pi, range: 5...480) == 5)
    }

    @Test func clampsToPomodoroRange() {
        #expect(FocusRingDial.minutes(base: 100, rotation: 2 * .pi, range: 5...120) == 120)
        #expect(FocusRingDial.minutes(base: 25, rotation: -4 * .pi, range: 5...120) == 5)
    }
}
