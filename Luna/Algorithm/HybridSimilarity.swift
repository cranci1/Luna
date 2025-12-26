//
//  HybridSimilarity.swift
//  Sora
//
//  Created by Francesco on 22/08/25.
//

import Foundation

class HybridSimilarity {
    public static func calculateSimilarity(original: String, result: String) -> Double {
        guard !original.isEmpty && !result.isEmpty else {
            return original.isEmpty && result.isEmpty ? 1.0 : 0.0
        }
        
        let normalizedOriginal = original.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        let normalizedResult = result.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        
        guard !normalizedOriginal.isEmpty && !normalizedResult.isEmpty else {
            return normalizedOriginal.isEmpty && normalizedResult.isEmpty ? 1.0 : 0.0
        }
        
        return hybridSimilarity(normalizedOriginal, normalizedResult)
    }
    
    private static func hybridSimilarity(_ s1: String, _ s2: String) -> Double {
        let jaroWinklerScore = JaroWinklerSimilarity.calculateSimilarity(original: s1, result: s2)
        let levenshteinScore = LevenshteinDistance.calculateSimilarity(original: s1, result: s2)
        
        let s1Length = s1.count
        let s2Length = s2.count
        let avgLength = Double(s1Length + s2Length) / 2.0
        let lengthDifference = abs(s1Length - s2Length)
        let lengthRatio = Double(lengthDifference) / avgLength
        
        let prefixSimilarity = calculatePrefixSimilarity(s1, s2)
        
        var jaroWinklerWeight: Double
        var levenshteinWeight: Double
        
        if avgLength < 10 || prefixSimilarity > 0.7 {
            jaroWinklerWeight = 0.7
            levenshteinWeight = 0.3
        }
        else if avgLength > 50 {
            jaroWinklerWeight = 0.3
            levenshteinWeight = 0.7
        }
        else if lengthRatio > 0.5 {
            jaroWinklerWeight = 0.4
            levenshteinWeight = 0.6
        }
        else {
            jaroWinklerWeight = 0.5
            levenshteinWeight = 0.5
        }
        
        let weightedScore = (jaroWinklerScore * jaroWinklerWeight) + (levenshteinScore * levenshteinWeight)
        
        let algorithmAgreement = 1.0 - abs(jaroWinklerScore - levenshteinScore)
        let agreementBonus = algorithmAgreement > 0.8 ? 0.05 : 0.0
        
        let averageScore = (jaroWinklerScore + levenshteinScore) / 2.0
        let lowScorePenalty = averageScore < 0.3 ? 0.05 : 0.0
        
        let finalScore = min(1.0, max(0.0, weightedScore + agreementBonus - lowScorePenalty))
        
        return finalScore
    }
    
    private static func calculatePrefixSimilarity(_ s1: String, _ s2: String) -> Double {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let minLength = min(s1Array.count, s2Array.count)
        
        guard minLength > 0 else { return 0.0 }
        
        var commonPrefixLength = 0
        for i in 0..<min(minLength, 10) {
            if s1Array[i] == s2Array[i] {
                commonPrefixLength += 1
            } else {
                break
            }
        }
        
        return Double(commonPrefixLength) / Double(min(minLength, 10))
    }
}
