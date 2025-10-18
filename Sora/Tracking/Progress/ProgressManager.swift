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
    
    private func episodeLatestWatchedKey(showId: Int) -> String {
        return "episode_latest_watched_\(showId)"
    }
    
    private func isLaterEpisode(season aS: Int, episode aE: Int, than b: (season: Int, episode: Int)?) -> Bool {
            guard let b = b else { return true }
            if aS != b.season { return aS > b.season }
            return aE > b.episode
    }
    
    private func updateLatestIfNeeded(showId: Int, seasonNumber: Int, episodeNumber: Int) {
            let latestKey = episodeLatestWatchedKey(showId: showId)
            let current = UserDefaults.standard.dictionary(forKey: latestKey) as? [String: Int]
            let currentTuple: (season: Int, episode: Int)? = {
                guard let c = current, let s = c["season"], let e = c["episode"] else { return nil }
                return (s, e)
            }()
            if isLaterEpisode(season: seasonNumber, episode: episodeNumber, than: currentTuple) {
                let new = ["season": seasonNumber, "episode": episodeNumber]
                UserDefaults.standard.set(new, forKey: latestKey)
            }
    }

    private func extractSeasonEpisode(from key: String) -> (season: Int, episode: Int)? {
           // Example keys: episode_progress_123_s3_e14
           let parts = key.split(separator: "_")
           guard let sPart = parts.first(where: { $0.first == "s" }),
                 let ePart = parts.first(where: { $0.first == "e" }),
                 let s = Int(sPart.dropFirst()),
                 let e = Int(ePart.dropFirst()) else {
               return nil
           }
           return (season: s, episode: e)
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
        
        Logger.shared.log("Updated movie progress: \(title) - \(String(format: "%.1f", progressPercentage * 100))%", type: "Progress")
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
        
        Logger.shared.log("Updated episode progress: S\(seasonNumber)E\(episodeNumber) - \(String(format: "%.1f", progressPercentage * 100))%", type: "Progress")
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
    
    func getLatestWatchedEpisode(showId: Int) -> (season: Int, episode: Int)? {
         let ud = UserDefaults.standard
         let latestKey = episodeLatestWatchedKey(showId: showId)

         // Start from explicitly stored "latest watched" pointer
         var latest: (season: Int, episode: Int)? = {
             guard let info = ud.dictionary(forKey: latestKey) as? [String: Int],
                   let s = info["season"], let e = info["episode"] else { return nil }
             return (s, e)
         }()

         let allKeys = ud.dictionaryRepresentation().keys
         let watchedPrefix = "episode_watched_\(showId)_"
         let progressPrefix = "episode_progress_\(showId)_"

         // Consider explicitly marked watched episodes
         for key in allKeys where key.hasPrefix(watchedPrefix) {
             guard ud.bool(forKey: key),
                   let (s, e) = parseSeasonEpisode(fromKey: key) else { continue }
             if isLater(season: s, episode: e, than: latest) {
                 latest = (s, e)
             }
         }

         // Consider episodes watched via progress >= 95%
         for key in allKeys where key.hasPrefix(progressPrefix) {
             guard let (s, e) = parseSeasonEpisode(fromKey: key) else { continue }
             let currentTime = ud.double(forKey: key)
             let durationKey = key.replacingOccurrences(of: "episode_progress_", with: "episode_duration_")
             let totalDuration = ud.double(forKey: durationKey)
             guard totalDuration > 0 else { continue }
             if currentTime / totalDuration >= 0.95,
                isLater(season: s, episode: e, than: latest) {
                 latest = (s, e)
             }
         }

         return latest
     }
    
    // Parse keys like "..._s<season>_e<episode>"
        private func parseSeasonEpisode(fromKey key: String) -> (Int, Int)? {
            let parts = key.split(separator: "_")
            guard parts.count >= 4 else { return nil }
            let sToken = parts[parts.count - 2]
            let eToken = parts[parts.count - 1]
            guard sToken.first == "s", eToken.first == "e",
                  let s = Int(sToken.dropFirst()),
                  let e = Int(eToken.dropFirst()) else {
                return nil
            }
            return (s, e)
        }

        // Lexicographic compare: by season, then by episode
        private func isLater(season: Int, episode: Int, than other: (season: Int, episode: Int)?) -> Bool {
            guard let o = other else { return true }
            return season > o.season || (season == o.season && episode > o.episode)
        }

    
    func resetEntireShowProgress(showId: Int) {
        // Reset the latest watched episode information
        let latestWatchedKey = episodeLatestWatchedKey(showId: showId)
        UserDefaults.standard.removeObject(forKey: latestWatchedKey)
        
        let userDefaults = UserDefaults.standard
        var count = 0
        
        // Get all UserDefaults keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Key patterns specific to episode data for this show
        let progressPrefix = "episode_progress_\(showId)_"
        let watchedPrefix = "episode_watched_\(showId)_"
        let durationPrefix = "episode_duration_\(showId)_"
        
        // Find and remove all keys related to this show
        for key in allKeys {
            if key.hasPrefix(progressPrefix) || key.hasPrefix(watchedPrefix) || key.hasPrefix(durationPrefix) {
                userDefaults.removeObject(forKey: key)
                count += 1
            }
        }
        
        Logger.shared.log("Reset entire progress for show ID \(showId) - cleared \(count) keys", type: "Progress")
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
        
        let isBeforeLatestWatched = isEpisodeBeforeLatestWatched(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        
        return isExplicitlyWatched || progress >= 0.95 || isBeforeLatestWatched
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
    
    // Save the latest watched episode and season
    func markAllEpisodesBeforeAsWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        let latestKey = episodeLatestWatchedKey(showId: showId)
        let latestWatchedInfo = ["season": seasonNumber, "episode": episodeNumber]
        UserDefaults.standard.set(latestWatchedInfo, forKey: latestKey)
        
        Logger.shared.log("Marked all episodes before S\(seasonNumber)E\(episodeNumber) as watched for show \(showId)", type: "Progress")
    }
    
    // Check if an episode is before the latest watched
    func isEpisodeBeforeLatestWatched(showId: Int, seasonNumber: Int, episodeNumber: Int) -> Bool {
        let latestKey = episodeLatestWatchedKey(showId: showId)
        guard let latestWatchedInfo = UserDefaults.standard.dictionary(forKey: latestKey) as? [String: Int],
              let latestSeason = latestWatchedInfo["season"],
              let latestEpisode = latestWatchedInfo["episode"] else {
            return false
        }
        
        if seasonNumber < latestSeason {
            return true
        } else if seasonNumber == latestSeason && episodeNumber < latestEpisode {
            return true
        }
        return false
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
