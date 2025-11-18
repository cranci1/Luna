
//
//  readerManagerView.swift
//  Kanzen
//
//  Created by Dawud Osman on 13/06/2025.
//
import SwiftUI
import Kingfisher


struct readerManagerView:View {
    @State  var chapters: [Chapter]?
    @State var selectedChapter: Chapter?
    @ObservedObject var kanzen : KanzenEngine
    @EnvironmentObject var settings : Settings
    @Environment(\.dismiss) var dismiss
    @State private var showFullScreen = true
    @State private var showChapterlist: Bool = false
    @State private var showReadingModePicker = false
    @Environment(\.colorScheme) var colorScheme
    @State var someValue: CGFloat = 0
    @State var RTL: Bool = true

    @State private var sliderRange: ClosedRange<CGFloat> = 0...0
    @State private var debounceWorkItem: DispatchWorkItem?
    // new Implementation
    
    @StateObject   var reader_manager: readerManager
    init (chapters: [Chapter]?,selectedChapter: Chapter?,kanzen: KanzenEngine)
    {
        print("CHAPTER IS")
        print(selectedChapter)
        self.kanzen = kanzen
        _reader_manager =  StateObject(wrappedValue: readerManager(kanzen:kanzen,chapters: chapters,selectedChapter: selectedChapter))
        _chapters = State(initialValue: chapters)
        _selectedChapter = State(initialValue: selectedChapter)
    }

    var body: some View {
        ZStack {
            // Custom Back Button
            
            //pageReader(reader_manager: reader_manager)
            
            //ScrollView{LazyVStack{ForEach(reader_manager.currChapter) { chapter in chapter.body}}}
            if(reader_manager.currChapter.count > 0)
            {
                readerContent()
            }
            else{
                CircularLoader(progress: 0)
            }
            readerOverlay()
        }
        
        .sheet(isPresented: $showChapterlist)
        {
            ChapterList(readerManager:  reader_manager)
        }
        .sheet(isPresented: $showReadingModePicker){
            readerManagerSettings(readerManager: reader_manager)
                //.presentationDetents([.fraction(0.3)]) // 👈 make it short (30% screen height)
                //.presentationCornerRadius(24) // 👈 curved top corners
                //.presentationBackground(.regularMaterial) // 👈 blurred material background

        }
        .onChange(of: reader_manager.index) { newIndex in
            let clamped = min(CGFloat(newIndex), reader_manager.currRange.upperBound)
            if someValue != clamped { // avoid redundant triggers
                someValue = clamped
            }
        }
        .onChange(of: someValue) { newValue in
            print("someValue changed")
            guard Int(newValue) != reader_manager.index else { return }
            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                reader_manager.setIndex(Int(newValue))
                reader_manager.changeIndex.toggle()
                
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }

    
        .navigationBarBackButtonHidden(true)
            .task {
                reader_manager.initChapters()
            }
    }

    @ViewBuilder
    func readerContent() -> some View {
        switch(reader_manager.readingMode){
        case .LTR: pageReader(reader_manager: reader_manager, pageViewConfig: .LTR) .id("LTR")                .onTapGesture {
            showFullScreen.toggle()
        }
        case .WEBTOON: WebtoonView(reader_manager:    reader_manager).id("WEBTOON")   .onTapGesture {
            showFullScreen.toggle()
        }
        case .RTL: pageReader(reader_manager: reader_manager,pageViewConfig: .RTL)    .id("RTL")              .onTapGesture {
            showFullScreen.toggle()
        }
        case .VERTICAL: pageReader(reader_manager: reader_manager,pageViewConfig: .Vertical) .id("VERTICAL")              .onTapGesture {
            showFullScreen.toggle()
        }
            
        }

    }
    
    @ViewBuilder
    func readerOverlay() -> some View {
        if showFullScreen
        {
            
            VStack{
                HStack{
                    
                    HStack{
                        Image(systemName: "multiply.circle.fill").onTapGesture {
                            dismiss()
                        }
                        .font(.title)
                        .foregroundColor(settings.accentColor )

                    }
                    
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading,10)
                    Spacer()
                    VStack{
                        Text("Chapter")
                        Text("\(reader_manager.selectedChapter?.chapterNumber ?? "No Title")")
                        
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                    HStack{
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title)
                            .foregroundColor(settings.accentColor )
                            .onTapGesture {
                               showReadingModePicker = true
                                
                            }
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.title)
                            .foregroundColor(settings.accentColor )
                            .onTapGesture {
                                showChapterlist = true
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing,10)
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(  colorScheme == .dark ?  Color.black.opacity(0.5) : Color.black.opacity(0.1))
                Spacer()
                VStack
                {
                    HStack{
                        
                        customSlider(value: $someValue,RTL: $RTL,range: reader_manager.currRange)
                        
                            .padding(.leading, 10)
                            .padding(.trailing,10)
                        
                        
                        
                        
                    }
                    .frame(height: 50)
                    Text("\(min(Int(someValue),Int(reader_manager.currRange.upperBound)))/\(Int(reader_manager.currRange.upperBound))")
                    
                    
                }
                .background(  colorScheme == .dark ?  Color.black.opacity(0.5) : Color.black.opacity(0.1))
                
                
            }
            
            
            
        }
    }


    

}
