//
//  AlternativeUIView.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import SwiftUI

struct AlternativeUIView: View {
    @AppStorage("seasonMenu") private var useSeasonMenu = false
    @AppStorage("horizontalEpisodeList") private var horizontalEpisodeList = false
    
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        List {
            #if !os(tvOS)
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accent Color")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("This affects buttons, links, and other interactive elements.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        ColorPicker("", selection: $accentColorManager.currentAccentColor)
                            .onChangeComp(of: accentColorManager.currentAccentColor) { _, newColor in
                                accentColorManager.saveAccentColor(newColor)
                            }
                    }
                } header: {
                    Text("INTERFACE")
                        .fontWeight(.bold)
                }

                Section {
                    NavigationLink(destination: HomeSectionsView()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Home Sections")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Customize which sections appear on the home screen and reorder them")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alternative Season Menu")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Use dropdown menu instead of horizontal scroll for seasons")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Toggle("", isOn: $useSeasonMenu)
                            .tint(accentColorManager.currentAccentColor)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Horizontal Episode list")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Use Horizontal list instead of vertical episode list")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Toggle("", isOn: $horizontalEpisodeList)
                            .tint(accentColorManager.currentAccentColor)
                    }
                } header: {
                    Text("DISPLAY OPTIONS")
                        .fontWeight(.bold)
                } footer: {
                    Text("The alternative season menu uses a dropdown instead of a horizontal scroll for selecting seasons.")
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
            #else
                Section {
                    NavigationLink(destination: HomeSectionsView()) {
                        Text("Customize Home Sections")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                        .padding(.vertical)

                    Button {
                        useSeasonMenu.toggle()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alternative Season Menu")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)

                                Text("Use dropdown menu instead of horizontal scroll for seasons")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Toggle("", isOn: $useSeasonMenu)
                                .tint(accentColorManager.currentAccentColor)
                        }
                    }
                        .buttonStyle(.plain)
                        .padding(.vertical)

                    Button {
                        horizontalEpisodeList.toggle()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Horizontal Episode list")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)

                                Text("Use Horizontal list instead of vertical episode list")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Toggle("", isOn: $horizontalEpisodeList)
                                .tint(accentColorManager.currentAccentColor)
                        }
                    }
                        .buttonStyle(.plain)
                        .padding(.vertical)
                } header: {
                    Text("DISPLAY OPTIONS")
                        .fontWeight(.bold)
                } footer: {
                    Text("The alternative season menu uses a dropdown instead of a horizontal scroll for selecting seasons.")
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
            #endif
        }
        #if os(tvOS)
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #else
            .navigationTitle("Appearance")
        #endif
    }
}
