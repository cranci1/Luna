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



/// Reader image decode sizing. Manhwa/webtoon chapters are often ONE very
/// tall strip image; past the GPU texture limit (8192px on A9-era devices,
/// 16384px on A12+) iOS can only render the layer heavily downscaled —
/// "full screen but low quality". Downsampling at decode time caps the
/// longest edge at a GPU-safe pixel count while preserving aspect ratio, so
/// every device renders crisply. Ordinary pages (well under the cap) pass
/// through unchanged: DownsamplingImageProcessor never upscales.
///
/// Every reader image path MUST use the same processor: Kingfisher caches
/// processed images under `url + "@" + processor.identifier`, so mixed
/// options would split the cache between paged, webtoon and prefetcher.
enum ReaderImageSizing {
    static let maxPixels: CGFloat = 8192
    static var scale: CGFloat { max(UIScreen.main.scale, 1) }
    static var processor: DownsamplingImageProcessor {
        DownsamplingImageProcessor(size: CGSize(width: maxPixels / scale,
                                                height: maxPixels / scale))
    }
    static var options: KingfisherOptionsInfo {
        [.processor(processor), .scaleFactor(scale), .cacheOriginalImage, .backgroundDecode]
    }
    /// The key under which the processed image is cached for `url`
    /// (mirrors Kingfisher's internal `String.computedKey(with:)`).
    static func cacheKey(for url: URL) -> String {
        url.absoluteString + "@" + processor.identifier
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
                        .setProcessor(ReaderImageSizing.processor)
                        .scaleFactor(ReaderImageSizing.scale)
                        .cacheOriginalImage()
                        .backgroundDecode()
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

struct TransitionPage: View {
    var index: String
    var body: some View {
        Text("Chapter \(index) End")
            .frame(maxWidth: .infinity)
            .clipped()
    }
}
