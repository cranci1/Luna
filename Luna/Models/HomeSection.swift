//
//  HomeSection.swift
//  Sora
//
//  Created by Francesco on 11/09/25.
//

import Foundation

struct HomeSection: Identifiable, Codable {
    let id: String
    let title: String
    var isEnabled: Bool
    var order: Int
    
    static let defaultSections = [
        HomeSection(id: "trending", title: "Trending This Week", isEnabled: true, order: 0),
        HomeSection(id: "popularMovies", title: "Popular Movies", isEnabled: true, order: 1),
        HomeSection(id: "popularTVShows", title: "Popular TV Shows", isEnabled: true, order: 2),
        HomeSection(id: "popularAnime", title: "Popular Anime", isEnabled: true, order: 3),
        HomeSection(id: "topRatedMovies", title: "Top Rated Movies", isEnabled: true, order: 4),
        HomeSection(id: "topRatedTVShows", title: "Top Rated TV Shows", isEnabled: true, order: 5),
        HomeSection(id: "topRatedAnime", title: "Top Rated Anime", isEnabled: true, order: 6)
    ]
}
