//
//  ProgressManager.swift
//  Sora
//
//  Created by Francesco on 27/08/25.
//

import Foundation
import AVFoundation

// MARK: - Data Models

struct ProgressData: Codable {
    var movieProgress: [MovieProgressEntry] = []
    var episodeProgress: [EpisodeProgressEntry] = []
    
    mutating func updateMovie(_ entry: MovieProgressEntry) {
        if let index = movieProgress.firstIndex(where: { $0.id == entry.id }) {
            movieProgress[index] = entry
        } else {
            movieProgress.append(entry)
        }
    }
    
    mutating func updateEpisode(_ entry: EpisodeProgressEntry) {
        if let index = episodeProgress.firstIndex(where: { $0.id == entry.id }) {
            episodeProgress[index] = entry
        } else {
            episodeProgress.append(entry)
        }
    }
    
    func findMovie(id: Int) -> MovieProgressEntry? {
        movieProgress.first { $0.id == id }
    }
    
    func findEpisode(showId: Int, season: Int, episode: Int) -> EpisodeProgressEntry? {
        episodeProgress.first { $0.showId == showId && $0.seasonNumber == season && $0.episodeNumber == episode }
    }
}

struct MovieProgressEntry: Codable, Identifiable {
    let id: Int
    let title: String
    var currentTime: Double = 0
    var totalDuration: Double = 0
    var isWatched: Bool = false
    var lastUpdated: Date = Date()
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(currentTime / totalDuration, 1.0)
    }
}

struct EpisodeProgressEntry: Codable, Identifiable {
    let id: String
    let showId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    var currentTime: Double = 0
    var totalDuration: Double = 0
    var isWatched: Bool = false
    var lastUpdated: Date = Date()
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(currentTime / totalDuration, 1.0)
    }
    
    init(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        self.id = "ep_\(showId)_s\(seasonNumber)_e\(episodeNumber)"
        self.showId = showId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
    }

    init(
        id: String,
        showId: Int,
        seasonNumber: Int,
        episodeNumber: Int,
        currentTime: Double,
        totalDuration: Double,
        isWatched: Bool,
        lastUpdated: Date
    ) {
        self.id = id
        self.showId = showId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.isWatched = isWatched
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Watch History Item

/// Represents an item in watch history that combines progress data with TMDB metadata
struct WatchHistoryItem: Identifiable {
    let id: String
    let type: ItemType
    let tmdbId: Int
    let title: String
    let posterURL: String?
    let backdropURL: String?
    let progress: Double
    let currentTime: Double
    let totalDuration: Double
    let isWatched: Bool
    let lastUpdated: Date
    
    // Additional episode info for TV shows
    let showId: Int?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeTitle: String?
    
    enum ItemType {
        case movie
        case episode
    }

    init(
        id: String,
        type: ItemType,
        tmdbId: Int,
        title: String,
        posterURL: String?,
        backdropURL: String?,
        progress: Double,
        currentTime: Double,
        totalDuration: Double,
        isWatched: Bool,
        lastUpdated: Date,
        showId: Int?,
        seasonNumber: Int?,
        episodeNumber: Int?,
        episodeTitle: String?
    ) {
        self.id = id
        self.type = type
        self.tmdbId = tmdbId
        self.title = title
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.progress = progress
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.isWatched = isWatched
        self.lastUpdated = lastUpdated
        self.showId = showId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
    }
    
    init(from movieEntry: MovieProgressEntry) {
        self.id = "movie_\(movieEntry.id)"
        self.type = .movie
        self.tmdbId = movieEntry.id
        self.title = movieEntry.title
        self.posterURL = nil
        self.backdropURL = nil
        self.progress = movieEntry.progress
        self.currentTime = movieEntry.currentTime
        self.totalDuration = movieEntry.totalDuration
        self.isWatched = movieEntry.isWatched
        self.lastUpdated = movieEntry.lastUpdated
        self.showId = nil
        self.seasonNumber = nil
        self.episodeNumber = nil
        self.episodeTitle = nil
    }
    
    init(from episodeEntry: EpisodeProgressEntry, showTitle: String = "TV Show", episodeTitle: String? = nil) {
        self.id = episodeEntry.id
        self.type = .episode
        self.tmdbId = episodeEntry.showId
        self.title = showTitle
        self.posterURL = nil
        self.backdropURL = nil
        self.progress = episodeEntry.progress
        self.currentTime = episodeEntry.currentTime
        self.totalDuration = episodeEntry.totalDuration
        self.isWatched = episodeEntry.isWatched
        self.lastUpdated = episodeEntry.lastUpdated
        self.showId = episodeEntry.showId
        self.seasonNumber = episodeEntry.seasonNumber
        self.episodeNumber = episodeEntry.episodeNumber
        self.episodeTitle = episodeTitle
    }
    
    var displayTitle: String {
        switch type {
        case .movie:
            return title
        case .episode:
            if let season = seasonNumber, let episode = episodeNumber {
                let episodeStr = episodeTitle ?? "Episode \(episode)"
                return "\(title) • S\(season)E\(episode) - \(episodeStr)"
            }
            return title
        }
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var formattedTime: String {
        let remaining = totalDuration - currentTime
        let minutes = Int(remaining / 60)
        if minutes < 60 {
            return "\(minutes)m left"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m left"
        }
    }
}

// MARK: - ProgressManager

@MainActor
final class ProgressManager: ObservableObject {
    static let shared = ProgressManager()

    /// If progress is >= this value, the item is treated as completed/watched.
    /// This is intentionally lower than 1.0 so credit sequences still count as completion.
    static let watchedProgressThreshold: Double = 0.89

    /// Tiny progress used to “surface” the next episode in Continue Watching after finishing one.
    static let nextEpisodeSeedProgress: Double = 0.01
    
    @Published private var progressData: ProgressData = ProgressData() {
        didSet {
            guard isLoadingFromDisk == false else { return }
            debouncedSave()
        }
    }
    
    private let progressKey = "watchProgressData" // legacy UserDefaults key
    private let debounceInterval: TimeInterval = 2.0
    private var debounceTask: Task<Void, Never>?
    private var isLoadingFromDisk = false

    private let store = ProgressStore.shared

    private var remoteChangeObserver: NSObjectProtocol? = nil
    private var pendingLegacyMigration: ProgressData? = nil
    private var dirtyMovieIds: Set<Int> = []
    private var dirtyEpisodeIds: Set<String> = []
    private var profileObserver: NSObjectProtocol? = nil
    
    private init() {
        load()

        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: ProgressStore.remoteChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.handleRemoteStoreChange()
        }

        #if os(tvOS)
        profileObserver = NotificationCenter.default.addObserver(
            forName: TVOSProfileManager.profileDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleProfileChange()
        }
        #endif
    }

    private func handleRemoteStoreChange() {
        guard store.status() == .ready else { return }

        let incoming = store.getProgressData()

        var merged = progressData

        // Merge movies by id using lastUpdated.
        for movie in incoming.movieProgress {
            if let local = merged.findMovie(id: movie.id) {
                if movie.lastUpdated > local.lastUpdated {
                    merged.updateMovie(movie)
                    dirtyMovieIds.remove(movie.id)
                }
            } else {
                merged.updateMovie(movie)
            }
        }

        // Merge episodes by id using lastUpdated.
        let localEpisodesById = Dictionary(uniqueKeysWithValues: merged.episodeProgress.map { ($0.id, $0) })
        for ep in incoming.episodeProgress {
            if let local = localEpisodesById[ep.id] {
                if ep.lastUpdated > local.lastUpdated {
                    merged.updateEpisode(ep)
                    dirtyEpisodeIds.remove(ep.id)
                }
            } else {
                merged.updateEpisode(ep)
            }
        }

        isLoadingFromDisk = true
        progressData = merged
        isLoadingFromDisk = false
        updateTopShelfSnapshot()
    }

    private func handleProfileChange() {
        pendingLegacyMigration = nil
        dirtyMovieIds.removeAll()
        dirtyEpisodeIds.removeAll()
        load()
    }
    
    // MARK: - Data Persistence (Core Data / CloudKit)
    
    private func load() {
        isLoadingFromDisk = true
        defer { isLoadingFromDisk = false }

        // Prefer the store when available.
        if store.status() == .ready {
            let loaded = store.getProgressData()
            progressData = loaded
            Logger.shared.log("Progress data loaded from store (\(loaded.movieProgress.count) movies, \(loaded.episodeProgress.count) episodes)", type: "Progress")

            // If store is empty and legacy exists, import once.
            if loaded.movieProgress.isEmpty && loaded.episodeProgress.isEmpty,
               let legacy = loadLegacyProgressFromUserDefaults() {
                pendingLegacyMigration = legacy
                migrateLegacyToStoreIfPossible()
                let refreshed = store.getProgressData()
                progressData = refreshed
            }

            updateTopShelfSnapshot()
            return
        }

        // Store not ready yet: load legacy for immediate UI.
        if let legacy = loadLegacyProgressFromUserDefaults() {
            progressData = legacy
            pendingLegacyMigration = legacy
            Logger.shared.log("Progress data loaded from legacy UserDefaults (\(legacy.movieProgress.count) movies, \(legacy.episodeProgress.count) episodes)", type: "Progress")
        } else {
            Logger.shared.log("No existing progress data found, starting fresh", type: "Progress")
        }

        updateTopShelfSnapshot()

        // Best-effort: once the store becomes ready later in startup, migrate and reload.
        Task {
            let deadline = Date().addingTimeInterval(6.0)
            while Date() < deadline {
                if self.store.status() == .ready { break }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard self.store.status() == .ready else { return }

            self.migrateLegacyToStoreIfPossible()
            let loaded = self.store.getProgressData()
            self.isLoadingFromDisk = true
            self.progressData = loaded
            self.isLoadingFromDisk = false
            self.updateTopShelfSnapshot()
        }
    }

    private func loadLegacyProgressFromUserDefaults() -> ProgressData? {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else { return nil }
        return try? JSONDecoder().decode(ProgressData.self, from: data)
    }

    private func migrateLegacyToStoreIfPossible() {
        guard store.status() == .ready else { return }
        guard let legacy = pendingLegacyMigration else { return }

        let counts = store.counts()
        guard counts.movies == 0 && counts.episodes == 0 else {
            pendingLegacyMigration = nil
            return
        }

        Logger.shared.log("Migrating legacy progress to store (\(legacy.movieProgress.count) movies, \(legacy.episodeProgress.count) episodes)", type: "CloudKit")
        for movie in legacy.movieProgress { store.upsertMovie(movie) }
        for episode in legacy.episodeProgress { store.upsertEpisode(episode) }

        UserDefaults.standard.removeObject(forKey: progressKey)
        pendingLegacyMigration = nil
    }
    
    private func save() {
        flushDirtyToStoreIfPossible()
        updateTopShelfSnapshot()
    }

    private func flushDirtyToStoreIfPossible() {
        guard store.status() == .ready else { return }

        if dirtyMovieIds.isEmpty == false {
            for id in dirtyMovieIds {
                if let entry = progressData.findMovie(id: id) {
                    store.upsertMovie(entry)
                }
            }
            dirtyMovieIds.removeAll()
        }

        if dirtyEpisodeIds.isEmpty == false {
            let byId = Dictionary(uniqueKeysWithValues: progressData.episodeProgress.map { ($0.id, $0) })
            for id in dirtyEpisodeIds {
                if let entry = byId[id] {
                    store.upsertEpisode(entry)
                }
            }
            dirtyEpisodeIds.removeAll()
        }
    }

    private func updateTopShelfSnapshot() {
        // Keep Top Shelf in sync (uses App Group storage)
        let snapshot = TopShelfProgressSnapshot(
            movies: progressData.movieProgress.map { movie in
                TopShelfProgressSnapshot.Movie(
                    id: movie.id,
                    title: movie.title,
                    currentTime: movie.currentTime,
                    totalDuration: movie.totalDuration,
                    progress: movie.progress,
                    isWatched: movie.isWatched,
                    lastUpdated: movie.lastUpdated
                )
            },
            episodes: progressData.episodeProgress.map { ep in
                TopShelfProgressSnapshot.Episode(
                    id: ep.id,
                    showId: ep.showId,
                    seasonNumber: ep.seasonNumber,
                    episodeNumber: ep.episodeNumber,
                    currentTime: ep.currentTime,
                    totalDuration: ep.totalDuration,
                    progress: ep.progress,
                    isWatched: ep.isWatched,
                    lastUpdated: ep.lastUpdated
                )
            }
        )
        TopShelfStore.shared.updateContinueWatching(from: snapshot)
        prefetchTopShelfMetadataIfNeeded(snapshot: snapshot)
    }

    private func prefetchTopShelfMetadataIfNeeded(snapshot: TopShelfProgressSnapshot) {
        let movies = snapshot.movies
            .filter { $0.isWatched == false && $0.progress > 0 && $0.progress < Self.watchedProgressThreshold }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(10)

        let episodes = snapshot.episodes
            .filter { $0.isWatched == false && $0.progress > 0 && $0.progress < Self.watchedProgressThreshold }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(10)

        guard movies.isEmpty == false || episodes.isEmpty == false else { return }

        Task.detached(priority: .utility) {
            for movie in movies {
                let cached = await MainActor.run {
                    TopShelfStore.shared.cachedArtwork(tmdbId: movie.id, kind: .movie)
                }

                if cached?.posterURL == nil || cached?.title == nil {
                    if let detail = try? await TMDBService.shared.getMovieDetails(id: movie.id) {
                        await MainActor.run {
                            TopShelfStore.shared.updateArtworkCache(
                                tmdbId: movie.id,
                                kind: .movie,
                                title: detail.title,
                                posterURL: detail.fullPosterURL
                            )
                        }
                    }
                }
            }

            for ep in episodes {
                let cached = await MainActor.run {
                    TopShelfStore.shared.cachedArtwork(tmdbId: ep.showId, kind: .episode)
                }

                if cached?.posterURL == nil || cached?.title == nil {
                    if let detail = try? await TMDBService.shared.getTVShowDetails(id: ep.showId) {
                        await MainActor.run {
                            TopShelfStore.shared.updateArtworkCache(
                                tmdbId: ep.showId,
                                kind: .episode,
                                title: detail.name,
                                posterURL: detail.fullPosterURL
                            )
                        }
                    }
                }
            }

            await MainActor.run {
                TopShelfStore.shared.updateContinueWatching(from: snapshot)
            }
        }
    }
    
    private func debouncedSave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            if !Task.isCancelled {
                self.save()
            }
        }
    }
    
    // MARK: - Movie Progress
    
    func updateMovieProgress(movieId: Int, title: String, currentTime: Double, totalDuration: Double) {
        guard currentTime >= 0 && totalDuration > 0 && currentTime <= totalDuration else {
            Logger.shared.log("Invalid progress values for movie \(title): currentTime=\(currentTime), totalDuration=\(totalDuration)", type: "Warning")
            return
        }
        
        var entry = self.progressData.findMovie(id: movieId) ?? MovieProgressEntry(id: movieId, title: title)
        entry.currentTime = currentTime
        entry.totalDuration = totalDuration
        entry.lastUpdated = Date()
        
        if entry.progress >= Self.watchedProgressThreshold {
            entry.isWatched = true
        }
        dirtyMovieIds.insert(movieId)
        self.progressData.updateMovie(entry)
    }
    
    func getMovieProgress(movieId: Int, title: String) -> Double {
        self.progressData.findMovie(id: movieId)?.progress ?? 0.0
    }
    
    func getMovieCurrentTime(movieId: Int, title: String) -> Double {
        self.progressData.findMovie(id: movieId)?.currentTime ?? 0.0
    }
    
    func isMovieWatched(movieId: Int, title: String) -> Bool {
        if let entry = self.progressData.findMovie(id: movieId) {
            return entry.isWatched || entry.progress >= Self.watchedProgressThreshold
        }
        return false
    }
    
    func markMovieAsWatched(movieId: Int, title: String) {
        var entry = self.progressData.findMovie(id: movieId) ?? MovieProgressEntry(id: movieId, title: title)

        entry.isWatched = true
        if entry.totalDuration <= 0 {
            entry.totalDuration = 1
        }
        entry.currentTime = entry.totalDuration
        entry.lastUpdated = Date()
        dirtyMovieIds.insert(movieId)
        self.progressData.updateMovie(entry)
        Logger.shared.log("Marked movie as watched: \(title)", type: "Progress")
        save()
    }
    
    func resetMovieProgress(movieId: Int, title: String) {
        if var entry = self.progressData.findMovie(id: movieId) {
            entry.currentTime = 0
            entry.isWatched = false
            entry.lastUpdated = Date()
            dirtyMovieIds.insert(movieId)
            self.progressData.updateMovie(entry)
            Logger.shared.log("Reset movie progress: \(title)", type: "Progress")
        }
        save()
    }
    
    // MARK: - Episode Progress
    
    func updateEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int, currentTime: Double, totalDuration: Double) {
        guard currentTime >= 0 && totalDuration > 0 && currentTime <= totalDuration else {
            Logger.shared.log("Invalid progress values for episode S\(seasonNumber)E\(episodeNumber): currentTime=\(currentTime), totalDuration=\(totalDuration)", type: "Warning")
            return
        }
        
        var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber) 
            ?? EpisodeProgressEntry(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        
        let wasWatched = entry.isWatched

        entry.currentTime = currentTime
        entry.totalDuration = totalDuration
        entry.lastUpdated = Date()
        
        if entry.progress >= Self.watchedProgressThreshold {
            entry.isWatched = true
        }
        dirtyEpisodeIds.insert(entry.id)
        self.progressData.updateEpisode(entry)

        if wasWatched == false, entry.isWatched == true {
            seedNextEpisodeForContinueWatching(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        }
        
        // Log every 10% progress milestone
        let progressPercent = Int(entry.progress * 100)
        if progressPercent % 10 == 0 {
            Logger.shared.log("Episode S\(seasonNumber)E\(episodeNumber) progress: \(progressPercent)%", type: "Progress")
        }
    }
    
    func getEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Double {
        self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber)?.progress ?? 0.0
    }
    
    func getEpisodeCurrentTime(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Double {
        self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber)?.currentTime ?? 0.0
    }
    
    func isEpisodeWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Bool {
        if let entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber) {
            return entry.isWatched || entry.progress >= Self.watchedProgressThreshold
        }
        return false
    }
    
    func markEpisodeAsWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber)
            ?? EpisodeProgressEntry(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)

        entry.isWatched = true

        // Ensure progress reflects watched even if we never played the episode (totalDuration may be 0).
        if entry.totalDuration <= 0 {
            entry.totalDuration = 1
        }
        entry.currentTime = entry.totalDuration
        entry.lastUpdated = Date()
        dirtyEpisodeIds.insert(entry.id)
        self.progressData.updateEpisode(entry)
        Logger.shared.log("Marked episode as watched: S\(seasonNumber)E\(episodeNumber)", type: "Progress")

        seedNextEpisodeForContinueWatching(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        save()
    }

    private func seedNextEpisodeForContinueWatching(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        let nextEpisodeNumber = episodeNumber + 1
        let nextSeasonNumber = seasonNumber + 1

        Task.detached(priority: .utility) {
            do {
                let season = try await TMDBService.shared.getSeasonDetails(tvShowId: showId, seasonNumber: seasonNumber)
                if season.episodes.contains(where: { $0.episodeNumber == nextEpisodeNumber }) {
                    await MainActor.run {
                        self.seedEpisodeIfNeeded(showId: showId, seasonNumber: seasonNumber, episodeNumber: nextEpisodeNumber)
                    }
                    return
                }

                // If there's no next episode in this season, only seed the next season if TMDB confirms it exists and has episodes.
                let nextSeason = try await TMDBService.shared.getSeasonDetails(tvShowId: showId, seasonNumber: nextSeasonNumber)
                guard nextSeason.episodes.isEmpty == false else { return }

                let firstEpisodeNumber = nextSeason.episodes.map { $0.episodeNumber }.min() ?? 1
                await MainActor.run {
                    self.seedEpisodeIfNeeded(showId: showId, seasonNumber: nextSeasonNumber, episodeNumber: firstEpisodeNumber)
                }

            } catch {
                // Best-effort; seeding isn't critical enough to spam logs.
            }
        }
    }

    private func seedEpisodeIfNeeded(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        // Don't override real progress or watched state.
        if isEpisodeWatched(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber) {
            return
        }
        if getEpisodeProgress(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber) > 0 {
            return
        }

        var entry = progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber)
            ?? EpisodeProgressEntry(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)

        entry.totalDuration = max(entry.totalDuration, 1)
        entry.currentTime = max(entry.currentTime, Self.nextEpisodeSeedProgress)
        entry.isWatched = false
        entry.lastUpdated = Date()
        dirtyEpisodeIds.insert(entry.id)
        progressData.updateEpisode(entry)
        save()
    }
    
    func resetEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        if var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber) {
            entry.currentTime = 0
            entry.isWatched = false
            entry.lastUpdated = Date()
            dirtyEpisodeIds.insert(entry.id)
            self.progressData.updateEpisode(entry)
            Logger.shared.log("Reset episode progress: S\(seasonNumber)E\(episodeNumber)", type: "Progress")
        }
        save()
    }
    
    func markPreviousEpisodesAsWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        guard episodeNumber > 1 else { return }
        
        for e in 1..<episodeNumber {
            if var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: e) {
                entry.isWatched = true
                entry.currentTime = entry.totalDuration
                entry.lastUpdated = Date()
                dirtyEpisodeIds.insert(entry.id)
                self.progressData.updateEpisode(entry)
            }
        }
        Logger.shared.log("Marked previous episodes as watched for S\(seasonNumber) up to E\(episodeNumber - 1)", type: "Progress")
        save()
    }
    
    // MARK: - Continue Watching & History
    
    /// Get all movies with progress (for continue watching)
    func getMoviesInProgress() -> [MovieProgressEntry] {
        self.progressData.movieProgress
            .filter { $0.progress > 0 && $0.progress < Self.watchedProgressThreshold && !$0.isWatched }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    /// Get all watched movies
    func getWatchedMovies() -> [MovieProgressEntry] {
        self.progressData.movieProgress
            .filter { $0.isWatched || $0.progress >= Self.watchedProgressThreshold }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    /// Get all episodes with progress (for continue watching)
    func getEpisodesInProgress() -> [EpisodeProgressEntry] {
        self.progressData.episodeProgress
            .filter { $0.progress > 0 && $0.progress < Self.watchedProgressThreshold && !$0.isWatched }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    /// Get all watched episodes
    func getWatchedEpisodes() -> [EpisodeProgressEntry] {
        self.progressData.episodeProgress
            .filter { $0.isWatched || $0.progress >= Self.watchedProgressThreshold }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    /// Get all items with any progress (movies and episodes combined)
    func getAllProgressItems() -> (movies: [MovieProgressEntry], episodes: [EpisodeProgressEntry]) {
        let movies = self.progressData.movieProgress
            .filter { $0.progress > 0 }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        let episodes = self.progressData.episodeProgress
            .filter { $0.progress > 0 }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        return (movies, episodes)
    }
    
    // MARK: - AVPlayer Extension
    
    func addPeriodicTimeObserver(to player: AVPlayer, for mediaInfo: MediaInfo) -> Any? {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        Logger.shared.log("Setting up periodic time observer for: \(mediaInfo)", type: "Progress")
        
        var lastLoggedSecond: Int = -1
        
        return player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            guard let currentItem = player.currentItem else {
                if lastLoggedSecond != -2 {
                    Logger.shared.log("No current item in player", type: "Warning")
                    lastLoggedSecond = -2
                }
                return
            }
            
            guard currentItem.duration.seconds.isFinite else {
                if lastLoggedSecond != -3 {
                    Logger.shared.log("Duration is not finite: \(currentItem.duration.seconds)", type: "Warning")
                    lastLoggedSecond = -3
                }
                return
            }
            
            guard currentItem.duration.seconds > 0 else {
                if lastLoggedSecond != -4 {
                    Logger.shared.log("Duration is not greater than 0: \(currentItem.duration.seconds)", type: "Warning")
                    lastLoggedSecond = -4
                }
                return
            }
            
            let currentTime = time.seconds
            let duration = currentItem.duration.seconds
            
            guard currentTime >= 0 && currentTime <= duration else {
                if lastLoggedSecond != -5 {
                    Logger.shared.log("Invalid time values - current: \(currentTime), duration: \(duration)", type: "Warning")
                    lastLoggedSecond = -5
                }
                return
            }
            
            // Log every 10 seconds to verify observer is still running
            let currentSecond = Int(currentTime)
            if currentSecond % 10 == 0 && currentSecond != lastLoggedSecond {
                Logger.shared.log("Time observer active - \(currentSecond)s / \(Int(duration))s", type: "Progress")
                lastLoggedSecond = currentSecond
            }
            
            switch mediaInfo {
            case .movie(let id, let title):
                Task { @MainActor in
                    self.updateMovieProgress(movieId: id, title: title, currentTime: currentTime, totalDuration: duration)
                }
                
            case .episode(let showId, let seasonNumber, let episodeNumber):
                Task { @MainActor in
                    self.updateEpisodeProgress(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber, currentTime: currentTime, totalDuration: duration)
                }
            }
        }
    }
}

// MARK: - MediaInfo Enum

enum MediaInfo {
    case movie(id: Int, title: String)
    case episode(showId: Int, seasonNumber: Int, episodeNumber: Int)
}
