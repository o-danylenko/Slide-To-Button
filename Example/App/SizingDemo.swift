import SlideToConfirm
import SwiftUI

/// One control resizing itself, plus one taking its height from its label.
///
/// The only demo that needs no touching: it cycles on its own, so a recording of it is a recording
/// of the behaviour. The pair matters — the left control is told its height, the right one derives
/// it from two lines of copy, which is what keeps a control from clipping its own text at large
/// Dynamic Type sizes.
struct SizingDemo: View {
    private enum Size: String, CaseIterable {
        case compact = "height: 40"
        case regular = "height: 56"
        case tall = "height: 76"

        var height: CGFloat {
            switch self {
            case .compact: 40
            case .regular: 56
            case .tall: 76
            }
        }

        /// Shrinks with the capsule, since a fixed height cannot grow to fit its copy.
        var font: Font {
            switch self {
            case .compact: .subheadline.weight(.semibold)
            case .regular: .headline
            case .tall: .title3.bold()
            }
        }

        var inset: CGFloat {
            switch self {
            case .compact: 3
            case .regular: 4
            case .tall: 6
            }
        }
    }

    @State private var size: Size = .compact
    @State private var isConfirmed = false
    @State private var isAutoConfirmed = false

    var body: some View {
        VStack(spacing: 28) {
            labelled(size.rawValue) {
                SlideToConfirm(isConfirmed: $isConfirmed) {} label: {
                    Text("Slide to Confirm").font(size.font)
                }
                .slideStyle(.tinted(.blue, inset: size.inset, height: size.height))
            }

            labelled("height: nil — grows with two lines of copy") {
                SlideToConfirm(isConfirmed: $isAutoConfirmed) {} label: {
                    VStack(spacing: 2) {
                        Text("Slide to Send").font(.headline)
                        Text("Two lines grow the track").font(.caption)
                    }
                }
                .slideStyle(.monochrome(.purple, height: nil))
            }
        }
        .padding(24)
        .animation(.slideAppearance, value: size)
        .task {
            // Cycles unattended, so the recording needs no gesture.
            var index = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.3))
                index += 1
                size = Size.allCases[index % Size.allCases.count]
            }
        }
    }

    private func labelled<Content: View>(
        _ caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 2)
            content()
        }
    }
}

#Preview {
    ZStack {
        Backdrop()
        SizingDemo()
    }
}
