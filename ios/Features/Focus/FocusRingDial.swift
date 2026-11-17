// FocusRingDial.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure geometry for the touch rotary dial on the focus ring (issue #797):
// turning a finger around the ring adjusts the idle duration like a kitchen
// timer. One full turn is 60 minutes, so every 30° is a 5 minute detent.
// No SwiftUI, no state — the view owns the gesture, this owns the maths.

import CoreGraphics
import Foundation

enum FocusRingDial {
    /// Minutes per detent — the same step as the ±5 steppers.
    static let stepMinutes = 5
    /// Clock-face gain: a full turn of the ring is one hour.
    static let minutesPerTurn = 60

    /// The dial only arms on the ring itself; the interior stays free for
    /// the tap-to-pause target. Fractions of the ring radius.
    private static let bandInnerFraction: CGFloat = 0.70
    private static let bandOuterFraction: CGFloat = 1.10

    /// Angle of `point` around the centre of `size`, in radians, measured
    /// clockwise from 12 o'clock in view coordinates (y grows downward).
    /// Range `-π...π`; the seam sits at 6 o'clock.
    static func angle(at point: CGPoint, in size: CGSize) -> Double {
        let dx = Double(point.x - size.width / 2)
        let dy = Double(point.y - size.height / 2)
        return atan2(dx, -dy)
    }

    /// Signed shortest rotation from one angle to another (clockwise
    /// positive), so crossing the 6 o'clock seam never reads as a full turn
    /// in the opposite direction.
    static func delta(from previous: Double, to current: Double) -> Double {
        var delta = current - previous
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }

    /// Whether `point` sits on the ring band, where a drag arms the dial.
    static func isOnRingBand(_ point: CGPoint, in size: CGSize) -> Bool {
        let radius = min(size.width, size.height) / 2
        guard radius > 0 else { return false }
        let fraction = distanceFromCentre(point, in: size) / radius
        return fraction >= bandInnerFraction && fraction <= bandOuterFraction
    }

    /// Whether `point` falls inside the ring's circle (band included).
    static func isInsideRing(_ point: CGPoint, in size: CGSize) -> Bool {
        let radius = min(size.width, size.height) / 2
        return radius > 0 && distanceFromCentre(point, in: size) <= radius
    }

    /// Duration after turning the ring by `rotation` radians (clockwise
    /// positive) from `base` minutes: snapped to the 5 minute grid and
    /// clamped to `range`.
    static func minutes(base: Int, rotation: Double, range: ClosedRange<Int>) -> Int {
        let radiansPerStep = 2 * Double.pi * Double(stepMinutes) / Double(minutesPerTurn)
        let steps = Int((rotation / radiansPerStep).rounded())
        let snappedBase = Int((Double(base) / Double(stepMinutes)).rounded()) * stepMinutes
        let target = snappedBase + steps * stepMinutes
        return min(range.upperBound, max(range.lowerBound, target))
    }

    private static func distanceFromCentre(_ point: CGPoint, in size: CGSize) -> CGFloat {
        hypot(point.x - size.width / 2, point.y - size.height / 2)
    }
}
