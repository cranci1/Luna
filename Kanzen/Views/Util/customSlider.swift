//
//  customSlider.swift
//  Kanzen
//
//  Created by Dawud Osman on 21/06/2025.
//
import SwiftUI
import Foundation

extension CGFloat {
    func map(from: ClosedRange<CGFloat>, to: ClosedRange<CGFloat>) -> CGFloat {
        let result = ((self - from.lowerBound) / (from.upperBound - from.lowerBound)) * (to.upperBound - to.lowerBound) + to.lowerBound
        return result
    }
}

#if !os(tvOS)
struct customSlider: View{
    @Binding var value: CGFloat
    @Binding var  RTL: Bool
    @State var lastOffset: CGFloat = 0
    @EnvironmentObject var settings : Settings
    var range: ClosedRange<CGFloat>
    
    var body: some View {
        GeometryReader { geometry in
            VStack{
                Spacer()
                ZStack {
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: self.$value.wrappedValue.map(from: self.range, to: 0...(geometry.size.width )), height: 5)
                            .foregroundColor(RTL ? .gray :settings.accentColor)

                        Rectangle()
                            .frame(height: 5)
                            .foregroundColor(RTL ? settings.accentColor : .gray)
                    }
                    HStack {
                        Circle()
                            .frame(width: 11, height: 11)
                            .foregroundColor(.white)
                            .offset(x: self.$value.wrappedValue.map(from: range, to: 0...(geometry.size.width - 0 - 11)))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        
                                        if abs(value.translation.width) < 0.1 {
                                            self.lastOffset = self.$value.wrappedValue.map(from: range, to: 0...(geometry.size.width - 0 - 11))
                                        }
                                        
                                        let sliderPos = max(0, min(self.lastOffset + value.translation.width, geometry.size.width - 0 - 11))
                                       
                                        let sliderVal = sliderPos.map(from: 0...(geometry.size.width  - 11), to: range)
                                        self.value = sliderVal
                                        
                                    }
                            )
                        Spacer()
                    }
                }
                .padding(.bottom,10)
            }

        }
        
    }
}
#endif
