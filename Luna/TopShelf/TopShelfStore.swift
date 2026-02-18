import Foundation

#if canImport(TVServices)
import TVServices
#endif

enum LunaAppGroup {
    // Update this if your App Group differs.
    static let identifier = "group.me.cranci.sora"

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

struct TopShelfContinueWatchingEntry: Codable, Identifiable {
    enum MediaKind: String, Codable {
        case movie
        case episode
    }

    let id: String
    let kind: MediaKind
    let tmdbId: Int
    let title: String
    let posterURL: String?
    let progress: Double
    let currentTime: Double
    let totalDuration: Double
    let lastUpdated: Date
    /// URL used when the user selects (clicks) the item.
    let displayLinkURL: String
    /// URL used when the user presses the Play button on the item.
    let playLinkURL: String
    /// Legacy field kept for backward compatibility with previously stored data.
    let deepLinkURL: String?

    // Episode-only
    let seasonNumber: Int?
    let episodeNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind, tmdbId, title, posterURL, progress, currentTime, totalDuration, lastUpdated
        case displayLinkURL, playLinkURL
        case deepLinkURL
        case seasonNumber, episodeNumber
    }

    init(
        id: String,
        kind: MediaKind,
        tmdbId: Int,
        title: String,
        posterURL: String?,
        progress: Double,
        currentTime: Double,
        totalDuration: Double,
        lastUpdated: Date,
        displayLinkURL: String,
        playLinkURL: String,
        deepLinkURL: String? = nil,
        seasonNumber: Int?,
        episodeNumber: Int?
    ) {
        self.id = id
        self.kind = kind
        self.tmdbId = tmdbId
        self.title = title
        self.posterURL = posterURL
        self.progress = progress
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.lastUpdated = lastUpdated
        self.displayLinkURL = displayLinkURL
        self.playLinkURL = playLinkURL
        self.deepLinkURL = deepLinkURL
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(MediaKind.self, forKey: .kind)
        tmdbId = try container.decode(Int.self, forKey: .tmdbId)
        title = try container.decode(String.self, forKey: .title)
        posterURL = try container.decodeIfPresent(String.self, forKey: .posterURL)
        progress = try container.decode(Double.self, forKey: .progress)
        currentTime = try container.decode(Double.self, forKey: .currentTime)
        totalDuration = try container.decode(Double.self, forKey: .totalDuration)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)

        let legacyDeepLink = try container.decodeIfPresent(String.self, forKey: .deepLinkURL)
        displayLinkURL = (try container.decodeIfPresent(String.self, forKey: .displayLinkURL)) ?? legacyDeepLink ?? "luna://"
        playLinkURL = (try container.decodeIfPresent(String.self, forKey: .playLinkURL)) ?? legacyDeepLink ?? "luna://"
        deepLinkURL = legacyDeepLink

        seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber)
        episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
    }
}

/// Lightweight export model so Top Shelf can be updated without depending on
/// ProgressManager's internal persistence types.
struct TopShelfProgressSnapshot {
    struct Movie: Codable {
        let id: Int
        let title: String
        let currentTime: Double
        let totalDuration: Double
        let progress: Double
        let isWatched: Bool
        let lastUpdated: Date
    }

    struct Episode: Codable {
        let id: String
        let showId: Int
        let seasonNumber: Int
        let episodeNumber: Int
        let currentTime: Double
        let totalDuration: Double
        let progress: Double
        let isWatched: Bool
        let lastUpdated: Date
    }

    let movies: [Movie]
    let episodes: [Episode]
}

@MainActor
final class TopShelfStore {
    static let shared = TopShelfStore()

    private init() {}

    private let continueWatchingKeyBase = "topShelf.continueWatching.v2"
    private let artworkCacheKeyBase = "topShelf.artworkCache.v1"

    private let watchedProgressThreshold: Double = 0.89

    private struct ArtworkCacheEntry: Codable {
        let title: String?
        let posterURL: String?
        let lastUpdated: Date
    }

    struct CachedArtwork {
        let title: String?
        let posterURL: String?
        let lastUpdated: Date
    }

    func updateArtworkCache(tmdbId: Int, kind: TopShelfContinueWatchingEntry.MediaKind, title: String?, posterURL: String?) {
        guard let defaults = LunaAppGroup.userDefaults else { return }
        var cache = loadArtworkCache(from: defaults)
        let key = cacheKey(tmdbId: tmdbId, kind: kind)

        let existing = cache[key]
        let mergedTitle = title ?? existing?.title
        let mergedPosterURL = posterURL ?? existing?.posterURL
        cache[key] = ArtworkCacheEntry(title: mergedTitle, posterURL: mergedPosterURL, lastUpdated: Date())
        saveArtworkCache(cache, to: defaults)
    }

    func cachedArtwork(tmdbId: Int, kind: TopShelfContinueWatchingEntry.MediaKind) -> CachedArtwork? {
        guard let defaults = LunaAppGroup.userDefaults else { return nil }
        let cache = loadArtworkCache(from: defaults)
        let key = cacheKey(tmdbId: tmdbId, kind: kind)
        guard let entry = cache[key] else { return nil }
        return CachedArtwork(title: entry.title, posterURL: entry.posterURL, lastUpdated: entry.lastUpdated)
    }

    func updateContinueWatching(from snapshot: TopShelfProgressSnapshot) {
        guard let defaults = LunaAppGroup.userDefaults else { return }

        let cache = loadArtworkCache(from: defaults)

        var items: [TopShelfContinueWatchingEntry] = []

        // Movies in progress
        for movie in snapshot.movies {
            guard movie.progress > 0, movie.progress < watchedProgressThreshold, movie.isWatched == false else { continue }

            let id = "movie_\(movie.id)"
            let cacheEntry = cache[cacheKey(tmdbId: movie.id, kind: .movie)]
            let clampedProgress = max(0, min(movie.progress, 1))

            let displayLink = "luna://details/movie/\(movie.id)"
            let playLink = "luna://play/movie/\(movie.id)?resumeTime=\(Int(movie.currentTime))"

            items.append(
                TopShelfContinueWatchingEntry(
                    id: id,
                    kind: .movie,
                    tmdbId: movie.id,
                    title: cacheEntry?.title ?? movie.title,
                    posterURL: cacheEntry?.posterURL,
                    progress: clampedProgress,
                    currentTime: movie.currentTime,
                    totalDuration: movie.totalDuration,
                    lastUpdated: movie.lastUpdated,
                    displayLinkURL: displayLink,
                    playLinkURL: playLink,
                    seasonNumber: nil,
                    episodeNumber: nil
                )
            )
        }

        // Episodes in progress
        for episode in snapshot.episodes {
            guard episode.progress > 0, episode.progress < watchedProgressThreshold, episode.isWatched == false else { continue }

            let id = episode.id
            let cacheEntry = cache[cacheKey(tmdbId: episode.showId, kind: .episode)]
            let clampedProgress = max(0, min(episode.progress, 1))

            let displayLink = "luna://details/tv/\(episode.showId)"
            let playLink = "luna://play/tv/\(episode.showId)/\(episode.seasonNumber)/\(episode.episodeNumber)?resumeTime=\(Int(episode.currentTime))"

            let title = cacheEntry?.title ?? "TV Show"

            items.append(
                TopShelfContinueWatchingEntry(
                    id: id,
                    kind: .episode,
                    tmdbId: episode.showId,
                    title: title,
                    posterURL: cacheEntry?.posterURL,
                    progress: clampedProgress,
                    currentTime: episode.currentTime,
                    totalDuration: episode.totalDuration,
                    lastUpdated: episode.lastUpdated,
                    displayLinkURL: displayLink,
                    playLinkURL: playLink,
                    seasonNumber: episode.seasonNumber,
                    episodeNumber: episode.episodeNumber
                )
            )
        }

        // Most recent first, cap to keep Top Shelf snappy.
        items.sort { $0.lastUpdated > $1.lastUpdated }
        if items.count > 10 { items = Array(items.prefix(10)) }

        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: scopedKey(continueWatchingKeyBase))

            #if canImport(TVServices)
            // Ask the system to refresh Top Shelf.
            TVTopShelfContentProvider.topShelfContentDidChange()
            #endif
        }
    }

    private func cacheKey(tmdbId: Int, kind: TopShelfContinueWatchingEntry.MediaKind) -> String {
        "\(kind.rawValue)_\(tmdbId)"
    }

    private func loadArtworkCache(from defaults: UserDefaults) -> [String: ArtworkCacheEntry] {
        guard let data = resolveData(for: artworkCacheKeyBase, defaults: defaults) else { return [:] }
        return (try? JSONDecoder().decode([String: ArtworkCacheEntry].self, from: data)) ?? [:]
    }

    private func saveArtworkCache(_ cache: [String: ArtworkCacheEntry], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: scopedKey(artworkCacheKeyBase))
    }

    private func scopedKey(_ base: String) -> String {
        #if os(tvOS)
        let profile = TVOSProfileManager.shared.currentProfileID
        let safe = TVOSProfileManager.sanitizedProfileIdentifier(profile)
        return "\(base).\(safe)"
        #else
        return base
        #endif
    }

    private func resolveData(for baseKey: String, defaults: UserDefaults) -> Data? {
        let scoped = scopedKey(baseKey)
        if let data = defaults.data(forKey: scoped) { return data }
        if scoped != baseKey, let legacy = defaults.data(forKey: baseKey) {
            defaults.set(legacy, forKey: scoped)
            return legacy
        }
        return nil
    }
}
