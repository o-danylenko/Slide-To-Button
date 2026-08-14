import SwiftUI

/// A one-shot slide-to-confirm control: drag the handle past the threshold to fire
/// `action`.
///
/// ```swift
/// @State private var isSending = false
///
/// SlideToConfirm(isConfirmed: $isSending) { send() } label: {
///     Text("Slide to Confirm").font(.headline)
/// }
/// ```
///
/// The caller owns the latch, so a confirm can also arrive from outside the gesture — a
/// server event, a push — and re-arming is the caller's call:
///
/// ```swift
/// withAnimation(.slideSnapBack) { isSending = false }
/// ```
///
/// The track sizes itself to its label, so Dynamic Type and multi-line copy grow it rather
/// than being clipped by it. `.disabled(_:)` dims it and drops the gesture.
///
/// The only type that owns the gesture. It wires interaction to state and hands a read-only
/// state to `SlideTrack` for drawing — so the drag is written, and tested, once.
public struct SlideToConfirm<Label: View, HandleContent: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.slideStyle) private var style

    /// Scales the style's inset for Dynamic Type, so density holds at larger text sizes.
    @ScaledMetric(relativeTo: .headline) private var insetScale: CGFloat = 1

    private var inset: CGFloat { style.inset * insetScale }

    /// The capsule's height, scaled alongside the inset so a fixed height still grows with text.
    private var height: CGFloat? { style.height.map { $0 * insetScale } }

    /// Whether the slide has been confirmed and the handle parked at the trailing edge.
    ///
    /// Owned by the caller, because the gesture is not the only thing that can confirm —
    /// a server event or a push can latch it too, and only the caller knows when the work
    /// behind it has finished. Set it back to `false` to re-arm; wrap that in
    /// `withAnimation(.slideSnapBack)` to spring the handle home.
    @Binding var isConfirmed: Bool

    public let action: () -> Void
    @ViewBuilder let label: Label

    /// What to draw inside the handle for a given state — a spinner once confirmed, a
    /// checkmark, whatever the state calls for.
    ///
    /// Receives the whole ``SlideState``, so `progress` is available too: a caller can turn
    /// the mark as the finger moves, not just swap it at the ends.
    @ViewBuilder public let handleContent: (SlideState) -> HandleContent

    /// Creates a control whose knob draws `handleContent` for the current state.
    ///
    /// - Parameters:
    ///   - isConfirmed: The confirm latch. Set it `false` to re-arm.
    ///   - action: Fired once the knob passes the threshold.
    ///   - label: The copy inside the capsule. Its height sizes the control.
    ///   - handleContent: The mark inside the knob, for a given state.
    public init(
        isConfirmed: Binding<Bool>,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label,
        @ViewBuilder handleContent: @escaping (SlideState) -> HandleContent
    ) {
        self._isConfirmed = isConfirmed
        self.action = action
        self.label = label()
        self.handleContent = handleContent
    }

    /// The finger's progress along the track, or `nil` when nothing is touching.
    ///
    /// SwiftUI resets this on cancellation as well as on lift — unlike `onEnded`, which
    /// never fires when the system claims the gesture — and `resetTransaction` gives the
    /// snap-back its spring. That keeps animation off the drag path: nothing interpolates
    /// while the finger is down.
    @GestureState(resetTransaction: Transaction(animation: .slideSnapBack))
    private var slideProgress: CGFloat?

    /// The gesture's progress and the caller's latch resolved into one value.
    ///
    /// Both inputs are load-bearing — `slideProgress` resets itself on cancellation, while
    /// the latch outlives the gesture — but only their combination is meaningful, so the
    /// precedence is settled here and every reader downstream sees a single state.
    private var state: SlideState {
        if isConfirmed { return .confirmed }
        if let slideProgress { return .sliding(progress: slideProgress) }
        return .idle
    }

    public var body: some View {
        SlideTrack(
            label: label,
            state: state,
            style: style,
            inset: inset,
            height: height,
            handleContent: handleContent
        )
            .opacity(isEnabled ? 1 : 0.5)
            .overlay(alignment: .topLeading) { hitRegion }
            .accessibilityRepresentation {
                // VoiceOver cannot drag a handle, so it gets a plain button.
                Button(action: action) { label }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: state.isSliding) { _, sliding in
                sliding
            }
            .sensoryFeedback(.success, trigger: isConfirmed) { _, confirmed in confirmed }
    }

    /// An invisible circle over the handle, carrying the gesture.
    ///
    /// Positioned by the same `handleOffset` the track draws with, so the touch target and
    /// the visible handle cannot drift apart — and the paint layer stays free of the
    /// gesture.
    private var hitRegion: some View {
        GeometryReader { proxy in
            let geometry = SlideGeometry(trackSize: proxy.size, inset: inset)
            Color.clear
                .frame(width: geometry.handleDiameter, height: geometry.handleDiameter)
                .contentShape(.circle)
                .offset(geometry.handleOffset(at: state.progress))
                // High priority keeps an enclosing scroll view or sheet from claiming the
                // touch first.
                .highPriorityGesture(drag(in: geometry), including: isEnabled ? .all : .none)
                // Published from here because this view already knows both the geometry and the
                // gesture, and it is the only place that does. Anything wrapping the control can read
                // it; the control does not know whether anything does.
                .preference(key: SlideKnobKey.self, value: knob(in: geometry))
        }
    }

    /// The knob's position and press state, for effects layered outside the control.
    private func knob(in geometry: SlideGeometry) -> SlideKnob {
        let offset = geometry.handleOffset(at: state.progress)
        let radius = geometry.handleDiameter / 2

        return SlideKnob(
            centre: CGPoint(x: offset.width + radius, y: offset.height + radius),
            diameter: geometry.handleDiameter,
            isDragging: state.isSliding
        )
    }

    // MARK: - Gesture

    private func drag(in geometry: SlideGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($slideProgress) { value, slideProgress, _ in
                slideProgress = geometry.progress(forTranslation: value.translation.width)
            }
            .onChanged { value in
                // Asked of the gesture value rather than of a derived flag, so a crossing
                // is caught in the event that produced it instead of a render pass later.
                let progress = geometry.progress(forTranslation: value.translation.width)
                guard !isConfirmed, state.applying(progress: progress) == .confirmed else {
                    return
                }
                confirm()
            }
    }

    private func confirm() {
        guard !reduceMotion else {
            isConfirmed = true
            action()
            return
        }
        withAnimation(.slideConfirm) {
            isConfirmed = true
        } completion: {
            action()
        }
    }
}

// MARK: - Default handle

extension SlideToConfirm where HandleContent == SlideChevron {
    /// A slide-to-confirm control with the default chevron handle.
    public init(
        isConfirmed: Binding<Bool>,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            isConfirmed: isConfirmed,
            action: action,
            label: label
        ) { _ in
            SlideChevron()
        }
    }
}

// There is deliberately no `PrimitiveButtonStyle` adapter. A style has no storage of its
// own, and a `Button` offers no channel for a confirm that arrives from outside the
// gesture — so such an adapter could only latch, never re-arm. Use `SlideToConfirm`
// directly and hold the latch where the work is.
