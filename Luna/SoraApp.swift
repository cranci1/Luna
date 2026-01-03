//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 12/08/25.
//

import SwiftUI

@main
struct SoraApp: App {

#if !os(tvOS)
    @StateObject private var settings = Settings()
    @StateObject private var moduleManager = ModuleManager.shared
    @StateObject private var favouriteManager = FavouriteManager.shared

    @AppStorage("showKanzen") private var showKanzen: Bool = false
    let kanzen = KanzenEngine();

    var body: some Scene {
        WindowGroup {
            if showKanzen {
                KanzenMenu()
                    .environmentObject(settings)
                    .environmentObject(moduleManager)
                    .environmentObject(favouriteManager)
                    .accentColor(settings.accentColor)
                    .storageErrorOverlay()
            } else {
                ContentView()
                    .storageErrorOverlay()
            }
        }
    }
#else
    var body: some Scene {
        WindowGroup {
            ContentView()
                .storageErrorOverlay()
        }
    }
#endif
}
