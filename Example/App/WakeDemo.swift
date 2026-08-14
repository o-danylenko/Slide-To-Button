import SlideToConfirm
import SwiftUI

/// One control with ripples, on the moving backdrop. Built to be recorded.
///
/// Nothing but the control: no captions, no comparison, no code labels. A README image has to read at a
/// glance, and anything else in the frame competes with the effect it is there to show.
///
/// The surface is translucent white because ripples are lenses — they bend what is *behind* the capsule.
/// Over an opaque fill they have nothing to refract and collapse to a shimmer at the rim.
struct WakeDemo: View {
    @State private var isConfirmed = false
    @State private var work: Task<Void, Never>?

    var body: some View {
        SlideToConfirm(isConfirmed: $isConfirmed) {
            rearm()
        } label: {
            Text("Slide to send")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        } handleContent: { state in
            if state == .confirmed {
                ProgressView().tint(.black.opacity(0.6))
            } else {
                Image(systemName: "chevron.right")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black.opacity(0.65))
            }
        }
        .slideStyle(Self.style)
        .padding(.horizontal, 24)
        .onDisappear { work?.cancel() }
    }

    /// Holds the confirm briefly, then re-arms, so the screen loops while it is being recorded.
    ///
    /// Called from the action rather than wrapped around the binding: the gesture sets `isConfirmed`
    /// itself, so a binding that only re-arms on its own writes never fires and the knob stays parked at
    /// the trailing edge.
    private func rearm() {
        work?.cancel()
        work = Task {
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }

            withAnimation(.slideSnapBack) { isConfirmed = false }
        }
    }

    /// Taller than the default, because ripples are radial: a 52pt capsule crops their vertical half and
    /// leaves the wake reading as a horizontal smear rather than as rings.
    private static let style = SlideStyle.solid(
        .white,
        surface: Color.white.opacity(0.22),
        inset: 7,
        height: 84
    ).stillEffect
}

#Preview {
    ZStack {
        Backdrop()
        WakeDemo()
    }
}
