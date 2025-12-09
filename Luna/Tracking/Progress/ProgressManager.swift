//
//  ProgressManager.swift
//  Sora
//
//  Created by Francesco on 27/08/25.
//

import Foundation
import AVFoundation

class ProgressManager {
    static let shared = ProgressManager()
    
    private init() {}
    
    // MARK: - Key Generation
    
    private func movieProgressKey(movieId: Int, title: String) -> String {
        let sanitizedTitle = title
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
            .prefix(50)
        let finalTitle = String(sanitizedTitle).isEmpty ? "unknown" : String(sanitizedTitle)
        return "movie_progress_\(movieId)_\(finalTitle)"
    }
    
    private func episodeProgressKey(showId: Int, seasonNumber: Int, episodeNumber: Int) -> String {
        return "episode_progress_\(showId)_s\(seasonNumber)_e\(episodeNumber)"
    }
    
    private func movieDurationKey(movieId: Int, title: String) -> String {
        let sanitizedTitle = title
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
            .prefix(50)
        let finalTitle = String(sanitizedTitle).isEmpty ? "unknown" : String(sanitizedTitle)
        return "movie_duration_\(movieId)_\(finalTitle)"
    }
    
    private func episodeDurationKey(showId: Int, seasonNumber: Int, episodeNumber: Int) -> String {
        return "episode_duration_\(showId)_s\(seasonNumber)_e\(episodeNumber)"
    }
    
    private func movieWatchedKey(movieId: Int, title: String) -> String {
        let sanitizedTitle = title
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
            .prefix(50)
        let finalTitle = String(sanitizedTitle).isEmpty ? "unknown" : String(sanitizedTitle)
        return "movie_watched_\(movieId)_\(finalTitle)"
    }
    
    private func episodeWatchedKey(showId: Int, seasonNumber: Int, episodeNumber: Int) -> String {
        return "episode_watched_\(showId)_s\(seasonNumber)_e\(episodeNumber)"
    }
    
    // MARK: - Progress Tracking
    
    func updateMovieProgress(movieId: Int, title: String, currentTime: Double, totalDuration: Double) {
        guard currentTime >= 0 && totalDuration > 0 && currentTime <= totalDuration else {
            Logger.shared.log("Invalid progress values for movie \(title): currentTime=\(currentTime), totalDuration=\(totalDuration)", type: "Warning")
            return
        }
        
        let progressKey = movieProgressKey(movieId: movieId, title: title)
        let durationKey = movieDurationKey(movieId: movieId, title: title)
        let watchedKey = movieWatchedKey(movieId: movieId, title: title)
        
        UserDefaults.standard.set(currentTime, forKey: progressKey)
        UserDefaults.standard.set(totalDuration, forKey: durationKey)
        
        let progressPercentage = currentTime / totalDuration
        if progressPercentage >= 0.95 {
            UserDefaults.standard.set(true, forKey: watchedKey)
        }
    }
    
    func updateEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int, currentTime: Double, totalDuration: Double) {
        guard currentTime >= 0 && totalDuration > 0 && currentTime <= totalDuration else {
            Logger.shared.log("Invalid progress values for episode S\(seasonNumber)E\(episodeNumber): currentTime=\(currentTime), totalDuration=\(totalDuration)", type: "Warning")
            return
        }
        
        let progressKey = episodeProgressKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let durationKey = episodeDurationKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let watchedKey = episodeWatchedKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        
        UserDefaults.standard.set(currentTime, forKey: progressKey)
        UserDefaults.standard.set(totalDuration, forKey: durationKey)
        
        let progressPercentage = currentTime / totalDuration
        if progressPercentage >= 0.95 {
            UserDefaults.standard.set(true, forKey: watchedKey)
        }
    }
    
    // MARK: - Progress Retrieval
    
    func getMovieProgress(movieId: Int, title: String) -> Double {
        let progressKey = movieProgressKey(movieId: movieId, title: title)
        let durationKey = movieDurationKey(movieId: movieId, title: title)
        
        let currentTime = UserDefaults.standard.double(forKey: progressKey)
        let totalDuration = UserDefaults.standard.double(forKey: durationKey)
        
        guard totalDuration > 0 else { return 0.0 }
        return min(currentTime / totalDuration, 1.0)
    }
    
    func getEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Double {
        let progressKey = episodeProgressKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let durationKey = episodeDurationKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        
        let currentTime = UserDefaults.standard.double(forKey: progressKey)
        let totalDuration = UserDefaults.standard.double(forKey: durationKey)
        
        guard totalDuration > 0 else { return 0.0 }
        return min(currentTime / totalDuration, 1.0)
    }
    
    func getMovieCurrentTime(movieId: Int, title: String) -> Double {
        let progressKey = movieProgressKey(movieId: movieId, title: title)
        return UserDefaults.standard.double(forKey: progressKey)
    }
    
    func getEpisodeCurrentTime(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Double {
        let progressKey = episodeProgressKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        return UserDefaults.standard.double(forKey: progressKey)
    }
    
    // MARK: - Watched Status
    
    func isMovieWatched(movieId: Int, title: String) -> Bool {
        let watchedKey = movieWatchedKey(movieId: movieId, title: title)
        let isExplicitlyWatched = UserDefaults.standard.bool(forKey: watchedKey)
        let progress = getMovieProgress(movieId: movieId, title: title)
        
        return isExplicitlyWatched || progress >= 0.95
    }
    
    func isEpisodeWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Bool {
        let watchedKey = episodeWatchedKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let isExplicitlyWatched = UserDefaults.standard.bool(forKey: watchedKey)
        let progress = getEpisodeProgress(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        
        return isExplicitlyWatched || progress >= 0.95
    }
    
    // MARK: - Manual Actions
    
    func markMovieAsWatched(movieId: Int, title: String) {
        let watchedKey = movieWatchedKey(movieId: movieId, title: title)
        let progressKey = movieProgressKey(movieId: movieId, title: title)
        let durationKey = movieDurationKey(movieId: movieId, title: title)
        
        UserDefaults.standard.set(true, forKey: watchedKey)
        
        let totalDuration = UserDefaults.standard.double(forKey: durationKey)
        if totalDuration > 0 {
            UserDefaults.standard.set(totalDuration, forKey: progressKey)
        }
        
        Logger.shared.log("Manually marked movie as watched: \(title)", type: "Progress")
    }
    
    func markEpisodeAsWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        let watchedKey = episodeWatchedKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let progressKey = episodeProgressKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let durationKey = episodeDurationKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        
        UserDefaults.standard.set(true, forKey: watchedKey)
        
        let totalDuration = UserDefaults.standard.double(forKey: durationKey)
        if totalDuration > 0 {
            UserDefaults.standard.set(totalDuration, forKey: progressKey)
        }
        
        Logger.shared.log("Manually marked episode as watched: S\(seasonNumber)E\(episodeNumber)", type: "Progress")
    }
    
    func markPreviousEpisodesAsWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        guard episodeNumber > 1 else { return }

        for e in 1..<episodeNumber {
            markEpisodeAsWatched(showId: showId, seasonNumber: seasonNumber, episodeNumber: e)
        }

        Logger.shared.log("Marked previous episodes as watched for S\(seasonNumber) up to E\(episodeNumber - 1)", type: "Progress")
    }
    
    func resetMovieProgress(movieId: Int, title: String) {
        let progressKey = movieProgressKey(movieId: movieId, title: title)
        let watchedKey = movieWatchedKey(movieId: movieId, title: title)
        
        UserDefaults.standard.set(0.0, forKey: progressKey)
        UserDefaults.standard.set(false, forKey: watchedKey)
        
        Logger.shared.log("Reset movie progress: \(title)", type: "Progress")
    }
    
    func resetEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        let progressKey = episodeProgressKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let watchedKey = episodeWatchedKey(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        
        UserDefaults.standard.set(0.0, forKey: progressKey)
        UserDefaults.standard.set(false, forKey: watchedKey)
        
        Logger.shared.log("Reset episode progress: S\(seasonNumber)E\(episodeNumber)", type: "Progress")
    }
}

// MARK: - AVPlayer Extension

extension ProgressManager {
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

enum MediaInfo {
    case movie(id: Int, title: String)
    case episode(showId: Int, seasonNumber: Int, episodeNumber: Int)
}
