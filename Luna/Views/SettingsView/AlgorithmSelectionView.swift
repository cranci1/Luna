//
//  AlgorithmSelectionView.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import SwiftUI

struct AlgorithmSelectionView: View {
    @StateObject private var algorithmManager = AlgorithmManager.shared
    
    var body: some View {
        List {
            Section {
                ForEach(SimilarityAlgorithm.allCases, id: \.self) { algorithm in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(algorithm.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(algorithm.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if algorithmManager.selectedAlgorithm == algorithm {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        algorithmManager.selectedAlgorithm = algorithm
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("SIMILARITY ALGORITHMS")
            } footer: {
                Text("The similarity algorithm determines how search results are matched and ranked. Jaro-Winkler is recommended for media titles as it performs better with names and short strings, but can fail sometimes.")
            }
        }
        .navigationTitle("Algorithm")
    }
}
