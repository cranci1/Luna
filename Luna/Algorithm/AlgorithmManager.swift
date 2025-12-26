//
//  AlgorithmManager.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import Foundation

enum SimilarityAlgorithm: String, CaseIterable {
    case hybrid = "hybrid"
    case jaroWinkler = "jaro_winkler"
    case levenshtein = "levenshtein"
    
    var displayName: String {
        switch self {
        case .hybrid:
            return "Hybrid"
        case .jaroWinkler:
            return "Jaro-Winkler Similarity"
        case .levenshtein:
            return "Levenshtein Distance"
        }
    }
    
    var description: String {
        switch self {
        case .hybrid:
            return "Combines both algorithms for optimal matching across different string types and lengths."
        case .jaroWinkler:
            return "When matching names, titles, or short strings where prefix similarity are important."
        case .levenshtein:
            return "When you need precise differences across all text available."
        }
    }
}

class AlgorithmManager: ObservableObject {
    static let shared = AlgorithmManager()
    
    @Published var selectedAlgorithm: SimilarityAlgorithm {
        didSet {
            UserDefaults.standard.set(selectedAlgorithm.rawValue, forKey: "selectedSimilarityAlgorithm")
        }
    }
    
    private init() {
        let savedAlgorithm = UserDefaults.standard.string(forKey: "selectedSimilarityAlgorithm") ?? SimilarityAlgorithm.hybrid.rawValue
        self.selectedAlgorithm = SimilarityAlgorithm(rawValue: savedAlgorithm) ?? .hybrid
    }
    
    func calculateSimilarity(original: String, result: String) -> Double {
        guard !original.isEmpty && !result.isEmpty else {
            return original.isEmpty && result.isEmpty ? 1.0 : 0.0
        }
        
        let cleanOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanOriginal.isEmpty && !cleanResult.isEmpty else {
            return cleanOriginal.isEmpty && cleanResult.isEmpty ? 1.0 : 0.0
        }
        
        do {
            switch selectedAlgorithm {
            case .levenshtein:
                return LevenshteinDistance.calculateSimilarity(original: cleanOriginal, result: cleanResult)
            case .jaroWinkler:
                return JaroWinklerSimilarity.calculateSimilarity(original: cleanOriginal, result: cleanResult)
            case .hybrid:
                return HybridSimilarity.calculateSimilarity(original: cleanOriginal, result: cleanResult)
            }
        }
    }
}
