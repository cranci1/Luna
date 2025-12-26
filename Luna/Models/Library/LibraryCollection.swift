//
//  LibraryCollection.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import Foundation

final class LibraryCollection: ObservableObject, Codable, Identifiable, Equatable {
    @Published var items: [LibraryItem] = []
    var id: UUID
    var name: String
    var description: String?
    
    init(id: UUID = UUID(), name: String, items: [LibraryItem] = [], description: String? = nil) {
        self.id = id
        self.name = name
        self.items = items
        self.description = description
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case items
        case description
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(items, forKey: .items)
        try container.encode(description, forKey: .description)
    }
    
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let items = try container.decodeIfPresent([LibraryItem].self, forKey: .items) ?? []
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        self.init(id: id, name: name, items: items, description: description)
    }
    
    // MARK: - Equatable
    static func == (lhs: LibraryCollection, rhs: LibraryCollection) -> Bool {
        lhs.id == rhs.id
    }
}
