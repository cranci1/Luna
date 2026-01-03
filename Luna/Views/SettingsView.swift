//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    @AppStorage("showKanzen") private var showKanzen: Bool = false

    @StateObject private var algorithmManager = AlgorithmManager.shared

    let languages = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es-ES", "Spanish (Spain)"),
        ("es-MX", "Spanish (Mexico)"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("zh-CN", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)"),
        ("ru-RU", "Russian"),
        ("ar-SA", "Arabic"),
        ("hi-IN", "Hindi"),
        ("th-TH", "Thai"),
        ("tr-TR", "Turkish"),
        ("pl-PL", "Polish"),
        ("nl-NL", "Dutch"),
        ("sv-SE", "Swedish"),
        ("da-DK", "Danish"),
        ("no-NO", "Norwegian"),
        ("fi-FI", "Finnish")
    ]
    
    var body: some View {
        #if os(tvOS)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    sidebarView
                        .frame(width: geometry.size.width * 0.4)
                        .frame(maxHeight: .infinity)

                    NavigationStack {
                        settingsContent
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        #else
            if #available(iOS 16.0, *) {
                NavigationStack {
                    settingsContent
                }
            } else {
                NavigationView {
                    settingsContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        #endif
    }

    private var sidebarView: some View {
        VStack(spacing: 30) {
            Image("Luna")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 500, height: 500)
                .background(colorScheme == .dark ? .black : .white)
                .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                .shadow(radius: 10)

            VStack(spacing: 15) {
                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)

                Text("Copyright © \(String(Calendar.current.component(.year, from: Date()))) Luna by Cranci")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
    }

    private var settingsContent: some View {
        List {
            Section {
                NavigationLink(destination: LanguageSelectionView(selectedLanguage: $selectedLanguage, languages: languages)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Informations Language")
                        }
                        
                        Spacer()
                        
                        Text(languages.first { $0.0 == selectedLanguage }?.1 ?? "English (US)")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(destination: TMDBFiltersView()) {
                    Text("Content Filters")
                }
            } header: {
                Text("TMDB SETTINGS")
                    .fontWeight(.bold)
            } footer: {
                Text("Configure language preferences and content filtering options for TMDB data.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            
            Section {
                NavigationLink(destination: AlgorithmSelectionView()) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Matching Algorithm")
                        }
                        
                        Spacer()
                        
                        Text(algorithmManager.selectedAlgorithm.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("SEARCH SETTINGS")
                    .fontWeight(.bold)
            } footer: {
                Text("Choose the algorithm used to match and rank search results.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            
            Section {
                NavigationLink(destination: PlayerSettingsView()) {
                    Text("Media Player")
                }
                
                NavigationLink(destination: AlternativeUIView()) {
                    Text("Appearance")
                }
                
                NavigationLink(destination: ServicesView()) {
                    Text("Services")
                }

                NavigationLink(destination: StorageView()) {
                    Text("Storage")
                }

                NavigationLink(destination: LoggerView()) {
                    Text("Logger")
                }
            } header: {
                Text("MISCELLANEOUS")
                    .fontWeight(.bold)
            } footer: {
                Text("")
                    .padding(.bottom)
            }

            #if !os(tvOS)
            Section{
                Text("Switch to Kanzen")
                    .onTapGesture {
                        showKanzen = true
                    }
            }
            header:{
                Text("OTHERS")
                    .fontWeight(.bold)
            }
            #endif
        }
        #if !os(tvOS)
            .navigationTitle("Settings")
        #else
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #endif
    }
}
