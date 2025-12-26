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
    
    private let horrorGenreIds = [27]
    
    private init() {
        self.filterHorror = UserDefaults.standard.bool(forKey: "filterHorror")
    }
    
    // MARK: - Filter Functions
    
    func filterSearchResults(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        if !filterHorror {
            return results
        }
        
        return results.filter { result in
            shouldIncludeContent(genreIds: result.genreIds)
        }
    }
    
    func filterMovies(_ movies: [TMDBMovie]) -> [TMDBMovie] {
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
