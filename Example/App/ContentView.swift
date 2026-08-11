import SlideToConfirm
import SwiftUI

/// Harness for iterating on ``SlideToConfirm``.
///
/// The backdrop is not decoration: Liquid Glass is a lens, so on a white page it has nothing to
/// refract and degrades to flat colour. A moving, saturated field is what makes the material
/// legible as material — and dragging a knob across it is the only way to see the refraction
/// change.
struct ContentView: View {
    /// Sizes the control can be switched between.
    ///
    /// `nil` means the height comes entirely from the label, which is the honest default: it is
    /// what keeps copy from being clipped at large Dynamic Type sizes.
    private enum Size: String, CaseIterable, Identifiable {
        case compact = "Compact"
        case regular = "Regular"
        case tall = "Tall"
        case auto = "Auto"

        var id: Self { self }

        var height: CGFloat? {
            switch self {
            case .compact: 40
            case .regular: 56
            case .tall: 76
            case .auto: nil
            }
        }

        /// Shrunk alongside the capsule, since a fixed height cannot grow to fit its copy.
        var font: Font {
            switch self {
            case .compact: .subheadline.weight(.semibold)
            case .regular: .headline
            case .tall: .title3.bold()
            case .auto: .headline
            }
        }

        /// A smaller inset in a smaller capsule, so density reads consistently across sizes.
        var inset: CGFloat {
            switch self {
            case .compact: 3
            case .regular: 4
            case .tall: 6
            case .auto: 4
            }
        }
    }

    @State private var size: Size = .regular

    var body: some View {
        ZStack {
            backdrop
            content
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            sizePicker

            Sample("Glass — untinted, accent knob") {
                SlideToConfirm(isConfirmed: $0) {} label: {
                    Text("Slide to Confirm").font(size.font)
                }
                .slideStyle(.tinted(.blue, inset: size.inset, height: size.height))
            }

            Sample("Colour glass — tinted at half strength") {
                SlideToConfirm(isConfirmed: $0) {} label: {
                    Text("Slide to Pay").font(size.font)
                } handleContent: { state in
                    if state == .confirmed {
                        ProgressView().tint(.white)
                    } else {
                        SlideChevron()
                    }
                }
                .slideStyle(.monochrome(.green, inset: size.inset, height: size.height))
            }

            Sample("No glass — flat surface") {
                SlideToConfirm(isConfirmed: $0) {} label: {
                    Text("Slide to Archive").font(size.font)
                }
                .slideStyle(.solid(.orange, inset: size.inset, height: size.height))
            }

            Sample("Disabled") {
                SlideToConfirm(isConfirmed: $0) {} label: {
                    Text("Enter Wager").font(size.font)
                }
                .slideStyle(.tinted(.blue, inset: size.inset, height: size.height))
                .disabled(true)
            }

            Spacer()
        }
        .padding()
        .animation(.slideAppearance, value: size)
    }

    private var sizePicker: some View {
        Picker("Size", selection: $size) {
            ForEach(Size.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    /// Something for the glass to bend.
    ///
    /// Saturated and structured on purpose: a lens over a flat colour returns that colour, so the
    /// backdrop needs edges and hue changes before refraction is visible at all. Slowly moving, so
    /// the distortion under a knob changes even when nothing is being dragged.
    private var backdrop: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate / 6

            LinearGradient(
                colors: [.indigo, .purple, .pink, .orange, .cyan, .indigo],
                startPoint: UnitPoint(x: cos(phase) * 0.5 + 0.5, y: 0),
                endPoint: UnitPoint(x: sin(phase) * 0.5 + 0.5, y: 1)
            )
            .overlay {
                // Hard edges refract far more legibly than a smooth ramp.
                GeometryReader { proxy in
                    ForEach(0..<8) { index in
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: proxy.size.width / 3)
                            .offset(
                                x: cos(phase + Double(index)) * proxy.size.width / 2.5,
                                y: Double(index) * proxy.size.height / 8
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// One captioned example with its own latch and a tap-to-re-arm caption.
private struct Sample<Content: View>: View {
    let caption: String
    @ViewBuilder let content: (Binding<Bool>) -> Content

    @State private var isConfirmed = false

    init(_ caption: String, @ViewBuilder content: @escaping (Binding<Bool>) -> Content) {
        self.caption = caption
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .shadow(radius: 2)

            content($isConfirmed)

            if isConfirmed {
                Button("Confirmed — tap to re-arm") {
                    withAnimation(.slideSnapBack) { isConfirmed = false }
                }
                .font(.caption2)
                .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ContentView()
}
