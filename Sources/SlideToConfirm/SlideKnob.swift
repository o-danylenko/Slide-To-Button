import CoreGraphics

/// Where the knob is, and whether a finger is on it.
///
/// What a visual effect needs to know about the gesture, and nothing more. A position and a size rather
/// than a progress, because an effect draws in the control's coordinate space and `progress` would make
/// every one of them re-derive the same geometry.
///
/// Internal. An earlier version published this outward as a `PreferenceKey` so an effect could be applied
/// from outside the control — which read well but placed the reader outside the publisher, leaving the
/// effect with nothing to draw. The paint layer already holds the state and the geometry, so it computes
/// this and hands it over directly.
/// `Sendable` because `onGeometryChange` computes it in a `@Sendable` closure.
struct SlideKnob: Equatable, Sendable {
    /// The knob's centre, in the control's own coordinates.
    var centre: CGPoint

    /// The knob's diameter, which is also the control's height less its inset on both sides.
    var diameter: CGFloat

    /// Whether a finger is currently on the knob.
    ///
    /// Distinct from movement: a finger held still is still a touch.
    var isDragging: Bool
}
