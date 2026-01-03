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
                    #if os(tvOS)
                        Button {
                            algorithmManager.selectedAlgorithm = algorithm
                        } label: {
                            rowContent(for: algorithm)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical)
                    #else
                        rowContent(for: algorithm)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                algorithmManager.selectedAlgorithm = algorithm
                            }
                    #endif
                }
            } header: {
                Text("ALGORITHMS")
                    .fontWeight(.bold)
            } footer: {
                Text("The similarity algorithm determines how search results are matched and ranked. Jaro-Winkler is recommended for media titles as it performs better with names and short strings, but can fail sometimes.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
        }
        #if os(tvOS)
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #else
            .navigationTitle("Algorithm")
        #endif
    }

    @ViewBuilder
    private func rowContent(for algorithm: SimilarityAlgorithm) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(algorithm.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)

                    Text(algorithm.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if algorithmManager.selectedAlgorithm == algorithm {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
