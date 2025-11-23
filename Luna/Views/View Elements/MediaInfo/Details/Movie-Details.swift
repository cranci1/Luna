//
//  MovieDetails.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct MovieDetailsSection: View {
    let movie: TMDBMovieDetail?
    let useSolidBackground: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let movie = movie {
                Text("Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                    .foregroundColor(useSolidBackground ? .primary : .white)
                
                VStack(spacing: 12) {
                    if let runtime = movie.runtime, runtime > 0 {
                        DetailRow(title: "Runtime", value: movie.runtimeFormatted, useSolidBackground: useSolidBackground)
                    }

                    if !movie.genres.isEmpty {
                        DetailRow(title: "Genres", value: movie.genres.map { $0.name }.joined(separator: ", "), useSolidBackground: useSolidBackground)
                    }

                    if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                        DetailRow(title: "Release Date", value: releaseDate, useSolidBackground: useSolidBackground)
                    }

                    if movie.voteAverage > 0 {
                        DetailRow(title: "Rating", value: String(format: "%.1f/10", movie.voteAverage), useSolidBackground: useSolidBackground)
                    }

                    if let ageRating = getAgeRating(from: movie.releaseDates) {
                        DetailRow(title: "Age Rating", value: ageRating, useSolidBackground: useSolidBackground)
                    }

                    if let tagline = movie.tagline, !tagline.isEmpty {
                        DetailRow(title: "Tagline", value: tagline, useSolidBackground: useSolidBackground)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .applyLiquidGlassBackground(cornerRadius: 12)
                .padding(.horizontal)
            }
        }
    }
    
    private func getAgeRating(from releaseDates: TMDBReleaseDates?) -> String? {
        guard let releaseDates = releaseDates else { return nil }
        
        for result in releaseDates.results {
            if result.iso31661 == "US" {
                for releaseDate in result.releaseDates {
                    if !releaseDate.certification.isEmpty {
                        return releaseDate.certification
                    }
                }
            }
        }
        
        for result in releaseDates.results {
            for releaseDate in result.releaseDates {
                if !releaseDate.certification.isEmpty {
                    return releaseDate.certification
                }
            }
        }
        
        return nil
    }
}
