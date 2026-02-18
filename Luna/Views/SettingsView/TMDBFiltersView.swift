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
                #if os(tvOS)
                    Button {
                        contentFilter.filterHorror.toggle()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Filter Horror Content")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
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
                    }
                        .buttonStyle(.plain)
                        .padding(.vertical)
                #else
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
                #endif
            } header: {
                Text("CONTENT FILTERS")
                    .fontWeight(.bold)
            } footer: {
                Text("Filters apply to all TMDB content including search results and home contents.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            
            Section {
                #if os(tvOS)
                    Button {

                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)

                            Text("Some content may still appear if not properly tagged or rated")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                    }
                        .buttonStyle(.plain)
                        .disabled(true)
                        .padding(.vertical)
                #else
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)

                        Text("Some content may still appear if not properly tagged or rated")
                            .font(.subheadline)
                    }
                #endif
            } header: {
                Text("INFORMATION")
                    .fontWeight(.bold)
            }
        }
        #if os(tvOS)
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #else
            .navigationTitle("Content Filters")
        #endif
    }
}

#Preview {
    NavigationView {
        TMDBFiltersView()
    }
}
