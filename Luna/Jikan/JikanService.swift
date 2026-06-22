//
//  JikanService.swift
//  Luna
//
//  Created by Francesco on 22/06/26.
//

import Foundation

// MARK: - Main Jikan
private struct JikanResponse: Decodable {
    let data: [JikanAnime]
    let pagination: JikanPagination
}

private struct JikanPagination: Decodable {
    let hasNextPage: Bool
    enum CodingKeys: String, CodingKey {
        case hasNextPage = "has_next_page"
    }
}

private struct JikanAnime: Decodable {
    let malId: Int
    let title: String
    let titleEnglish: String?
    let synopsis: String?
    let score: Double?
    let members: Int?
    let popularity: Int?
    let images: JikanImages
    let aired: JikanAired?
    let genres: [JikanGenre]?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case malId = "mal_id"
        case title
        case titleEnglish = "title_english"
        case synopsis, score, members, popularity, images, aired, genres, type
    }
}

private struct JikanImages: Decodable {
    let jpg: JikanImageSet
}

private struct JikanImageSet: Decodable {
    let imageUrl: String?
    let largeImageUrl: String?
    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case largeImageUrl = "large_image_url"
    }
}

private struct JikanAired: Decodable {
    let from: String?
}

private struct JikanGenre: Decodable {
    let malId: Int
    let name: String
    enum CodingKeys: String, CodingKey {
        case malId = "mal_id"
        case name
    }
}

private struct TMDBFindResponse: Decodable {
    let tvResults: [TMDBFindTVResult]
    let movieResults: [TMDBFindMovieResult]
    enum CodingKeys: String, CodingKey {
        case tvResults = "tv_results"
        case movieResults = "movie_results"
    }
}

private struct TMDBFindTVResult: Decodable {
    let id: Int
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let popularity: Double?
    let genreIds: [Int]?
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
}

private struct TMDBFindMovieResult: Decodable {
    let id: Int
    let title: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let popularity: Double?
    let genreIds: [Int]?
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
}

// MARK: - JikanService

final class JikanService {
    static let shared = JikanService()
    private init() {}
    
    private let jikanBase = "https://api.jikan.moe/v4"
    
    private let tmdbBase = "https://api.themoviedb.org/3"
    private let tmdbKey = "738b4edd0a156cc126dc4a4b8aea4aca"
    
    private let pageSize = 25
    private let concurrency = 5
    
    // MARK: - Public API
    
    func getPopularAnime(page: Int = 1) async throws -> [TMDBTVShow] {
        let anime = try await fetchJikan(
            path: "/top/anime",
            queryItems: [
                URLQueryItem(name: "type", value: "tv"),
                URLQueryItem(name: "filter", value: "bypopularity"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(pageSize)")
            ]
        )
        return try await resolveToTMDB(anime)
    }
    
    func getTopRatedAnime(page: Int = 1) async throws -> [TMDBTVShow] {
        let anime = try await fetchJikan(
            path: "/top/anime",
            queryItems: [
                URLQueryItem(name: "type", value: "tv"),
                URLQueryItem(name: "filter", value: "byrating"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(pageSize)")
            ]
        )
        return try await resolveToTMDB(anime)
    }
    
    // MARK: - Private helpers
    
    private func fetchJikan(path: String, queryItems: [URLQueryItem]) async throws -> [JikanAnime] {
        var comps = URLComponents(string: jikanBase + path)!
        comps.queryItems = queryItems
        guard let url = comps.url else { throw JikanError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            let (retryData, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(JikanResponse.self, from: retryData).data
        }
        
        return try JSONDecoder().decode(JikanResponse.self, from: data).data
    }
    
    private func resolveToTMDB(_ anime: [JikanAnime]) async throws -> [TMDBTVShow] {
        var results: [TMDBTVShow] = []
        let batches = stride(from: 0, to: anime.count, by: concurrency).map {
            Array(anime[$0 ..< min($0 + concurrency, anime.count)])
        }
        
        for batch in batches {
            let batchResults = try await withThrowingTaskGroup(of: TMDBTVShow?.self) { group in
                for entry in batch {
                    group.addTask { [self] in
                        await self.findOnTMDB(entry)
                    }
                }
                var out: [TMDBTVShow] = []
                for try await item in group {
                    if let item { out.append(item) }
                }
                return out
            }
            results.append(contentsOf: batchResults)
        }
        
        return results
    }
    
    private func findOnTMDB(_ entry: JikanAnime) async -> TMDBTVShow? {
        var comps = URLComponents(string: "\(tmdbBase)/find/\(entry.malId)")!
        comps.queryItems = [
            URLQueryItem(name: "api_key",         value: tmdbKey),
            URLQueryItem(name: "external_source", value: "myanimelist_id")
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let found = try? JSONDecoder().decode(TMDBFindResponse.self, from: data)
        else { return nil }
        
        if let tv = found.tvResults.first {
            return TMDBTVShow(
                id: tv.id,
                name: tv.name ?? entry.titleEnglish ?? entry.title,
                overview: tv.overview ?? entry.synopsis,
                posterPath: tv.posterPath,
                backdropPath: tv.backdropPath,
                firstAirDate: tv.firstAirDate ?? entry.aired?.from,
                voteAverage: tv.voteAverage ?? entry.score ?? 0,
                popularity: tv.popularity  ?? Double(entry.members ?? 0) / 1000,
                genreIds: tv.genreIds ?? [16]
            )
        }
        
        if let movie = found.movieResults.first {
            return TMDBTVShow(
                id: movie.id,
                name: movie.title ?? entry.titleEnglish ?? entry.title,
                overview: movie.overview ?? entry.synopsis,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                firstAirDate: movie.releaseDate ?? entry.aired?.from,
                voteAverage: movie.voteAverage ?? entry.score ?? 0,
                popularity: movie.popularity  ?? Double(entry.members ?? 0) / 1000,
                genreIds: movie.genreIds ?? [16]
            )
        }
        
        return nil
    }
}

// MARK: - Errors

enum JikanError: Error, LocalizedError {
    case invalidURL
    case rateLimited
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Jikan URL"
        case .rateLimited: return "Jikan rate limit hit – please wait a moment"
        case .networkError(let e): return "Jikan network error: \(e.localizedDescription)"
        }
    }
}
