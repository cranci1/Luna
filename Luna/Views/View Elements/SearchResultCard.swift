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
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)) {
            VStack(spacing: 8) {
                KFImage(URL(string: result.fullPosterURL ?? ""))
                    .placeholder {
                        FallbackImageView(
                            isMovie: result.isMovie,
                            size: CGSize(width: 120, height: 180)
                        )
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Text(result.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 34)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
