import SwiftUI
import UIKit

struct pageReader: UIViewControllerRepresentable {
    @ObservedObject var reader_manager: readerManager
    var pageViewConfig: pageViewMode
    
    func makeCoordinator() -> Coordinator {
        return  Coordinator(reader_manager: reader_manager,pageViewConfig:    pageViewConfig)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let navigationOrientation: UIPageViewController.NavigationOrientation
        switch pageViewConfig {
        case .LTR:
            navigationOrientation = .horizontal
        case .RTL:
            navigationOrientation = .horizontal
        case .Vertical:
            navigationOrientation = .vertical
        }
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: navigationOrientation
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        
        DispatchQueue.main.async {
            if self.reader_manager.currControllers == nil{
                self.reader_manager.generateCurrControllers()
            }
            if self.reader_manager.nextControllers == nil{
                self.reader_manager.generateNextControllers()
            }
            if self.reader_manager.prevControllers == nil{
                self.reader_manager.generatePrevControllers()
            }
            let index = self.reader_manager.getIndex()
            if let currControllers = self.reader_manager.currControllers,
               !currControllers.isEmpty,
               index >= 0,
               index < currControllers.count {
                controller.setViewControllers([currControllers[index]], direction: .forward, animated: false)
            }
            else{
                Logger.shared.log("failed to set initial controller", type: "Error")
                Logger.shared.log("index < currController count ? \(index < (self.reader_manager.currControllers?.count ?? 0))", type: "Debug")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let index = reader_manager.getIndex()
        
        if let currControllers = reader_manager.currControllers, index >= 0 && index < currControllers.count {
            if (reader_manager.currChapter != context.coordinator.currChapter) || (reader_manager.changeIndex == true) {
                context.coordinator.currChapter = reader_manager.currChapter
                context.coordinator.currControllers = currControllers
                context.coordinator.currIdx = index
                controller.setViewControllers([currControllers[index]], direction: .forward, animated: false)
                if reader_manager.changeIndex == true {
                    reader_manager.changeIndex = false
                }
                reader_manager.preloadAdjacentPages()
            }
        }
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        func navigateForward(index: Int) -> UIViewController?
        {
            if index < currControllers.count - 1 {
                return currControllers[index + 1]
            }
            if let nextControllers = reader_manager.nextControllers,!nextControllers.isEmpty {
                return nextControllers.first
            }
            return nil
        }
        
        func navigateBackward(index: Int) -> UIViewController?{
            if index > 0 {
                return currControllers[index - 1]
            }
            if let prevControllers = reader_manager.prevControllers, !prevControllers.isEmpty
            {
                return prevControllers.last
            }
            return nil
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = currControllers.firstIndex(of: viewController) else {
                print("find before Controlelr instead")
                print(reader_manager.findControllers(currView: viewController))
                return nil
            }
            switch pageViewConfig {
            case .LTR:
                return navigateBackward(index: index)
            case .RTL:
                return navigateForward(index: index)
            case .Vertical:
                return navigateBackward(index: index)
            }
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = currControllers.firstIndex(of: viewController) else {
                print("find after Controlelr instead")
                print(reader_manager.findControllers(currView: viewController))
                return nil
            }
            switch pageViewConfig {
            case .LTR:
                return navigateForward(index: index)
            case .RTL:
                return navigateBackward(index: index)
            case .Vertical:
                return navigateForward(index: index)
            }
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            transitioning = true
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if !completed  || !finished {
                
            }
            transitioning = false
            guard let vC = pageViewController.viewControllers?.first else {
                return
            }
            guard let index = currControllers.firstIndex(of: vC) else {
                
                if let nextControllers = reader_manager.nextControllers,nextControllers.contains(vC){
                    reader_manager.shiftRight()
                    currChapter = reader_manager.currChapter
                    currControllers = reader_manager.currControllers ?? []
                    reader_manager.fetchTask(bool: true)
                    
                    return
                }
                else if let prevControllers = reader_manager.prevControllers, prevControllers.contains(vC){
                    DispatchQueue.main.async{}
                    reader_manager.shiftLeft()
                    currChapter = reader_manager.currChapter
                    currControllers = reader_manager.currControllers ?? []
                    reader_manager.fetchTask(bool: false)
                    
                    return
                }
                
                return
            }
            currIdx = index
            reader_manager.setIndex(index)
            reader_manager.preloadAdjacentPages()
            
        }
        
        @ObservedObject var reader_manager: readerManager
        var currChapter: [PageData]
        var currControllers: [UIViewController]
        var currIdx: Int = 0
        var transitioning: Bool = false
        var pageViewConfig: pageViewMode
        init(reader_manager: readerManager, pageViewConfig: pageViewMode) {
            self.reader_manager = reader_manager
            self.currChapter = reader_manager.currChapter
            self.currControllers = reader_manager.currControllers ?? []
            self.currIdx = reader_manager.getIndex()
            self.pageViewConfig = pageViewConfig
        }
    }
}
