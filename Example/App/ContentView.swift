import SlideToConfirm
import SwiftUI

/// Picks between the demos, each sized to be recorded on its own.
///
/// Every demo sits on the same backdrop, because glass is a lens: over a flat background it has
/// nothing to refract and reads as a plain translucent fill. Motion behind it is what makes the
/// material legible as material.
struct ContentView: View {
    private enum Demo: String, CaseIterable, Identifiable {
        case confirm = "Confirm"
        case materials = "Materials"
        case sizing = "Sizing"
        case external = "External"
        case wake = "Wake"

        var id: Self { self }
    }

    @State private var demo: Demo = .wake

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                picker

                Spacer(minLength: 0)

                // Each demo is rebuilt on switch, so its timers and latches start clean — a
                // recording of one is never part-way through another's animation.
                switch demo {
                case .confirm: ConfirmDemo()
                case .materials: MaterialsDemo()
                case .sizing: SizingDemo()
                case .external: ExternalConfirmDemo()
                case .wake: WakeDemo()
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var picker: some View {
        Picker("Demo", selection: $demo) {
            ForEach(Demo.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}
