//
//  HomeSectionsView.swift
//  Sora
//
//  Created by Francesco on 11/09/25.
//

import SwiftUI

struct HomeSectionsView: View {
    @AppStorage("homeSections") private var homeSectionsData: Data = {
        if let data = try? JSONEncoder().encode(HomeSection.defaultSections) {
            return data
        }
        return Data()
    }()
    
    @State private var sections: [HomeSection] = []
    @StateObject private var accentColorManager = AccentColorManager.shared
    @StateObject private var contentFilter = TMDBContentFilter.shared
    
    var body: some View {
        List {
            Section {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    let isLocked = contentFilter.animeOnlyMode && contentFilter.isNonAnimeSection(section.id)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if isLocked {
                                Text("Hidden in Anime Only Mode")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("Order: \(section.order + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { isLocked ? false : section.isEnabled },
                            set: { newValue in
                                guard !isLocked else { return }
                                sections[index].isEnabled = newValue
                                saveSections()
                            }
                        ))
                        .tint(accentColorManager.currentAccentColor)
                        .disabled(isLocked)
                    }
                    .opacity(isLocked ? 0.4 : 1.0)
                }
                .onMove(perform: moveSection)
            } header: {
                HStack {
                    Text("Content Sections")
                    Spacer()
#if !os(tvOS)
                    EditButton()
                        .foregroundColor(accentColorManager.currentAccentColor)
#endif
                }
            } footer: {
                Text("Toggle sections on/off and reorder them by tapping Edit.")
            }
            
            Section {
                Button("Reset to Default") {
                    resetToDefault()
                }
                .foregroundColor(accentColorManager.currentAccentColor)
            } header: {
                Text("Reset")
            } footer: {
                Text("This will restore all sections to their default state and order.")
            }
        }
        .navigationTitle("Home Sections")
        .onAppear {
            loadSections()
        }
    }
    
    private func loadSections() {
        if let decodedSections = try? JSONDecoder().decode([HomeSection].self, from: homeSectionsData) {
            sections = decodedSections.sorted { $0.order < $1.order }
        } else {
            sections = HomeSection.defaultSections
            saveSections()
        }
    }
    
    private func saveSections() {
        for (index, _) in sections.enumerated() {
            sections[index].order = index
        }
        
        if let encoded = try? JSONEncoder().encode(sections) {
            homeSectionsData = encoded
        }
    }
    
    private func moveSection(from source: IndexSet, to destination: Int) {
        sections.move(fromOffsets: source, toOffset: destination)
        saveSections()
    }
    
    private func resetToDefault() {
        sections = HomeSection.defaultSections
        saveSections()
    }
}
