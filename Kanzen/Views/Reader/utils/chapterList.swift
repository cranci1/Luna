//
//  chapterList.swift
//  Kanzen
//
//  Created by Dawud Osman on 09/10/2025.
//
import SwiftUI
struct ChapterList: View {
    @ObservedObject var readerManager: readerManager
    @EnvironmentObject var settings : Settings
    @State var reverseChapterlist: Bool = false

    var body: some View {
        ScrollView {
            VStack{
               if let chapters = readerManager.chapters {
                   var displayedChapters: Array<EnumeratedSequence<[Chapter]>.Element> {
                       if reverseChapterlist
                       {
                           Array(chapters.enumerated().reversed())
                       }
                       else
                       {Array(chapters.enumerated())}
                      
                   
                   }
                   HStack{
                       Text("\(chapters.count) Chapters")
                           .font(.headline)
                           .bold()
                           .foregroundColor(settings.accentColor)
                       Spacer()
                       Image(systemName: "line.3.horizontal.decrease")
                       
                           .renderingMode(.template)
                           .foregroundColor(settings.accentColor)
                           .padding(.leading,20)
                           .font(.title2)
                          
                           
                           .contentShape(Rectangle())
                           .onTapGesture {
                               reverseChapterlist.toggle()
                           }
                       
                   }
                   Divider()
                   ForEach(displayedChapters, id:\.offset) { index, item in
                       if let chapterData = item.chapterData {
                           Button
                           {
                               DispatchQueue.main.async {
                                   readerManager.selectedChapter = item
                                   readerManager.resetState()
                               }
                           }label: {
                               HStack{
                                   
                                   
                                       if chapterData.count > 0 {

                                           Text("\(item.chapterNumber )").font(.subheadline)
                                               .foregroundColor(settings.accentColor)  + Text(" \u{00B7} \(chapterData[0].scanlationGroup)")
                                               .foregroundColor(settings.accentColor)
                                               .font(.footnote)
                                               //.foregroundStyle(.secondary)
                                               
                                           
                                       }
                                   else{
                                       Text("\(item.chapterNumber)").font(.subheadline)
                                           .foregroundColor(settings.accentColor)
                                   }
                              

                               }.frame(maxWidth: .infinity, alignment: .leading)
                           }
                       }
                       Divider()
                   }
                }
            }
        }.padding(10)
    }
}

