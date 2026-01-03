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
                    #if !os(tvOS)
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
                    #else
                    Button {
                        sections[index].isEnabled.toggle()
                        saveSections()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
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
                        .buttonStyle(.plain)
                        .padding(.vertical)
                    #endif
                }
                #if !os(tvOS)
                    .onMove(perform: moveSection)
                #endif
            } header: {
                HStack {
                    Text("CONTENT SECTIONS")
                        .fontWeight(.bold)
                    #if !os(tvOS)
                        Spacer()
                        EditButton()
                            .foregroundColor(accentColorManager.currentAccentColor)
                    #endif
                }
            } footer: {
                #if !os(tvOS)
                    Text("Toggle sections on/off and reorder them by tapping Edit.")
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                #endif
            }
            
            Section {
                Button(role: .destructive) {
                    resetToDefault()
                } label: {
                    Text("Reset to Default")
                        .foregroundColor(.red)

                    Spacer()
                }
                .buttonStyle(.plain)
                #if os(tvOS)
                    .padding(.vertical)
                #endif
                .foregroundColor(accentColorManager.currentAccentColor)
            } header: {
                Text("RESET")
                    .fontWeight(.bold)
            } footer: {
                Text("This will restore all sections to their default state and order.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
        }
        #if os(tvOS)
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #else
            .navigationTitle("Home Sections")
        #endif
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
