import SwiftUI

/// The progress fill: a capsule behind the handle, widened by however far it has travelled.
///
/// A `Shape` rather than a reframed view, so `progress` can be `animatableData`. SwiftUI
/// then writes an interpolated progress back on every animation frame and re-runs
/// `path(in:)` — without rebuilding any view body, since a shape has none. That makes the
/// fill's extent and the handle's travel two readings of one interpolated value, so they
/// cannot settle on different curves.
struct SlideFill: Shape {
    /// How far along the track the fill reaches, `0...1`.
    var progress: CGFloat

    /// The handle's diameter, which the fill wraps at rest.
    var handleDiameter: CGFloat

    /// The breathing room between the handle and the track's edge.
    var inset: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// The share of travel over which the fill emerges from behind the handle.
    private static let emergence: CGFloat = 0.05

    func path(in rect: CGRect) -> Path {
        // At rest the fill is exactly the handle: same width, same position, so it is hidden
        // beneath it with nothing to fade or scale. Emerging widens it to one inset past the
        // handle on either side, which is the only thing that ever makes it visible.
        let emerged = min(1, progress / Self.emergence)

        // Both axes grow together, from the handle's square to the track's bounds. Growing
        // only the width would leave a full-height capsule standing behind a shorter handle
        // at rest — visible above and below it, which is the whole thing being avoided.
        let padding = inset * (1 - emerged)

        // Derived from the handle rather than the track, so the fill ends exactly one inset
        // past the handle at every progress — and, because the travel range is itself the
        // track minus the handle and both insets, closes on the track's full width at the end
        // without that being a separate case.
        let maxTravel = max(0, rect.width - handleDiameter - inset * 2)
        let width = handleDiameter + inset * 2 * emerged + maxTravel * progress

        return Capsule().path(
            in: CGRect(
                x: padding,
                y: padding,
                width: width,
                height: rect.height - padding * 2
            )
        )
    }
}
