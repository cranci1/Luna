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
    
    var body: some View {
        List {
            Section {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Order: \(section.order + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { section.isEnabled },
                            set: { newValue in
                                sections[index].isEnabled = newValue
                                saveSections()
                            }
                        ))
                        .tint(accentColorManager.currentAccentColor)
                    }
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
