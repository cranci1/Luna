//
//  TMDBSearchResult+AniList.swift
//  Luna
//
//  Created by Francesco on 22/06/26.
//

import Foundation

// MARK: - AniList compatibility helpers

extension TMDBSearchResult {
    var isAniList: Bool { mediaType == AniListMediaType }
    
    var resolvedPosterURL: String? {
        guard let path = posterPath else { return nil }
        if path.hasPrefix("https://") || path.hasPrefix("http://") {
            return path
        }
        return "\(TMDBService.tmdbImageBaseURL)\(path)"
    }
    
    var resolvedBackdropURL: String? {
        guard let path = backdropPath else { return nil }
        if path.hasPrefix("https://") || path.hasPrefix("http://") {
            return path
        }
        return "\(TMDBService.tmdbImageBaseURL)\(path)"
    }
}
