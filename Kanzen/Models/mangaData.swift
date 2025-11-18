//
//  mangaData.swift
//  Luna
//
//  Created by Dawud Osman on 17/11/2025.
//
//
//  mangaData.swift
//  Kanzen
//
//  Created by Dawud Osman on 12/10/2025.
//
import SwiftUI
import CoreData

struct Manga: Identifiable {
    let id: UUID = UUID()
    let title: String
    let imageURL: String
    let mangaId: String
    var parentModule: ModuleDataContainer?
    
}


// official mangaData
class MangaData: NSManagedObject {
    @NSManaged var sourceId : UUID
    @NSManaged var mangaId : String
    @NSManaged var title: String?
    @NSManaged var imageURL: String?
    @NSManaged var synopsis: String?
    
}
