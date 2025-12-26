//
//  favouriteManager.swift
//  Luna
//
//  Created by Dawud Osman on 17/11/2025.
//

//
//  favouriteManager.swift
//  Kanzen
//
//  Created by Dawud Osman on 18/10/2025.
//
import SwiftUI
import CoreData
class FavouriteManager: ObservableObject {
    static let shared = FavouriteManager()
    let container: NSPersistentContainer
    init() {
        container = NSPersistentContainer(name: "ContentModel")
        container.loadPersistentStores{ description, error in
            if let error = error {
                fatalError("Unable to load Core Data store: \(error)")
            }
            else
            {
                print("Favourite Manager init success")
            }
        }
    }
    func addFavourite(module: ModuleDataContainer?, content: Manga) {
        print("add favourite called")
        let _ = createFavouriteEntity(module: module, content: content)
    }
    func removeFavourite(moduleId: UUID, contentId: String)
    {
        
            let context = container.viewContext

            let fetchRequest: NSFetchRequest<MangaData> = MangaData.fetchRequest() as! NSFetchRequest<MangaData>
            fetchRequest.predicate = NSPredicate(format: "sourceId == %@ AND mangaId == %@", moduleId as CVarArg, contentId)
            do {
                let contentsToDelete = try context.fetch(fetchRequest)
                for contentToDelete in contentsToDelete {
                    context.delete(contentToDelete)
                }
                try context.save()
            }
            catch {
                print("error deleting favourites: \(error) ")
            }
        
        print("remove favourite Called")
    }
    func removeAllModuleFavourites(module: ModuleDataContainer){}
    func createFavouriteEntity(module: ModuleDataContainer?, content: Manga)
    {
        print("create favourite called")
        if let module = module
        {
            let context = container.viewContext
            let newContent = MangaData(context: context)
            newContent.title = content.title
            newContent.imageURL = content.imageURL
            newContent.mangaId = content.mangaId
            newContent.sourceId = module.id
            do {
                try context.save()
                print("✅ Favourite saved successfully!")
            } catch {
                print("❌ Failed to save favourite: \(error)")
            }

            return
        }
    }
    func isFavourite(moduleId: UUID, contentId: String) -> Bool
    {
        let context = container.viewContext

        let fetchRequest: NSFetchRequest<MangaData> = MangaData.fetchRequest() as! NSFetchRequest<MangaData>
        fetchRequest.predicate = NSPredicate(format: "sourceId == %@ AND mangaId == %@", moduleId as CVarArg, contentId)
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        }
        catch{
            print("Error finding favourite: \(error)")
            return false
        }
        
    }
}
