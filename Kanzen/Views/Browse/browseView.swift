import SwiftUI
struct BrowseView: View {
    @EnvironmentObject var moduleManager: ModuleManager
    let kanzen: KanzenEngine = KanzenEngine()
    var body: some View {
        NavigationView(){
            KanzenModuleView()
        }.environmentObject(kanzen)
    }
}
