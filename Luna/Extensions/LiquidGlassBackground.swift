//
//  LiquidGlassBackground.swift
//  Luna
//
//  Created by Francesco on 02/11/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func applyLiquidGlassBackground(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                )
        }
    }
}
