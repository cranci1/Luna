//
//  pageData.swift
//  Luna
//
//  Created by Dawud Osman on 17/11/2025.
//
//
//  pageData.swift
//  Kanzen
//
//  Created by Dawud Osman on 15/07/2025.
//
import SwiftUI
import Foundation
import Kingfisher
enum ChapterPosition
{
    case prev
    case curr
    case next
}

struct PageData: Identifiable, Equatable {
    let id: UUID = UUID()
    let content: String
    init (content:String)
    {
        
        self.content = content
    }
    
    var body:  chapterView {
        chapterView(page: self, index: "0")
    }
    static func == (lhs: PageData, rhs: PageData) -> Bool {
        lhs.id == rhs.id
    }
        
    
}
struct Chapters: Identifiable
{
    let id: UUID = UUID()
    let language: String
    var chapters: [Chapter]
}
struct Chapter: Identifiable
{
    let id: UUID = UUID()
    let chapterNumber: String
    let idx: Int
    let chapterData: [ ChapterData]?
}
struct ChapterData: Identifiable
{
    let id: UUID = UUID()
    var scanlationGroup: String = ""
    var title: String = ""
    let params: Any?
    init?(dict: [String:Any])
    {
        print("dicts are")
        print(dict)
        guard let scanlationGroup = dict["scanlation_group"] as? String, let params = dict["id"] else { return nil }
        
        self.scanlationGroup = scanlationGroup
        self.params = params

    }
}



struct chapterView: View {
    let page: PageData
    let index: String

    
    
    var body: some View {
        
            if page.content == "CHAPTER_END"
            {
                Text("Chapter \(index) End")
                    .frame(maxWidth: .infinity)
                    .clipped()


                    
            }
            else{
                if let url = URL(string: page.content)
                {
                    
                    KFImage(url)
                        .placeholder{
                            CircularLoader(progress: 0)
                        }
                        .resizable()
                        .scaledToFit()
                        .frame(width: UIScreen.main.bounds.width)
                        .background(Color.black)
                        
                        
                }
            }

        
   
    }
}
