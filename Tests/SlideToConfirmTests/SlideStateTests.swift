import CoreGraphics
import Testing
@testable import SlideToConfirm

@Suite("Slide state machine")
struct SlideStateTests {
    @Test("A slide short of the threshold reports its progress")
    func slidingBelowThreshold() {
        #expect(SlideState.idle.applying(progress: 0.5) == .sliding(progress: 0.5))
        #expect(SlideState.sliding(progress: 0.2).applying(progress: 0.4) == .sliding(progress: 0.4))
    }

    @Test("Reaching the threshold confirms")
    func confirmingAtThreshold() {
        #expect(SlideState.idle.applying(progress: SlideState.threshold) == .confirmed)
        #expect(SlideState.idle.applying(progress: 1) == .confirmed)
    }

    @Test("Stopping just short of the threshold does not confirm")
    func notConfirmingBelowThreshold() {
        let justShort = SlideState.threshold - 0.001
        #expect(SlideState.idle.applying(progress: justShort) == .sliding(progress: justShort))
    }

    /// The property the whole design rests on: once confirmed, a live finger cannot un-confirm.
    @Test("Confirmed absorbs any later progress", arguments: [0, 0.5, 0.79, 1] as [CGFloat])
    func confirmedAbsorbs(progress: CGFloat) {
        #expect(SlideState.confirmed.applying(progress: progress) == .confirmed)
    }

    @Test("Progress reads 0 at rest and 1 once confirmed")
    func progressEndpoints() {
        #expect(SlideState.idle.progress == 0)
        #expect(SlideState.confirmed.progress == 1)
        #expect(SlideState.sliding(progress: 0.3).progress == 0.3)
    }

    @Test("Only a live finger counts as sliding")
    func isSliding() {
        #expect(SlideState.sliding(progress: 0.3).isSliding)
        #expect(!SlideState.idle.isSliding)
        #expect(!SlideState.confirmed.isSliding)
    }

    /// Both ends of the gesture look alike; only the middle reads as held.
    @Test("The knob shrinks only while held")
    func handleScale() {
        #expect(SlideState.idle.handleScale == 1)
        #expect(SlideState.confirmed.handleScale == 1)
        #expect(SlideState.sliding(progress: 0.5).handleScale < 1)
    }
}
