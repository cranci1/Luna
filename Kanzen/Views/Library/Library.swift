//
//  LibraryView.swift
//  Kanzen
//
//  Created by Dawud Osman on 22/05/2025.
//
import SwiftUI
import CoreData
struct KanzenLibraryView: View {
    @EnvironmentObject var favouriteManager: FavouriteManager
    @EnvironmentObject var moduleManager : ModuleManager
    @FetchRequest(
        entity: MangaData.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \MangaData.title, ascending: true)]
    ) var favouriteRequest : FetchedResults<MangaData>
    @State var cellWidth: CGFloat = 150
    private var columnCount: Int {
        let screenWidth = UIScreen.main.bounds.width
        return Int(screenWidth/(cellWidth+10))
    }
    var favouriteList : [MangaData]{
        if !favouriteRequest.isEmpty{
            return Array(favouriteRequest)
        }
        else{
            return []
        }
    }
    var body: some View {
        NavigationView
        {
            ZStack{
                if !favouriteList.isEmpty{
                    ScrollView{
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellWidth),spacing: 10), count: columnCount), spacing: 10) {
                            ForEach(favouriteList, id: \.self)
                            {
                                item in
                                let currItem : MangaData = item
                                let currModuleId : UUID = currItem.sourceId
                                let currModule : ModuleDataContainer? = ModuleManager.shared.getModule(currModuleId)
                                NavigationLink(destination: favouriteViewWrapper(favouriteContent: currItem,currModule: currModule) ) {contentCell(title: (item.title ?? ""), urlString: (item.imageURL ?? ""), width: cellWidth)}
                                    .contextMenu{
                                        Button("Remove from Favourites"){
                                            removeFavourite(item: currItem)

                                        }
                                    }
                            }
                        }
                    }
                }
                else{
                    Text("Empty Favourites :(  Add some to your favourites")
                }
            }
            .navigationTitle("Favourites")
            .navigationBarTitleDisplayMode(.inline)
        }
        



        
    }
    func removeFavourite(item: MangaData){
        FavouriteManager.shared.removeFavourite(moduleId: item.sourceId,contentId: item.mangaId)
    }
}
