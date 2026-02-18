//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 12/08/25.
//

import SwiftUI

@main
struct SoraApp: App {
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared

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
                    .environmentObject(deepLinkHandler)
                    .accentColor(settings.accentColor)
                    .storageErrorOverlay()
                    .onOpenURL { url in
                        deepLinkHandler.handle(url: url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                        deepLinkHandler.handleUserActivity(userActivity)
                    }
                    .onContinueUserActivity("com.luna.details") { userActivity in
                        deepLinkHandler.handleUserActivity(userActivity)
                    }
            } else {
                ContentView()
                    .environmentObject(deepLinkHandler)
                    .storageErrorOverlay()
                    .onOpenURL { url in
                        deepLinkHandler.handle(url: url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                        deepLinkHandler.handleUserActivity(userActivity)
                    }
                    .onContinueUserActivity("com.luna.details") { userActivity in
                        deepLinkHandler.handleUserActivity(userActivity)
                    }
            }
        }
    }
#else
    @StateObject private var profileManager = TVOSProfileManager.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkHandler)
                .environmentObject(profileManager)
                .storageErrorOverlay()
                .onOpenURL { url in
                    deepLinkHandler.handle(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    deepLinkHandler.handleUserActivity(userActivity)
                }
                .onContinueUserActivity("com.luna.details") { userActivity in
                    deepLinkHandler.handleUserActivity(userActivity)
                }
        }
    }
#endif
}
