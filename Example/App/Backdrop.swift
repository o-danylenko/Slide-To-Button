import SwiftUI

/// A moving, saturated field for the glass to bend.
///
/// Not decoration. Liquid Glass is a lens: over a flat colour it returns that colour, so without
/// structure behind it the material is indistinguishable from a translucent fill. Hue changes and
/// hard-edged shapes are what make refraction visible, and the slow drift means the distortion
/// under a knob keeps changing even when nothing is being dragged.
struct Backdrop: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate / 8

            LinearGradient(
                colors: [.indigo, .purple, .pink, .orange, .cyan, .indigo],
                startPoint: UnitPoint(x: cos(phase) * 0.5 + 0.5, y: 0),
                endPoint: UnitPoint(x: sin(phase) * 0.5 + 0.5, y: 1)
            )
            .overlay {
                GeometryReader { proxy in
                    ForEach(0..<7) { index in
                        Circle()
                            .fill(.white.opacity(0.16))
                            .frame(width: proxy.size.width / 2.6)
                            .offset(
                                x: cos(phase * 1.3 + Double(index)) * proxy.size.width / 2.2,
                                y: Double(index) * proxy.size.height / 6
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
