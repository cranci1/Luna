//
//  FallbackImageView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct FallbackImageView: View {
    let isMovie: Bool
    let size: CGSize
    
    init(isMovie: Bool, size: CGSize = CGSize(width: 120, height: 180)) {
        self.isMovie = isMovie
        self.size = size
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: iconSpacing) {
                    Image(systemName: iconName)
                        .font(iconFont)
                        .foregroundColor(.white)
                    Text(mediaTypeText)
                        .font(textFont)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
            )
            .frame(width: size.width, height: size.height)
            .aspectRatio(2/3, contentMode: .fill)
    }
    
    private var gradientColors: [Color] {
        if isMovie {
            return [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]
        } else {
            return [Color.green.opacity(0.8), Color.teal.opacity(0.8)]
        }
    }
    
    private var iconName: String {
        isMovie ? "film" : "tv"
    }
    
    private var mediaTypeText: String {
        isMovie ? "Movie" : "TV"
    }
    
    private var iconFont: Font {
        if size.width <= 60 {
            return .title2
        } else if size.width <= 120 {
            return .title
        } else {
            return .largeTitle
        }
    }
    
    private var textFont: Font {
        if size.width <= 60 {
            return .caption2
        } else if size.width <= 120 {
            return .caption
        } else {
            return .body
        }
    }
    
    private var iconSpacing: CGFloat {
        if size.width <= 60 {
            return 2
        } else if size.width <= 120 {
            return 4
        } else {
            return 8
        }
    }
}
