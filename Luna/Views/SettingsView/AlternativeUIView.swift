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
    @AppStorage("useSolidBackgroundBehindHero") private var useSolidBackgroundBehindHero = false
    
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        List {
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
#if !os(tvOS)
                    ColorPicker("", selection: $accentColorManager.currentAccentColor)
                        .onChange(of: accentColorManager.currentAccentColor) { _, newColor in
                            accentColorManager.saveAccentColor(newColor)
                        }
#endif
                }
            } header: {
                Text("Interface")
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
                        Text("Horizontal Episode list ")
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
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Solid Background")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("This will replace the gradient with a solid background")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $useSolidBackgroundBehindHero)
                        .tint(accentColorManager.currentAccentColor)
                }
            } header: {
                Text("DISPLAY OPTIONS")
            } footer: {
                Text("The alternative season menu uses a dropdown instead of a horizontal scroll for selecting seasons.")
            }
        }
        .navigationTitle("Appearance")
    }
}

#Preview {
    NavigationView {
        AlternativeUIView()
    }
}
