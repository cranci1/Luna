//
//  Module.swift
//  Kanzen
//
//  Created by Dawud Osman on 13/05/2025.
//
import Foundation
struct ModuleData: Codable, Equatable
{

    
    let sourceName: String
    let author: Author
    let iconURL: String
    let version: String
    let language: String
    let scriptURL: String
    
    struct Author: Codable, Equatable
    {
        let name: String
        let iconURL: String
    }
}
struct ModuleDataContainer: Codable, Identifiable,Hashable
{
    let id: UUID
    let moduleData: ModuleData
    let localPath: String
    let moduleurl: String
    var isActive: Bool
    init(id:UUID = UUID(), moduleData: ModuleData, localPath: String, moduleurl: String, isActive: Bool = false) {
        self.id = id
        self.moduleData = moduleData
        self.localPath = localPath
        self.moduleurl = moduleurl
        self.isActive = isActive
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: ModuleDataContainer, rhs: ModuleDataContainer) -> Bool {
        return lhs.id == rhs.id
    }
}
