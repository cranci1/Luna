//
//  DeepLinkHandler.swift
//  Luna
//
//  Created for Apple TV App Integration
//

import Foundation
import SwiftUI

class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var pendingDeepLink: DeepLink?
    
    enum DeepLink: Equatable {
        case playMovie(tmdbId: Int, resumeTime: Double?)
        case playEpisode(tmdbId: Int, seasonNumber: Int, episodeNumber: Int, resumeTime: Double?)
        case showDetails(tmdbId: Int, mediaType: String)
    }
    
    private init() {}
    
    func handle(url: URL) {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("[DeepLink] Invalid deep link URL: \(url)")
            return
        }

        // NOTE:
        // For custom schemes like luna://play/tv/123...
        // URL.host == "play" and URL.path == "/tv/123..."
        // (i.e. the first route segment lives in the host, not the path).
        // We support both luna://play/... and luna:///play/... formats.

        let queryItems = urlComponents.queryItems ?? []
        let resumeTime = queryItems.first(where: { $0.name == "resumeTime" })?.value.flatMap(Double.init)

        var routeParts: [String] = []
        if let host = url.host, !host.isEmpty {
            routeParts.append(host)
        }

        let pathParts = url.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        routeParts.append(contentsOf: pathParts)

        guard routeParts.isEmpty == false else {
            print("[DeepLink] Empty deep link route: \(url)")
            return
        }

        // Supported routes:
        // - luna://play/movie/<tmdbId>?resumeTime=<seconds>
        // - luna://play/tv/<tmdbId>/<season>/<episode>?resumeTime=<seconds>
        // - luna://details/<movie|tv>/<tmdbId>
        // Also works with luna:///play/... where 'play' is in the path.

        switch routeParts[0] {
        case "play":
            guard routeParts.count >= 3 else {
                print("[DeepLink] Invalid play route (too short): \(url)")
                return
            }

            switch routeParts[1] {
            case "movie":
                if let tmdbId = Int(routeParts[2]) {
                    pendingDeepLink = .playMovie(tmdbId: tmdbId, resumeTime: resumeTime)
                    print("[DeepLink] Play movie \(tmdbId) at \(resumeTime ?? 0)s")
                } else {
                    print("[DeepLink] Invalid movie id in URL: \(url)")
                }

            case "tv":
                guard routeParts.count >= 5,
                      let tmdbId = Int(routeParts[2]),
                      let season = Int(routeParts[3]),
                      let episode = Int(routeParts[4])
                else {
                    print("[DeepLink] Invalid tv route in URL: \(url)")
                    return
                }

                pendingDeepLink = .playEpisode(
                    tmdbId: tmdbId,
                    seasonNumber: season,
                    episodeNumber: episode,
                    resumeTime: resumeTime
                )
                print("[DeepLink] Play TV \(tmdbId) S\(season)E\(episode) at \(resumeTime ?? 0)s")

            default:
                print("[DeepLink] Unknown play media type '\(routeParts[1])' in URL: \(url)")
            }

        case "details":
            guard routeParts.count >= 3, let tmdbId = Int(routeParts[2]) else {
                print("[DeepLink] Invalid details route in URL: \(url)")
                return
            }
            let mediaType = routeParts[1]
            pendingDeepLink = .showDetails(tmdbId: tmdbId, mediaType: mediaType)
            print("[DeepLink] Show details for \(mediaType) \(tmdbId)")

        default:
            print("[DeepLink] Unsupported deep link route '\(routeParts[0])' for URL: \(url)")
        }
    }
    
    func handleUserActivity(_ userActivity: NSUserActivity) {
        // Handle NSUserActivity from TV app
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handle(url: url)
            return
        }
        
        // Handle custom activity type
        if userActivity.activityType == "com.luna.details",
           let userInfo = userActivity.userInfo,
           let tmdbId = userInfo["tmdbId"] as? Int,
           let mediaType = userInfo["mediaType"] as? String {
            
            if mediaType == "movie" {
                pendingDeepLink = .playMovie(tmdbId: tmdbId, resumeTime: nil)
            } else if mediaType == "tv",
                      let seasonNumber = userInfo["seasonNumber"] as? Int,
                      let episodeNumber = userInfo["episodeNumber"] as? Int {
                pendingDeepLink = .playEpisode(tmdbId: tmdbId, seasonNumber: seasonNumber, episodeNumber: episodeNumber, resumeTime: nil)
            } else {
                pendingDeepLink = .showDetails(tmdbId: tmdbId, mediaType: mediaType)
            }
            
            print("[DeepLink] User activity: \(mediaType) \(tmdbId)")
        }
    }
    
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }
}
