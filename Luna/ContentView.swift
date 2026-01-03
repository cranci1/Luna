//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared

    @AppStorage("activeTab") private var selectedTab = 0
    @State private var showStorageError = false
    @State private var storageErrorMessage = ""

    var body: some View {
#if compiler(>=6.0)
        if #available(iOS 26.0, tvOS 26.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: 0) {
                    HomeView()
                }

                Tab("Library", systemImage: "books.vertical.fill", value: 1) {
                    LibraryView()
                }
                
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                    SearchView()
                }
                
                Tab("Settings", systemImage: "gear", value: 3) {
                    SettingsView()
                        .id(selectedTab)
                }

            }
#if !os(tvOS)
            .tabBarMinimizeBehavior(.onScrollDown)
#endif
            .accentColor(accentColorManager.currentAccentColor)
            
        } else {
            olderTabView
        }
#else
        olderTabView
#endif
    }
    
    private var olderTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(0)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            LibraryView()
                .tag(1)
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("Library")
                }
            
            SearchView()
                .tag(2)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            SettingsView()
                .tag(3)
                .id(selectedTab)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(accentColorManager.currentAccentColor)
    }
}

#Preview {
    ContentView()
}
