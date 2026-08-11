import CoreFoundation

/// The input state of one slide-to-confirm gesture.
///
/// Reasons in progress rather than points, so the machine is resolution-independent and
/// says nothing about layout: `SlideGeometry` converts, this decides.
///
/// There is deliberately no `released` case. Release-to-idle is implemented by
/// `@GestureState`'s automatic reset, which also covers the cancellation `onEnded` never
/// reports — so a case here would never be reached.
enum SlideState: Equatable {
    /// Nothing is touching the handle.
    case idle
    /// A finger is dragging the handle, `0...1` along the track.
    case sliding(progress: CGFloat)
    /// The threshold has been crossed. Terminal.
    case confirmed

    /// The fraction of the track, `0...1`, past which the swipe confirms.
    static let threshold: CGFloat = 0.8

    /// The only place a drag event acquires meaning.
    ///
    /// Total, and `confirmed` absorbs — so the precedence of a latched confirm over a live
    /// finger is stated once, here, rather than re-derived at each read.
    func applying(progress: CGFloat) -> SlideState {
        switch self {
        case .confirmed:
            .confirmed
        case .idle, .sliding:
            progress >= Self.threshold ? .confirmed : .sliding(progress: progress)
        }
    }

    /// How far along the track the handle should be drawn.
    var progress: CGFloat {
        switch self {
        case .idle: 0
        case .sliding(let progress): progress
        case .confirmed: 1
        }
    }

    /// Whether a finger is currently on the handle.
    var isSliding: Bool {
        if case .sliding = self { return true }
        return false
    }

    /// The handle's scale: it shrinks under the finger and returns to full size once the
    /// slide is committed, so the two ends of the gesture look alike and only the middle
    /// reads as held.
    var handleScale: CGFloat {
        switch self {
        case .idle: 1
        case .sliding: 0.92
        case .confirmed: 1
        }
    }
}
