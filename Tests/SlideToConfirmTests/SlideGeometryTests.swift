import CoreGraphics
import Testing
@testable import SlideToConfirm

@Suite("Slide geometry")
struct SlideGeometryTests {
    private let track = SlideGeometry(trackSize: CGSize(width: 336, height: 56), inset: 4)

    @Test("The knob fills the height, less its inset on both sides")
    func handleDiameter() {
        #expect(track.handleDiameter == 48)
    }

    @Test("Travel is what the knob does not already occupy")
    func maxTravel() {
        #expect(track.maxTravel == 280)
    }

    /// A track too small for its knob must not produce a negative range — every value derived
    /// from it would then be nonsense.
    @Test(
        "A track narrower than its knob has no travel rather than negative travel",
        arguments: [CGSize.zero, CGSize(width: 20, height: 56), CGSize(width: 50, height: 56)]
    )
    func tracksTooNarrow(size: CGSize) {
        let geometry = SlideGeometry(trackSize: size, inset: 4)
        #expect(geometry.maxTravel == 0)
        // The division guard: no travel means no progress, not a crash.
        #expect(geometry.progress(forTranslation: 100) == 0)
    }

    /// Any size at all, however degenerate, must keep the derived values sane: a negative diameter
    /// or range would propagate into offsets and paths.
    @Test(
        "No size produces a negative measurement",
        arguments: [
            CGSize.zero,
            CGSize(width: 336, height: 0),
            CGSize(width: 0, height: 56),
            CGSize(width: 4, height: 4)
        ]
    )
    func noNegativeMeasurements(size: CGSize) {
        let geometry = SlideGeometry(trackSize: size, inset: 4)
        #expect(geometry.handleDiameter >= 0)
        #expect(geometry.maxTravel >= 0)
        #expect(geometry.progress(forTranslation: 100) >= 0)
        #expect(geometry.progress(forTranslation: 100) <= 1)
    }

    @Test("Translation clamps to the travel range")
    func progressClamping() {
        #expect(track.progress(forTranslation: -50) == 0)
        #expect(track.progress(forTranslation: 0) == 0)
        #expect(track.progress(forTranslation: 140) == 0.5)
        #expect(track.progress(forTranslation: 280) == 1)
        #expect(track.progress(forTranslation: 9999) == 1)
    }

    @Test("The knob rests at its inset and ends one inset from the far edge")
    func handleOffset() {
        #expect(track.handleOffset(at: 0) == CGSize(width: 4, height: 4))
        #expect(track.handleOffset(at: 1) == CGSize(width: 284, height: 4))
    }
}

@Suite("Slide fill")
struct SlideFillTests {
    private let rect = CGRect(x: 0, y: 0, width: 336, height: 56)
    private let inset: CGFloat = 4
    private let handleDiameter: CGFloat = 48

    private func fill(at progress: CGFloat) -> CGRect {
        SlideFill(progress: progress, handleDiameter: handleDiameter, inset: inset)
            .path(in: rect)
            .boundingRect
    }

    /// What hides the trail at rest: it is exactly the knob, so there is nothing to fade or scale.
    @Test("At rest the trail is exactly the knob")
    func hiddenAtRest() {
        #expect(fill(at: 0) == CGRect(x: 4, y: 4, width: 48, height: 48))
    }

    /// And what makes a full slide look filled rather than nearly filled.
    @Test("At full travel the trail covers the track exactly")
    func fullAtEnd() {
        #expect(fill(at: 1) == rect)
    }

    @Test("The trail grows on both axes as it emerges")
    func emergesOnBothAxes() {
        let emerging = fill(at: 0.025)
        #expect(emerging.minY > 0)
        #expect(emerging.height < rect.height)
        #expect(emerging.height > handleDiameter)
    }

    @Test("Past the emergence window the trail spans the full height")
    func fullHeightAfterEmerging() {
        #expect(fill(at: 0.5).height == rect.height)
        #expect(fill(at: 0.5).minY == 0)
    }
}
