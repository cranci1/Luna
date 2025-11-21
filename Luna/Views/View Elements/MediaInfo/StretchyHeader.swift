//
//  StretchyHeader.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct StretchyHeaderView: View {
    let backdropURL: String?
    let isMovie: Bool
    let headerHeight: CGFloat
    let minHeaderHeight: CGFloat
    let onAmbientColorExtracted: ((Color) -> Void)?
    
    @State private var localAmbientColor: Color = Color.black
    @State private var backdropImage: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let deltaY = frame.minY
            let height = headerHeight + max(0, deltaY)
            let offset = min(0, -deltaY)

            ZStack(alignment: .bottom) {
                Color.clear
                    .overlay(
                        KFImage(URL(string: backdropURL ?? ""))
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .onSuccess { result in
                                backdropImage = result.image
                                let extractedColor = Color.ambientColor(from: result.image)
                                localAmbientColor = extractedColor
                                onAmbientColorExtracted?(extractedColor)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill),
                        alignment: .center
                    )
                    .clipped()
                    .frame(height: height)
                    .offset(y: offset)

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: localAmbientColor.opacity(0.0), location: 0.0),
                        .init(color: localAmbientColor.opacity(0.1), location: 0.2),
                        .init(color: localAmbientColor.opacity(0.3), location: 0.7),
                        .init(color: localAmbientColor.opacity(0.6), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 0))
            }
        }
        .frame(height: headerHeight)
        .clipShape(Path { path in
            let screenWidth = UIScreen.main.bounds.width
            path.addRect(CGRect(x: 0, y: -10000, width: screenWidth, height: headerHeight + 10000))
        })
        .onAppear {
            if let backdropURL = backdropURL, let url = URL(string: backdropURL) {
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    switch result {
                    case .success(let value):
                        Task { @MainActor in
                            backdropImage = value.image
                            let extractedColor = Color.ambientColor(from: value.image)
                            localAmbientColor = extractedColor
                            onAmbientColorExtracted?(extractedColor)
                        }
                    case .failure:
                        break
                    }
                }
            }
        }
    }
}
