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

            VStack(spacing: 20) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)

                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .font(.body)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}
