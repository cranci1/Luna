//
//  TMDBContentFilter.swift
//  Sora
//
//  Created by Francesco on 11/09/25.
//

import Foundation

class TMDBContentFilter: ObservableObject {
    static let shared = TMDBContentFilter()
    
    @Published var filterHorror: Bool {
        didSet {
            UserDefaults.standard.set(filterHorror, forKey: "filterHorror")
        }
    }
    
    @Published var animeOnlyMode: Bool {
        didSet {
            UserDefaults.standard.set(animeOnlyMode, forKey: "animeOnlyMode")
        }
    }
    
    @Published var filterNSFW: Bool {
        didSet {
            UserDefaults.standard.set(filterNSFW, forKey: "filterNSFW")
        }
    }
    
    private let horrorGenreIds = [27]
    private let animationGenreId = 16
    
    private init() {
        self.filterHorror = UserDefaults.standard.bool(forKey: "filterHorror")
        self.animeOnlyMode = UserDefaults.standard.bool(forKey: "animeOnlyMode")
        self.filterNSFW = UserDefaults.standard.bool(forKey: "filterNSFW")
    }
    
    // MARK: - Filter Functions
    
    func filterSearchResults(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        var filtered = results
        
        if animeOnlyMode {
            filtered = filtered.filter { result in
                isAnimeContent(genreIds: result.genreIds)
            }
        }
        
        if filterHorror {
            filtered = filtered.filter { result in
                shouldIncludeContent(genreIds: result.genreIds)
            }
        }
        
        if filterNSFW {
            filtered = filtered.filter { result in
                !isNSFWContent(id: result.id, isAdult: result.adult)
            }
        }
        
        return filtered
    }
    
    func filterMovies(_ movies: [TMDBMovie]) -> [TMDBMovie] {
        if animeOnlyMode {
            var filtered = movies.filter { isAnimeContent(genreIds: $0.genreIds) }
            if filterHorror {
                filtered = filtered.filter { shouldIncludeContent(genreIds: $0.genreIds) }
            }
            if filterNSFW {
                filtered = filtered.filter { !isNSFWContent(id: $0.id, isAdult: $0.adult) }
            }
            return filtered
        }
        
        var filtered = movies
        
        if filterHorror {
            filtered = filtered.filter { shouldIncludeContent(genreIds: $0.genreIds) }
        }
        
        if filterNSFW {
            filtered = filtered.filter { !isNSFWContent(id: $0.id, isAdult: $0.adult) }
        }
        
        return filtered
    }
    
    func filterTVShows(_ tvShows: [TMDBTVShow]) -> [TMDBTVShow] {
        var filtered = tvShows
        
        if filterHorror {
            filtered = filtered.filter { shouldIncludeContent(genreIds: $0.genreIds) }
        }
        
        if filterNSFW {
            filtered = filtered.filter { !isNSFWContent(id: $0.id, isAdult: nil) }
        }
        
        return filtered
    }
    
    func filterMovieDetail(_ movie: TMDBMovieDetail) -> Bool {
        if filterNSFW && isNSFWContent(id: movie.id, isAdult: movie.adult) { return false }
        return shouldIncludeContent(genres: movie.genres)
    }
    
    func filterTVShowDetail(_ tvShow: TMDBTVShowDetail) -> Bool {
        if filterNSFW && isNSFWContent(id: tvShow.id, isAdult: tvShow.adult) { return false }
        return shouldIncludeContent(genres: tvShow.genres)
    }
    
    func isAnimeContent(genreIds: [Int]?) -> Bool {
        guard let genreIds = genreIds else { return false }
        return genreIds.contains(animationGenreId)
    }
    
    func isNonAnimeSection(_ sectionId: String) -> Bool {
        let nonAnimeSections = ["trending", "popularMovies", "popularTVShows", "topRatedMovies", "topRatedTVShows"]
        return nonAnimeSections.contains(sectionId)
    }
    
    func isNSFWContent(id: Int, isAdult: Bool?) -> Bool {
        if isAdult == true { return true }
        return false
    }
    
    private func shouldIncludeContent(genreIds: [Int]?) -> Bool {
        if filterHorror {
            if let genreIds = genreIds {
                let containsHorror = genreIds.contains { genreId in
                    horrorGenreIds.contains(genreId)
                }
                if containsHorror {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func shouldIncludeContent(genres: [TMDBGenre]) -> Bool {
        if filterHorror {
            let containsHorror = genres.contains { genre in
                horrorGenreIds.contains(genre.id)
            }
            if containsHorror {
                return false
            }
        }
        
        return true
    }
}
