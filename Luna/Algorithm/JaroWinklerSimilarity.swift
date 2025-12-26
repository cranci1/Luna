//
//  JaroWinklerSimilarity.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import Foundation

class JaroWinklerSimilarity {
    public static func calculateSimilarity(original: String, result: String) -> Double {
        guard !original.isEmpty && !result.isEmpty else {
            return original.isEmpty && result.isEmpty ? 1.0 : 0.0
        }
        
        let normalizedOriginal = original.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        let normalizedResult = result.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        
        guard !normalizedOriginal.isEmpty && !normalizedResult.isEmpty else {
            return normalizedOriginal.isEmpty && normalizedResult.isEmpty ? 1.0 : 0.0
        }
        
        return jaroWinklerSimilarity(normalizedOriginal, normalizedResult)
    }
    
    public static func jaroWinklerSimilarity(_ s1: String, _ s2: String) -> Double {
        let jaroSimilarity = jaroSimilarity(s1, s2)
        
        if jaroSimilarity < 0.7 {
            return jaroSimilarity
        }
        
        let prefixLength = min(4, commonPrefixLength(s1, s2))
        return jaroSimilarity + (0.1 * Double(prefixLength) * (1.0 - jaroSimilarity))
    }
    
    private static func jaroSimilarity(_ s1: String, _ s2: String) -> Double {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        if s1Count == 0 && s2Count == 0 { return 1.0 }
        if s1Count == 0 || s2Count == 0 { return 0.0 }
        
        let matchWindow = max(0, max(s1Count, s2Count) / 2 - 1)
        let s1Matches = Array(repeating: false, count: s1Count)
        let s2Matches = Array(repeating: false, count: s2Count)
        
        var matches = 0
        var transpositions = 0
        
        var s1MatchesMutable = s1Matches
        var s2MatchesMutable = s2Matches
        
        for i in 0..<s1Count {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, s2Count)
            
            guard start < end else { continue }
            
            for j in start..<end {
                guard j < s2Count && j < s2MatchesMutable.count else { continue }
                
                if s2MatchesMutable[j] || s1Array[i] != s2Array[j] {
                    continue
                }
                
                s1MatchesMutable[i] = true
                s2MatchesMutable[j] = true
                matches += 1
                break
            }
        }
        
        if matches == 0 { return 0.0 }
        
        var k = 0
        for i in 0..<s1Count {
            if !s1MatchesMutable[i] { continue }
            
            while k < s2Count && !s2MatchesMutable[k] {
                k += 1
            }
            
            guard k < s2Count && k < s2Array.count else { break }
            
            if s1Array[i] != s2Array[k] {
                transpositions += 1
            }
            k += 1
        }
        
        guard matches > 0 else { return 0.0 }
        
        let jaro = (Double(matches) / Double(s1Count) +
                    Double(matches) / Double(s2Count) +
                    (Double(matches) - Double(transpositions) / 2.0) / Double(matches)) / 3.0
        
        return jaro
    }
    
    private static func commonPrefixLength(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let minLength = min(s1Array.count, s2Array.count)
        
        for i in 0..<minLength {
            if s1Array[i] != s2Array[i] {
                return i
            }
        }
        
        return minLength
    }
}
