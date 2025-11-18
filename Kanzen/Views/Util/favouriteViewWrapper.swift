//
//  favouriteViewWrapper.swift
//  Kanzen
//
//  Created by Dawud Osman on 22/10/2025.
//
import SwiftUI
struct favouriteViewWrapper: View {
     var favouriteContent: MangaData
    var currModule: ModuleDataContainer?
    @State var moduleLoaded: Bool
    @ObservedObject var kanzen : KanzenEngine
    init(favouriteContent: MangaData, currModule: ModuleDataContainer?) {
        self.favouriteContent = favouriteContent
        self.moduleLoaded = false
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
                    print("module is ")
                    print(currModule)
                    if let module = currModule {
                        print("this called")
                        do {
                            let content = try ModuleManager.shared.getModuleScript(module: module)
                            try kanzen.loadScript(content)
                            self.moduleLoaded = true
                        }
                        catch{
                            print("Error loading module")
                        }
                    }
                    else{
                        print("no module assigned in init")
                    }
                }
        }
        
    }
}

