import SwiftUI

/// Draws a slide-to-confirm track for a given state.
///
/// Paint only. No `@State`, no `@GestureState`, and no gesture — so no change made here can
/// regress the drag. That guarantee comes from the shape of the type, not from discipline.
///
/// Three layers, outermost last: the capsule carries the material, the trail grows across it,
/// and the knob rides on top. The material goes on the capsule because it is the largest surface
/// — a knob-sized pane has too little area for refraction to read, and would need a tint so
/// strong it hid the effect anyway.
struct SlideTrack<Label: View, HandleContent: View>: View {
    let label: Label
    let state: SlideState
    let style: SlideStyle
    let inset: CGFloat

    /// The capsule's height, already scaled for Dynamic Type, or `nil` to use the label's.
    let height: CGFloat?

    /// What to draw inside the knob for a given state.
    ///
    /// Only the contents: the circle and its size stay here, because the trail's geometry assumes
    /// a knob of exactly `handleDiameter` and a caller returning something else would pull the
    /// two apart.
    @ViewBuilder let handleContent: (SlideState) -> HandleContent

    var body: some View {
        labelRow
            .opacity(state == .confirmed ? 0 : 1)
            // Reads backwards: each `background` sits behind the one before it, so the trail goes
            // on first to land just under the label, and the material after it to land under
            // both. Reversed, the material would paint over the trail.
            .background(alignment: .leading) { measured { trail(in: $0) } }
            .clipShape(.capsule)
            .background { surface }
            .overlay(alignment: .topLeading) { measured { knob(in: $0) } }
    }

    // MARK: - Label

    /// The label flanked by two hidden knob footprints.
    ///
    /// Those footprints are what make the control self-sizing: they establish the capsule's
    /// height — a square scaled to the label's own height, plus the inset — and the lane the
    /// centred label must keep clear, from one rule rather than two constants that could drift
    /// apart.
    private var labelRow: some View {
        HStack(spacing: 0) {
            handleFootprint
            label.frame(maxWidth: .infinity)
            handleFootprint
        }
        // Applied to the row rather than the capsule, so the footprints see the final height and
        // keep deriving the knob's diameter from it. On the capsule instead, the track would
        // resize while the knob stayed the label's size.
        .frame(height: height.map { max(0, $0 - inset * 2) })
        .padding(inset)
    }

    /// A square as tall as the row, so its width equals the knob's diameter without ever naming a
    /// size.
    private var handleFootprint: some View {
        Color.clear.aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Layers

    /// The capsule the knob travels along, and the one thing here made of glass.
    ///
    /// The single availability branch in the control: nothing else has to know which era it is
    /// running in.
    @ViewBuilder
    private var surface: some View {
        switch style.surface {
        case .glass(let tint, let fallback):
            if #available(iOS 26, macOS 26, *) {
                Color.clear.glassEffect(.regular.tint(tint), in: Capsule())
            } else {
                Capsule().fill(fallback)
            }

        case .clearGlass(let fallback):
            if #available(iOS 26, macOS 26, *) {
                Color.clear.glassEffect(.clear, in: Capsule())
            } else {
                Capsule().fill(fallback)
            }

        case .filled(let style):
            Capsule().fill(style)
        }
    }

    /// The trail behind the knob: one shape, stretched by progress.
    ///
    /// At rest its rect equals the knob's exactly, so it is hidden beneath it with nothing to
    /// fade or scale — emerging and travelling are the same value, which is why neither can lag
    /// the other.
    private func trail(in geometry: SlideGeometry) -> some View {
        SlideFill(
            progress: state.progress,
            handleDiameter: geometry.handleDiameter,
            inset: inset
        )
        .fill(style.tint.opacity(0.3))
        // Progress is a property of the shape itself, so it sits inside any animation scope
        // applied further out — unlike an `offset`, which can be placed beyond one. Clearing the
        // transaction is what keeps the finger and the trail in the same frame: a spring would
        // otherwise interpolate the path and a quick flick would outrun it. Only while a finger
        // is down; released and confirmed, it wants the ambient spring, which is what keeps the
        // trail and the knob locked together on auto-confirm.
        .transaction { transaction in
            if state.isSliding { transaction.animation = nil }
        }
    }

    /// The knob, solid so it stays legible over whatever the surface is refracting.
    private func knob(in geometry: SlideGeometry) -> some View {
        Circle()
            .fill(style.tint)
            .frame(width: geometry.handleDiameter, height: geometry.handleDiameter)
            .overlay { handleContent(state) }
            .scaleEffect(state.handleScale)
            .animation(.slideAppearance, value: state.handleScale)
            // Outside the animation scope above, so travel tracks the finger one-to-one during a
            // drag and rides the ambient spring on confirm.
            .offset(geometry.handleOffset(at: state.progress))
    }

    // MARK: - Measurement

    /// Builds content from the track's size.
    ///
    /// A `GeometryReader` here is layout-neutral: placed in a `background` or `overlay` it is
    /// proposed the size layout already decided for the label row, so it neither expands greedily
    /// nor re-runs layout for real content.
    private func measured<Content: View>(
        @ViewBuilder content: @escaping (SlideGeometry) -> Content
    ) -> some View {
        GeometryReader { proxy in
            content(SlideGeometry(trackSize: proxy.size, inset: inset))
        }
    }
}

// MARK: - Default handle

/// The mark inside the knob when a caller does not supply one.
public struct SlideChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
    }
}

// MARK: - Animations

extension Animation {
    /// Returns the knob to rest when a slide is abandoned or cancelled.
    public static let slideSnapBack = Animation.spring(response: 0.25, dampingFraction: 0.8)

    /// Carries the knob the rest of the way once the threshold is crossed.
    public static let slideConfirm = Animation.spring(response: 0.3, dampingFraction: 0.6)

    /// Scales the knob as a slide begins and ends.
    public static let slideAppearance = Animation.spring(response: 0.28, dampingFraction: 0.7)
}
