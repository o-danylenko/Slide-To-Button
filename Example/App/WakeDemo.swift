import SlideToConfirm
import SwiftUI

/// The three wake presets, on real controls.
///
/// Uses the public API only — `.slideWake(_:)` on an ordinary `SlideToConfirm` — because that is the
/// thing worth demonstrating. The effect needs nothing from the caller but the modifier.
///
/// Solid surfaces throughout, because the wake cannot bend glass: a distortion rasterises its content,
/// and Liquid Glass has nothing left to sample once it has been flattened. The last row shows the
/// difference the effect makes by leaving it off.
struct WakeDemo: View {
    private struct Variant: Identifiable {
        let id: Int
        let code: String
        let title: String
        let wake: SlideWake
        let tint: Color
    }

    @State private var confirmed: Set<Int> = []

    private let variants: [Variant] = [
        Variant(id: 0, code: ".slideWake(.still)", title: "Slide to send",
                wake: .still, tint: .blue),
        Variant(id: 1, code: ".slideWake(.water)", title: "Slide to unlock",
                wake: .water, tint: .teal),
        Variant(id: 2, code: ".slideWake(.splash)", title: "Slide to launch",
                wake: .splash, tint: .indigo),
        Variant(id: 3, code: "no wake", title: "Slide to archive",
                wake: .none, tint: .orange)
    ]

    var body: some View {
        VStack(spacing: 20) {
            ForEach(variants) { variant in
                VStack(alignment: .leading, spacing: 6) {
                    Text(variant.code)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 2)

                    SlideToConfirm(isConfirmed: binding(for: variant.id)) {} label: {
                        Text(variant.title).font(.headline)
                    }
                    .slideStyle(.solid(variant.tint, surface: variant.tint.opacity(0.18)))
                    .slideWake(variant.wake)
                }
            }

            Text("Drag slowly for a faint trail, flick for a strong one.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
    }

    /// Confirming re-arms after a beat, so the screen loops without being touched again.
    private func binding(for id: Int) -> Binding<Bool> {
        Binding(
            get: { confirmed.contains(id) },
            set: { isConfirmed in
                guard isConfirmed else {
                    confirmed.remove(id)
                    return
                }
                confirmed.insert(id)
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    withAnimation(.slideSnapBack) { _ = confirmed.remove(id) }
                }
            }
        )
    }
}

#Preview {
    ZStack {
        Backdrop()
        WakeDemo()
    }
}
