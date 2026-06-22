//
//  AniListService.swift
//  Celestia
//
//  Created by Francesco on 31/05/26.
//

import Foundation

final class AniListService {
    static let shared = AniListService()
    
    private let endpoint = URL(string: "https://graphql.anilist.co")!
    private let decoder = JSONDecoder()
    
    private init() {}
    
    func fetchTrendingAnime() async throws -> [AnimeSummary] {
        let query = includeAdultContent ? trendingQueryAll : trendingQueryFiltered
        let data = try await performRequest(query: query)
        let response = try decoder.decode(GraphQLResponse<TrendingData>.self, from: data)
        
        return response.data.Page.media.map {
            AnimeSummary(
                id: $0.id,
                title: $0.title,
                coverImage: $0.coverImage,
                episodes: nil,
                description: nil,
                airingAt: nil
            )
        }
    }
    
    func fetchSeasonalAnime() async throws -> [AnimeSummary] {
        let seasonInfo = currentSeasonInfo()
        let variables: [String: Any] = [
            "season": seasonInfo.season,
            "seasonYear": seasonInfo.year
        ]
        
        let query = includeAdultContent ? seasonalQueryAll : seasonalQueryFiltered
        let data = try await performRequest(query: query, variables: variables)
        let response = try decoder.decode(GraphQLResponse<TrendingData>.self, from: data)
        
        return response.data.Page.media.map {
            AnimeSummary(
                id: $0.id,
                title: $0.title,
                coverImage: $0.coverImage,
                episodes: nil,
                description: nil,
                airingAt: nil
            )
        }
    }
    
    func fetchAiringAnime() async throws -> [AnimeSummary] {
        let now = Int(Date().timeIntervalSince1970)
        let oneWeek = 7 * 24 * 60 * 60
        let variables: [String: Any] = [
            "page": 1,
            "perPage": 100,
            "startTime": now,
            "endTime": now + oneWeek
        ]
        
        let data = try await performRequest(query: airingQuery, variables: variables)
        let response = try decoder.decode(GraphQLResponse<AiringData>.self, from: data)
        
        let schedules = includeAdultContent
        ? response.data.Page.airingSchedules
        : response.data.Page.airingSchedules.filter { !$0.media.isAdult }
        
        return schedules.map { schedule in
            AnimeSummary(
                id: schedule.media.id,
                title: schedule.media.title,
                coverImage: schedule.media.coverImage,
                episodes: schedule.media.nextAiringEpisode?.episode,
                description: schedule.media.description,
                airingAt: schedule.media.nextAiringEpisode?.airingAt
            )
        }
    }
    
    func fetchAnimeDetails(animeID: Int) async throws -> AniListMediaDetails {
        let variables: [String: Any] = ["id": animeID]
        let data = try await performRequest(query: detailsQuery, variables: variables)
        let response = try decoder.decode(GraphQLResponse<DetailsData>.self, from: data)
        return response.data.Media
    }
    
    func fetchID(byTitle title: String) async throws -> Int {
        let query = """
      query($search: String) {
        Media(search: $search, type: ANIME) {
        id
        }
      }
      """
        
        let variables: [String: Any] = ["search": title]
        let data = try await performRequest(query: query, variables: variables)
        let wrapper = try decoder.decode(GraphQLResponse<MediaIdData>.self, from: data)
        return wrapper.data.Media.id
    }
    
    private struct MediaIdData: Decodable {
        let Media: MediaId
    }
    
    private struct MediaId: Decodable {
        let id: Int
    }
    
    private func performRequest(query: String, variables: [String: Any]? = nil) async throws -> Data {
        var payload: [String: Any] = ["query": query]
        if let variables {
            payload["variables"] = variables
        }
        
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (data, response) = try await URLSession.custom.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw AniListServiceError.invalidResponse
        }
        
        return data
    }
    
    private func currentSeasonInfo() -> (season: String, year: Int) {
        let month = Calendar.current.component(.month, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        
        let season: String
        switch month {
        case 12, 1, 2:
            season = "WINTER"
        case 3, 4, 5:
            season = "SPRING"
        case 6, 7, 8:
            season = "SUMMER"
        default:
            season = "FALL"
        }
        
        return (season, year)
    }
    
    private struct GraphQLResponse<T: Decodable>: Decodable {
        let data: T
    }
    
    private struct TrendingData: Decodable {
        let Page: TrendingPage
    }
    
    private struct TrendingPage: Decodable {
        let media: [AniListMedia]
    }
    
    private struct AiringData: Decodable {
        let Page: AiringPage
    }
    
    private struct AiringPage: Decodable {
        let airingSchedules: [AiringSchedule]
    }
    
    private struct AiringSchedule: Decodable {
        let media: AniListMedia
    }
    
    private struct DetailsData: Decodable {
        let Media: AniListMediaDetails
    }
    
    private enum AniListServiceError: Error {
        case invalidResponse
    }
    
    private var includeAdultContent: Bool {
        UserDefaults.standard.bool(forKey: "filterNSFW")
    }
    
    // MARK: - GraphQL
    
    private let trendingQueryFiltered = """
    query {
      Page(page: 1, perPage: 100) {
        media(sort: TRENDING_DESC, type: ANIME, isAdult: false) {
          id
          title {
            romaji
            english
            native
            userPreferred
          }
          coverImage {
            large
            extraLarge
          }
          isAdult
        }
      }
    }
    """
    
    private let trendingQueryAll = """
    query {
      Page(page: 1, perPage: 100) {
        media(sort: TRENDING_DESC, type: ANIME) {
          id
          title {
            romaji
            english
            native
            userPreferred
          }
          coverImage {
            large
            extraLarge
          }
          isAdult
        }
      }
    }
    """
    
    private let seasonalQueryFiltered = """
    query($season: MediaSeason, $seasonYear: Int) {
      Page(page: 1, perPage: 100) {
        media(season: $season, seasonYear: $seasonYear, type: ANIME, isAdult: false) {
          id
          title {
            romaji
            english
            native
            userPreferred
          }
          coverImage {
            large
            extraLarge
          }
          isAdult
        }
      }
    }
    """
    
    private let seasonalQueryAll = """
    query($season: MediaSeason, $seasonYear: Int) {
      Page(page: 1, perPage: 100) {
        media(season: $season, seasonYear: $seasonYear, type: ANIME) {
          id
          title {
            romaji
            english
            native
            userPreferred
          }
          coverImage {
            large
            extraLarge
          }
          isAdult
        }
      }
    }
    """
    
    private let airingQuery = """
    query($page: Int, $perPage: Int, $startTime: Int, $endTime: Int) {
      Page(page: $page, perPage: $perPage) {
        airingSchedules(
          sort: [TIME],
          airingAt_greater: $startTime,
          airingAt_lesser: $endTime
        ) {
          media {
            id
            title {
              romaji
              english
              native
              userPreferred
            }
            description
            coverImage {
              extraLarge
              large
            }
            isAdult
            nextAiringEpisode {
              episode
              airingAt
            }
          }
        }
      }
    }
    """
    
    private let detailsQuery = """
    query($id: Int) {
      Media(id: $id, type: ANIME) {
        id
        title {
          romaji
          english
          native
          userPreferred
        }
        description
        coverImage {
          extraLarge
          large
        }
        bannerImage
        genres
        episodes
        duration
        season
        status
        siteUrl
      }
    }
    """
}
