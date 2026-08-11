import SlideToConfirm
import SwiftUI

/// The four materials on one screen, each labelled with the call that produces it.
///
/// Stacked so glass and flat are a direct comparison rather than a claim, and ordered by how much of
/// the backdrop each lets through: clear, untinted, half-tinted, none. Dragging any one of them
/// shows the same gesture reading differently through each material.
struct MaterialsDemo: View {
    private struct Variant: Identifiable {
        let id: Int
        let code: String
        let title: String
        let icon: String
        let style: SlideStyle
        let prefersLightLabel: Bool
    }

    @State private var confirmed: Set<Int> = []

    private var variants: [Variant] {
        [
            Variant(
                id: 0,
                code: ".clear(.white)",
                title: "Slide to unlock",
                icon: "lock.open.fill",
                style: .clear(.white),
                prefersLightLabel: true
            ),
            Variant(
                id: 1,
                code: ".tinted(.blue)",
                title: "Slide to confirm",
                icon: "checkmark",
                style: .tinted(.blue),
                prefersLightLabel: false
            ),
            Variant(
                id: 2,
                code: ".monochrome(.red)",
                title: "Slide to delete",
                icon: "trash.fill",
                style: .monochrome(.red),
                prefersLightLabel: false
            ),
            Variant(
                id: 3,
                code: ".solid(.orange)",
                title: "Slide to archive",
                icon: "archivebox.fill",
                style: .solid(.orange),
                prefersLightLabel: false
            )
        ]
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(variants) { variant in
                VStack(alignment: .leading, spacing: 6) {
                    Text(variant.code)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 2)

                    SlideToConfirm(isConfirmed: binding(for: variant.id)) {} label: {
                        Text(variant.title)
                            .font(.headline)
                            .foregroundStyle(variant.prefersLightLabel ? .white : .primary)
                    } handleContent: { state in
                        Image(systemName: state == .confirmed ? "checkmark" : variant.icon)
                            .font(.subheadline.bold())
                            // A light knob wants a dark mark. The control does not guess at this;
                            // the caller states it, which is why the mark is a closure.
                            .foregroundStyle(variant.prefersLightLabel ? .black : .white)
                    }
                    .slideStyle(variant.style)
                }
            }
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
        MaterialsDemo()
    }
}
