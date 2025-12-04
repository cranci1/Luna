//
//  DownloadProgressView.swift
//  Luna
//
//  Created by Dominic on 04.12.25.
//

import SwiftUI

struct DownloadProgressView: View {
    let progress: Double
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 8) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .font(.system(.body))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .frame(minHeight: 40)
                    .padding(.bottom, 8)

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .scaleEffect(y: 1.2, anchor: .center)

                Text("\(Int(progress * 100))%")
                    .foregroundColor(.secondary)
                    .font(.system(.caption))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .padding(32)
        }
    }
}

#Preview {
    DownloadProgressView(progress: 0.65, message: "Downloading JavaScript for My Awesome Service...")
}
