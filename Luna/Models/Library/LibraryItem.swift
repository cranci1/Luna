//
//  LibraryItem.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import Foundation

struct LibraryItem: Codable, Identifiable {
    var id: Int { searchResult.id }
    let searchResult: TMDBSearchResult
    var dateAdded: Date = Date()
}
