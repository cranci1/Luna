//
//  ModuleView.swift
//  Kanzen
//
//  Created by Dawud Osman on 15/05/2025.
//
import SwiftUI
import Kingfisher

#if !os(tvOS)
struct KanzenModuleView: View {
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @EnvironmentObject var moduleManager : ModuleManager
    @State var copySelectedModule: String? = nil
    private var fallbackCircle: some View {
        Circle()
            .fill(Color.black)
            .frame(width: 60, height: 60)
    }
    func metaDataInfo(title: String, value: String ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.body)
                        .lineLimit(2)
                }
            
        
    }
    func deleteItems(at offsets: IndexSet) {
        for index in offsets
        {
            moduleManager.deleteModule(moduleManager.modules[index])
        }
    }
    var body: some View {
        
        ZStack{
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
                 Form
                 {
                     if(moduleManager.modules.isEmpty)
                     {
                         VStack(spacing:10){
                             Image(systemName: "plus.app").font(.largeTitle).foregroundColor(.secondary)
                             Text("No Modules Found").font(.headline)
                             Text("Tap the \"+\" button to add a module").font(.caption).foregroundColor(.secondary)
                         }.padding().frame(maxWidth:.infinity)
                     }
                     else
                     { Section{
                         ForEach(moduleManager.modules){item in
                             let selectedModule = copySelectedModule == item.moduleurl
                             let row = ZStack{
                                 
                                 HStack
                                 {
                                     
                                     circularImage(from: item.moduleData.iconURL, size: 50)
                                         .padding(.trailing,10)
                                     HStack{Divider()}
                                    
                                     VStack(alignment: .leading)
                                     {
                                         HStack(alignment: .bottom, spacing: 4){
                                             Text(item.moduleData.sourceName)
                                                 .font(.headline)
                                                 .foregroundColor(.primary)
                                             Text("v\(item.moduleData.version)")
                                                 .font(.subheadline)
                                                 .foregroundColor(.secondary)
                                         }
                                         
                                         Text("Author: \(item.moduleData.author.name)")
                                             .font(.subheadline)
                                             .foregroundColor(.secondary)
                                         Text("Language: \(item.moduleData.language)")
                                             .font(.subheadline)
                                             .foregroundColor(.secondary)
                                     }.padding(.horizontal,20)
                                     Spacer()
                                     

                                 }
                                 .padding(.leading,10)
                                 .padding(.trailing,10)
                                 .animation(.spring(response: 0.3, dampingFraction: 0.4), value: selectedModule)
                                 .scaleEffect(selectedModule ? 1.02 : 1.0)
                             }
                             let destination = KanzenSearchView(module: item)
                             NavigationLink(destination: destination){
                                 row
                                     .allowsHitTesting(true)
                                     .buttonStyle(.plain)
                             }
                             .allowsHitTesting(true)
                             .buttonStyle(.plain)
                             .simultaneousGesture(
                                 LongPressGesture(minimumDuration: 0.3)
                                     .onEnded { _ in
                                         UIPasteboard.general.string = item.moduleurl
                                         withAnimation(.spring) {
                                             copySelectedModule = item.moduleurl
                                         }
                                         UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                         DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                             withAnimation(.snappy) {
                                                 copySelectedModule = nil
                                             }
                                         }
                                     }
                             )
                             .padding(.leading,5)
                             .padding(.trailing,5)
                             .padding(.top,10)
                             .padding(.bottom,10)
                             .listRowInsets(EdgeInsets())
                             .compositingGroup()  // create a drawing group
                             
                             .frame(maxWidth: .infinity,alignment: .center)
                             .shadow(color: .black.opacity(selectedModule ? 0.4 : 0.2), radius: selectedModule ? 10 : 4)
                             
                             .clipShape(RoundedRectangle(cornerRadius: 12))
                             
                             .overlay(
                                 RoundedRectangle(cornerRadius: 12)
                                     .stroke(Color.accentColor.opacity(selectedModule ? 1 : 0), lineWidth: selectedModule ? 5 : 0)
                             )
                            

                        
                         }
                         
                         
                         .onDelete(perform: deleteItems)
                     }



                             
                        
                     }

                 }
                 
                 // Remove default list styling
                 //.scrollContentBackground(.hidden) // hides default form background
                 .background(Color(.systemGroupedBackground))
             .navigationTitle("Modules")
             .navigationBarTitleDisplayMode(.inline)
             .frame(maxWidth: .infinity,alignment: .center)
             .padding(.top,10)
             .overlay
             {
                 if copySelectedModule != nil
                 {
                     Text("Copied to Clipboard")
                         
                         .foregroundColor(.accentColor)
                         
                         .padding()
                         .background(Color(.systemBackground).cornerRadius(20))
                         .padding(.bottom)
                         .shadow(radius: 3)
                         .transition(.move(edge: .top))
                         .frame(maxHeight: .infinity, alignment: .top)
                 }
             }
                 .toolbar{
                     ToolbarItem(placement: .navigationBarTrailing)
                     {
                         Button(action: {
                             addModuleAlert()
                         }){Image(systemName: "plus").resizable().frame(width: 20, height: 20)}
                     }
                 }
        }


    }
    func circularImage(from urlString: String, size: CGFloat) -> some View {
        Group {
            if let url = URL(string: urlString) {
                KFImage(url)
                    .placeholder {
                        ProgressView()
                    }
                    .cancelOnDisappear(true)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .background {
                        // Optional: placeholder background or error state
                    }
            } else {
                Circle().fill(Color.black)
            }
        }
 
      
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(radius: 5)
        
    }
    func addModule(fetchedModule: ModuleData, url: String, dismiss: @escaping () -> Void)
    {
      Task{
          do{
              try await moduleManager.addModules(url, metaData: fetchedModule)
          }
          catch {
              Logger.shared.log((error.localizedDescription),type: "Error")
          }
          dismiss()
        }
    }
    func popupContent(fetchedModule: ModuleData?,url: String,width: CGFloat,height: CGFloat, dismiss: @escaping () -> Void) -> some View {
        
        ZStack{
            if let moduleData = fetchedModule
            {
                VStack(spacing:25){
                    VStack(spacing:15){
                        circularImage(from: moduleData.iconURL, size: 120)
                        Text(moduleData.sourceName)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    Divider()
                    HStack(spacing:10){
                        circularImage(from: moduleData.author.iconURL, size: 60)
                        VStack(alignment: .leading,spacing:4)
                        {
                            Text(moduleData.author.name).font(.headline)
                            Text("Author").font(.subheadline).foregroundColor(.secondary)
                        }
                        HStack(){Divider().frame(maxHeight: 125)}
                            .padding(.horizontal)
                        VStack(alignment: .leading, spacing: 10){
                            metaDataInfo(title: "Version", value: moduleData.version)
                            metaDataInfo(title: "Language" , value: moduleData.language)
                            metaDataInfo(title: "Script URL", value: moduleData.scriptURL)
                        }.padding(.horizontal)
                        Spacer()
                    }
                    .padding(.horizontal)
                        .frame(maxHeight: 150,alignment: .center)

                    Divider()
                    Spacer()
                    VStack()
                    {
                        Button(action : {
                            addModule(fetchedModule: moduleData,url: url,dismiss: dismiss)
                        } )
                        {
                            HStack{
                                Image(systemName: "plus.circle.fill")
                                Text("add module")
                            }
                        }
                        .tint(.accentColor)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.accentColor)
                        )
                        .padding(.horizontal)
                        Button(action :  {
                         dismiss()
                        })
                        {
                            Text("Cancel")
                                .foregroundColor((Color.accentColor))
                                .padding(.top, 10)
                        }
                    }.padding(.bottom, 20)
                }.padding(.top).frame(maxWidth: .infinity,alignment: .top)
                
                }

        }.padding(.top).frame(maxWidth: .infinity,alignment: .top)
            .clipped()
    }

    func fetchModule(url: String) -> Void
    {
        let screenBounds = UIScreen.main.bounds
        let width = screenBounds.width
        let height = screenBounds.height
        validFetchedModule(url){metaData in
            DispatchQueue.main.async {
                if let metaData = metaData
                {
                    
                    var hostingController: UIHostingController<AnyView>? = nil

                    let content = popupContent(
                        fetchedModule: metaData,url: url,
                        width: width,
                        height: height,
                        dismiss: {
                            hostingController?.dismiss(animated: true)
                        }
                    )

                    hostingController = UIHostingController(rootView: AnyView(content))
                    

                    if let topVC = getTopViewController(), let hc = hostingController {
                        topVC.present(hc, animated: true)
                    }


                }
                else{
                    let alert = UIAlertController(title: "Failed to Add Module",
                                                  message: "The provided Module URL is invalid",
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    // Present it from the top view controller
                    if let topVC = getTopViewController() {
                        topVC.present(alert, animated: true)
                    }
                }

            }
           
        }
       
    }
    //
    func validFetchedModule(_ urlString: String, completion: @escaping (ModuleData?) -> Void) {
        Task {
            do{
                let metaData = try await moduleManager.validateModuleUrl(urlString)
                
               
                completion(metaData)
            }
            catch {
                Logger.shared.log(error.localizedDescription,type: "Error")
                completion(nil)
            }
        }
    }
    func addModuleAlert()
    {
        let alert = UIAlertController(title: "Add Module", message: "Enter Module Name", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "https://real.url/module.json"
        }
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: {_ in
            if let url = alert.textFields?.first?.text, !url.isEmpty {
                displayFetchedContent(url: url)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        // Present alert directly from this top View Controler
        if let topVC = getTopViewController() {
            topVC.present(alert, animated: true, completion: nil)
        }
    }
    //display content from fetchedUrl
    func displayFetchedContent(url: String)
    {
        self.fetchModule(url:url)

    }
    
    // returns visible viewController to display Alert
    func getTopViewController(base: UIViewController? = UIApplication.shared.connectedScenes
                                .compactMap { $0 as? UIWindowScene }
                                .first?.windows
                                .first(where: { $0.isKeyWindow })?.rootViewController) -> UIViewController? {
        
        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)
        }
        
        if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }
        
        return base
    }

}
#endif
