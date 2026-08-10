//
//  GlitchRippleView.swift
//  ShaderPlayground
//
//  Created by Oleksandr Danylenko on 20.07.2026.
//

import SwiftUI

struct GlitchRippleView: View {
    @State private var tapTime = Date.now
    @State private var center  = CGPoint(x: 200, y: 400)

    var body: some View {
        TimelineView(.animation) { context in
            let age = Float(context.date.timeIntervalSince(tapTime))
            let rippleCenter = center

            ZStack {
                LinearGradient(colors: [.indigo, .purple, .orange],
                               startPoint: .top, endPoint: .bottom)
                Text("SYSTEM BREACH")
                    .font(.system(size: 34, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .visualEffect { content, proxy in
                content.layerEffect(
                    ShaderLibrary.glitchRipple(
                        .float2(proxy.size),
                        .float2(rippleCenter),
                        .float(age)
                    ),
                    maxSampleOffset: CGSize(width: 120, height: 60)   // must cover jump 60 + streak 56
                )
            }
            .onTapGesture { location in
                center  = location
                tapTime = context.date
            }
            .ignoresSafeArea()
        }
    }
}

#Preview { GlitchRippleView() }
