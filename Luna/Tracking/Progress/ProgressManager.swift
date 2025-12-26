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
}

// MARK: - ProgressManager

final class ProgressManager {
    static let shared = ProgressManager()
    
    private let fileManager = FileManager.default
    private var progressData: ProgressData = ProgressData()
    private let progressFileURL: URL
    private let debounceInterval: TimeInterval = 2.0
    private var debounceTask: Task<Void, Never>?
    private let accessQueue = DispatchQueue(label: "com.luna.progress-manager", attributes: .concurrent)
    
    private static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    private init() {
        self.progressFileURL = Self.documentsDirectory.appendingPathComponent("ProgressData.json")
        loadProgressData()
    }
    
    // MARK: - Data Persistence
    
    private func loadProgressData() {
        guard fileManager.fileExists(atPath: progressFileURL.path) else {
            Logger.shared.log("Progress file not found, initializing new data", type: "Progress")
            return
        }
        
        do {
            let data = try Data(contentsOf: progressFileURL)
            let decoded = try JSONDecoder().decode(ProgressData.self, from: data)
            accessQueue.async(flags: .barrier) { [weak self] in
                self?.progressData = decoded
            }
            Logger.shared.log("Progress data loaded successfully (\(decoded.movieProgress.count) movies, \(decoded.episodeProgress.count) episodes)", type: "Progress")
        } catch {
            Logger.shared.log("Failed to load progress data: \(error.localizedDescription)", type: "Error")
        }
    }
    
    private func saveProgressData() {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(self.progressData)
                try data.write(to: self.progressFileURL, options: .atomic)
                Logger.shared.log("Progress data saved successfully", type: "Progress")
            } catch {
                Logger.shared.log("Failed to save progress data: \(error.localizedDescription)", type: "Error")
            }
        }
    }
    
    private func debouncedSave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            if !Task.isCancelled {
                self.saveProgressData()
            }
        }
    }
    
    // MARK: - Movie Progress
    
    func updateMovieProgress(movieId: Int, title: String, currentTime: Double, totalDuration: Double) {
        guard currentTime >= 0 && totalDuration > 0 && currentTime <= totalDuration else {
            Logger.shared.log("Invalid progress values for movie \(title): currentTime=\(currentTime), totalDuration=\(totalDuration)", type: "Warning")
            return
        }
        
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            var entry = self.progressData.findMovie(id: movieId) ?? MovieProgressEntry(id: movieId, title: title)
            entry.currentTime = currentTime
            entry.totalDuration = totalDuration
            entry.lastUpdated = Date()
            
            if entry.progress >= 0.95 {
                entry.isWatched = true
            }
            
            self.progressData.updateMovie(entry)
        }
        debouncedSave()
    }
    
    func getMovieProgress(movieId: Int, title: String) -> Double {
        var result: Double = 0.0
        accessQueue.sync {
            result = self.progressData.findMovie(id: movieId)?.progress ?? 0.0
        }
        return result
    }
    
    func getMovieCurrentTime(movieId: Int, title: String) -> Double {
        var result: Double = 0.0
        accessQueue.sync {
            result = self.progressData.findMovie(id: movieId)?.currentTime ?? 0.0
        }
        return result
    }
    
    func isMovieWatched(movieId: Int, title: String) -> Bool {
        var result: Bool = false
        accessQueue.sync {
            if let entry = self.progressData.findMovie(id: movieId) {
                result = entry.isWatched || entry.progress >= 0.95
            }
        }
        return result
    }
    
    func markMovieAsWatched(movieId: Int, title: String) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if var entry = self.progressData.findMovie(id: movieId) {
                entry.isWatched = true
                entry.currentTime = entry.totalDuration
                entry.lastUpdated = Date()
                self.progressData.updateMovie(entry)
                Logger.shared.log("Marked movie as watched: \(title)", type: "Progress")
            }
        }
        saveProgressData()
    }
    
    func resetMovieProgress(movieId: Int, title: String) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if var entry = self.progressData.findMovie(id: movieId) {
                entry.currentTime = 0
                entry.isWatched = false
                entry.lastUpdated = Date()
                self.progressData.updateMovie(entry)
                Logger.shared.log("Reset movie progress: \(title)", type: "Progress")
            }
        }
        saveProgressData()
    }
    
    // MARK: - Episode Progress
    
    func updateEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int, currentTime: Double, totalDuration: Double) {
        guard currentTime >= 0 && totalDuration > 0 && currentTime <= totalDuration else {
            Logger.shared.log("Invalid progress values for episode S\(seasonNumber)E\(episodeNumber): currentTime=\(currentTime), totalDuration=\(totalDuration)", type: "Warning")
            return
        }
        
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber) 
                ?? EpisodeProgressEntry(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
            
            entry.currentTime = currentTime
            entry.totalDuration = totalDuration
            entry.lastUpdated = Date()
            
            if entry.progress >= 0.95 {
                entry.isWatched = true
            }
            
            self.progressData.updateEpisode(entry)
        }
        debouncedSave()
    }
    
    func getEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Double {
        var result: Double = 0.0
        accessQueue.sync {
            result = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber)?.progress ?? 0.0
        }
        return result
    }
    
    func getEpisodeCurrentTime(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Double {
        var result: Double = 0.0
        accessQueue.sync {
            result = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber)?.currentTime ?? 0.0
        }
        return result
    }
    
    func isEpisodeWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Bool {
        var result: Bool = false
        accessQueue.sync {
            if let entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber) {
                result = entry.isWatched || entry.progress >= 0.95
            }
        }
        return result
    }
    
    func markEpisodeAsWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber) {
                entry.isWatched = true
                entry.currentTime = entry.totalDuration
                entry.lastUpdated = Date()
                self.progressData.updateEpisode(entry)
                Logger.shared.log("Marked episode as watched: S\(seasonNumber)E\(episodeNumber)", type: "Progress")
            }
        }
        saveProgressData()
    }
    
    func resetEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: episodeNumber) {
                entry.currentTime = 0
                entry.isWatched = false
                entry.lastUpdated = Date()
                self.progressData.updateEpisode(entry)
                Logger.shared.log("Reset episode progress: S\(seasonNumber)E\(episodeNumber)", type: "Progress")
            }
        }
        saveProgressData()
    }
    
    func markPreviousEpisodesAsWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        guard episodeNumber > 1 else { return }
        
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            for e in 1..<episodeNumber {
                if var entry = self.progressData.findEpisode(showId: showId, season: seasonNumber, episode: e) {
                    entry.isWatched = true
                    entry.currentTime = entry.totalDuration
                    entry.lastUpdated = Date()
                    self.progressData.updateEpisode(entry)
                }
            }
            Logger.shared.log("Marked previous episodes as watched for S\(seasonNumber) up to E\(episodeNumber - 1)", type: "Progress")
        }
        saveProgressData()
    }
    
    // MARK: - AVPlayer Extension
    
    func addPeriodicTimeObserver(to player: AVPlayer, for mediaInfo: MediaInfo) -> Any? {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        return player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let currentItem = player.currentItem,
                  currentItem.duration.seconds.isFinite,
                  currentItem.duration.seconds > 0 else {
                return
            }
            
            let currentTime = time.seconds
            let duration = currentItem.duration.seconds
            
            guard currentTime >= 0 && currentTime <= duration else { return }
            
            switch mediaInfo {
            case .movie(let id, let title):
                self.updateMovieProgress(movieId: id, title: title, currentTime: currentTime, totalDuration: duration)
                
            case .episode(let showId, let seasonNumber, let episodeNumber):
                self.updateEpisodeProgress(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber, currentTime: currentTime, totalDuration: duration)
            }
        }
    }
}

// MARK: - MediaInfo Enum

enum MediaInfo {
    case movie(id: Int, title: String)
    case episode(showId: Int, seasonNumber: Int, episodeNumber: Int)
}
