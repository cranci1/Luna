//
//  LevenshteinDistance.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import Foundation

class LevenshteinDistance {
    public static func calculateSimilarity(original: String, result: String) -> Double {
        guard !original.isEmpty && !result.isEmpty else {
            return original.isEmpty && result.isEmpty ? 1.0 : 0.0
        }
        
        let normalizedOriginal = original.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        let normalizedResult = result.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        
        guard !normalizedOriginal.isEmpty && !normalizedResult.isEmpty else {
            return normalizedOriginal.isEmpty && normalizedResult.isEmpty ? 1.0 : 0.0
        }
        
        let distance = levenshteinDistance(normalizedOriginal, normalizedResult)
        let maxLength = max(normalizedOriginal.count, normalizedResult.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - Double(distance) / Double(maxLength)
    }
    
    public static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        if s1Count == 0 { return s2Count }
        if s2Count == 0 { return s1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
}
