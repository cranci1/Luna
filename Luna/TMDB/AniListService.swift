import Foundation

final class AniListService {
    static let shared = AniListService()

    private let graphQLEndpoint = URL(string: "https://graphql.anilist.co")!
    private var preferredLanguageCode: String {
        let raw = UserDefaults.standard.string(forKey: "tmdbLanguage") ?? "en-US"
        return raw.split(separator: "-").first.map(String.init) ?? "en"
    }

    enum AniListCatalogKind {
        case trending
        case popular
        case topRated
        case airing
        case upcoming
    }

    // MARK: - Catalog Fetching

    /// Fetch a lightweight AniList catalog and hydrate entries with TMDB matches for posters/details.
    func fetchAnimeCatalog(
        _ kind: AniListCatalogKind,
        limit: Int = 20,
        tmdbService: TMDBService
    ) async throws -> [TMDBSearchResult] {
        let sort: String
        let status: String?

        switch kind {
        case .trending:
            sort = "TRENDING_DESC"
            status = nil
        case .popular:
            sort = "POPULARITY_DESC"
            status = nil
        case .topRated:
            sort = "SCORE_DESC"
            status = nil
        case .airing:
            sort = "POPULARITY_DESC"
            status = "RELEASING"
        case .upcoming:
            sort = "POPULARITY_DESC"
            status = "NOT_YET_RELEASED"
        }

        let statusClause = status.map { ", status: \($0)" } ?? ""

        let query = """
        query {
            Page(perPage: \(limit)) {
                media(type: ANIME, sort: [\(sort)]\(statusClause)) {
                    id
                    title { romaji english native }
                    episodes
                    status
                    seasonYear
                    season
                    coverImage { large medium }
                    format
                }
            }
        }
        """

        struct CatalogResponse: Codable {
            let data: DataWrapper
            struct DataWrapper: Codable { let Page: PageData }
            struct PageData: Codable { let media: [AniListAnime] }
        }

        let data = try await executeGraphQLQuery(query, token: nil)
        let decoded = try JSONDecoder().decode(CatalogResponse.self, from: data)
        let animeList = decoded.data.Page.media
        return await mapAniListCatalogToTMDB(animeList, tmdbService: tmdbService)
    }

    // MARK: - Airing Schedule

    /// Fetch upcoming airing episodes for the next `daysAhead` days (default 7).
    func fetchAiringSchedule(daysAhead: Int = 7, perPage: Int = 100) async throws -> [AniListAiringScheduleEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let today = calendar.startOfDay(for: Date())
        let upperDay = calendar.date(byAdding: .day, value: max(daysAhead, 1) + 1, to: today) ?? today

        let lowerBound = Int(today.timeIntervalSince1970)
        let upperBound = Int(upperDay.timeIntervalSince1970)

        let query = """
        query {
            Page(perPage: \(perPage)) {
                airingSchedules(airingAt_greater: \(lowerBound - 1), airingAt_lesser: \(upperBound), sort: TIME) {
                    id
                    airingAt
                    episode
                    media {
                        id
                        title { romaji english native }
                        coverImage { large medium }
                    }
                }
            }
        }
        """

        struct Response: Codable {
            let data: DataWrapper
            struct DataWrapper: Codable { let Page: PageData }
            struct PageData: Codable { let airingSchedules: [AiringSchedule] }
            struct AiringSchedule: Codable {
                let id: Int
                let airingAt: Int
                let episode: Int
                let media: AniListAnime
            }
        }

        let data = try await executeGraphQLQuery(query, token: nil)
        let decoded = try JSONDecoder().decode(Response.self, from: data)

        let start = today
        let end = upperDay

        return decoded.data.Page.airingSchedules
            .map { schedule in
                let title = AniListTitlePicker.title(from: schedule.media.title, preferredLanguageCode: preferredLanguageCode)
                let cover = schedule.media.coverImage?.large ?? schedule.media.coverImage?.medium
                return AniListAiringScheduleEntry(
                    id: schedule.id,
                    mediaId: schedule.media.id,
                    title: title,
                    airingAt: Date(timeIntervalSince1970: TimeInterval(schedule.airingAt)),
                    episode: schedule.episode,
                    coverImage: cover
                )
            }
            .filter { entry in
                entry.airingAt >= start && entry.airingAt < end
            }
    }

    // MARK: - Fetch Anime Details

    /// Fetch minimal anime info (title and cover) by AniList ID
    func fetchAnimeBasicInfo(anilistId: Int) async throws -> AniListBasicInfo {
        let query = """
        query {
            Media(id: \(anilistId), type: ANIME) {
                id
                title { romaji english native }
                coverImage { large medium }
            }
        }
        """

        struct Response: Codable {
            let data: DataWrapper
            struct DataWrapper: Codable { let Media: MediaData? }
            struct MediaData: Codable {
                let id: Int
                let title: AniListAnime.AniListTitle
                let coverImage: AniListAnime.AniListCoverImage?
            }
        }

        let data = try await executeGraphQLQuery(query, token: nil)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let media = decoded.data.Media else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "AniList title not found for id \(anilistId)"])
        }

        let title = AniListTitlePicker.title(from: media.title, preferredLanguageCode: preferredLanguageCode)
        let cover = media.coverImage?.large ?? media.coverImage?.medium
        return AniListBasicInfo(id: media.id, title: title, coverImage: cover)
    }

    /// Fetch full anime details with seasons and episodes from AniList + TMDB
    /// Uses AniList for season structure and sequels, TMDB for episode details
    func fetchAnimeDetailsWithEpisodes(
        title: String,
        tmdbShowId: Int,
        tmdbService: TMDBService,
        tmdbShowPoster: String?,
        token: String?
    ) async throws -> AniListAnimeWithSeasons {
        let query = """
        query {
            Page(perPage: 6) {
                media(search: "\(title.replacingOccurrences(of: "\"", with: "\\\""))", type: ANIME, sort: POPULARITY_DESC) {
                    id
                    title {
                        romaji
                        english
                        native
                    }
                    episodes
                    status
                    seasonYear
                    season
                    coverImage {
                        large
                        medium
                    }
                    format
                    nextAiringEpisode {
                        episode
                        airingAt
                    }
                    relations {
                        edges {
                            relationType
                            node {
                                id
                                title {
                                    romaji
                                    english
                                    native
                                }
                                episodes
                                status
                                seasonYear
                                season
                                format
                                type
                                coverImage {
                                    large
                                    medium
                                }
                                relations {
                                    edges {
                                        relationType
                                        node {
                                            id
                                            title { romaji english native }
                                            episodes
                                            status
                                            seasonYear
                                            season
                                            format
                                            type
                                            coverImage { large medium }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        """

        let response = try await executeGraphQLQuery(query, token: token)

        struct Response: Codable {
            let data: DataWrapper
            struct DataWrapper: Codable {
                let Page: PageData
                struct PageData: Codable { let media: [AniListAnime] }
            }
        }

        let result = try JSONDecoder().decode(Response.self, from: response)
        let candidates = result.data.Page.media
        guard !candidates.isEmpty else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "AniList did not return any matches for \(title)"])
        }

        let tvShowDetail: TMDBTVShowWithSeasons? = await {
            do {
                return try await tmdbService.getTVShowWithSeasons(id: tmdbShowId)
            } catch {
                Logger.shared.log("AniListService: Failed to prefetch TMDB show details: \(error.localizedDescription)", type: "TMDB")
                return nil
            }
        }()

        let anime = pickBestAniListMatch(from: candidates, tmdbShow: tvShowDetail)

        let pickedTitle = AniListTitlePicker.title(from: anime.title, preferredLanguageCode: preferredLanguageCode)
        Logger.shared.log("AniListService: Selected AniList match '\(pickedTitle)' (id: \(anime.id))", type: "AniList")
        let seasonVal = anime.season ?? "UNKNOWN"
        Logger.shared.log(
            "AniListService: Raw response - episodes: \(anime.episodes ?? 0), seasonYear: \(anime.seasonYear ?? 0), season: \(seasonVal)",
            type: "AniList"
        )

        var allAnimeToProcess: [(anime: AniListAnime, seasonOffset: Int, posterUrl: String?)] = []

        func appendAnime(_ entry: AniListAnime) {
            let poster = entry.coverImage?.large ?? entry.coverImage?.medium ?? tmdbShowPoster
            allAnimeToProcess.append((entry, 0, poster))
        }

        appendAnime(anime)

        Logger.shared.log("AniListService: Starting sequel detection for \(AniListTitlePicker.title(from: anime.title, preferredLanguageCode: preferredLanguageCode)) (ID: \(anime.id), episodes: \(anime.episodes ?? 0), relations: \(anime.relations?.edges.count ?? 0))", type: "AniList")

        let allowedRelationTypes: Set<String> = ["SEQUEL", "PREQUEL", "SEASON"]

        var queue: [AniListAnime] = [anime]
        var seenIds = Set<Int>([anime.id])

        while let current = queue.first {
            queue.removeFirst()

            let currentTitle = AniListTitlePicker.title(from: current.title, preferredLanguageCode: preferredLanguageCode)
            let edges = current.relations?.edges ?? []
            Logger.shared.log("AniListService: Checking relations for '\(currentTitle)': \(edges.count) edges total", type: "AniList")

            for edge in edges {
                let edgeTitle = AniListTitlePicker.title(from: edge.node.title, preferredLanguageCode: preferredLanguageCode)
                Logger.shared.log("  Edge: type=\(edge.relationType) nodeType=\(edge.node.type ?? "nil") format=\(edge.node.format ?? "nil") title=\(edgeTitle)", type: "AniList")

                guard allowedRelationTypes.contains(edge.relationType), edge.node.type == "ANIME" else {
                    Logger.shared.log("    → Skipped: relationType or nodeType mismatch", type: "AniList")
                    continue
                }
                if let format = edge.node.format, !(format == "TV" || format == "TV_SHORT" || format == "ONA") {
                    Logger.shared.log("    → Skipped: format not TV/TV_SHORT/ONA (\(format))", type: "AniList")
                    continue
                }
                if !seenIds.insert(edge.node.id).inserted {
                    Logger.shared.log("    → Skipped: already processed", type: "AniList")
                    continue
                }

                Logger.shared.log("    → Added sequel: \(edgeTitle)", type: "AniList")

                let fullNode: AniListAnime
                if edge.node.relations != nil {
                    fullNode = edge.node.asAnime()
                } else if let fetched = try? await fetchAniListAnimeNode(id: edge.node.id) {
                    fullNode = fetched
                } else {
                    fullNode = edge.node.asAnime()
                }

                appendAnime(fullNode)
                queue.append(fullNode)
            }
        }

        var tmdbEpisodesByAbsolute: [Int: TMDBEpisode] = [:]
        if let tvShowDetail {
            var absoluteIndex = 1
            let realSeasons = tvShowDetail.seasons.filter { $0.seasonNumber > 0 }.sorted { $0.seasonNumber < $1.seasonNumber }
            for season in realSeasons {
                do {
                    let seasonDetail = try await tmdbService.getSeasonDetails(tvShowId: tmdbShowId, seasonNumber: season.seasonNumber)
                    Logger.shared.log("AniListService: TMDB season \(season.seasonNumber) returned \(seasonDetail.episodes.count) episodes", type: "AniList")
                    for episode in seasonDetail.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                        tmdbEpisodesByAbsolute[absoluteIndex] = episode
                        if absoluteIndex <= 3 {
                            Logger.shared.log("  Episode \(episode.episodeNumber): '\(episode.name)', overview: \(episode.overview?.isEmpty == false ? "YES" : "NO"), stillPath: \(episode.stillPath != nil ? "YES" : "NO")", type: "AniList")
                        }
                        absoluteIndex += 1
                    }
                } catch {
                    Logger.shared.log("AniListService: Failed to fetch TMDB season \(season.seasonNumber): \(error.localizedDescription)", type: "AniList")
                }
            }
        }

        if tmdbEpisodesByAbsolute.isEmpty {
            Logger.shared.log("AniListService: No TMDB episodes loaded; attempting direct season fetch", type: "AniList")
            var absoluteIndex = 1
            var seasonNumber = 1
            while true {
                do {
                    let seasonDetail = try await tmdbService.getSeasonDetails(tvShowId: tmdbShowId, seasonNumber: seasonNumber)
                    if seasonDetail.episodes.isEmpty {
                        Logger.shared.log("AniListService: Fallback found empty season \(seasonNumber), stopping", type: "AniList")
                        break
                    }
                    for episode in seasonDetail.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                        tmdbEpisodesByAbsolute[absoluteIndex] = episode
                        absoluteIndex += 1
                    }
                    Logger.shared.log("AniListService: Fallback fetched season \(seasonNumber): \(seasonDetail.episodes.count) episodes", type: "AniList")
                    seasonNumber += 1
                } catch {
                    Logger.shared.log("AniListService: Fallback stopped at season \(seasonNumber) (no more seasons found)", type: "AniList")
                    break
                }
            }
        }

        var seasons: [AniListSeasonWithPoster] = []
        var currentAbsoluteEpisode = 1
        var seasonIndex = 1

        for (currentAnime, _, posterUrl) in allAnimeToProcess {
            let seasonTitle = AniListTitlePicker.title(from: currentAnime.title, preferredLanguageCode: preferredLanguageCode)
            let anilistEpisodeCount = currentAnime.episodes ?? 0

            let totalEpisodesInAnime: Int
            if anilistEpisodeCount > 0 {
                totalEpisodesInAnime = anilistEpisodeCount
                Logger.shared.log("AniListService: Season \(seasonIndex) '\(seasonTitle)' using AniList count: \(totalEpisodesInAnime) episodes", type: "AniList")
            } else {
                let remainingTmdb = max(0, tmdbEpisodesByAbsolute.count - (currentAbsoluteEpisode - 1))
                totalEpisodesInAnime = remainingTmdb > 0 ? remainingTmdb : 12
                Logger.shared.log("AniListService: Season \(seasonIndex) '\(seasonTitle)' AniList has no count, falling back to: \(totalEpisodesInAnime) episodes", type: "AniList")
            }

            let seasonEpisodes: [AniListEpisode] = (0..<totalEpisodesInAnime).map { offset in
                let absoluteEp = currentAbsoluteEpisode + offset
                let localEp = offset + 1
                if let tmdbEp = tmdbEpisodesByAbsolute[absoluteEp] {
                    return AniListEpisode(
                        number: localEp,
                        title: tmdbEp.name,
                        description: tmdbEp.overview,
                        seasonNumber: seasonIndex,
                        stillPath: tmdbEp.stillPath,
                        airDate: tmdbEp.airDate,
                        runtime: tmdbEp.runtime
                    )
                } else {
                    return AniListEpisode(
                        number: localEp,
                        title: "Episode \(localEp)",
                        description: nil,
                        seasonNumber: seasonIndex,
                        stillPath: nil,
                        airDate: nil,
                        runtime: nil
                    )
                }
            }

            seasons.append(AniListSeasonWithPoster(
                seasonNumber: seasonIndex,
                anilistId: currentAnime.id,
                title: seasonTitle,
                episodes: seasonEpisodes,
                posterUrl: posterUrl
            ))

            currentAbsoluteEpisode += totalEpisodesInAnime
            seasonIndex += 1
        }

        let totalEpisodes = seasons.reduce(0) { $0 + $1.episodes.count }
        Logger.shared.log("AniListService: Fetched \(title) with \(totalEpisodes) total episodes grouped into \(seasons.count) seasons", type: "AniList")
        for season in seasons {
            Logger.shared.log("  Season \(season.seasonNumber): \(season.episodes.count) episodes, poster: \(season.posterUrl ?? "none")", type: "AniList")
        }

        return AniListAnimeWithSeasons(
            id: anime.id,
            title: pickedTitle,
            seasons: seasons,
            totalEpisodes: totalEpisodes,
            status: anime.status ?? "UNKNOWN"
        )
    }

    private func pickBestAniListMatch(from candidates: [AniListAnime], tmdbShow: TMDBTVShowWithSeasons?) -> AniListAnime {
        let allowedFormats: Set<String> = ["TV", "TV_SHORT", "OVA", "ONA"]
        let formatFiltered = candidates.filter { anime in
            guard let format = anime.format else { return false }
            return allowedFormats.contains(format)
        }

        let pool = formatFiltered.isEmpty ? candidates : formatFiltered

        guard let tmdbShow else {
            return pool.sorted(by: { lhs, rhs in
                let lhsEpisodes = lhs.episodes ?? 0
                let rhsEpisodes = rhs.episodes ?? 0
                if lhsEpisodes != rhsEpisodes { return lhsEpisodes > rhsEpisodes }
                return lhs.id < rhs.id
            }).first ?? candidates.first!
        }

        let tmdbYear = tmdbShow.firstAirDate.flatMap { dateStr in
            Int(String(dateStr.prefix(4)))
        }
        let tmdbEpisodes = tmdbShow.numberOfEpisodes

        let yearFiltered: [AniListAnime]
        if let tmdbYear {
            let exactYear = pool.filter { $0.seasonYear == tmdbYear }
            yearFiltered = exactYear.isEmpty ? pool : exactYear
        } else {
            yearFiltered = pool
        }

        let chosen: AniListAnime?
        if let tmdbEpisodes {
            chosen = yearFiltered.min(by: { lhs, rhs in
                let lhsEpisodes = lhs.episodes ?? 0
                let rhsEpisodes = rhs.episodes ?? 0
                let lhsDiff = abs(lhsEpisodes - tmdbEpisodes)
                let rhsDiff = abs(rhsEpisodes - tmdbEpisodes)
                if lhsDiff != rhsDiff { return lhsDiff < rhsDiff }
                if lhsEpisodes != rhsEpisodes { return lhsEpisodes > rhsEpisodes }
                return lhs.id < rhs.id
            })
        } else {
            chosen = yearFiltered.sorted(by: { lhs, rhs in
                let lhsEpisodes = lhs.episodes ?? 0
                let rhsEpisodes = rhs.episodes ?? 0
                if lhsEpisodes != rhsEpisodes { return lhsEpisodes > rhsEpisodes }
                return lhs.id < rhs.id
            }).first
        }

        return chosen ?? candidates.first!
    }

    // MARK: - Update Watch Progress

    func updateAnimeProgress(
        mediaId: Int,
        episodeNumber: Int,
        token: String
    ) async throws {
        let mutation = """
        mutation {
            SaveMediaListEntry(mediaId: \(mediaId), progress: \(episodeNumber)) {
                id
                progress
            }
        }
        """

        _ = try await executeGraphQLQuery(mutation, token: token)
    }

    // MARK: - Search Anime

    func searchAnime(query: String, token: String?) async throws -> [AniListSearchResult] {
        let graphQLQuery = """
        query {
            Page(perPage: 10) {
                media(search: "\(query.replacingOccurrences(of: "\"", with: "\\\""))", type: ANIME, sort: POPULARITY_DESC) {
                    id
                    title {
                        romaji
                        english
                    }
                    episodes
                    coverImage {
                        medium
                    }
                    status
                }
            }
        }
        """

        let response = try await executeGraphQLQuery(graphQLQuery, token: token)

        struct Response: Codable {
            let data: DataWrapper
            struct DataWrapper: Codable {
                let Page: PageData
                struct PageData: Codable {
                    let media: [AniListAnime]
                }
            }
        }

        let result = try JSONDecoder().decode(Response.self, from: response)
        return result.data.Page.media.map { AniListSearchResult(from: $0, preferredLanguageCode: preferredLanguageCode) }
    }

    // MARK: - Catalog Mapping Helpers

    private func mapAniListCatalogToTMDB(_ animeList: [AniListAnime], tmdbService: TMDBService) async -> [TMDBSearchResult] {
        func normalized(_ value: String) -> String {
            return value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }

        let langCode = self.preferredLanguageCode

        return await withTaskGroup(of: TMDBSearchResult?.self) { group in
            for anime in animeList {
                group.addTask {
                    let titleCandidates = AniListTitlePicker.titleCandidates(from: anime.title)
                    let expectedYear = anime.seasonYear

                    var bestMatch: TMDBTVShow?

                    for candidate in titleCandidates where !candidate.isEmpty {
                        guard let results = try? await tmdbService.searchTVShows(query: candidate), !results.isEmpty else { continue }
                        let candidateKey = normalized(candidate)

                        let exactMatches = results.filter { normalized($0.name) == candidateKey }
                        if !exactMatches.isEmpty {
                            let bestExact = exactMatches.min { a, b in
                                let aYear = Int(a.firstAirDate?.prefix(4) ?? "")
                                let bYear = Int(b.firstAirDate?.prefix(4) ?? "")

                                if let expectedYear {
                                    let aDiff = aYear.map { abs($0 - expectedYear) } ?? 10000
                                    let bDiff = bYear.map { abs($0 - expectedYear) } ?? 10000
                                    if aDiff != bDiff { return aDiff < bDiff }
                                }

                                let aHasAnimation = a.genreIds?.contains(16) == true
                                let bHasAnimation = b.genreIds?.contains(16) == true
                                if aHasAnimation != bHasAnimation { return aHasAnimation }

                                let aHasPoster = a.posterPath != nil
                                let bHasPoster = b.posterPath != nil
                                if aHasPoster != bHasPoster { return aHasPoster }

                                return a.popularity > b.popularity
                            }
                            if let best = bestExact {
                                bestMatch = best
                                break
                            }
                        }

                        let partialMatches = results.filter {
                            let nameKey = normalized($0.name)
                            return nameKey.contains(candidateKey) || candidateKey.contains(nameKey)
                        }
                        if !partialMatches.isEmpty {
                            let best = partialMatches.min { a, b in
                                if let expectedYear {
                                    let aYear = Int(a.firstAirDate?.prefix(4) ?? "")
                                    let bYear = Int(b.firstAirDate?.prefix(4) ?? "")
                                    let aDiff = aYear.map { abs($0 - expectedYear) } ?? 10000
                                    let bDiff = bYear.map { abs($0 - expectedYear) } ?? 10000
                                    if aDiff != bDiff { return aDiff < bDiff }
                                }

                                let aHasAnimation = a.genreIds?.contains(16) == true
                                let bHasAnimation = b.genreIds?.contains(16) == true
                                if aHasAnimation != bHasAnimation { return aHasAnimation }

                                let aHasPoster = a.posterPath != nil
                                let bHasPoster = b.posterPath != nil
                                if aHasPoster != bHasPoster { return aHasPoster }

                                return a.popularity > b.popularity
                            }
                            if let best = best {
                                bestMatch = best
                                break
                            }
                        }

                        if bestMatch == nil {
                            let best = results.min { a, b in
                                let aHasAnimation = a.genreIds?.contains(16) == true
                                let bHasAnimation = b.genreIds?.contains(16) == true
                                if aHasAnimation != bHasAnimation { return aHasAnimation }

                                let aHasPoster = a.posterPath != nil
                                let bHasPoster = b.posterPath != nil
                                if aHasPoster != bHasPoster { return aHasPoster }

                                return a.popularity > b.popularity
                            }
                            bestMatch = best
                        }
                    }

                    if let bestMatch = bestMatch {
                        let aniTitle = AniListTitlePicker.title(from: anime.title, preferredLanguageCode: langCode)
                        Logger.shared.log("AniListService: Matched '\(aniTitle)' → TMDB '\(bestMatch.name)' (ID: \(bestMatch.id))", type: "AniList")
                    }
                    return bestMatch?.asSearchResult
                }
            }

            var results: [TMDBSearchResult] = []
            var seenIds = Set<Int>()
            for await match in group {
                if let match = match, !seenIds.contains(match.id) {
                    seenIds.insert(match.id)
                    results.append(match)
                }
            }
            return results
        }
    }

    // MARK: - MAL ID to AniList ID Conversion

    /// Convert MyAnimeList ID to AniList ID for tracking purposes
    func getAniListId(fromMalId malId: Int) async throws -> Int? {
        let query = """
        query {
            Media(idMal: \(malId), type: ANIME) {
                id
            }
        }
        """

        struct Response: Codable {
            let data: DataWrapper?
            struct DataWrapper: Codable {
                let Media: MediaData?
                struct MediaData: Codable {
                    let id: Int
                }
            }
        }

        do {
            let data = try await executeGraphQLQuery(query, token: nil)
            let result = try JSONDecoder().decode(Response.self, from: data)
            return result.data?.Media?.id
        } catch {
            Logger.shared.log("AniListService: Failed to convert MAL ID \(malId) to AniList ID: \(error.localizedDescription)", type: "AniList")
            return nil
        }
    }

    // MARK: - Private Helpers

    private func executeGraphQLQuery(_ query: String, token: String?) async throws -> Data {
        var request = URLRequest(url: graphQLEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                let error = "AniList error (HTTP \(httpResponse.statusCode))"
                throw NSError(domain: "AniList", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: error])
            }
            throw NSError(domain: "AniList", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch from AniList"])
        }

        return data
    }

    /// Fetch a single anime node with relations for deeper traversal
    private func fetchAniListAnimeNode(id: Int) async throws -> AniListAnime {
        let query = """
        query {
            Media(id: \(id), type: ANIME) {
                id
                title { romaji english native }
                episodes
                status
                seasonYear
                season
                format
                type
                coverImage { large medium }
                relations {
                    edges {
                        relationType
                        node {
                            id
                            title { romaji english native }
                            episodes
                            status
                            seasonYear
                            season
                            format
                            type
                            coverImage { large medium }
                        }
                    }
                }
            }
        }
        """

        struct Response: Codable {
            let data: DataWrapper
            struct DataWrapper: Codable {
                let Media: AniListAnime
            }
        }

        let data = try await executeGraphQLQuery(query, token: nil)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.data.Media
    }

    /// Search for a TV/TV_SHORT anime by title, preferring those formats
    private func fetchAniListAnimeBySearch(
        _ title: String,
        formats: [String],
        expectedEpisodeCount: Int?,
        preferredSeasonYear: Int?
    ) async throws -> AniListAnime? {
        let query = """
        query {
            Page(perPage: 25) {
                media(search: \"\(title.replacingOccurrences(of: "\"", with: "\\\""))\", type: ANIME, sort: POPULARITY_DESC) {
                    id
                    title { romaji english native }
                    episodes
                    status
                    seasonYear
                    season
                    format
                    type
                    coverImage { large medium }
                    relations {
                        edges {
                            relationType
                            node {
                                id
                                title { romaji english native }
                                episodes
                                status
                                seasonYear
                                season
                                format
                                type
                                coverImage { large medium }
                            }
                        }
                    }
                }
            }
        }
        """

        struct Response: Codable {
            let data: DataWrapper
            struct DataWrapper: Codable {
                let Page: PageData
                struct PageData: Codable {
                    let media: [AniListAnime]
                }
            }
        }

        let data = try await executeGraphQLQuery(query, token: nil)
        let decoded = try JSONDecoder().decode(Response.self, from: data)

        let allowedFormats = Set(formats)
        var results = decoded.data.Page.media.filter { allowedFormats.contains($0.format ?? "") }

        Logger.shared.log("AniListService: TV search found \(results.count) results (from \(decoded.data.Page.media.count) total)", type: "AniList")
        for (idx, result) in results.prefix(3).enumerated() {
            let resultTitle = AniListTitlePicker.title(from: result.title, preferredLanguageCode: preferredLanguageCode)
            let formatText = result.format ?? "nil"
            let episodeText = result.episodes ?? 0
            Logger.shared.log("  [\(idx + 1)] ID: \(result.id), Format: \(formatText), Episodes: \(episodeText), Title: \(resultTitle)", type: "AniList")
        }

        guard !results.isEmpty else { return nil }

        func normalized(_ value: String) -> String {
            return value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }

        let queryKey = normalized(title)
        let queryHasPart = queryKey.contains("part")
        let queryHasSeason = queryKey.contains("season")
        let queryHasDigits = queryKey.rangeOfCharacter(from: .decimalDigits) != nil
        let queryHasQualifier = queryHasPart || queryHasSeason || queryHasDigits

        func titleMatchScore(for anime: AniListAnime) -> Int {
            let candidates = AniListTitlePicker.titleCandidates(from: anime.title)
            for candidate in candidates {
                let candidateKey = normalized(candidate)
                if candidateKey.contains(queryKey) || queryKey.contains(candidateKey) {
                    return 120
                }
            }
            return 0
        }

        func statusScore(_ status: String?) -> Int {
            switch status ?? "" {
            case "FINISHED": return 60
            case "RELEASING": return 40
            case "NOT_YET_RELEASED": return queryHasQualifier ? -60 : -120
            default: return 0
            }
        }

        func formatScore(for anime: AniListAnime) -> Int {
            switch anime.format ?? "" {
            case "TV": return 120
            case "TV_SHORT": return 60
            case "ONA": return -40
            default: return -20
            }
        }

        func seasonYearScore(for anime: AniListAnime) -> Int {
            guard let expectedYear = preferredSeasonYear, let year = anime.seasonYear else { return 0 }

            if expectedYear == year {
                return 500
            }

            let diff = abs(expectedYear - year)
            if diff <= 2 {
                return 200 - diff * 50
            } else if diff <= 5 {
                return 100 - diff * 20
            } else {
                return max(0, 50 - diff * 10)
            }
        }

        func episodesHintScore(for anime: AniListAnime) -> Int {
            guard let expected = expectedEpisodeCount, expected > 0 else { return 0 }
            let candidate = anime.episodes ?? 0
            if candidate == 0 { return -180 }
            let diff = abs(expected - candidate)
            let closeness = max(0, 240 - min(diff, expected) * 3)
            return closeness
        }

        func penalty(for anime: AniListAnime) -> Int {
            let title = AniListTitlePicker.title(from: anime.title, preferredLanguageCode: preferredLanguageCode).lowercased()
            var total = 0

            if !queryHasPart && title.contains("part") {
                total += 260
            }
            if !queryHasSeason && title.contains("season") {
                total += 160
            }

            if !queryHasDigits {
                let regex = try? NSRegularExpression(pattern: "\\d+", options: [])
                let range = NSRange(location: 0, length: title.utf16.count)
                let digitMatches = regex?.matches(in: title, options: [], range: range) ?? []

                let nonYearDigits = digitMatches.contains { match in
                    let matchRange = match.range
                    guard let swiftRange = Range(matchRange, in: title) else { return false }
                    let chunk = String(title[swiftRange])
                    if chunk.count == 4, let year = Int(chunk), (1980...2050).contains(year) {
                        return false
                    }
                    return true
                }

                if nonYearDigits {
                    total += 80
                }
            }

            if !queryHasQualifier, let status = anime.status, status == "NOT_YET_RELEASED" {
                total += 220
            }

            return total
        }

        func score(for anime: AniListAnime) -> Int {
            let episodesScore = (anime.episodes ?? 0) * 6
            let titleScore = titleMatchScore(for: anime)

            let exactMatchBonus: Int = {
                let candidateKey = normalized(AniListTitlePicker.title(from: anime.title, preferredLanguageCode: preferredLanguageCode))
                return candidateKey == queryKey ? 200 : 0
            }()

            return episodesScore
                + statusScore(anime.status)
                + titleScore
                + exactMatchBonus
                + formatScore(for: anime)
                + seasonYearScore(for: anime)
                + episodesHintScore(for: anime)
                - penalty(for: anime)
        }

        let best = results.max { lhs, rhs in
            return score(for: lhs) < score(for: rhs)
        }

        if let best {
            let pickedTitle = AniListTitlePicker.title(from: best.title, preferredLanguageCode: preferredLanguageCode)
            Logger.shared.log("AniListService: Picked TV candidate ID \(best.id) (score: \(score(for: best))) title: \(pickedTitle)", type: "AniList")
        }

        return best
    }
}

// MARK: - Helper Models

protocol AniListEpisodeProtocol {
    var number: Int { get }
    var title: String { get }
    var description: String? { get }
    var seasonNumber: Int { get }
}

struct AniListEpisode: AniListEpisodeProtocol {
    let number: Int
    let title: String
    let description: String?
    let seasonNumber: Int
    let stillPath: String?
    let airDate: String?
    let runtime: Int?
}

struct AniListAiringScheduleEntry: Identifiable {
    let id: Int
    let mediaId: Int
    let title: String
    let airingAt: Date
    let episode: Int
    let coverImage: String?
}

struct AniListSeasonWithPoster {
    let seasonNumber: Int
    let anilistId: Int
    let title: String
    let episodes: [AniListEpisode]
    let posterUrl: String?
}

struct AniListAnimeWithSeasons {
    let id: Int
    let title: String
    let seasons: [AniListSeasonWithPoster]
    let totalEpisodes: Int
    let status: String
}

struct AniListAnimeWithEpisodes {
    let id: Int
    let title: String
    let episodes: [AniListEpisode]
    let totalEpisodes: Int
    let status: String
}

struct AniListAnimeDetails {
    let id: Int
    let title: String
    let episodes: Int?
    let status: String

    init(from anime: AniListAnime, preferredLanguageCode: String) {
        self.id = anime.id
        self.title = AniListTitlePicker.title(from: anime.title, preferredLanguageCode: preferredLanguageCode)
        self.episodes = anime.episodes
        self.status = ""
    }
}

struct AniListSearchResult {
    let id: Int
    let title: String
    let episodes: Int?
    let coverImage: String?

    init(from anime: AniListAnime, preferredLanguageCode: String) {
        self.id = anime.id
        self.title = AniListTitlePicker.title(from: anime.title, preferredLanguageCode: preferredLanguageCode)
        self.episodes = anime.episodes
        self.coverImage = nil
    }
}

struct AniListBasicInfo {
    let id: Int
    let title: String
    let coverImage: String?
}

// MARK: - AniList Codable Models

struct AniListAnime: Codable {
    let id: Int
    let title: AniListTitle
    let episodes: Int?
    let status: String?
    let seasonYear: Int?
    let season: String?
    let coverImage: AniListCoverImage?
    let format: String?
    let type: String?
    let nextAiringEpisode: AniListNextAiringEpisode?
    let relations: AniListRelations?

    struct AniListTitle: Codable {
        let romaji: String?
        let english: String?
        let native: String?
    }

    struct AniListCoverImage: Codable {
        let large: String?
        let medium: String?
    }

    struct AniListNextAiringEpisode: Codable {
        let episode: Int?
        let airingAt: Int?
    }

    struct AniListRelations: Codable {
        let edges: [AniListRelationEdge]
    }

    struct AniListRelationEdge: Codable {
        let relationType: String
        let node: AniListRelationNode
    }

    struct AniListRelationNode: Codable {
        let id: Int
        let title: AniListTitle
        let episodes: Int?
        let status: String?
        let seasonYear: Int?
        let season: String?
        let format: String?
        let type: String?
        let coverImage: AniListCoverImage?
        let relations: AniListRelations?

        func asAnime() -> AniListAnime {
            return AniListAnime(
                id: id,
                title: title,
                episodes: episodes,
                status: status,
                seasonYear: seasonYear,
                season: season,
                coverImage: coverImage,
                format: format,
                type: type,
                nextAiringEpisode: nil,
                relations: relations
            )
        }
    }
}

enum AniListTitlePicker {
    private static func cleanTitle(_ title: String) -> String {
        let cleaned = title
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? title : cleaned
    }

    static func title(from title: AniListAnime.AniListTitle, preferredLanguageCode: String) -> String {
        let lang = preferredLanguageCode.lowercased()

        if lang.hasPrefix("en"), let english = title.english, !english.isEmpty {
            return cleanTitle(english)
        }

        if lang.hasPrefix("ja"), let native = title.native, !native.isEmpty {
            return cleanTitle(native)
        }

        if let english = title.english, !english.isEmpty {
            return cleanTitle(english)
        }

        if let romaji = title.romaji, !romaji.isEmpty {
            return cleanTitle(romaji)
        }

        if let native = title.native, !native.isEmpty {
            return cleanTitle(native)
        }

        return "Unknown"
    }

    static func titleCandidates(from title: AniListAnime.AniListTitle) -> [String] {
        var seen = Set<String>()
        let ordered = [title.english, title.romaji, title.native].compactMap { $0 }
        return ordered.compactMap { value in
            let cleaned = value
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .trimmingCharacters(in: .whitespaces)
            let finalValue = cleaned.isEmpty ? value : cleaned

            if seen.contains(finalValue) { return nil }
            seen.insert(finalValue)
            return finalValue
        }
    }
}
