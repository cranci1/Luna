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
    
    private let horrorGenreIds = [27]
    private let animationGenreId = 16
    
    private init() {
        self.filterHorror = UserDefaults.standard.bool(forKey: "filterHorror")
        self.animeOnlyMode = UserDefaults.standard.bool(forKey: "animeOnlyMode")
    }
    
    // MARK: - Filter Functions
    
    func filterSearchResults(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        var filtered = results
        
        if animeOnlyMode {
            filtered = filtered.filter { result in
                result.mediaType == "tv" && isAnimeContent(genreIds: result.genreIds)
            }
        }
        
        if filterHorror {
            filtered = filtered.filter { result in
                shouldIncludeContent(genreIds: result.genreIds)
            }
        }
        
        return filtered
    }
    
    func filterMovies(_ movies: [TMDBMovie]) -> [TMDBMovie] {
        if animeOnlyMode {
            return []
        }
        
        if !filterHorror {
            return movies
        }
        
        return movies.filter { movie in
            shouldIncludeContent(genreIds: movie.genreIds)
        }
    }
    
    func filterTVShows(_ tvShows: [TMDBTVShow]) -> [TMDBTVShow] {
        if !filterHorror {
            return tvShows
        }
        
        return tvShows.filter { tvShow in
            shouldIncludeContent(genreIds: tvShow.genreIds)
        }
    }
    
    func filterMovieDetail(_ movie: TMDBMovieDetail) -> Bool {
        return shouldIncludeContent(genres: movie.genres)
    }
    
    func filterTVShowDetail(_ tvShow: TMDBTVShowDetail) -> Bool {
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
