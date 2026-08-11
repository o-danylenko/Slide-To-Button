import CoreGraphics

/// Converts between the track's measured size and a slide's `0...1` progress.
///
/// Pure arithmetic, built fresh from a measured size, so it holds no state and cannot fall
/// out of step with the layout that produced it.
///
/// Sizes are derived, never declared: the track's height originates from its label, the
/// handle is a circle inset into that height, and the travel range follows from both.
/// Nothing here assumes a point value.
struct SlideGeometry: Equatable {
    /// The track's measured size. Its height comes from the label's intrinsic height, so it
    /// already reflects Dynamic Type and multi-line copy.
    let trackSize: CGSize

    /// The breathing room between the handle and the track's edge.
    let inset: CGFloat

    /// The handle fills the track's height, minus its inset on both sides.
    var handleDiameter: CGFloat {
        max(0, trackSize.height - inset * 2)
    }

    /// How far the handle can travel before reaching the trailing edge.
    ///
    /// Clamped at zero, so a track narrower than its handle — or one not yet measured —
    /// cannot produce a negative range.
    var maxTravel: CGFloat {
        max(0, trackSize.width - handleDiameter - inset * 2)
    }

    /// A finger's horizontal translation as progress. Zero when there is no room to
    /// travel, so this never divides by zero.
    func progress(forTranslation translation: CGFloat) -> CGFloat {
        guard maxTravel > 0 else { return 0 }
        return min(max(0, translation), maxTravel) / maxTravel
    }

    func travel(at progress: CGFloat) -> CGFloat {
        maxTravel * progress
    }

    /// Where the handle sits, relative to the track's top-leading corner.
    ///
    /// One definition, consumed by both the paint layer and the gesture's hit region, so
    /// the two cannot drift apart.
    func handleOffset(at progress: CGFloat) -> CGSize {
        CGSize(width: inset + travel(at: progress), height: inset)
    }

}
