//
//  SubtitleOverlayView.swift
//  Luna
//
//  Created by TrinityHades on 09/01/26.
//

import SwiftUI
import AVFoundation
import Combine

/// A subtitle cue with timing information
struct SubtitleCue: Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

/// View that displays synchronized subtitles over video content
struct SubtitleOverlayView: View {
    @ObservedObject var controller: SubtitleController
    
    var body: some View {
        VStack {
            Spacer()
            
            if let currentCue = controller.currentCue {
                Text(currentCue.text)
                    .font(.system(size: subtitleFontSize, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.75))
                    )
                    .padding(.bottom, bottomPadding)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: controller.currentCue?.id)
            }
        }
    }
    
    private var subtitleFontSize: CGFloat {
        #if os(tvOS)
        return 42
        #else
        return 18
        #endif
    }
    
    private var bottomPadding: CGFloat {
        #if os(tvOS)
        return 80
        #else
        return 60
        #endif
    }
}

/// Controller that manages subtitle parsing and synchronization
class SubtitleController: ObservableObject {
    static let overlayTrackName = "Overlay English"

    @Published var currentCue: SubtitleCue?
    @Published var isLoaded: Bool = false
    @Published var subtitlesEnabled: Bool = true
    /// Positive values delay subtitles; negative values show earlier.
    @Published var timeOffset: TimeInterval = 0

    /// True when the system player has a legible option selected; we suppress overlay to avoid double subtitles.
    @Published private(set) var suppressedBySystemSubtitles: Bool = false
    
    private var cues: [SubtitleCue] = []
    private var timeObserver: Any?
    private weak var player: AVPlayer?
    private var lastCueIndex: Int = -1
    private var lastSystemSubtitleSelectionEnabled: Bool?
    private var manualOverlaySelection: Bool = false
    
    init() {}
    
    /// Load subtitles from URL
    func loadSubtitles(from urlString: String) {
        guard let url = URL(string: urlString) else {
            Logger.shared.log("[SubtitleController] Invalid subtitle URL: \(urlString)", type: "Error")
            return
        }
        
        Logger.shared.log("[SubtitleController] Loading subtitles from: \(urlString)", type: "Stream")
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                guard let content = String(data: data, encoding: .utf8) else {
                    Logger.shared.log("[SubtitleController] Failed to decode subtitle data", type: "Error")
                    return
                }

                // Normalize line endings for consistent parsing across sources.
                let normalizedContent = content
                    .replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "\n")
                
                let parsedCues: [SubtitleCue]
                
                // Detect format and parse
                if normalizedContent.contains("WEBVTT") {
                    parsedCues = parseVTT(normalizedContent)
                } else {
                    parsedCues = parseSRT(normalizedContent)
                }
                
                await MainActor.run {
                    self.cues = parsedCues
                    self.isLoaded = true
                    Logger.shared.log("[SubtitleController] Loaded \(parsedCues.count) subtitle cues", type: "Stream")
                }
                
            } catch {
                Logger.shared.log("[SubtitleController] Failed to load subtitles: \(error.localizedDescription)", type: "Error")
            }
        }
    }
    
    /// Attach to player for time synchronization
    func attach(to player: AVPlayer) {
        self.player = player
        
        // Remove existing observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        
        // Add periodic time observer (every 0.1 seconds for smooth subtitle updates)
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateCurrentCue(for: time.seconds)
        }
        
        Logger.shared.log("[SubtitleController] Attached to player", type: "Stream")
    }
    
    /// Detach from player
    func detach() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        player = nil
    }
    
    private func updateCurrentCue(for time: TimeInterval) {
        guard time.isFinite else { return }

        // Follow the user's intent in the built-in player subtitle menu.
        syncWithSystemSubtitleSelection()

        guard subtitlesEnabled, !cues.isEmpty else {
            if currentCue != nil {
                currentCue = nil
            }
            return
        }

        // Apply global offset. Most real-world subtitle issues are a constant offset.
        let adjustedTime = time + timeOffset

        // Binary search for efficiency with large subtitle files
        let cue = findCue(for: adjustedTime)
        
        if cue?.id != currentCue?.id {
            currentCue = cue
        }
    }

    private func syncWithSystemSubtitleSelection() {
        guard let player else { return }
        guard let item = player.currentItem else { return }
        guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            // No legible group in the asset; nothing to track.
            if suppressedBySystemSubtitles { suppressedBySystemSubtitles = false }
            lastSystemSubtitleSelectionEnabled = nil
            return
        }

        let selected = item.currentMediaSelection.selectedMediaOption(in: group)
        let systemEnabled = (selected != nil)
        let selectedName = selected?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOverlaySelection = selectedName?.caseInsensitiveCompare(Self.overlayTrackName) == .orderedSame

        suppressedBySystemSubtitles = systemEnabled && !isOverlaySelection

        if manualOverlaySelection {
            if systemEnabled {
                item.select(nil, in: group)
            }
            if !subtitlesEnabled {
                subtitlesEnabled = true
                Logger.shared.log("[SUBTITLE] Manual overlay selection active; enabling overlay subtitles", type: "Stream")
            }
            lastSystemSubtitleSelectionEnabled = systemEnabled
            return
        }

        // Sync overlay subtitles with the specific overlay track selection.
        if isOverlaySelection {
            if !subtitlesEnabled {
                subtitlesEnabled = true
                Logger.shared.log("[SUBTITLE] Overlay track selected; enabling overlay subtitles", type: "Stream")
            }
        } else {
            if subtitlesEnabled {
                subtitlesEnabled = false
                let selectedLabel = selectedName ?? "none"
                Logger.shared.log("[SUBTITLE] Overlay track not selected (current: \(selectedLabel)); disabling overlay subtitles", type: "Stream")
            }
            if systemEnabled {
                manualOverlaySelection = false
            }
        }

        lastSystemSubtitleSelectionEnabled = systemEnabled
    }

    func setManualOverlaySelection(_ active: Bool) {
        manualOverlaySelection = active
        if active {
            syncWithSystemSubtitleSelection()
        }
    }
    
    private func findCue(for time: TimeInterval) -> SubtitleCue? {
        // Optimization: check if we're still in the same cue
        if lastCueIndex >= 0 && lastCueIndex < cues.count {
            let cue = cues[lastCueIndex]
            if time >= cue.startTime && time <= cue.endTime {
                return cue
            }
            
            // Check next cue
            let nextIndex = lastCueIndex + 1
            if nextIndex < cues.count {
                let nextCue = cues[nextIndex]
                if time >= nextCue.startTime && time <= nextCue.endTime {
                    lastCueIndex = nextIndex
                    return nextCue
                }
            }
        }
        
        // Binary search
        var low = 0
        var high = cues.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            let cue = cues[mid]
            
            if time < cue.startTime {
                high = mid - 1
            } else if time > cue.endTime {
                low = mid + 1
            } else {
                lastCueIndex = mid
                return cue
            }
        }
        
        return nil
    }
    
    // MARK: - SRT Parsing
    
    private func parseSRT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        // Split on one-or-more blank lines (supports extra spacing).
        let blocks = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n\n")
        
        for block in blocks {
            let lines = block.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            guard lines.count >= 2 else { continue }
            
            // Find the timing line (contains " --> ")
            var timingLineIndex = -1
            for (index, line) in lines.enumerated() {
                if line.contains(" --> ") {
                    timingLineIndex = index
                    break
                }
            }
            
            guard timingLineIndex >= 0 && timingLineIndex < lines.count - 1 else { continue }
            
            let timingLine = lines[timingLineIndex]
            let timeParts = timingLine.components(separatedBy: " --> ")
            
            guard timeParts.count == 2 else { continue }
            let startPart = timeParts[0].trimmingCharacters(in: .whitespaces)
            let endPart = timeParts[1]
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .first ?? ""

            guard let startTime = parseTimestamp(startPart),
                  let endTime = parseTimestamp(endPart) else {
                continue
            }
            
            // Get text lines (everything after timing)
            let textLines = Array(lines[(timingLineIndex + 1)...])
            let text = textLines.joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Remove HTML tags
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !text.isEmpty {
                cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: text))
            }
        }
        
        return cues.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - VTT Parsing
    
    private func parseVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            
            // Look for timing line
            if line.contains(" --> ") {
                let timeParts = line.components(separatedBy: " --> ")
                
                     if timeParts.count >= 2,
                         let startTime = parseVTTTimestamp(timeParts[0].trimmingCharacters(in: .whitespaces)),
                         let endTime = parseVTTTimestamp(timeParts[1].components(separatedBy: .whitespaces).first?.trimmingCharacters(in: .whitespaces) ?? "") {
                    
                    // Collect text lines until empty line or end
                    var textLines: [String] = []
                    i += 1
                    
                    while i < lines.count && !lines[i].isEmpty && !lines[i].contains(" --> ") {
                        textLines.append(lines[i])
                        i += 1
                    }
                    
                    let text = textLines.joined(separator: "\n")
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !text.isEmpty {
                        cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: text))
                    }
                    
                    continue
                }
            }
            
            i += 1
        }
        
        return cues.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Timestamp Parsing
    
    /// Parse SRT timestamp (00:00:00,000)
    private func parseTimestamp(_ string: String) -> TimeInterval? {
        // Handle both comma and period as decimal separator
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return parseVTTTimestamp(normalized)
    }
    
    /// Parse VTT timestamp (00:00:00.000 or 00:00.000)
    private func parseVTTTimestamp(_ string: String) -> TimeInterval? {
        let parts = string.components(separatedBy: ":")
        
        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0
        
        if parts.count == 3 {
            hours = Double(parts[0]) ?? 0
            minutes = Double(parts[1]) ?? 0
            seconds = Double(parts[2]) ?? 0
        } else if parts.count == 2 {
            minutes = Double(parts[0]) ?? 0
            seconds = Double(parts[1]) ?? 0
        } else {
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    deinit {
        detach()
    }
}
