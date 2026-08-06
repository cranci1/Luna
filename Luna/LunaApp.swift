//
//  LunaApp.swift
//  Sora
//
//  Created by Francesco on 12/08/25.
//

import Sybau
import SwiftUI
import Kingfisher

@main
struct LunaApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var moduleManager = ModuleManager.shared
    @StateObject private var favouriteManager = FavouriteManager.shared
    @AppStorage("updateUserAgents") private var updateUserAgents: Bool = true
    
#if !os(tvOS)
    @AppStorage("showKanzen") private var showKanzen: Bool = false
    let kanzen = KanzenEngine();
#endif
    
    // MARK: - Initialization
    init() {
        if updateUserAgents {
            URLSession.fetchAndUpdateUserAgents { error in
                if let error = error {
                    Logger.shared.log("Failed to update user agents: \(error.localizedDescription)", type: "Error")
                } else {
                    Logger.shared.log("User agents updated from microlink.io")
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
#if os(tvOS)
            ContentView()
#else
            if showKanzen {
                KanzenMenu()
                    .environmentObject(settings)
                    .environmentObject(moduleManager)
                    .environmentObject(favouriteManager)
                    .environment(\.managedObjectContext, favouriteManager.container.viewContext)
                    .accentColor(settings.accentColor)
            } else {
                ContentView()
            }
#endif
        }
    }
}
