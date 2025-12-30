//
//  contentView.swift
//  Kanzen
//
//  Created by Dawud Osman on 27/05/2025.
//

import SwiftUI
import Foundation
import Kingfisher

#if !os(tvOS)
struct contentView: View {
    @State var parentModule: ModuleDataContainer?
    @State  var title: String
    @State  var imageURL: String
    @State  var params: String
    @State var expandedDescription : Bool = false
    @State private var contentData: [String:Any]?
    @State private var contentChapters: [Chapters]?
    @EnvironmentObject var kanzen: KanzenEngine
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var favouriteManager : FavouriteManager
    @State private var width: CGFloat = 150
    @State private var langaugeIdx: Int = 0
    @State private var showChaptersMenu: Bool = false
    @State private var selectedChapterData: Chapter? = nil
    @State private var selectedChapterIdx: Int?
    @State var reverseChapterlist: Bool = false
    @State var toggleFavourite: Bool = false
    @State var loadingState : Bool = true
    
    
    var body: some View {
        renderedContent().onAppear{
            getContentData()
        }
    }
    
    func renderedContent() -> some View {
        ScrollView{
            VStack(alignment: .leading){
                HStack(){
                    KFImage(URL(string: imageURL)!)
                        .resizable()
                        .placeholder{
                            ProgressView()
                        }
                        .scaledToFill()
                        .frame(width: width, height: width * 1.5)
                        .clipped()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: width)
                        .frame(height: width * 1.5)
                        .cornerRadius(5)
                    
                    VStack(alignment: .leading){
                        Text(title)
                            .font(.title)
                        
                        if let contentData = contentData {
                            if let authorArtist = contentData["authorArtist"] as? [String]
                            {
                                HStack{
                                    ForEach(Array(authorArtist.enumerated()),id: \.offset)
                                    {
                                        idx,item in
                                        Text(item).font(.caption)
                                            .padding(.leading,3)
                                            .padding(.trailing,3)
                                            .background(Color.accentColor)
                                        
                                            .cornerRadius(3)
                                    }
                                }
                                
                                
                                
                            }
                            if let tags = contentData["tags"] as? [String]
                            {
                                HStack{
                                    ForEach(Array(tags.enumerated()),id: \.offset)
                                    {
                                        idx,item in
                                        Text(item).font(.caption)
                                            .padding(.leading,3)
                                            .padding(.trailing,3)
                                            .background(Color.accentColor)
                                        
                                            .cornerRadius(3)
                                    }
                                }
                                
                                
                                
                            }
                        }
                        Divider()
                        HStack{
                            if !toggleFavourite {
                                Image(systemName: "bookmark")
                                    .foregroundColor(settings.accentColor)
                                    .onTapGesture {
                                        favouriteManager.addFavourite(module: parentModule ?? nil, content: Manga(title: title, imageURL: imageURL, mangaId: params))
                                        toggleFavourite.toggle()
                                    }
                            }
                            else{
                                Image(systemName: "bookmark.fill")
                                    .foregroundColor(settings.accentColor)
                                    .onTapGesture {
                                        if let module = parentModule{
                                            favouriteManager.removeFavourite(moduleId:  module.id, contentId: params)
                                        }
                                        toggleFavourite.toggle()
                                    }
                            }
                        }.frame(alignment: .leading)
                    }
                    
                    .frame(maxHeight: .infinity, alignment: .top)
                    
                }
                .frame(maxWidth: .infinity,alignment: .leading)
                
                Divider()
                if let contentData = contentData {
                    
                    if let description = contentData["description"] as? String{
                        
                        Text(description)
                            .font(.footnote)
                            .lineLimit(expandedDescription ? nil : 3)
                            .onTapGesture {
                                withAnimation{
                                    expandedDescription.toggle()
                                }
                                
                            }
                        
                        
                    }
                }
                Divider()
                if loadingState {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                else{
                    chaptersView()
                        .padding(.trailing,5)
                        .padding(.leading,5)
                }
                
                
            }
            .padding(.trailing,5)
            .padding(.leading,5)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .fullScreenCover(item: $selectedChapterData){ chapter in
            if let contentChapters = self.contentChapters{
                readerManagerView(chapters: contentChapters[langaugeIdx].chapters,selectedChapter: chapter,kanzen: kanzen)
            }
            
        }
        .onAppear{
            toggleFavourite = checkIfFavorited()
        }
        .navigationTitle(title)
    }
    
    func checkIfFavorited() -> Bool {
        if let module = parentModule
        {
            return FavouriteManager.shared.isFavourite(moduleId: module.id, contentId: params)
        }
        else{
            return false
        }
    }
    
    func getContentData() {
        DispatchQueue.main.async{
            kanzen.getContentData(params: self.params)
            {
                result in
                
                self.contentData = result
            }
            kanzen.getChapters(params: self.params){
                result in
                if let result = result{
                    var temp: [Chapters] = []
                    for (key, value) in result
                    {
                        var tempChapters: [Chapter] = []
                        if let chapters = value as? [Any?]
                        {
                            for (idx,chapter) in chapters.enumerated() {
                                print("chapter is ")
                                print(idx)
                                print(chapter ?? "")
                                if let chapter = chapter as? [Any?], let chapterName = chapter[0] as? String, let rawData = chapter[1] as? [[String: Any?]], let chapterData = rawData.compactMap({ChapterData(dict: $0 as [String : Any])}) as? [ChapterData] {
                                    let tempChapter: Chapter = Chapter(chapterNumber: chapterName, idx:idx,chapterData: chapterData)
                                    tempChapters.append(tempChapter)
                                    
                                }
                            }
                        }
                        if tempChapters.count > 0 {
                            temp.append(Chapters(language: key, chapters: tempChapters))
                        }
                    }
                    self.contentChapters = temp
                    print("contentChapters is")
                    print(contentChapters ?? [] )
                }
                
                loadingState = false
            }
            
        }
    }
    @ViewBuilder
    func chaptersMenu() -> some View {
        if let contentChapters = self.contentChapters,  contentChapters.count > 0 {
            
        }
    }
    
    @ViewBuilder
    func chaptersView() -> some View {
        if let chaptersData = self.contentChapters, chaptersData.count > 0 {
            let selectedLanguage = chaptersData[langaugeIdx]
            var displayedChapters: Array<EnumeratedSequence<[Chapter]>.Element> {
                if reverseChapterlist
                {
                    Array(selectedLanguage.chapters.enumerated().reversed())
                }
                else
                {Array(selectedLanguage.chapters.enumerated())}
                
                
            }
            
            VStack {
                HStack {
                    Text("\(selectedLanguage.chapters.count) Chapters")
                        .font(.headline)
                        .bold()
                        .foregroundColor(Color.accentColor)
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease")
                    
                        .renderingMode(.template)
                        .foregroundColor(.accentColor)
                        .padding(.leading,20)
                        .font(.title2)
                    
                    
                        .contentShape(Rectangle())
                        .contextMenu{
                            if let contentChapters = contentChapters, contentChapters.count > 0 {
                                Menu{
                                    ForEach(Array(contentChapters.enumerated()),id: \.offset)
                                    {
                                        index, item in
                                        Button(item.language){langaugeIdx = index}
                                    }
                                    
                                } label: {Text("Language")}
                            }
                            
                        }
                        .onTapGesture {
                            print("chapterList reversed")
                            reverseChapterlist.toggle()
                        }
                        .onLongPressGesture {
                            withAnimation(){
                                if((contentChapters ?? []).count  > 0)
                                {
                                    showChaptersMenu.toggle()
                                }
                                
                            }
                        }
                    
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                VStack{
                    ForEach(displayedChapters, id:\.offset )
                    {
                        index,item in
                        
                        if let chapterData = item.chapterData
                        {
                            Button{
                                
                                selectedChapterIdx = index
                                DispatchQueue.main.async {
                                    selectedChapterData = item
                                }
                                
                            }label:{
                                HStack{
                                    
                                    
                                    if chapterData.count > 0 {
                                        
                                        Text("\(item.chapterNumber )").font(.subheadline)
                                            .foregroundColor(Color.accentColor)  + Text(" \u{00B7} \(chapterData[0].scanlationGroup)")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        
                                        
                                    }
                                    else{
                                        Text("\(item.chapterNumber)").font(.subheadline)
                                            .foregroundColor(Color.accentColor)
                                    }
                                    
                                    
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                        }
                        
                        
                        
                        Divider()
                    }
                }
            }
        } else {
            Text("No chapters found")
        }
    }
}
#endif
