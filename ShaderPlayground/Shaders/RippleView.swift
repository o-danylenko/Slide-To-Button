//
//  RippleView.swift
//  ShaderPlayground
//
//  Created by Oleksandr Danylenko on 20.07.2026.
//
import SwiftUI

struct RippleView: View {
    @State private var start = Date.now
    @State private var center = CGPoint(x: 200, y: 400)
    @State private var tapTime = Date.now

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince(start)
            let rippleCenter = center
            let age = Float(context.date.timeIntervalSince(tapTime))
            
            ZStack {
                LinearGradient(colors: [.blue, .cyan, .white],
                               startPoint: .top, endPoint: .bottom)
                Text("tap me 💧").font(.largeTitle.bold())
            }
            .visualEffect { content, proxy in
                content.layerEffect(
                    ShaderLibrary.ripple(
                        .float2(proxy.size),
                        .float2(rippleCenter),
                        .float(age)
                    ),
                    maxSampleOffset: .init(width: 10, height: 10)
                )
            }
            .onTapGesture { location in
                center = location
                tapTime = context.date
            }
            .ignoresSafeArea()
        }
    }
}

#Preview { RippleView() }
