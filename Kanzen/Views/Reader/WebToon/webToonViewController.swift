//
//  WebtoonView.swift
//  Kanzen
//
//  Created by Dawud Osman on 01/09/2025.
//
import SwiftUI
import Kingfisher

struct WebtoonView: UIViewRepresentable {
    @ObservedObject var reader_manager: readerManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(reader_manager: reader_manager)
    }
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(ChapterCollectionViewCell.self, forCellWithReuseIdentifier: ChapterCollectionViewCell.reuseIdentifier)

        return collectionView
    }
    
    func updateUIView(_ uiView: UICollectionView, context: Context) {
        //print("updateUIVIEW called")
        if context.coordinator.currChapter != reader_manager.currChapter {
            print("diff CurrChapter")
            context.coordinator.reader_manager = reader_manager
            context.coordinator.currChapter = reader_manager.currChapter
            context.coordinator.chapters = [reader_manager.currChapter]
            context.coordinator.imageSizes = [[:]] // Clear cached sizes
            uiView.reloadData()
            uiView.collectionViewLayout.invalidateLayout()
            uiView.layoutIfNeeded()
            context.coordinator.reader_manager = reader_manager
            context.coordinator.currChapter = reader_manager.currChapter
            context.coordinator.chapters = [reader_manager.currChapter]
        }
        
        if reader_manager.changeIndex, let sectionIdx = context.coordinator.chapters.firstIndex(of: reader_manager.currChapter){
            print("Change index called && currChapter in chapters")
            let pathItem = IndexPath(item: reader_manager.index, section: sectionIdx )
            uiView.scrollToItem(at: pathItem, at: UICollectionView.ScrollPosition.centeredVertically, animated: false)
            if reader_manager.changeIndex == true {
                reader_manager.changeIndex = false
            }
        }


        
    }
    
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        
        // Cache image sizes to avoid recalculating
        var imageSizes: [[Int: CGSize]] = []
        var loadingPrevious = false
        var loadingNext = false
        
        init(reader_manager: readerManager) {
            self.reader_manager = reader_manager
            self.chapters.append(reader_manager.currChapter)
            self.currChapter = reader_manager.currChapter
            imageSizes.append([:])
        }
        
        func getCurrentpagePath(collectionView: UICollectionView, position: ScreenPosition = .mid) -> IndexPath? {
            let value : CGFloat = switch position
            {
            case .mid: collectionView.bounds.height / 2
            case .bottom: collectionView.bounds.height
            case .top: 0
            }
            
            let currentPoint = CGPoint(x: collectionView.contentOffset.x,y: collectionView.contentOffset.y + value )
            return collectionView.indexPathForItem(at: currentPoint)
        }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if let collectionView = scrollView as? UICollectionView {
                //print("=== DEBUG INFO ===")
                //print("Chapters Count: \(chapters.count)")
                
            
                guard
                    let chapterIdx = chapters.firstIndex(of: currChapter)
                else {
                    print("Curr Chapter not found")
                    print("Curr Chapter cnt: \(currChapter.count)")
                    return
                }
                let midPath = getCurrentpagePath(collectionView: collectionView,position: .mid)
                let midIdx = midPath?.section ?? 0
                //print("midPath Idx: \(String(describing: midIdx))")
                //print("currChapter Idx: \(String(describing: chapterIdx)) ")
                reader_manager.setIndex(midPath?.item ?? 0)
                if midIdx == chapterIdx {
                    return
                }
                if chapterIdx > 0 && midIdx < chapterIdx {
                    print("shift Left")
                    
                    self.reader_manager.shiftLeft()
                    loadingPrevious = false
                    
                    // sync currChapter and reader_manager.currChapter
                    // More robust sync
                    if midIdx >= 0 && midIdx < chapters.count {
                        self.reader_manager.currChapter = chapters[midIdx]
                        self.currChapter = self.reader_manager.currChapter
                    }
         
                }
                else if chapterIdx < chapters.count - 1 && midIdx > chapterIdx
                {
                    print("shift Right")
                    self.reader_manager.shiftRight()
                    loadingNext = false
                    // sync currChapter and reader_manager.currChapter
                    // More robust sync
                    if midIdx >= 0 && midIdx < chapters.count {
                        self.reader_manager.currChapter = chapters[midIdx]
                        self.currChapter = self.reader_manager.currChapter
                    }

                }
                print("==================")
                
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
           if let collectionView = scrollView as? UICollectionView {
               let visibleIndexPaths = collectionView.indexPathsForVisibleItems
               if !loadingPrevious {
                   if visibleIndexPaths.contains(IndexPath(item:0, section:0))
                   {
                       print("First cell is VISIBLE adding prev chapters")
                       
                       if reader_manager.prevChapter.count  == 0 {
                           loadingNext = true
                           self.reader_manager.fetchTask(bool: false){
                               print("completion handler called")
                               
                               self.prependChapter(collectionView: collectionView)
                               
                           }
                       }
                       else {
                           print("nextChap is not empty")
                           prependChapter(collectionView: collectionView)
                       }
                       
                       

                   }
               }
               
               let bottomPath = getCurrentpagePath(collectionView: collectionView,position: .bottom)
               if !loadingNext {
                 
                   if bottomPath == nil || bottomPath?.section == chapters.count - 1  && bottomPath?.item == chapters[chapters.count - 1].count - 1 {
                       print("bottom path (section, idx) is (\(bottomPath?.section),\(bottomPath?.item)")
                       if reader_manager.nextChapter.count  == 0 {
                           loadingNext = true
                           self.reader_manager.fetchTask(bool: true){
                               print("completion handler called")
                               
                               self.appendChapter(collectionView: collectionView)
                               
                           }
                       }
                       else {
                           print("nextChap is not empty")
                           appendChapter(collectionView: collectionView)
                       }
                   }
               }
               
            }
            print("SCROLLING AS STOPPED")
        }
        //get height
        func getHeightForSection(_ section: Int, collectionView: UICollectionView) -> CGFloat {
            var totalHeight: CGFloat = 0
            let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
            for item in 0..<chapters[section].count {
                let indexPath = IndexPath(item: item, section: section)
                let size = self.collectionView(collectionView, layout: layout, sizeForItemAt: indexPath)
                totalHeight += size.height
            }
            return totalHeight
        }
        // prepend Chapter
        func prependChapter(collectionView: UICollectionView)
        {
            print("prependChapter called")
            if reader_manager.prevChapter.count > 0
            {
                print("prevChap > 0 && loadingNext == false")
                loadingPrevious = true
                
                // 🔧 FIX: Disable animations to prevent jumping
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                UIView.setAnimationsEnabled(false)
                
                // Store current offset and content size
                let oldOffset = collectionView.contentOffset
                let oldContentSize = collectionView.collectionViewLayout.collectionViewContentSize
                
                
                chapters.insert(reader_manager.prevChapter, at: 0)
                imageSizes.insert([:], at: 0)
                
                 collectionView.performBatchUpdates({
                    collectionView.insertSections(IndexSet(integer: 0))
                }, completion: { _ in
                    // Calculate new offset
                    let newContentSize = collectionView.collectionViewLayout.collectionViewContentSize
                    let heightDiff = newContentSize.height - oldContentSize.height
                    let newOffset = CGPoint(x: oldOffset.x, y: oldOffset.y + heightDiff)
                    
                    // Set new offset without animation
                    collectionView.setContentOffset(newOffset, animated: false)
                    
                    // 🔧 FIX: Re-enable animations and reset loading flag
                    if self.chapters.count > 3 {
                        // 1. First update your data source
                        let lastSectionIndex = self.chapters.count - 1
                        self.chapters.removeLast()
                        self.imageSizes.removeLast() // Also remove corresponding cached data

                        // 2. Then update the UI
                         collectionView.performBatchUpdates({
                            collectionView.deleteSections(IndexSet(integer: lastSectionIndex))
                        }, completion: { completed in
                            if completed {
                                print("First section removed successfully")
                               
                            }
                            self.loadingPrevious = false
                            UIView.setAnimationsEnabled(true)
                            CATransaction.commit()
                            
                        })
                    }
                    else {
                        self.loadingPrevious = false
                        UIView.setAnimationsEnabled(true)
                        CATransaction.commit()
                    }
                   
                })
               
            }
        }
        // append Chapter
        func appendChapter(collectionView: UICollectionView){
            print("append Called")
            if reader_manager.nextChapter.count > 0
            {
                print("nextChap > 0 && loadingNext == false")
                // append next Chapter
                loadingNext = true
                // 🔧 FIX: Disable animations to prevent jumping
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                UIView.setAnimationsEnabled(false)
                
                // Store current offset and content size
                let oldOffset = collectionView.contentOffset
                let oldContentSize = collectionView.collectionViewLayout.collectionViewContentSize
                let removedSectionHeight = getHeightForSection(0, collectionView: collectionView)
                if chapters.count >= 3 {
                    // Sliding window: replace first chapter with new one
                    chapters.removeFirst()
                    chapters.append(reader_manager.nextChapter)
                    imageSizes.removeFirst()
                    imageSizes.append([:])

                    collectionView.performBatchUpdates({
                        collectionView.deleteSections(IndexSet(integer: 0))
                        collectionView.insertSections(IndexSet(integer: 2))
                    }, completion: { _ in
                        // 🔧 FIX: Adjust offset by the difference in content size

                        let adjustedOffset = CGPoint(x: oldOffset.x, y: max(0, oldOffset.y - removedSectionHeight))
                                                
                            collectionView.setContentOffset(adjustedOffset, animated: false)
                      
                                                
                        UIView.setAnimationsEnabled(true)
                        CATransaction.commit()
                        self.loadingNext = false
                    })
                } else {
                    // Simple append: just add new chapter
                    chapters.append(reader_manager.nextChapter)
                    imageSizes.append([:])
                    
                    collectionView.performBatchUpdates({
                        collectionView.insertSections(IndexSet(integer: self.chapters.count - 1))
                    }, completion: { _ in
                        UIView.setAnimationsEnabled(true)
                        CATransaction.commit()
                        self.loadingNext = false
                    })
                }
               
                print("sucessfully added")
            }
            
            
            
        }
        
        
        func numberOfSections(in collectionView: UICollectionView) -> Int {
            chapters.count
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            chapters[section].count
        }
        
        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            // Don't reveal image here - let it happen after resize
           // print("cell  section \(indexPath.section) -  item \(indexPath.item) displayed ; number of sections \(chapters.count)")
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChapterCollectionViewCell.reuseIdentifier, for: indexPath) as? ChapterCollectionViewCell else {
                fatalError("Could not dequeue cell")
            }
            
            print("cellForItemAt section \(indexPath.section) -  item \(indexPath.item)")
            print("chapters count \(chapters.count)")
            if chapters.count >= 3 {
                print("last chapter count \(chapters[2].count)")
            }
            let rootView = chapters[indexPath.section][indexPath.item].body
            cell.set(rootView: rootView, coordinator: self, indexPath: indexPath)
            
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let width = collectionView.bounds.width
            
            // If we have the cached size, use it
            if let cachedSize = imageSizes[indexPath.section][indexPath.item] {
                let aspectRatio = cachedSize.height / cachedSize.width
                return CGSize(width: width, height: width * aspectRatio)
            }
            
            // Default size while image loads
            return CGSize(width: width, height:  400)
        }
        
        func updateImageSize(for indexPath: IndexPath, size: CGSize, collectionView: UICollectionView, isCached: Bool) {
            print("cell  section \(indexPath.section) -  item \(indexPath.item) updated ; number of sections \(chapters.count)")
            imageSizes[indexPath.section][indexPath.item] = size
            
            // 🔧 FIX: Only update layout if this is a new image that needs resizing
            if !isCached {
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        collectionView.performBatchUpdates({
                            collectionView.reloadItems(at: [indexPath])
                        }) { completed in
                            collectionView.layoutIfNeeded()
                            if completed, let cell = collectionView.cellForItem(at: indexPath) as? ChapterCollectionViewCell, cell.indexPath == indexPath {
                                cell.revealImage()
                            }
                        }
                    }
                }
            } else {
                // 🔧 FIX: For cached images, just reveal immediately without layout updates
                if let cell = collectionView.cellForItem(at: indexPath) as? ChapterCollectionViewCell, cell.indexPath == indexPath {
                    cell.revealImage()
                }
            }
        }
        
        var reader_manager: readerManager
        var chapters: [[PageData]] = []
        var currChapter: [PageData]
    }
}

// Updated cell that calculates size dynamically
class ChapterCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "ChapterCell"
    private let imageView = UIImageView()
    private var hostingController : UIHostingController<CircularLoader>!
    private var coordinator: WebtoonView.Coordinator?
    var indexPath: IndexPath?
    private let hostingContainer = UIView()

    
    // Add a unique identifier for each cell configuration
    private var currentLoadingTask: UUID?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 🔧 FIX: Modified prepareForReuse to prevent flicker
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Cancel any ongoing image loading
        imageView.kf.cancelDownloadTask()
        
        // Reset state properly
        currentLoadingTask = nil
        
        // 🔧 FIX: DON'T reset image or visibility state here - let set() method handle it
        // This prevents the flicker when cells are reused during batch updates
        
        // Clear references
        coordinator = nil
        indexPath = nil
    }
    
    private func setupImageView() {
        print("🏗️ setupImageView called")
        
        // Only setup once - check if already setup
        if !hostingContainer.subviews.isEmpty {
            return
        }
        
        // progress bar
        // 1️⃣ Add container to contentView
        hostingContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingContainer)
        NSLayoutConstraint.activate([
            hostingContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hostingContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        
        // 2️⃣ Add hostingController inside container
        hostingController = UIHostingController(rootView: CircularLoader(progress: 0))
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.clipsToBounds = false
        hostingController.view.isOpaque = false
        hostingContainer.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: hostingContainer.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: hostingContainer.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: hostingContainer.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: hostingContainer.trailingAnchor)
        ])
        
        // image view
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    // 🔧 FIX: Smart loading state management
    func set(rootView: chapterView, coordinator: WebtoonView.Coordinator, indexPath: IndexPath) {
        self.coordinator = coordinator
        self.indexPath = indexPath
        
        // Create a unique task identifier for this configuration
        let taskId = UUID()
        self.currentLoadingTask = taskId
        
        // 🔧 FIX: Check if image is already cached
        let url = URL(string: rootView.page.content)
        let isCached = url != nil && ImageCache.default.isCached(forKey: url!.absoluteString)
        
        if isCached {
            // 🔧 FIX: Image is cached, show it immediately without loading view
            imageView.isHidden = false
            hostingController.view.isHidden = true
        } else {
            // 🔧 FIX: Image needs to load, show loading view
            imageView.isHidden = true
            hostingController.view.isHidden = false
        }
        
        guard let url = URL(string: rootView.page.content) else { return }
        
        // 🔧 FIX: Set the image with options to prevent flicker
        imageView.kf.setImage(
            with: url,
            options: [
                .transition(.none), // Disable fade transition to prevent flicker
                .cacheOriginalImage
            ]
        ) { [weak self] result in
            guard let self = self,
                  let coordinator = self.coordinator,
                  let indexPath = self.indexPath,
                  self.currentLoadingTask == taskId else {
                // Cell was reused or task was cancelled
                return
            }
            
            switch result {
            case .success(let value):
                let imageSize = value.image.size
                
                // If size is not cached, update it and trigger resize
                if coordinator.imageSizes[indexPath.section][indexPath.item] == nil {
                    if let collectionView = self.findCollectionView() {
                        coordinator.updateImageSize(for: indexPath, size: imageSize, collectionView: collectionView, isCached: false)
                    }
                } else {
                    // 🔧 FIX: Size is cached, update cache and reveal immediately
                    coordinator.imageSizes[indexPath.section][indexPath.item] = imageSize
                    self.revealImage()
                }
                
            case .failure(let error):
                print("Image loading failed: \(error)")
                
                // Handle the special case where image loaded but task was cancelled
                if case .imageSettingError(let reason) = error,
                   case .notCurrentSourceTask(let result) = reason,
                   let retrieveResult = result.result {
                    // Image actually loaded successfully, we can still use the size info
                    let imageSize = retrieveResult.image.size
                    if let collectionView = self.findCollectionView() {
                        coordinator.updateImageSize(for: indexPath, size: imageSize, collectionView: collectionView, isCached: false)
                    }
                } else {
                    // True failure - keep loading view visible
                    DispatchQueue.main.async {
                        //self.imageView.isHidden = true
                        //self.hostingController.view.isHidden = false
                    }
                }
            }
        }
    }
    
    func revealImage() {
        // Double check that this cell hasn't been reused
        guard currentLoadingTask != nil else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.imageView.isHidden = false
            self.hostingController.view.isHidden = true
        }
    }
    
    private func findCollectionView() -> UICollectionView? {
        var view = self.superview
        while view != nil {
            if let collectionView = view as? UICollectionView {
                return collectionView
            }
            view = view?.superview
        }
        return nil
    }
}


//enum ScreenPosition
enum ScreenPosition {
    case mid
    case top
    case bottom
}

