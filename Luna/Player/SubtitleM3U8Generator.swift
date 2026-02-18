//
//  SubtitleM3U8Generator.swift
//  Luna
//
//  Created by TrinityHades on 09/01/26
//

import Foundation

/// Generates HLS subtitle playlists for WebVTT files
class SubtitleM3U8Generator {
    
    /// Creates an HLS subtitle playlist (m3u8) for a WebVTT file
    /// - Parameters:
    ///   - subtitleURL: URL of the WebVTT or SRT subtitle file (SRT will be converted)
    ///   - duration: Duration of the subtitle file in seconds (optional, will be calculated if not provided)
    /// - Returns: M3U8 playlist content as a string
    static func createPlaylist(for subtitleURL: URL, duration: Double? = nil) async -> String? {
        Logger.shared.log("[SUBTITLE] Creating playlist for: \(subtitleURL.absoluteString)", type: "Stream")
        
        // Check if this is an SRT file that needs conversion
        let urlString = subtitleURL.absoluteString.lowercased()
        let isSRT = urlString.contains("format=srt") || urlString.hasSuffix(".srt")
        
        var finalSubtitleURL = subtitleURL
        
        if isSRT {
            Logger.shared.log("[SUBTITLE] Detected SRT format, attempting conversion to VTT", type: "Stream")
            // Try to download and convert SRT to VTT
            if let vttURL = await convertSRTtoVTT(from: subtitleURL) {
                finalSubtitleURL = vttURL
                Logger.shared.log("[SUBTITLE] Successfully converted SRT to VTT", type: "Stream")
            } else {
                Logger.shared.log("[SUBTITLE] SRT conversion failed, using original URL", type: "Warning")
            }
        }
        
        // If duration not provided, try to calculate it from the VTT file
        var playlistDuration = duration ?? 3600.0 // Default to 1 hour if can't determine
        
        if duration == nil {
            if let calculatedDuration = await calculateDuration(from: finalSubtitleURL) {
                playlistDuration = calculatedDuration
            }
        }
        
        // Round up to nearest second
        let targetDuration = Int(ceil(playlistDuration))
        
        Logger.shared.log("[SUBTITLE] Playlist duration: \(targetDuration)s, URL: \(finalSubtitleURL.absoluteString)", type: "Stream")
        
        // Create the playlist
        // Note: We don't segment the VTT file as Apple recommends, because it can't be done client-side
        // See: https://developer.apple.com/forums/thread/113063?answerId=623328022#623328022
        let playlist = """
        #EXTM3U
        #EXT-X-TARGETDURATION:\(targetDuration)
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(targetDuration).0
        \(finalSubtitleURL.absoluteString)
        #EXT-X-ENDLIST
        """
        
        Logger.shared.log("[SUBTITLE] Generated playlist successfully", type: "Stream")
        return playlist
    }
    
    /// Calculates the duration of a WebVTT file by parsing its last timestamp
    private static func calculateDuration(from url: URL) async -> Double? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            return parseDuration(from: content)
            
        } catch {
            Logger.shared.log("Failed to fetch subtitle file for duration calculation: \(error.localizedDescription)", type: "Warning")
            return nil
        }
    }
    
    /// Parses the duration from WebVTT content by finding the last end timestamp
    private static func parseDuration(from content: String) -> Double? {
        let lines = content.components(separatedBy: .newlines)
        var lastEndTime: Double = 0
        
        for line in lines {
            // Look for timestamp lines (format: 00:00:00.000 --> 00:00:05.000)
            if line.contains("-->") {
                let components = line.components(separatedBy: "-->")
                if components.count == 2 {
                    let endTimeStr = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let endTime = timeStringToSeconds(endTimeStr) {
                        lastEndTime = max(lastEndTime, endTime)
                    }
                }
            }
        }
        
        return lastEndTime > 0 ? lastEndTime : nil
    }
    
    /// Converts a time string (HH:MM:SS.mmm or MM:SS.mmm) to seconds
    private static func timeStringToSeconds(_ timeStr: String) -> Double? {
        // Normalize comma to period for milliseconds
        let normalized = timeStr.replacingOccurrences(of: ",", with: ".")
        
        // Remove any additional text after space
        let timePart = normalized.components(separatedBy: " ").first ?? normalized
        
        // Split by colon
        let components = timePart.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0
        
        if components.count == 3 {
            // HH:MM:SS.mmm
            hours = Double(components[0]) ?? 0
            minutes = Double(components[1]) ?? 0
            seconds = Double(components[2]) ?? 0
        } else if components.count == 2 {
            // MM:SS.mmm
            minutes = Double(components[0]) ?? 0
            seconds = Double(components[1]) ?? 0
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    /// Creates a simple in-memory subtitle playlist without fetching the VTT file
    /// Useful when duration is already known or when you want to avoid network requests
    static func createQuickPlaylist(for subtitleURL: URL, estimatedDuration: Double = 3600.0) -> String {
        let targetDuration = Int(ceil(estimatedDuration))
        
        return """
        #EXTM3U
        #EXT-X-TARGETDURATION:\(targetDuration)
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(targetDuration).0
        \(subtitleURL.absoluteString)
        #EXT-X-ENDLIST
        """
    }
    
    /// Converts SRT subtitle to VTT format by downloading, converting, and hosting temporarily
    private static func convertSRTtoVTT(from srtURL: URL) async -> URL? {
        do {
            // Download SRT file
            let (data, _) = try await URLSession.shared.data(from: srtURL)
            guard let srtContent = String(data: data, encoding: .utf8) else {
                Logger.shared.log("[SUBTITLE] Failed to decode SRT content", type: "Error")
                return nil
            }
            
            // Convert SRT to VTT
            let vttContent = convertSRTContentToVTT(srtContent)
            
            // Save to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let vttFileName = "subtitle_\(UUID().uuidString).vtt"
            let vttFileURL = tempDir.appendingPathComponent(vttFileName)
            
            try vttContent.write(to: vttFileURL, atomically: true, encoding: .utf8)
            Logger.shared.log("[SUBTITLE] Converted SRT saved to: \(vttFileURL.path)", type: "Stream")
            
            return vttFileURL
            
        } catch {
            Logger.shared.log("[SUBTITLE] SRT conversion error: \(error.localizedDescription)", type: "Error")
            return nil
        }
    }
    
    /// Converts SRT content string to VTT format
    private static func convertSRTContentToVTT(_ srtContent: String) -> String {
        var vttLines: [String] = ["WEBVTT", ""]
        
        let blocks = srtContent.components(separatedBy: "\n\n")
        
        for block in blocks {
            let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            guard lines.count >= 3 else { continue }
            
            // Skip the index number (first line)
            // Second line is the timestamp
            let timestampLine = lines[1].replacingOccurrences(of: ",", with: ".")
            vttLines.append(timestampLine)
            
            // Remaining lines are the subtitle text
            let textLines = Array(lines[2...])
            vttLines.append(contentsOf: textLines)
            vttLines.append("") // Empty line between cues
        }
        
        return vttLines.joined(separator: "\n")
    }
}
