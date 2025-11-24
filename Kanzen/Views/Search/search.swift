//
//  SearchView.swift
//  Kanzen
//
//  Created by Dawud Osman on 22/05/2025.
//
import SwiftUI
import Foundation
import Kingfisher
struct KanzenSearchView: View {

    @State var module: ModuleDataContainer?
    @State var searchText: String = ""
    @State var cellWidth: CGFloat = 150
     @State var searchPage: Int = 0
    @State var endOfPage: Bool = false
    private var columnCount: Int {
        let screenWidth = UIScreen.main.bounds.width
        return Int(screenWidth/(cellWidth+10))
    }
    @EnvironmentObject var kanzen: KanzenEngine
    @EnvironmentObject var moduleManager: ModuleManager
    @State var searchArray : [Manga] = []
    
    private func performSearch(append:Bool = false){
        if endOfPage{
            print("end of page")
            return
        }
        kanzen.searchInput(searchText,page: searchPage){
            
            result in
            if let result = result{
                if result.isEmpty{
                    endOfPage = true
                    return
                }
                let item = result.compactMap{ dict -> Manga? in
                    guard
                        
                        let title = dict["title"] as? String,
                        let imageURL = dict["imageURL"] as? String,
                        let mangaId = dict["id"] as? String
                    else {  print(dict) ; print("error formating search Output") ;return nil }
                    return Manga(title: title, imageURL: imageURL, mangaId: mangaId,parentModule: module)
                    
                }
                

 

                DispatchQueue.main.async {
                    if append {
                        searchArray.append(contentsOf: item)
                    } else {
                        searchArray = item
                    }
                    searchPage += 1
                }

            }
                
            

        }
    }
    private func generateCells() -> some View {

        return             ScrollView{
            if searchArray.count > 0
            {
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellWidth),spacing: 5), count: columnCount), spacing: 5) {
                    ForEach(searchArray) { item in
                       
                        NavigationLink(destination: {contentView(parentModule: module,title: item.title,imageURL: item.imageURL,params: item.mangaId)}){contentCell(title:item.title,urlString: item.imageURL,width: cellWidth)}
                        
                    }
                    Color.clear.frame(height:1)
                        .onAppear{
                            if(!endOfPage)
                            {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    performSearch(append: true)
                                    print("End of List")
                                }
                            }
                            
                          
                        }
                }

            }
        }

    }
    var body: some View {
        VStack {
            SearchBar(text: $searchText,onSearchButtonClicked: {
                searchPage = 0
                endOfPage = false
                performSearch()
            }
            ).padding(.leading,20)
                .padding(.trailing,20)
            generateCells()
            
        }.frame(maxHeight: .infinity, alignment: .top)
            .onAppear{
                do {
                    if let module = module {
                        let content = try moduleManager.getModuleScript(module: module)
                        try kanzen.loadScript(content)
                    }
                    }
                catch{
                    Logger.shared.log(error.localizedDescription,type: "Error")
                }
            }
    }
}
struct SearchBar: View {
    @State private var debounceTimer: Timer?
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search...", text: $text, onCommit: onSearchButtonClicked)
                
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .contentShape(Rectangle())
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
    }
}
