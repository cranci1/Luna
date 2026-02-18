//
//  MoonPhaseLoader.swift
//  Luna
//
//  Created by TrinityHades on 08/01/26.
//

import SwiftUI

struct MoonPhaseLoader: View {
    var iconSize: CGFloat = 22
    var spacing: CGFloat = 12
    var stepDuration: TimeInterval = 0.18

    @State private var startDate: Date = Date()

    private let phaseProgresses: [Double] = [
        0.125, // waxing crescent
        0.25,  // first quarter
        0.375, // waxing gibbous
        0.5,   // full
        0.625, // waning gibbous
        0.75,  // last quarter
        0.875  // waning crescent
    ]
    
    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let activeIndex = Int(elapsed / stepDuration) % max(phaseProgresses.count, 1)

            HStack(spacing: spacing) {
                ForEach(Array(phaseProgresses.enumerated()), id: \ .offset) { index, progress in
                    let isActive = index == activeIndex

                    MoonPhaseIcon(progress: progress)
                        .frame(width: iconSize, height: iconSize)
                        .opacity(isActive ? 1.0 : 0.35)
                        .scaleEffect(isActive ? 1.18 : 1.0)
                        .shadow(color: .white.opacity(isActive ? 0.35 : 0.0), radius: isActive ? 6 : 0)
                        .animation(.easeInOut(duration: stepDuration * 0.75), value: activeIndex)
                }
            }
            .accessibilityLabel("Loading")
        }
    }
}

private struct MoonPhaseIcon: View {
    /// 0.0 = new moon, 0.5 = full moon, 1.0 = new moon
    let progress: Double

    private var baseColor: Color { Color(white: 0.35).opacity(0.55) }
    private var lightColor: Color { Color(white: 0.92) }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let shadowOffsetX = terminatorOffset(radius: radius)

            ZStack {
                Circle().fill(baseColor)

                Circle()
                    .fill(lightColor)
                    .overlay(
                        Circle()
                            .fill(.black)
                            .offset(x: shadowOffsetX)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func terminatorOffset(radius: CGFloat) -> CGFloat {
        let p = progress.truncatingRemainder(dividingBy: 1.0)

        if p <= 0.5 {
            // Waxing: new (0) -> full (0.5)
            let u = p / 0.5 // 0..1
            let d = 2 * radius * u // 0..2r
            return -d
        } else {
            // Waning: full (0.5) -> new (1)
            let u = (p - 0.5) / 0.5 // 0..1
            let d = 2 * radius * (1 - u) // 2r..0
            return d
        }
    }
}

#Preview("MoonPhaseLoader") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            MoonPhaseLoader(iconSize: 30, spacing: 14, stepDuration: 0.3)
            MoonPhaseLoader(iconSize: 18, spacing: 10, stepDuration: 0.12)
                .opacity(0.85)
        }
    }
}
