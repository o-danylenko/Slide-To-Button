import SwiftUI

/// Where the knob is, and whether a finger is on it.
///
/// The whole of what ``SlideToConfirm`` publishes about its gesture, and the seam every visual effect
/// attaches to. It is deliberately a position and a size rather than a progress: an effect draws in
/// the control's coordinate space, and `progress` would make each one re-derive the same geometry.
///
/// Reported through a preference rather than the environment, because it travels the other way —
/// outward from the control to whatever wraps it. That direction is what keeps the control ignorant of
/// its decorations: it states a fact, and does not know or care who reads it.
public struct SlideKnob: Equatable, Sendable {
    /// The knob's centre, in the control's own coordinates.
    public var centre: CGPoint

    /// The knob's diameter, which is also the control's height less its inset on both sides.
    public var diameter: CGFloat

    /// Whether a finger is currently on the knob.
    ///
    /// Distinct from movement: a finger held still is still a touch, and an effect may want to respond
    /// to the press rather than to the travel.
    public var isDragging: Bool

    /// A knob that has not been measured yet.
    ///
    /// The default a preference reduces to when nothing publishes one, so an effect applied to
    /// something that is not a slide control simply draws nothing.
    public static let unmeasured = SlideKnob(centre: .zero, diameter: 0, isDragging: false)

    /// Whether this reading came from a laid-out control.
    public var isMeasured: Bool { diameter > 0 }
}

/// Carries the knob's position out of the control to any effect wrapping it.
///
/// Last writer wins, since exactly one control publishes per subtree. Nested controls would each
/// report to their own enclosing effect, which is the behaviour a caller would expect.
struct SlideKnobKey: PreferenceKey {
    static let defaultValue = SlideKnob.unmeasured

    static func reduce(value: inout SlideKnob, nextValue: () -> SlideKnob) {
        let next = nextValue()
        guard next.isMeasured else { return }
        value = next
    }
}
