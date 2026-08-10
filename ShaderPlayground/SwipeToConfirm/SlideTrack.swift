import SwiftUI

/// Draws a slide-to-confirm track for a given state.
///
/// Paint only. No `@State`, no `@GestureState`, and no gesture — so no change made here can
/// regress the drag. That guarantee comes from the shape of the type, not from discipline.
///
/// Everything that moves is a render transform — an `offset`, never a `frame` — so a drag
/// tick redraws without triggering a layout pass and the handle stays glued to the finger.
struct SlideTrack<Label: View>: View {
    let label: Label
    let state: SlideState
    let inset: CGFloat

    var body: some View {
        labelRow
            .opacity(state == .confirmed ? 0 : 1)
            .background(.quaternary)
            // The fill sits behind the label; the handle must sit in front of it, or the
            // label paints over the handle. Leading-aligned, since the fill grows from
            // there rather than filling the frame it is given.
            .background(alignment: .leading) { measured { progressFill(in: $0) } }
            .clipShape(.capsule)
            .overlay(alignment: .topLeading) { measured { handle(in: $0) } }
    }

    // MARK: - Label

    /// The label flanked by two hidden handle footprints.
    ///
    /// Those footprints are what make the control self-sizing: they establish the track's
    /// height — a square scaled to the label's own height, plus the inset — and the lane
    /// the centred label must keep clear, from one rule rather than two constants that
    /// could drift apart.
    private var labelRow: some View {
        HStack(spacing: 0) {
            handleFootprint
            label.frame(maxWidth: .infinity)
            handleFootprint
        }
        .padding(inset)
    }

    /// A square as tall as the row, so its width equals the handle's diameter without ever
    /// naming a size.
    private var handleFootprint: some View {
        Color.clear.aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Moving parts

    /// The fill, which grows out from behind the handle and then tracks it.
    ///
    /// Its width is a shape parameter, so the ambient transaction reaches it: on confirm the
    /// same `slideConfirm` spring that carries the handle interpolates the fill's progress,
    /// and the two stay locked. Only the appearance — the scale and fade of step 1 — carries
    /// a local animation, and it is keyed on whether a slide is under way rather than on
    /// progress, so nothing interpolates between finger and fill mid-drag.
    private func progressFill(in geometry: SlideGeometry) -> some View {
        SlideFill(
            progress: state.progress,
            handleDiameter: geometry.handleDiameter,
            inset: inset
        )
        .fill(Color.accentColor.opacity(0.24))
        // Progress is a property of the shape itself, so it sits inside any animation scope
        // applied further out — unlike the handle, whose travel is an `offset` applied beyond
        // its own. Clearing the transaction here is what keeps the finger and the fill in the
        // same frame: a spring would otherwise interpolate the path, and a quick flick would
        // outrun it. Only while a finger is down; released and confirmed, the fill wants the
        // ambient spring, which is also what keeps it locked to the handle on auto-confirm.
        .transaction { transaction in
            if state.isSliding { transaction.animation = nil }
        }
    }

    private func handle(in geometry: SlideGeometry) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: geometry.handleDiameter, height: geometry.handleDiameter)
            .overlay { chevron }
            .scaleEffect(state.handleScale)
            .animation(.slideAppearance, value: state.handleScale)
            // Outside the animation scope above, so travel tracks the finger one-to-one
            // during a drag and rides the ambient spring on confirm.
            .offset(geometry.handleOffset(at: state.progress))
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
    }

    // MARK: - Measurement

    /// Builds content from the track's size.
    ///
    /// A `GeometryReader` here is layout-neutral: placed in a `background` or `overlay` it
    /// is proposed the size layout already decided for the label row, so it neither expands
    /// greedily nor re-runs layout for real content.
    private func measured<Content: View>(
        @ViewBuilder content: @escaping (SlideGeometry) -> Content
    ) -> some View {
        GeometryReader { proxy in
            content(SlideGeometry(trackSize: proxy.size, inset: inset))
        }
    }
}

// MARK: - Animations

extension Animation {
    /// Returns the handle to rest when a slide is abandoned or cancelled.
    static let slideSnapBack = Animation.spring(response: 0.25, dampingFraction: 0.8)

    /// Carries the handle the rest of the way once the threshold is crossed.
    static let slideConfirm = Animation.spring(response: 0.3, dampingFraction: 0.6)

    /// Scales the handle and the fill in and out as a slide begins and ends.
    static let slideAppearance = Animation.spring(response: 0.28, dampingFraction: 0.7)
}
