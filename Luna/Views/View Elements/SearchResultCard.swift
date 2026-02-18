//
//  SearchResultCard.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct SearchResultCard: View {
    let result: TMDBSearchResult

    private var posterHeight: CGFloat { isTvOS ? 380 : 180 }
    private var posterCornerRadius: CGFloat { isTvOS ? 20 : 12 }
    private var titleHeight: CGFloat { isTvOS ? 52 : 34 }
    private var fallbackSize: CGSize {
        CGSize(width: isTvOS ? 280 : 120, height: isTvOS ? 380 : 180)
    }
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)) {
            VStack(spacing: 8) {
                KFImage(URL(string: result.fullPosterURL ?? ""))
                    .placeholder {
                        FallbackImageView(
                            isMovie: result.isMovie,
                            size: fallbackSize
                        )
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: isTvOS ? 280 : nil, height: posterHeight)
                    .clipShape(RoundedRectangle(cornerRadius: posterCornerRadius))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Text(result.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: titleHeight)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
