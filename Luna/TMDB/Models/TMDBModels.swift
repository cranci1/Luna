//
//  TMDBModels.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import Foundation

// MARK: - Search Response
struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBSearchResult]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Search Result
struct TMDBSearchResult: Codable, Identifiable {
    let id: Int
    let mediaType: String
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let popularity: Double
    let adult: Bool?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, overview, popularity, adult
        case mediaType = "media_type"
        case title, name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
    
    var displayTitle: String {
        return title ?? name ?? "Unknown Title"
    }
    
    var displayDate: String {
        return releaseDate ?? firstAirDate ?? ""
    }
    
    var isMovie: Bool {
        return mediaType == "movie"
    }
    
    var isTVShow: Bool {
        return mediaType == "tv"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(backdropPath)"
    }
}

// MARK: - Movie Search Response
struct TMDBMovieSearchResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - TV Show Search Response
struct TMDBTVSearchResponse: Codable {
    let page: Int
    let results: [TMDBTVShow]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Movie Model
struct TMDBMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double
    let popularity: Double
    let adult: Bool?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity, adult
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(backdropPath)"
    }
    
    var asSearchResult: TMDBSearchResult {
        return TMDBSearchResult(
            id: id,
            mediaType: "movie",
            title: title,
            name: nil,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            firstAirDate: nil,
            voteAverage: voteAverage,
            popularity: popularity,
            adult: adult,
            genreIds: genreIds
        )
    }
}

// MARK: - TV Show Model
struct TMDBTVShow: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double
    let popularity: Double
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(backdropPath)"
    }
    
    var asSearchResult: TMDBSearchResult {
        return TMDBSearchResult(
            id: id,
            mediaType: "tv",
            title: nil,
            name: name,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: nil,
            firstAirDate: firstAirDate,
            voteAverage: voteAverage,
            popularity: popularity,
            adult: nil,
            genreIds: genreIds
        )
    }
}

// MARK: - Movie Detail Model
struct TMDBMovieDetail: Codable, Identifiable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double
    let popularity: Double
    let runtime: Int?
    let genres: [TMDBGenre]
    let tagline: String?
    let status: String?
    let budget: Int?
    let revenue: Int?
    let imdbId: String?
    let originalLanguage: String?
    let originalTitle: String?
    let adult: Bool
    let voteCount: Int
    let releaseDates: TMDBReleaseDates?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity, runtime, genres, tagline, status, budget, revenue, adult
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case imdbId = "imdb_id"
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
        case voteCount = "vote_count"
        case releaseDates = "release_dates"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(backdropPath)"
    }
    
    var runtimeFormatted: String {
        guard let runtime = runtime, runtime > 0 else { return "Unknown" }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var yearFromReleaseDate: String {
        guard let releaseDate = releaseDate, !releaseDate.isEmpty else { return "Unknown" }
        return String(releaseDate.prefix(4))
    }
}

// MARK: - TV Show Detail Model
struct TMDBTVShowDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let voteAverage: Double
    let popularity: Double
    let genres: [TMDBGenre]
    let tagline: String?
    let status: String?
    let originalLanguage: String?
    let originalName: String?
    let adult: Bool
    let voteCount: Int
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let episodeRunTime: [Int]?
    let inProduction: Bool?
    let languages: [String]?
    let originCountry: [String]?
    let type: String?
    let contentRatings: TMDBContentRatings?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity, genres, tagline, status, adult, languages, type
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case voteAverage = "vote_average"
        case originalLanguage = "original_language"
        case originalName = "original_name"
        case voteCount = "vote_count"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case episodeRunTime = "episode_run_time"
        case inProduction = "in_production"
        case originCountry = "origin_country"
        case contentRatings = "content_ratings"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(backdropPath)"
    }
    
    var yearFromFirstAirDate: String {
        guard let firstAirDate = firstAirDate, !firstAirDate.isEmpty else { return "Unknown" }
        return String(firstAirDate.prefix(4))
    }
    
    var episodeRuntimeFormatted: String {
        guard let runtime = episodeRunTime?.first, runtime > 0 else { return "Unknown" }
        return "\(runtime)m"
    }
}

// MARK: - Genre Model
struct TMDBGenre: Codable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - Season Model
struct TMDBSeason: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let seasonNumber: Int
    let episodeCount: Int
    let airDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case airDate = "air_date"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
}

// MARK: - Episode Model
struct TMDBEpisode: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let airDate: String?
    let runtime: Int?
    let voteAverage: Double
    let voteCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case stillPath = "still_path"
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case airDate = "air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
    
    var fullStillURL: String? {
        guard let stillPath = stillPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(stillPath)"
    }
    
    var runtimeFormatted: String {
        guard let runtime = runtime, runtime > 0 else { return "Unknown" }
        return "\(runtime)m"
    }
}

// MARK: - Season Detail Model
struct TMDBSeasonDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let seasonNumber: Int
    let airDate: String?
    let episodes: [TMDBEpisode]
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, episodes
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
        case airDate = "air_date"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
}

// MARK: - TV Show with Seasons
struct TMDBTVShowWithSeasons: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let voteAverage: Double
    let popularity: Double
    let genres: [TMDBGenre]
    let tagline: String?
    let status: String?
    let originalLanguage: String?
    let originalName: String?
    let adult: Bool
    let voteCount: Int
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let episodeRunTime: [Int]?
    let inProduction: Bool?
    let languages: [String]?
    let originCountry: [String]?
    let type: String?
    let seasons: [TMDBSeason]
    let contentRatings: TMDBContentRatings?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity, genres, tagline, status, adult, languages, type, seasons
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case voteAverage = "vote_average"
        case originalLanguage = "original_language"
        case originalName = "original_name"
        case voteCount = "vote_count"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case episodeRunTime = "episode_run_time"
        case inProduction = "in_production"
        case originCountry = "origin_country"
        case contentRatings = "content_ratings"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(backdropPath)"
    }
    
    var yearFromFirstAirDate: String {
        guard let firstAirDate = firstAirDate, !firstAirDate.isEmpty else { return "Unknown" }
        return String(firstAirDate.prefix(4))
    }
    
    var episodeRuntimeFormatted: String {
        guard let runtime = episodeRunTime?.first, runtime > 0 else { return "Unknown" }
        return "\(runtime)m"
    }
}

// MARK: - Alternative Titles
struct TMDBAlternativeTitles: Codable {
    let id: Int
    let titles: [TMDBAlternativeTitle]
}

struct TMDBAlternativeTitle: Codable {
    let iso31661: String
    let title: String
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case title, type
        case iso31661 = "iso_3166_1"
    }
}

// MARK: - TV Alternative Titles
struct TMDBTVAlternativeTitles: Codable {
    let id: Int
    let results: [TMDBTVAlternativeTitle]
}

struct TMDBTVAlternativeTitle: Codable {
    let iso31661: String
    let title: String
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case title, type
        case iso31661 = "iso_3166_1"
    }
}

// MARK: - Content Ratings Models
struct TMDBReleaseDates: Codable {
    let results: [TMDBReleaseDateResult]
}

struct TMDBReleaseDateResult: Codable {
    let iso31661: String
    let releaseDates: [TMDBReleaseDate]
    
    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

struct TMDBReleaseDate: Codable {
    let certification: String
    let iso6391: String?
    let note: String?
    let releaseDate: String
    let type: Int
    
    enum CodingKeys: String, CodingKey {
        case certification, note, type
        case iso6391 = "iso_639_1"
        case releaseDate = "release_date"
    }
}

struct TMDBContentRatings: Codable {
    let results: [TMDBContentRating]
}

struct TMDBContentRating: Codable {
    let descriptors: [String]?
    let iso31661: String
    let rating: String
    
    enum CodingKeys: String, CodingKey {
        case descriptors, rating
        case iso31661 = "iso_3166_1"
    }
}

