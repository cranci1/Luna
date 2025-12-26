//
//  CircularProgressBar.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct CircularProgressBar: View {
    var progress: Double
    var size: CGFloat = 30
    var lineWidth: CGFloat = 3
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(Color.accentColor)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.accentColor)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            if progress >= 0.9 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.accentColor)
            } else if progress > 0 {
                Text(String(format: "%.0f%%", min(progress, 1.0) * 100.0))
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        CircularProgressBar(progress: 0.0)
        CircularProgressBar(progress: 0.45)
        CircularProgressBar(progress: 0.75)
        CircularProgressBar(progress: 0.95)
    }
    .padding()
}
