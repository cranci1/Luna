//
//  LanguageSelectionView.swift
//  Luna
//
//  Created by Dominic on 03.01.26.
//

import SwiftUI

struct LanguageSelectionView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared
    @Binding var selectedLanguage: String
    let languages: [(String, String)]

    var body: some View {
        List {
            Section {
                ForEach(languages, id: \.0) { language in
                    #if os(tvOS)
                        Button {
                            selectedLanguage = language.0
                        } label: {
                            rowContent(for: language)
                        }
                            .buttonStyle(.plain)
                            .padding(.vertical)
                    #else
                        rowContent(for: language)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedLanguage = language.0
                            }
                    #endif
                }
            } header: {
                #if os(tvOS)
                    Text("LANGUAGE")
                        .fontWeight(.bold)
                #endif
            }
        }
        #if os(tvOS)
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #else
            .navigationTitle("Language")
        #endif
    }

    @ViewBuilder
    private func rowContent(for language: (String, String)) -> some View {
        HStack {
            Text(language.1)
                .foregroundColor(.primary)
            Spacer()
            if selectedLanguage == language.0 {
                Image(systemName: "checkmark")
                    .foregroundColor(accentColorManager.currentAccentColor)
            }
        }
    }
}
