//
//  TMDBService.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import Foundation

class TMDBService: ObservableObject {
    static let shared = TMDBService()
    
    static let tmdbBaseURL = "https://api.themoviedb.org/3"
    static let tmdbImageBaseURL = "https://image.tmdb.org/t/p/original"
    
    private let apiKey = "738b4edd0a156cc126dc4a4b8aea4aca"
    private let baseURL = tmdbBaseURL
    
    private init() {}

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        try await Task.detached(priority: .utility) {
            try JSONDecoder().decode(T.self, from: data)
        }.value
    }
    
    private var currentLanguage: String {
        return UserDefaults.standard.string(forKey: "tmdbLanguage") ?? "en-US"
    }
    
    // MARK: - Multi Search (Movies and TV Shows)
    func searchMulti(query: String) async throws -> [TMDBSearchResult] {
        guard !query.isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/multi?api_key=\(apiKey)&query=\(encodedQuery)&language=\(currentLanguage)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBSearchResponse = try await decode(TMDBSearchResponse.self, from: data)
            return response.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Search Movies
    func searchMovies(query: String) async throws -> [TMDBMovie] {
        guard !query.isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedQuery)&language=\(currentLanguage)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBMovieSearchResponse = try await decode(TMDBMovieSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Search TV Shows
    func searchTVShows(query: String) async throws -> [TMDBTVShow] {
        guard !query.isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/tv?api_key=\(apiKey)&query=\(encodedQuery)&language=\(currentLanguage)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBTVSearchResponse = try await decode(TMDBTVSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Movie Details
    func getMovieDetails(id: Int) async throws -> TMDBMovieDetail {
        let urlString = "\(baseURL)/movie/\(id)?api_key=\(apiKey)&language=\(currentLanguage)&append_to_response=release_dates"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBMovieDetail.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get TV Show Details
    func getTVShowDetails(id: Int) async throws -> TMDBTVShowDetail {
        let urlString = "\(baseURL)/tv/\(id)?api_key=\(apiKey)&language=\(currentLanguage)&append_to_response=content_ratings"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBTVShowDetail.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get TV Show with Seasons
    func getTVShowWithSeasons(id: Int) async throws -> TMDBTVShowWithSeasons {
        let urlString = "\(baseURL)/tv/\(id)?api_key=\(apiKey)&language=\(currentLanguage)&append_to_response=content_ratings"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBTVShowWithSeasons.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Season Details
    func getSeasonDetails(tvShowId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetail {
        let urlString = "\(baseURL)/tv/\(tvShowId)/season/\(seasonNumber)?api_key=\(apiKey)&language=\(currentLanguage)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBSeasonDetail.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }

    // MARK: - Get TV Show Credits
    func getTVShowCredits(id: Int) async throws -> TMDBCreditsResponse {
        let urlString = "\(baseURL)/tv/\(id)/credits?api_key=\(apiKey)&language=\(currentLanguage)"

        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBCreditsResponse.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Movie Credits
    func getMovieCredits(id: Int) async throws -> TMDBCreditsResponse {
        let urlString = "\(baseURL)/movie/\(id)/credits?api_key=\(apiKey)&language=\(currentLanguage)"

        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBCreditsResponse.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Movie Alternative Titles
    func getMovieAlternativeTitles(id: Int) async throws -> TMDBAlternativeTitles {
        let urlString = "\(baseURL)/movie/\(id)/alternative_titles?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBAlternativeTitles.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get TV Show Alternative Titles
    func getTVShowAlternativeTitles(id: Int) async throws -> TMDBTVAlternativeTitles {
        let urlString = "\(baseURL)/tv/\(id)/alternative_titles?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBTVAlternativeTitles.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Trending Movies and TV Shows
    func getTrending(mediaType: String = "all", timeWindow: String = "week") async throws -> [TMDBSearchResult] {
        let urlString = "\(baseURL)/trending/\(mediaType)/\(timeWindow)?api_key=\(apiKey)&language=\(currentLanguage)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBSearchResponse = try await decode(TMDBSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Popular Movies
    func getPopularMovies(page: Int = 1) async throws -> [TMDBMovie] {
        let urlString = "\(baseURL)/movie/popular?api_key=\(apiKey)&language=\(currentLanguage)&page=\(page)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBMovieSearchResponse = try await decode(TMDBMovieSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Popular TV Shows
    func getPopularTVShows(page: Int = 1) async throws -> [TMDBTVShow] {
        let urlString = "\(baseURL)/tv/popular?api_key=\(apiKey)&language=\(currentLanguage)&page=\(page)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBTVSearchResponse = try await decode(TMDBTVSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Top Rated Movies
    func getTopRatedMovies(page: Int = 1) async throws -> [TMDBMovie] {
        let urlString = "\(baseURL)/movie/top_rated?api_key=\(apiKey)&language=\(currentLanguage)&page=\(page)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBMovieSearchResponse = try await decode(TMDBMovieSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Top Rated TV Shows
    func getTopRatedTVShows(page: Int = 1) async throws -> [TMDBTVShow] {
        let urlString = "\(baseURL)/tv/top_rated?api_key=\(apiKey)&language=\(currentLanguage)&page=\(page)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBTVSearchResponse = try await decode(TMDBTVSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Popular Anime (Animation TV Shows from Japan)
    func getPopularAnime(page: Int = 1) async throws -> [TMDBTVShow] {
        let urlString = "\(baseURL)/discover/tv?api_key=\(apiKey)&language=\(currentLanguage)&page=\(page)&with_genres=16&with_origin_country=JP&sort_by=popularity.desc&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBTVSearchResponse = try await decode(TMDBTVSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Get Top Rated Anime (Animation TV Shows from Japan)
    func getTopRatedAnime(page: Int = 1) async throws -> [TMDBTVShow] {
        let urlString = "\(baseURL)/discover/tv?api_key=\(apiKey)&language=\(currentLanguage)&page=\(page)&with_genres=16&with_origin_country=JP&sort_by=vote_average.desc&vote_count.gte=100&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response: TMDBTVSearchResponse = try await decode(TMDBTVSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Helper function to get romaji title
    func getRomajiTitle(for mediaType: String, id: Int) async -> String? {
        do {
            let isRomajiType: (String?) -> Bool = { type in
                let lowered = (type ?? "").lowercased()
                return lowered.contains("romaji") || lowered.contains("romanized")
            }

            if mediaType == "movie" {
                let alternativeTitles = try await getMovieAlternativeTitles(id: id)
                return alternativeTitles.titles
                    .first(where: { $0.iso31661 == "JP" && isRomajiType($0.type) })?
                    .title
            } else {
                let alternativeTitles = try await getTVShowAlternativeTitles(id: id)
                return alternativeTitles.results
                    .first(where: { $0.iso31661 == "JP" && isRomajiType($0.type) })?
                    .title
            }
        } catch {
            return nil
        }
    }

    // MARK: - Get Images (Backdrops, Logos, Posters)
    func getMovieImages(id: Int, preferredLanguage: String? = nil) async throws -> TMDBImagesResponse {
        let langCode = (preferredLanguage ?? currentLanguage).components(separatedBy: "-").first ?? "en"
        let urlString = "\(baseURL)/movie/\(id)/images?api_key=\(apiKey)&include_image_language=\(langCode),en,null"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBImagesResponse.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    func getTVShowImages(id: Int, preferredLanguage: String? = nil) async throws -> TMDBImagesResponse {
        let langCode = (preferredLanguage ?? currentLanguage).components(separatedBy: "-").first ?? "en"
        let urlString = "\(baseURL)/tv/\(id)/images?api_key=\(apiKey)&include_image_language=\(langCode),en,null"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try await decode(TMDBImagesResponse.self, from: data)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    func getBestLogo(from images: TMDBImagesResponse, preferredLanguage: String? = nil) -> TMDBImage? {
        guard let logos = images.logos, !logos.isEmpty else { return nil }
        
        let langCode = (preferredLanguage ?? currentLanguage).components(separatedBy: "-").first ?? "en"
        
        if let logo = logos.first(where: { $0.iso6391 == langCode }) {
            return logo
        }
        if let logo = logos.first(where: { $0.iso6391 == "en" }) {
            return logo
        }
        if let logo = logos.first(where: { $0.iso6391 == nil }) {
            return logo
        }
        return logos.first
    }
}

// MARK: - Error Handling
enum TMDBError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to decode response"
        case .missingAPIKey:
            return "API key is missing. Please add your TMDB API key."
        }
    }
}
