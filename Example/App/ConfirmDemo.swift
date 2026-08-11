import SlideToConfirm
import SwiftUI

/// A payment confirmation sheet: the control doing its job in context.
///
/// Framed as a real screen rather than a control on a page, because that is the case the design is
/// answering — a slide is what you reach for when the action moves money and a stray thumb must not
/// be able to produce it. The work is a real `Task` with a real delay, so the spinner is in flight
/// rather than a flash, and the re-arm happens because the work finished.
struct ConfirmDemo: View {
    /// Where a transfer is in its life. An enum rather than flags, so "sent but still sending" is
    /// not a state that can be reached.
    private enum Transfer: Equatable {
        case ready
        case sending
        case sent
    }

    @State private var transfer: Transfer = .ready
    @State private var isConfirmed = false
    @State private var work: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            recipient
            Divider().overlay(.white.opacity(0.2))
            amount
            slide
        }
        .background(.background.opacity(0.55), in: .rect(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.25)))
        .padding(20)
        .onDisappear { work?.cancel() }
    }

    // MARK: - Sheet

    private var recipient: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.teal.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Text("AR")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text("Alex Rivera").font(.subheadline.weight(.semibold))
                Text("Checking •••• 4021").font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            statusMark
        }
        .padding(16)
    }

    @ViewBuilder
    private var statusMark: some View {
        switch transfer {
        case .ready:
            EmptyView()
        case .sending:
            ProgressView().controlSize(.small)
        case .sent:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var amount: some View {
        VStack(spacing: 4) {
            Text("$240.00")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())

            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private var caption: String {
        switch transfer {
        case .ready: "Arrives instantly · No fee"
        case .sending: "Sending…"
        case .sent: "Sent to Alex"
        }
    }

    private var slide: some View {
        SlideToConfirm(isConfirmed: $isConfirmed) {
            send()
        } label: {
            Text(title).font(.headline)
        } handleContent: { state in
            // The latch lasts exactly as long as the work, so this reads as in flight.
            if state == .confirmed {
                ProgressView().tint(.white)
            } else {
                SlideChevron()
            }
        }
        .slideStyle(.tinted(.green, inset: 5))
        .padding(16)
        .animation(.slideAppearance, value: transfer)
    }

    private var title: String {
        switch transfer {
        case .ready: "Slide to send"
        case .sending: "Sending"
        case .sent: "Sent"
        }
    }

    // MARK: - Work

    private func send() {
        transfer = .sending
        work?.cancel()
        work = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }

            withAnimation(.slideConfirm) { transfer = .sent }
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }

            // The caller re-arms, because only the caller knows the work is done.
            withAnimation(.slideSnapBack) {
                transfer = .ready
                isConfirmed = false
            }
        }
    }
}

#Preview {
    ZStack {
        Backdrop()
        ConfirmDemo()
    }
}
