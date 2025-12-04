//
//  MainMenu.swift
//  Luna
//
//  Created by Dawud Osman on 17/11/2025.
//

import SwiftUI

struct KanzenMenu: View {
    let kanzen = KanzenEngine();
    var body: some View {
        TabView {
            KanzenLibraryView().tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            BrowseView().tabItem {
                Label("Browse",systemImage: "list.bullet")
            }
            KanzenSettingsView().tabItem{
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
