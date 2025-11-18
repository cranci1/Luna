//
//  readerManager.swift
//  Luna
//
//  Created by Dawud Osman on 17/11/2025.
//

import SwiftUI
import Kingfisher



class readerManager: ObservableObject {
    @Published  var chapters: [Chapter]?
    @Published var selectedChapter: Chapter?
    @Published var index: Int
    @Published var currChapter: [PageData]
    @Published var prevChapter: [PageData]
    @Published var nextChapter: [PageData]
    @AppStorage("readingMode") var readingModeRaw: Int = 0
    var pagePrefetcher: ImagePrefetcher?
    var readingMode: ReadingMode {
        ReadingMode(rawValue: readingModeRaw) ?? .LTR
    }
    var changeIndex: Bool = false

     var kanzen : KanzenEngine
    // Cached controllers - only recreated when data changes
 var currControllers: [UIViewController]?
  var prevControllers: [UIViewController]?
var nextControllers: [UIViewController]?
    
    // task
    private var currTask: Task<Void, Never>?
    
    // Task storage for loadPages operations
    private var loadPagesTasks: [ChapterPosition: Task<Void, Never>] = [:]
    

    
    var currRange: ClosedRange<CGFloat> {
        //print("currChapter type: \(type(of: currChapter))")
        //print("currChapter value: \(currChapter)")
        
        guard currChapter is [PageData] else {
            print("ERROR: currChapter is not [PageData]!")
            return 0...0
        }
        if currChapter.count > 0 {
           return 0...CGFloat(currChapter.count - 1)
        } else {
           return  0...CGFloat(0)
        }
    }
    
    init(index: Int = 0, currChapter: [PageData] = [], prevChapter: [PageData] = [], nextChapter: [PageData] = [], shiftChapterLeft: @escaping () -> Void = {}, shiftChapterRight: @escaping () -> Void = {}, fetchPrev: @escaping () -> Void = {}, fetchNext: @escaping () -> Void = {}, kanzen: KanzenEngine,chapters: [Chapter]?, selectedChapter: Chapter?) {
        self.index = index
        self.currChapter = currChapter
        self.prevChapter = prevChapter
        self.nextChapter = nextChapter
        self.kanzen = kanzen
        self.chapters = chapters
        self.selectedChapter = selectedChapter
    }
    func initChapters(){
        // resetState
        resetState()

    }
    func resetState()
    {
        cancelAllLoadPagesTasks()
        prevChapter = []
        currChapter = []
        nextChapter = []
        currControllers = nil
        prevControllers = nil
        nextControllers = nil
        if let selectedChapter = selectedChapter, let chapters = chapters
        {
            if let currSources = selectedChapter.chapterData, currSources.count > 0
            {
                let currParams = currSources[0].params
                loadPages(params: currParams, position: .curr)
            }
            let idx = selectedChapter.idx
            // fetch Prev Images
            
            if idx > 0
            {
                let prevChapter = chapters[idx - 1]
                if let prevSources = prevChapter.chapterData, prevSources.count > 0
                {
                    let prevParams = prevSources[0].params
                    loadPages(params: prevParams, position: .prev)
                    
                }
                
            }
            if idx < chapters.count - 1
            {
                let nextChapters = chapters[idx + 1]
                if let nextSources = nextChapters.chapterData, nextSources.count > 0
                {
                    let nextParams = nextSources[0].params
                    loadPages(params: nextParams, position: .next)
                }
            }

                    
        }
    }
    // Cancel all loadPages tasks
    private func cancelAllLoadPagesTasks() {
        for (_, task) in loadPagesTasks {
            task.cancel()
        }
        loadPagesTasks.removeAll()
    }
    
    // Cancel specific loadPages task
    private func cancelLoadPagesTask(for position: ChapterPosition) {
        
        loadPagesTasks[position]?.cancel()
        loadPagesTasks.removeValue(forKey: position)
    }
    
    // Setter Functions
    func setIndex(_ index: Int) {
        self.index = index
    }

    func setCurrChapter(_ currChapter: [PageData]) {
        self.currChapter = currChapter
        generateCurrControllers()
    }
    
    func setPrevChapter(_ prevChapter: [PageData]) {
        self.prevChapter = prevChapter
        generatePrevControllers()
    }
    
    func setNextChapter(_ nextChapter: [PageData]) {
        self.nextChapter = nextChapter
        generateNextControllers()
    }
    func generateCurrControllers()
    {
        currControllers = currChapter.map { UIHostingController(rootView: $0.body) }
        if let selectedChapter = selectedChapter{
            let transistionView: any View = chapterView(page: PageData(content: "CHAPTER_END"), index: selectedChapter.chapterNumber)
            currControllers = currChapter.map { UIHostingController(rootView: $0.body) } + [UIHostingController(rootView: AnyView( transistionView))]
        }
       
    }
    func generatePrevControllers()
    {

        prevControllers = prevChapter.map { UIHostingController(rootView: $0.body) }
        if let selectedChapter = selectedChapter, let chapters = chapters, selectedChapter.idx > 0 {
            let transistionView: any View = chapterView(page: PageData(content: "CHAPTER_END"), index: chapters[selectedChapter.idx-1].chapterNumber)
            prevControllers = prevChapter.map { UIHostingController(rootView: $0.body) } + [UIHostingController(rootView: AnyView( transistionView))]
            
        }
    }
    func generateNextControllers()
    {
        nextControllers = nextChapter.map { UIHostingController(rootView: $0.body) }
        if let selectedChapter = selectedChapter, let chapters = chapters, selectedChapter.idx < chapters.count - 1 {
            let transistionView: any View = chapterView(page: PageData(content: "CHAPTER_END"), index: chapters[selectedChapter.idx + 1].chapterNumber)
            nextControllers =  nextChapter.map { UIHostingController(rootView: $0.body) } + [UIHostingController(rootView: AnyView( transistionView))]
            
        }
    }
    func shiftLeft() {
        // Cancel next chapter loading since it's no longer needed
        cancelLoadPagesTask(for: .next)
        if let currChapter = selectedChapter, let idx = currChapter.idx as? Int, let chapters = chapters, currChapter.idx == 0
        {
            print("End of chapters reached - no more chapters to load")
            return
        }
        
        //shift Controllers
        nextControllers = currControllers
        currControllers = prevControllers
        prevControllers = nil
        
        // Shift chapters (this will trigger didSet and invalidate controllers)
        nextChapter = currChapter
        currChapter = prevChapter
        prevChapter = []
        
        // Now shift the controllers to maintain references
        // What was "current" becomes "next"
        // What was "previous" becomes "current"
        // "Previous" becomes empty
        shiftChapterLeft()
        index = currChapter.count - 1
        print("Shifted left - controllers moved")
    }
    
    func shiftRight() {
        // Cancel prev chapter loading since it's no longer needed
        cancelLoadPagesTask(for: .prev)
        if let currChapter = selectedChapter, let idx = currChapter.idx as? Int, let chapters = chapters, currChapter.idx == chapters.count - 1
        {
            print("End of chapters reached - no more chapters to load")
            return
        }
        
        prevControllers = currControllers
        currControllers = nextControllers
        nextControllers = nil
        // Shift chapters (this will trigger didSet and invalidate controllers)
        prevChapter = currChapter
        currChapter = nextChapter
        nextChapter = []
        
        
        // What was "current" becomes "previous"
        // What was "next" becomes "current"
        // "Next" becomes empty

        index = 0
        shiftChapterRight()

        print("Shifted right - controllers moved")
    }
    
    func getIndex() -> Int {
        return index
    }
    
    // Optional: Force refresh all controllers (useful for debugging)
    func refreshAllControllers() {
        print("Force refreshing all controllers")

    }
    func findControllers(currView: UIViewController) -> Bool {
        if let currControllers = currControllers, currControllers.contains(currView) {
            return true
        }
        if let prevControllers = prevControllers, prevControllers.contains(currView) {
            return true
        }
        if let nextControllers = nextControllers, nextControllers.contains(currView) {
            return true
        }
        return false
    }
    func fetchTask(bool: Bool, completion: @escaping (() -> Void ) = {})
    {
        currTask?.cancel()
        if bool {
            // Also cancel the actual loading task for next
            cancelLoadPagesTask(for: .next)
            currTask = Task
            {
                 fetchNext(completion: completion)
            }

            
        }
        else
        {            // Also cancel the actual loading task for prev
            cancelLoadPagesTask(for: .prev)
            currTask = Task
            {
                fetchPrev(completion: completion)
            }


        }
    }
  
    
    func loadPages(params: Any,position: ChapterPosition, completion: @escaping () -> Void = {}){
        print("params are")
        print(params)
        // Cancel any existing task for this position
        cancelLoadPagesTask(for: position)
        
        // Create new task and store it
        loadPagesTasks[position] = Task { @MainActor in
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()
                
                print("Loading chapter \(position)...")
                
                // Convert callback to async/await
                let result = await withCheckedContinuation { continuation in
                    self.kanzen.getChapterImages(params: params) { result in
                        continuation.resume(returning: result)
                    }
                }
                
                // Check for cancellation after network call
                try Task.checkCancellation()
                
       
                
                if let result = result {
                    var pages = result.map{PageData(content: $0)}
                    pages = pages
                    print("pages is ")
                    print("\(pages)")
                    // Check for cancellation before updating UI
                    try Task.checkCancellation()
                    
                    // Update UI on main thread (already on MainActor)
                    switch position
                    {
                    case .prev:
                       print("prev is called")
                        self.setPrevChapter(pages)
                        
                    case .next:
                        print("next is called")
                        self.setNextChapter(pages)
                        
                        
                    case .curr:
                        print("curr is called")
                        self.setCurrChapter(pages)


                    }
                    print("successfully set \(position) chapter")
                    completion()
                }
                
                // Remove completed task from storage
                self.loadPagesTasks.removeValue(forKey: position)
                
            } catch {
                if error is CancellationError {
                    print("Loading chapter \(position) was cancelled")
                } else {
                    print("Error loading chapter \(position): \(error)")
                }
                // Remove failed/cancelled task from storage
                self.loadPagesTasks.removeValue(forKey: position)
            }
        }
    }
    // shiftCurrChapter
    func shiftChapterLeft()
    {
        if let currChapter = selectedChapter, let chapters = chapters
        {
            let idx = currChapter.idx
            if idx > 0
            {
                selectedChapter = chapters[idx - 1]
                print("shift chapter Left successfull")
            }
        }
    }
    func shiftChapterRight()
    {
        if let currChapter = selectedChapter, let chapters = chapters
        {
            let idx = currChapter.idx
            if idx < chapters.count - 1
            {
                selectedChapter = chapters[idx + 1]
                print("shift Chapter Right successfull")
            }
        }
    }
    func fetchPrev(completion: @escaping () -> Void = {})
    {
        print("fetchPrev called")
        if let selectedChapter = selectedChapter, let chapters = chapters {
            let idx = selectedChapter.idx
            if idx > 0 {
                let prevChapter = chapters[idx - 1]
                if let prevSources = prevChapter.chapterData, prevSources.count > 0
                {
                    let prevParams = prevSources[0].params
                    loadPages(params: prevParams, position: .prev,completion: completion)
                    
                }
                
            }
        }
    }
    func fetchNext(completion: @escaping () -> Void = {})
    {        if let selectedChapter = selectedChapter, let chapters = chapters {
        let idx = selectedChapter.idx
        if idx < chapters.count - 1 {
            let nextChapters = chapters[idx + 1]
            if let nextSources = nextChapters.chapterData, nextSources.count > 0
            {
                let nextParams = nextSources[0].params
                loadPages(params: nextParams, position: .next,completion: completion)
            }
            
        }
    }
        
    }
    
    func preloadAdjacentPages()
    {
        pagePrefetcher?.stop()
        var pagesURLs: [URL] = []
        
        if index < currChapter.count - 1 {
            let pageUrl = URL(string: currChapter[index+1].content)
            if let pageUrl = pageUrl {
                pagesURLs.append(pageUrl)
            }
        }
        if index < currChapter.count - 2 {
            let pageUrl = URL(string: currChapter[index+2].content)
            if let pageUrl = pageUrl {
                pagesURLs.append(pageUrl)
            }
        }
        else if nextChapter.count > 0 {
            let pageUrl = URL(string: nextChapter.first!.content)
            if let pageUrl = pageUrl {
                pagesURLs.append(pageUrl)
            }
        }
        
        if index > 0 {
            let pageUrl = URL(string: currChapter[index - 1 ].content)
            if let pageUrl = pageUrl {
                pagesURLs.append(pageUrl)
            }
        }
        else if prevChapter.count > 0 {
            let pageUrl = URL(string: prevChapter.last!.content)
            if let pageUrl = pageUrl {
                pagesURLs.append(pageUrl)
            }
        }
        
        pagePrefetcher = ImagePrefetcher(urls: pagesURLs)
        pagePrefetcher?.start()
        
    }
}
