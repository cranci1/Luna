//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
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
            HStack(spacing: 0) {
                VStack(spacing: 30) {
                    Image("Luna")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 500, height: 500)
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                        .shadow(radius: 10)

                    VStack(spacing: 15) {
                        Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                            .font(.footnote)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)

                        Text("Copyright © \(Calendar.current.component(.year, from: Date())) Luna by Cranci")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                NavigationStack {
                    settingsContent
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text("TMDB Settings")
            } footer: {
                Text("Configure language preferences and content filtering options for TMDB data.")
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
            } footer: {
                Text("Choose the algorithm used to match and rank search results.")
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
                
                NavigationLink(destination: LoggerView()) {
                    Text("Logger")
                }
            }
        }
        #if !os(tvOS)
            .navigationTitle("Settings")
        #else
            .listStyle(.grouped)
            .scrollClipDisabled()
        #endif
    }
}

struct LanguageSelectionView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared
    @Binding var selectedLanguage: String
    let languages: [(String, String)]
    
    var body: some View {
        List {
            ForEach(languages, id: \.0) { language in
                HStack {
                    Text(language.1)
                    Spacer()
                    if selectedLanguage == language.0 {
                        Image(systemName: "checkmark")
                            .foregroundColor(accentColorManager.currentAccentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedLanguage = language.0
                }
            }
        }
        .navigationTitle("Language")
    }
}
