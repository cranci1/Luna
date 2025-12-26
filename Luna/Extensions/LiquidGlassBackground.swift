//
//  LiquidGlassBackground.swift
//  Luna
//
//  Created by Francesco on 02/11/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func applyLiquidGlassBackground(cornerRadius: CGFloat, fallbackFill: Color = Color.black.opacity(0.2), fallbackMaterial: Material = .ultraThinMaterial, glassTint: Color? = nil) -> some View {
#if compiler(>=6.0)
        if #available(iOS 26.0, macOS 15.0, tvOS 20.0, *) {
            self
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(alignment: .center) {
                    if let glassTint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(glassTint)
                            .allowsHitTesting(false)
                    }
                }
        } else {
            oldBackground(cornerRadius: cornerRadius, fallbackFill: fallbackFill, fallbackMaterial: fallbackMaterial)
        }
#else
        oldBackground(cornerRadius: cornerRadius, fallbackFill: fallbackFill, fallbackMaterial: fallbackMaterial)
#endif
    }
    
    @ViewBuilder
    private func oldBackground(cornerRadius: CGFloat, fallbackFill: Color, fallbackMaterial: Material) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fallbackFill)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(fallbackMaterial)
                    )
            )
    }
}
