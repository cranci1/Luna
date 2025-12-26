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
