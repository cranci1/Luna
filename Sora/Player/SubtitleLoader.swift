//
//  SubtitleLoader.swift
//  Luna
//
//  Created by Francesco on 25/10/25.
//

import UIKit

struct SubtitleEntry {
    let startTime: Double
    let endTime: Double
    let text: String
    let attributedText: NSAttributedString
}

class SubtitleLoader {
    
    static func parseSubtitles(from content: String, fontSize: CGFloat = 18.0, foregroundColor: UIColor = .white) -> [SubtitleEntry] {
        if content.contains("WEBVTT") {
            return parseVTT(content, fontSize: fontSize, foregroundColor: foregroundColor)
        } else {
            return parseSRT(content, fontSize: fontSize, foregroundColor: foregroundColor)
        }
    }
    
    // MARK: - SRT Parser
    
    private static func parseSRT(_ content: String, fontSize: CGFloat, foregroundColor: UIColor) -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []
        let blocks = content.components(separatedBy: "\n\n")
        
        for block in blocks {
            let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard lines.count >= 3 else { continue }
            
            let timeLine = lines[1]
            let textLines = Array(lines[2...])
            
            if let (start, end) = parseTimestamp(timeLine) {
                let rawText = textLines.joined(separator: "\n")
                let attributedText = parseHTMLTags(rawText, fontSize: fontSize, foregroundColor: foregroundColor)
                entries.append(SubtitleEntry(startTime: start, endTime: end, text: rawText, attributedText: attributedText))
            }
        }
        
        return entries
    }
    
    // MARK: - VTT Parser
    
    private static func parseVTT(_ content: String, fontSize: CGFloat, foregroundColor: UIColor) -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0
        
        while i < lines.count && !lines[i].contains("-->") {
            i += 1
        }
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line.contains("-->") {
                if let (start, end) = parseTimestamp(line) {
                    var textLines: [String] = []
                    i += 1
                    
                    while i < lines.count {
                        let textLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        if textLine.isEmpty || textLine.contains("-->") {
                            break
                        }
                        textLines.append(textLine)
                        i += 1
                    }
                    
                    if !textLines.isEmpty {
                        let rawText = textLines.joined(separator: "\n")
                        let attributedText = parseHTMLTags(rawText, fontSize: fontSize, foregroundColor: foregroundColor)
                        entries.append(SubtitleEntry(startTime: start, endTime: end, text: rawText, attributedText: attributedText))
                    }
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }
        
        return entries
    }
    
    // MARK: - Timestamp Parser
    
    private static func parseTimestamp(_ line: String) -> (start: Double, end: Double)? {
        let components = line.components(separatedBy: "-->")
        guard components.count == 2 else { return nil }
        
        let startStr = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let endStr = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let start = timeStringToSeconds(startStr),
              let end = timeStringToSeconds(endStr) else {
            return nil
        }
        
        return (start, end)
    }
    
    private static func timeStringToSeconds(_ timeStr: String) -> Double? {
        let normalized = timeStr.replacingOccurrences(of: ",", with: ".")
        let timePart = normalized.components(separatedBy: " ").first ?? normalized
        
        let components = timePart.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0
        
        if components.count == 3 {
            hours = Double(components[0]) ?? 0
            minutes = Double(components[1]) ?? 0
            seconds = Double(components[2]) ?? 0
        } else if components.count == 2 {
            minutes = Double(components[0]) ?? 0
            seconds = Double(components[1]) ?? 0
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    // MARK: - HTML Tag Parser
    
    private static func parseHTMLTags(_ text: String, fontSize: CGFloat, foregroundColor: UIColor) -> NSAttributedString {
        let baseFont = UIFont.boldSystemFont(ofSize: fontSize)
        let italicFont = UIFont.italicSystemFont(ofSize: fontSize)
        
        let attributedString = NSMutableAttributedString()
        var currentText = text
        var currentIndex = currentText.startIndex
        
        while currentIndex < currentText.endIndex {
            if let italicStart = currentText[currentIndex...].range(of: "<i>") {
                let beforeItalic = String(currentText[currentIndex..<italicStart.lowerBound])
                if !beforeItalic.isEmpty {
                    let cleanText = removeHTMLTags(beforeItalic)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: baseFont,
                        .foregroundColor: foregroundColor
                    ]
                    attributedString.append(NSAttributedString(string: cleanText, attributes: attrs))
                }
                
                let searchStart = italicStart.upperBound
                if let italicEnd = currentText[searchStart...].range(of: "</i>") {
                    let italicText = String(currentText[italicStart.upperBound..<italicEnd.lowerBound])
                    let cleanItalicText = removeHTMLTags(italicText)
                    let italicAttrs: [NSAttributedString.Key: Any] = [
                        .font: italicFont,
                        .foregroundColor: foregroundColor
                    ]
                    attributedString.append(NSAttributedString(string: cleanItalicText, attributes: italicAttrs))
                    currentIndex = italicEnd.upperBound
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: baseFont,
                        .foregroundColor: foregroundColor
                    ]
                    attributedString.append(NSAttributedString(string: "<i>", attributes: attrs))
                    currentIndex = italicStart.upperBound
                }
            } else {
                let remainingText = String(currentText[currentIndex...])
                let cleanText = removeHTMLTags(remainingText)
                if !cleanText.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: baseFont,
                        .foregroundColor: foregroundColor
                    ]
                    attributedString.append(NSAttributedString(string: cleanText, attributes: attrs))
                }
                break
            }
        }
        
        if attributedString.length == 0 {
            let cleanText = removeHTMLTags(text)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: foregroundColor
            ]
            return NSAttributedString(string: cleanText, attributes: attrs)
        }
        
        return attributedString
    }
    
    private static func removeHTMLTags(_ text: String) -> String {
        var result = text
        
        let tags = ["<i>", "</i>", "<b>", "</b>", "<u>", "</u>", "<font.*?>", "</font>"]
        
        for tag in tags {
            if tag.contains(".*?") {
                result = result.replacingOccurrences(of: tag, with: "", options: .regularExpression)
            } else {
                result = result.replacingOccurrences(of: tag, with: "")
            }
        }
        
        return result
    }
}
