import SlideToConfirm
import SwiftUI

/// A confirm arriving from somewhere other than the finger.
///
/// The demo that justifies the binding. A stand-in "server" latches the control on its own, and the
/// knob travels and parks exactly as it would from a drag — no gesture involved. This is why the
/// latch cannot live inside the control: only the caller knows that something else confirmed.
struct ExternalConfirmDemo: View {
    @State private var isConfirmed = false
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 20) {
            SlideToConfirm(isConfirmed: $isConfirmed) {
                note("approved here")
            } label: {
                Text(isConfirmed ? "Paired" : "Slide to pair, or approve on device")
                    .font(.headline)
            } handleContent: { state in
                if state == .confirmed {
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                } else {
                    SlideChevron()
                }
            }
            .slideStyle(.tinted(.teal, inset: 5))

            transcript
        }
        .padding(24)
        .task { await simulateServer() }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(log.suffix(3), id: \.self) { line in
                Text(line)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(height: 52, alignment: .top)
        .animation(.slideAppearance, value: log)
    }

    /// Latches and clears the binding on its own schedule, as a push or a socket event would.
    private func simulateServer() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.6))
            guard !isConfirmed else { continue }
            note("approved on device")
            withAnimation(.slideConfirm) { isConfirmed = true }

            try? await Task.sleep(for: .seconds(1.6))
            note("session ended")
            withAnimation(.slideSnapBack) { isConfirmed = false }
        }
    }

    private func note(_ line: String) {
        log.append("→ \(line)")
    }
}

#Preview {
    ZStack {
        Backdrop()
        ExternalConfirmDemo()
    }
}
