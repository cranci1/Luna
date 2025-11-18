//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 12/08/25.
//

import SwiftUI
import Kingfisher
@main
struct SoraApp: App {
    
    @StateObject private var settings = Settings()
    @StateObject private var moduleManager = ModuleManager.shared
    @StateObject private var favouriteManager = FavouriteManager.shared
    let kanzen = KanzenEngine();
    func configureKingfisher() {
        let cache = ImageCache.default
        // set max disk cache size
        cache.diskStorage.config.sizeLimit = 100 * 1024 * 1024
        cache.diskStorage.config.expiration = .seconds(600)
        
        // set max memory cache size
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100 mb
        cache.memoryStorage.config.countLimit = 100
        cache.memoryStorage.config.expiration = .seconds(600)
        
    }
    init() {
        configureKingfisher()
        let downloader = ImageDownloader(name: "custom.downloader")
        downloader.downloadTimeout = 15

        // Limit the concurrent download count
        downloader.sessionConfiguration.httpMaximumConnectionsPerHost = 2

        // Assign the custom downloader to the shared manager
        KingfisherManager.shared.downloader = downloader
    }
    // Persisted toggle state
    @AppStorage("showKanzen") private var showKanzen: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if showKanzen {
                    KanzenMenu().environmentObject(settings).environmentObject(moduleManager).environmentObject(favouriteManager)
                    .environment(\.managedObjectContext, favouriteManager.container.viewContext)
                    .accentColor(settings.accentColor)
            }
            else{
                ContentView()
            }
        }
    }
}
