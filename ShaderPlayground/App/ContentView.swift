import SwiftUI

/// Harness for iterating on ``SlideToConfirm``.
struct ContentView: View {
    @State private var isConfirmed = false
    @State private var confirmations = 0

    var body: some View {
        VStack(spacing: 32) {
            SlideToConfirm(isConfirmed: $isConfirmed) {
                confirmations += 1
            } label: {
                Text("Slide to Confirm").font(.headline)
            }

            VStack(spacing: 12) {
                Text("Confirmed \(confirmations)×")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                // Stands in for a confirm arriving from outside the gesture, and for the
                // caller re-arming once its work is done.
                Toggle("Confirmed", isOn: $isConfirmed.animation(.slideSnapBack))
                    .font(.subheadline)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
