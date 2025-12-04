//
//  MusicProgressSlider.swift
//  Custom Seekbar
//
//  Created by Pratik on 08/01/23.
//
//  Thanks to pratikg29 for this code inside his open source project "https://github.com/pratikg29/Custom-Slider-Control?ref=iosexample.com"
//  I did edit some of the code for my liking (added a buffer indicator, etc.)

import SwiftUI

struct MusicProgressSlider<T: BinaryFloatingPoint>: View {
    @Binding var value: T
    let inRange: ClosedRange<T>
    let activeFillColor: Color
    let fillColor: Color
    let textColor: Color
    let emptyColor: Color
    let height: CGFloat
    let onEditingChanged: (Bool) -> Void
    
    @State private var localRealProgress: T = 0
    @State private var localTempProgress: T = 0
    @GestureState private var isActive: Bool = false
    @State private var progressDuration: T = 0
    
    init(
        value: Binding<T>,
        inRange: ClosedRange<T>,
        activeFillColor: Color,
        fillColor: Color,
        textColor: Color,
        emptyColor: Color,
        height: CGFloat,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        self._value = value
        self.inRange = inRange
        self.activeFillColor = activeFillColor
        self.fillColor = fillColor
        self.textColor = textColor
        self.emptyColor = emptyColor
        self.height = height
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        GeometryReader { bounds in
            ZStack {
                Color.clear
                    .allowsHitTesting(false)
                VStack(spacing: 8) {
                    ZStack(alignment: .center) {
                        ZStack(alignment: .center) {
                            Capsule()
                                .fill(.ultraThinMaterial)
                        }
                        .clipShape(Capsule())

                        Capsule()
                            .fill(isActive ? activeFillColor : fillColor)
                            .mask({
                                HStack {
                                    Rectangle()
                                        .frame(
                                            width: max(
                                                bounds.size.width * CGFloat(localRealProgress + localTempProgress),
                                                0
                                            ),
                                            alignment: .leading
                                        )
                                    Spacer(minLength: 0)
                                }
                            })
                    }
                    
                    HStack {
                        Text(timeString(from: progressDuration))
                        Spacer(minLength: 0)
                        Text("-" + timeString(from: (inRange.upperBound - progressDuration)))
                    }
                    .font(.system(size: 12.5))
                    .foregroundColor(textColor)
                }
                .frame(width: isActive ? bounds.size.width * 1.04 : bounds.size.width, alignment: .center)
                .animation(animation, value: isActive)
            }
            .frame(width: bounds.size.width, height: bounds.size.height, alignment: .center)
            .contentShape(Rectangle())
            #if !os(tvOS)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($isActive) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        localTempProgress = T(gesture.translation.width / bounds.size.width)
                        let prg = max(min((localRealProgress + localTempProgress), 1), 0)
                        progressDuration = inRange.upperBound * prg
                        value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
                    }
                    .onEnded { _ in
                        localRealProgress = max(min(localRealProgress + localTempProgress, 1), 0)
                        localTempProgress = 0
                    }
            )
            #endif
            .onChangeComp(of: isActive) { _, newValue in
                value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
                onEditingChanged(newValue)
            }
            .onAppear {
                localRealProgress = getPrgPercentage(value)
            }
            .onChangeComp(of: value) { _, newValue in
                if !isActive {
                    localRealProgress = getPrgPercentage(newValue)
                    progressDuration = inRange.upperBound * localRealProgress
                }
            }
        }
        .frame(height: isActive ? height * 1.25 : height, alignment: .center)
    }
        
    private var animation: Animation {
        if isActive {
            return .spring()
        } else {
            return .spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.6)
        }
    }
    
    private func getPrgPercentage(_ value: T) -> T {
        let range = inRange.upperBound - inRange.lowerBound
        let correctedStartValue = value - inRange.lowerBound
        let percentage = correctedStartValue / range
        return percentage
    }
    
    private func getPrgValue() -> T {
        return ((localRealProgress + localTempProgress) * (inRange.upperBound - inRange.lowerBound)) + inRange.lowerBound
    }
    
    private func timeString(from value: T) -> String {
        let seconds = Double(value)
        guard seconds.isFinite && seconds > 0 else { return "00:00" }
        let total = Int(round(seconds))
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
