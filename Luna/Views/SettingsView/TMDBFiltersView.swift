//
//  TMDBFiltersView.swift
//  Sora
//
//  Created by Francesco on 11/09/25.
//

import SwiftUI

struct TMDBFiltersView: View {
    @StateObject private var contentFilter = TMDBContentFilter.shared
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Filter Horror Content")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Hide movies and TV shows with horror genre")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $contentFilter.filterHorror)
                        .tint(accentColorManager.currentAccentColor)
                }
            } header: {
                Text("Content Filters")
            } footer: {
                Text("Filters apply to all TMDB content including search results and home contents.")
            }
            
            Section {
                HStack() {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Some content may still appear if not properly tagged or rated")
                        .font(.subheadline)
                }
            } header: {
                Text("Information")
            }
        }
        .navigationTitle("Content Filters")
    }
}

#Preview {
    NavigationView {
        TMDBFiltersView()
    }
}
