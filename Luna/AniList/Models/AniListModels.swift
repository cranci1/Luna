//
//  AniListModels.swift
//  Sora
//
//  Created by Francesco on 31/05/26.
//

import Foundation

let AniListMediaType = "anilist"

struct AnimeSummary: Identifiable, Hashable {
    let id: Int
    let title: AniListTitle
    let coverImage: CoverImage
    let episodes: Int?
    let description: String?
    let airingAt: Int?
}

extension AnimeSummary {
    var displayTitle: String {
        title.userPreferred ?? title.romaji ?? title.english ?? title.native ?? "Unknown"
    }
    
    var imageURL: URL? {
        let urlString = coverImage.extraLarge ?? coverImage.large
        return urlString.flatMap(URL.init(string:))
    }
    
    func toSearchResult() -> TMDBSearchResult {
        let imageURL = coverImage.extraLarge ?? coverImage.large
        return TMDBSearchResult(
            id: id,
            mediaType: AniListMediaType,
            title: displayTitle,
            name: nil,
            overview: description,
            posterPath: imageURL,
            backdropPath: imageURL,
            releaseDate: nil,
            firstAirDate: nil,
            voteAverage: nil,
            popularity: 0,
            adult: nil,
            genreIds: nil
        )
    }
}

struct AniListTitle: Decodable, Hashable {
    let romaji: String?
    let english: String?
    let native: String?
    let userPreferred: String?
}

struct CoverImage: Decodable, Hashable {
    let extraLarge: String?
    let large: String?
}

struct AniListMedia: Decodable {
    let id: Int
    let title: AniListTitle
    let coverImage: CoverImage
    let description: String?
    let nextAiringEpisode: AniListAiringEpisode?
    let isAdult: Bool
}

struct AniListAiringEpisode: Decodable {
    let episode: Int?
    let airingAt: Int?
}

struct AniListMediaDetails: Decodable {
    let id: Int
    let title: AniListTitle
    let description: String?
    let coverImage: CoverImage
    let bannerImage: String?
    let genres: [String]?
    let episodes: Int?
    let duration: Int?
    let season: String?
    let status: String?
    let siteUrl: String?
}
