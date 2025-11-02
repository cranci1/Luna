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
        if #available(iOS 26.0, macOS 15.0, tvOS 20.0, *) {
            self
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(alignment: .center) {
                    if let glassTint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(glassTint)
                            .allowsHitTesting(false)
                    }
                }
        } else {
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
}
