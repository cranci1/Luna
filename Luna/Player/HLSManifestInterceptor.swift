//
//  HLSManifestInterceptor.swift
//  Luna
//
//  Created by TrinityHades on 09/01/26.
//

import AVFoundation
import Foundation

/// Intercepts HLS manifest requests to dynamically inject subtitle tracks
class HLSManifestInterceptor: NSObject, AVAssetResourceLoaderDelegate {
    
    // Custom scheme to trigger interception (must not be http/https)
    static let customScheme = "lunahls"
    
    // Internal mapping of intercepted URLs to their original URLs
    private var urlMapping: [URL: URL] = [:]
    
    // Subtitle tracks to inject
    private var subtitleTracks: [SubtitleTrack] = []
    
    // Headers for video requests
    private var headers: [String: String]?
    
    struct SubtitleTrack {
        let name: String
        let language: String
        let url: URL
        let isDefault: Bool
        let autoSelect: Bool
    }
    
    init(subtitles: [String]?, headers: [String: String]?) {
        self.headers = headers
        super.init()
        
        Logger.shared.log("[SUBTITLE] HLSManifestInterceptor init with \(subtitles?.count ?? 0) subtitle(s)", type: "Stream")
        
        if let subtitles = subtitles, !subtitles.isEmpty {
            Logger.shared.log("[SUBTITLE] Parsing subtitles: \(subtitles)", type: "Stream")
            self.subtitleTracks = parseSubtitles(subtitles)
            Logger.shared.log("[SUBTITLE] Parsed \(self.subtitleTracks.count) track(s)", type: "Stream")
        } else {
            Logger.shared.log("[SUBTITLE] No subtitles to parse", type: "Warning")
        }
    }
    
    private func parseSubtitles(_ subtitles: [String]) -> [SubtitleTrack] {
        var tracks: [SubtitleTrack] = []
        var index = 0
        var trackNumber = 1
        
        while index < subtitles.count {
            let entry = subtitles[index]
            
            if isURL(entry) {
                // URL without name
                if let url = convertToVTTURL(entry) {
                    Logger.shared.log("Parsed subtitle URL: \(url.absoluteString)", type: "Stream")
                    let track = SubtitleTrack(
                        name: "Subtitle \(trackNumber)",
                        language: "en",
                        url: url,
                        isDefault: trackNumber == 1,
                        autoSelect: true
                    )
                    tracks.append(track)
                    trackNumber += 1
                }
                index += 1
            } else {
                // Name followed by URL
                let nextIndex = index + 1
                if nextIndex < subtitles.count, isURL(subtitles[nextIndex]) {
                    if let url = convertToVTTURL(subtitles[nextIndex]) {
                        Logger.shared.log("Parsed subtitle '\(entry)': \(url.absoluteString)", type: "Stream")
                        let isOverlayTrack = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                            .caseInsensitiveCompare(SubtitleController.overlayTrackName) == .orderedSame
                        let track = SubtitleTrack(
                            name: entry,
                            language: detectLanguage(from: entry),
                            url: url,
                            isDefault: (trackNumber == 1 && !isOverlayTrack),
                            autoSelect: !isOverlayTrack
                        )
                        tracks.append(track)
                        trackNumber += 1
                    }
                    index += 2
                } else {
                    index += 1
                }
            }
        }
        
        Logger.shared.log("Parsed \(tracks.count) subtitle track(s)", type: "Stream")
        return tracks
    }
    
    /// Converts SRT URLs to VTT format if possible, or returns original URL
    private func convertToVTTURL(_ urlString: String) -> URL? {
        guard var components = URLComponents(string: urlString) else {
            return URL(string: urlString)
        }
        
        // Check if URL has format parameter and convert srt to vtt
        if var queryItems = components.queryItems {
            for i in 0..<queryItems.count {
                if queryItems[i].name.lowercased() == "format" {
                    let currentFormat = queryItems[i].value?.lowercased()
                    if currentFormat == "srt" {
                        queryItems[i].value = "vtt"
                        components.queryItems = queryItems
                        Logger.shared.log("Converted subtitle format from SRT to VTT in URL", type: "Stream")
                        return components.url ?? URL(string: urlString)
                    }
                }
            }
        }
        
        // Check file extension
        let path = components.path.lowercased()
        if path.hasSuffix(".srt") {
            // Try to change extension to .vtt
            components.path = components.path.replacingOccurrences(of: ".srt", with: ".vtt", options: .caseInsensitive)
            if let vttURL = components.url {
                Logger.shared.log("Converted .srt extension to .vtt in URL", type: "Stream")
                return vttURL
            }
        }
        
        return components.url ?? URL(string: urlString)
    }
    
    private func isURL(_ string: String) -> Bool {
        let lowercased = string.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }
    
    private func detectLanguage(from name: String) -> String {
        let lowercased = name.lowercased()
        
        if lowercased.contains("english") || lowercased.contains("eng") {
            return "en"
        } else if lowercased.contains("spanish") || lowercased.contains("español") {
            return "es"
        } else if lowercased.contains("french") || lowercased.contains("français") {
            return "fr"
        } else if lowercased.contains("german") || lowercased.contains("deutsch") {
            return "de"
        } else if lowercased.contains("italian") || lowercased.contains("italiano") {
            return "it"
        } else if lowercased.contains("portuguese") || lowercased.contains("português") {
            return "pt"
        } else if lowercased.contains("japanese") || lowercased.contains("日本語") {
            return "ja"
        } else if lowercased.contains("korean") || lowercased.contains("한국어") {
            return "ko"
        } else if lowercased.contains("chinese") || lowercased.contains("中文") {
            return "zh"
        }
        
        return "en" // Default to English
    }
    
    /// Prepares a URL for interception by changing its scheme
    func prepareURL(_ originalURL: URL) -> URL {
        guard var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false) else {
            return originalURL
        }
        
        // Change scheme to trigger interception
        components.scheme = Self.customScheme
        
        guard let interceptedURL = components.url else {
            return originalURL
        }
        
        // Store mapping
        urlMapping[interceptedURL] = originalURL
        
        return interceptedURL
    }
    
    // Store the base URL for relative URL resolution
    private var baseURL: URL?
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                       shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        guard let url = loadingRequest.request.url else {
            Logger.shared.log("[SUBTITLE] No URL in loading request", type: "Error")
            return false
        }
        
        Logger.shared.log("[SUBTITLE] Resource loader intercepting: \(url.absoluteString)", type: "Stream")
        
        // Get original URL
        guard let originalURL = getOriginalURL(from: url) else {
            Logger.shared.log("[SUBTITLE] Could not find original URL for: \(url)", type: "Error")
            return false
        }
        
        Logger.shared.log("[SUBTITLE] Resolved to original URL: \(originalURL.absoluteString)", type: "Stream")
        
        // Handle the request asynchronously
        Task {
            await handleResourceRequest(loadingRequest, originalURL: originalURL)
        }
        
        return true
    }
    
    private func getOriginalURL(from interceptedURL: URL) -> URL? {
        // First check our mapping
        if let mapped = urlMapping[interceptedURL] {
            return mapped
        }
        
        // Try to convert back by changing scheme
        guard var components = URLComponents(url: interceptedURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        // Change scheme back to https
        components.scheme = "https"
        
        return components.url
    }
    
    private func handleResourceRequest(_ loadingRequest: AVAssetResourceLoadingRequest, originalURL: URL) async {
        Logger.shared.log("[SUBTITLE] Handling resource request for: \(originalURL.absoluteString)", type: "Stream")
        
        // Check if this is a subtitle playlist request
        let urlString = originalURL.absoluteString
        if urlString.contains("subtitle/track") || originalURL.host == "subtitle" {
            await handleSubtitlePlaylistRequest(loadingRequest, originalURL: originalURL)
            return
        }
        
        do {
            var request = URLRequest(url: originalURL)
            request.timeoutInterval = 30
            
            // Add custom headers
            if let headers = headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            // Handle byte range requests
            if let dataRequest = loadingRequest.dataRequest {
                let requestedOffset = dataRequest.requestedOffset
                let requestedLength = dataRequest.requestedLength
                
                if requestedOffset > 0 || requestedLength > 0 {
                    let endOffset = requestedOffset + Int64(requestedLength) - 1
                    request.setValue("bytes=\(requestedOffset)-\(endOffset)", forHTTPHeaderField: "Range")
                    Logger.shared.log("[SUBTITLE] Byte range request: \(requestedOffset)-\(endOffset)", type: "Stream")
                }
            }
            
            Logger.shared.log("[SUBTITLE] Fetching: \(originalURL.lastPathComponent)", type: "Stream")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.shared.log("[SUBTITLE] Invalid response type", type: "Error")
                loadingRequest.finishLoading(with: NSError(domain: "HLSInterceptor", code: -1, userInfo: nil))
                return
            }
            
            Logger.shared.log("[SUBTITLE] Response: \(httpResponse.statusCode) for \(originalURL.lastPathComponent), size: \(data.count)", type: "Stream")
            
            // Check if this is a manifest file
            let lowercasedURL = originalURL.absoluteString.lowercased()
            let isManifest = lowercasedURL.hasSuffix(".m3u8") || lowercasedURL.contains(".m3u8?") || lowercasedURL.contains("/m3u8")
            
            var responseData = data
            
            if isManifest, let manifestString = String(data: data, encoding: .utf8) {
                Logger.shared.log("[SUBTITLE] Processing HLS manifest: \(originalURL.lastPathComponent)", type: "Stream")
                
                // Check if this is a master playlist (has #EXT-X-STREAM-INF)
                let isMasterPlaylist = manifestString.contains("#EXT-X-STREAM-INF")
                
                if isMasterPlaylist && !subtitleTracks.isEmpty {
                    // Inject subtitle tracks
                    let modifiedManifest = injectSubtitles(into: manifestString, baseURL: originalURL)
                    if let modifiedData = modifiedManifest.data(using: .utf8) {
                        responseData = modifiedData
                        Logger.shared.log("[SUBTITLE] Injected \(subtitleTracks.count) subtitle track(s) into manifest", type: "Stream")
                    }
                }
            }
            
            // Fill content information
            if let contentInfo = loadingRequest.contentInformationRequest {
                // Get total content length from headers
                if let contentLengthStr = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                   let contentLength = Int64(contentLengthStr) {
                    contentInfo.contentLength = contentLength
                } else if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
                          let totalLength = contentRange.components(separatedBy: "/").last,
                          let length = Int64(totalLength) {
                    contentInfo.contentLength = length
                } else {
                    contentInfo.contentLength = Int64(responseData.count)
                }
                
                contentInfo.isByteRangeAccessSupported = true
                
                if isManifest {
                    contentInfo.contentType = "public.m3u-playlist"
                } else if let mimeType = httpResponse.mimeType {
                    // Convert MIME type to UTType if possible
                    if mimeType.contains("mp2t") || mimeType.contains("mpeg") {
                        contentInfo.contentType = "public.mpeg-2-transport-stream"
                    } else if mimeType.contains("mp4") {
                        contentInfo.contentType = "public.mpeg-4"
                    } else {
                        contentInfo.contentType = mimeType
                    }
                }
            }
            
            // Respond with data
            if let dataRequest = loadingRequest.dataRequest {
                dataRequest.respond(with: responseData)
            }
            
            loadingRequest.finishLoading()
            Logger.shared.log("[SUBTITLE] Successfully loaded: \(originalURL.lastPathComponent)", type: "Stream")
            
        } catch {
            Logger.shared.log("[SUBTITLE] Failed to load resource: \(error.localizedDescription)", type: "Error")
            loadingRequest.finishLoading(with: error)
        }
    }
    
    private func handleSubtitlePlaylistRequest(_ loadingRequest: AVAssetResourceLoadingRequest, originalURL: URL) async {
        Logger.shared.log("[SUBTITLE] Handling subtitle playlist request: \(originalURL)", type: "Stream")
        
        // Extract track index from URL (e.g., lunahls://subtitle/track0.m3u8)
        let pathComponents = originalURL.pathComponents
        guard pathComponents.count >= 2,
              let trackFileName = pathComponents.last,
              trackFileName.hasPrefix("track"),
              let indexString = trackFileName.replacingOccurrences(of: "track", with: "").replacingOccurrences(of: ".m3u8", with: "").components(separatedBy: CharacterSet.decimalDigits.inverted).first,
              let trackIndex = Int(indexString),
              trackIndex < subtitleTracks.count else {
            Logger.shared.log("[SUBTITLE] Invalid subtitle track request: \(originalURL)", type: "Error")
            loadingRequest.finishLoading(with: NSError(domain: "HLSInterceptor", code: -2, userInfo: nil))
            return
        }
        
        let track = subtitleTracks[trackIndex]
        Logger.shared.log("[SUBTITLE] Generating subtitle playlist for: \(track.name) (\(track.url.absoluteString))", type: "Stream")
        
        // Generate subtitle playlist
        if let playlistContent = await SubtitleM3U8Generator.createPlaylist(for: track.url) {
            if let playlistData = playlistContent.data(using: .utf8) {
                loadingRequest.contentInformationRequest?.contentType = "application/vnd.apple.mpegurl"
                loadingRequest.contentInformationRequest?.contentLength = Int64(playlistData.count)
                loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
                
                loadingRequest.dataRequest?.respond(with: playlistData)
                loadingRequest.finishLoading()
                
                Logger.shared.log("Subtitle playlist generated successfully for \(track.name)", type: "Stream")
                return
            }
        }
        
        // Fallback: use quick playlist generation
        let quickPlaylist = SubtitleM3U8Generator.createQuickPlaylist(for: track.url)
        if let playlistData = quickPlaylist.data(using: .utf8) {
            loadingRequest.contentInformationRequest?.contentType = "application/vnd.apple.mpegurl"
            loadingRequest.contentInformationRequest?.contentLength = Int64(playlistData.count)
            loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
            
            loadingRequest.dataRequest?.respond(with: playlistData)
            loadingRequest.finishLoading()
            
            Logger.shared.log("Quick subtitle playlist generated for \(track.name)", type: "Stream")
        } else {
            loadingRequest.finishLoading(with: NSError(domain: "HLSInterceptor", code: -3, userInfo: nil))
        }
    }
    
    private func injectSubtitles(into manifest: String, baseURL: URL) -> String {
        let lines = manifest.components(separatedBy: .newlines)
        var modifiedLines: [String] = []
        var subtitleGroupAdded = false
        
        for (_, line) in lines.enumerated() {
            // Add subtitle media declarations before the first stream
            if !subtitleGroupAdded && line.contains("#EXT-X-STREAM-INF") {
                // Add subtitle tracks
                for (trackIndex, track) in subtitleTracks.enumerated() {
                    let subtitlePlaylistURL = createSubtitlePlaylistURL(for: track, index: trackIndex)
                    let defaultFlag = track.isDefault ? "YES" : "NO"
                    let autoSelectFlag = track.autoSelect ? "YES" : "NO"
                    
                    let mediaLine = "#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"subs\",NAME=\"\(track.name)\",LANGUAGE=\"\(track.language)\",DEFAULT=\(defaultFlag),AUTOSELECT=\(autoSelectFlag),FORCED=NO,URI=\"\(subtitlePlaylistURL)\""
                    modifiedLines.append(mediaLine)
                }
                
                modifiedLines.append("")
                subtitleGroupAdded = true
            }
            
            // Add SUBTITLES="subs" to stream info lines
            if line.contains("#EXT-X-STREAM-INF") {
                if !line.contains("SUBTITLES=") {
                    // Add SUBTITLES attribute
                    let modifiedLine = line + ",SUBTITLES=\"subs\""
                    modifiedLines.append(modifiedLine)
                } else {
                    modifiedLines.append(line)
                }
            } else {
                modifiedLines.append(line)
            }
        }
        
        return modifiedLines.joined(separator: "\n")
    }
    
    private func createSubtitlePlaylistURL(for track: SubtitleTrack, index: Int) -> String {
        // Create a custom URL that we'll intercept and handle
        return "\(Self.customScheme)://subtitle/track\(index).m3u8"
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                       shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return false
    }
}
