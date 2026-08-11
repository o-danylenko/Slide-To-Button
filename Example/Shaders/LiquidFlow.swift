//
//  LiquidFlow.swift
//  ShaderPlayground
//
//  Created by Oleksandr Danylenko on 20.07.2026.
//
import SwiftUI

struct LiquidFlow: View {
    @State private var start = Date.now
    @State private var center = CGPoint(x: 200, y: 400)
    @State private var tapTime = Date.now
    
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince(start)
            let rippleCenter = center;
            let age = Float(context.date.timeIntervalSince(tapTime))
            Rectangle()
                .visualEffect { content, proxy in     // proxy gives us the size
                    
                    content
                        .colorEffect(
                            ShaderLibrary.flow(
                                .float2(proxy.size),
                                .float(time)
                            )
                        )
                        .layerEffect(
                            ShaderLibrary.ripple(
                                .float2(proxy.size),
                                .float2(rippleCenter),
                                .float(age)
                            ),
                            maxSampleOffset:
                                    .init(width: 40, height: 40)
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

#Preview { LiquidFlow() }
