//
//  favouriteViewWrapper.swift
//  Kanzen
//
//  Created by Dawud Osman on 22/10/2025.
//

import SwiftUI

#if !os(tvOS)
struct favouriteViewWrapper: View {
    var favouriteContent: MangaData
    var currModule: ModuleDataContainer?
    @State var moduleLoaded: Bool = false
    @ObservedObject var kanzen : KanzenEngine
    
    init(favouriteContent: MangaData, currModule: ModuleDataContainer?) {
        self.favouriteContent = favouriteContent
        self.kanzen = KanzenEngine()
        self.currModule = currModule
    }
    
    var body: some View {
        if moduleLoaded {
            contentView(parentModule: currModule,title: favouriteContent.title ?? "", imageURL: favouriteContent.imageURL ?? "", params: favouriteContent.mangaId).environmentObject(kanzen)
        }
        else{
            Text("MODULE NOT LOADED")
                .task{
                    if let module = currModule {
                        do {
                            let content = try ModuleManager.shared.getModuleScript(module: module)
                            try kanzen.loadScript(content)
                            self.moduleLoaded = true
                        }
                        catch{
                            Logger.shared.log("Error loading module", type: "Error")
                        }
                    }
                }
        }
    }
}
#endif
