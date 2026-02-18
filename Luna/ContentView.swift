//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler

    @State private var selectedTab = 0
    @State private var showStorageError = false
    @State private var storageErrorMessage = ""
    @State private var showDeepLinkContent = false
    @State private var deepLinkSearchResult: TMDBSearchResult?

    var body: some View {
#if compiler(>=6.0)
        if #available(iOS 26.0, tvOS 26.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: 0) {
                    HomeView()
                }

                Tab("Library", systemImage: "books.vertical.fill", value: 1) {
                    if selectedTab == 1 {
                        LibraryView()
                    }
                }
                
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                    SearchView()
                }
                
                Tab("Settings", systemImage: "gear", value: 3) {
                    SettingsView()
                        .id(selectedTab)
                }

            }
#if !os(tvOS)
            .tabBarMinimizeBehavior(.onScrollDown)
#endif
            .accentColor(accentColorManager.currentAccentColor)
            .tvos({ view in
                view.fullScreenCover(isPresented: $showDeepLinkContent) {
                    if let searchResult = deepLinkSearchResult {
                        MediaDetailView(searchResult: searchResult)
                    }
                }
            }, else: { view in
                view.sheet(isPresented: $showDeepLinkContent) {
                    if let searchResult = deepLinkSearchResult {
                        MediaDetailView(searchResult: searchResult)
                    }
                }
            })
            .onChangeComp(of: deepLinkHandler.pendingDeepLink) { _, newValue in
                handleDeepLink(newValue)
            }
            
        } else {
            olderTabView
        }
#else
        olderTabView
#endif
    }
    
    private var olderTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(0)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            Group {
                if selectedTab == 1 {
                    LibraryView()
                } else {
                    Color.clear
                }
            }
            .tag(1)
            .tabItem {
                Image(systemName: "books.vertical.fill")
                Text("Library")
            }
            
            SearchView()
                .tag(2)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            SettingsView()
                .tag(3)
                .id(selectedTab)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(accentColorManager.currentAccentColor)
        .tvos({ view in
            view.fullScreenCover(isPresented: $showDeepLinkContent) {
                if let searchResult = deepLinkSearchResult {
                    MediaDetailView(searchResult: searchResult)
                }
            }
        }, else: { view in
            view.sheet(isPresented: $showDeepLinkContent) {
                if let searchResult = deepLinkSearchResult {
                    MediaDetailView(searchResult: searchResult)
                }
            }
        })
        .onChangeComp(of: deepLinkHandler.pendingDeepLink) { _, newValue in
            handleDeepLink(newValue)
        }
    }
    
    // MARK: - Deep Link Handling
    private func handleDeepLink(_ deepLink: DeepLinkHandler.DeepLink?) {
        guard let deepLink = deepLink else { return }
        
        Task {
            do {
                switch deepLink {
                case .playMovie(let tmdbId, _):
                    let movie = try await TMDBService.shared.getMovieDetails(id: tmdbId)
                    let searchResult = TMDBSearchResult(
                        id: movie.id,
                        mediaType: "movie",
                        title: movie.title,
                        name: nil,
                        overview: movie.overview,
                        posterPath: movie.posterPath,
                        backdropPath: movie.backdropPath,
                        releaseDate: movie.releaseDate,
                        firstAirDate: nil,
                        voteAverage: movie.voteAverage,
                        popularity: movie.popularity ?? 0.0,
                        adult: movie.adult,
                        genreIds: movie.genres.map { $0.id }
                    )
                    await MainActor.run {
                        deepLinkSearchResult = searchResult
                        showDeepLinkContent = true
                        deepLinkHandler.clearPendingDeepLink()
                    }
                    
                case .showDetails(let tmdbId, let mediaType) where mediaType == "movie":
                    let movie = try await TMDBService.shared.getMovieDetails(id: tmdbId)
                    let searchResult = TMDBSearchResult(
                        id: movie.id,
                        mediaType: "movie",
                        title: movie.title,
                        name: nil,
                        overview: movie.overview,
                        posterPath: movie.posterPath,
                        backdropPath: movie.backdropPath,
                        releaseDate: movie.releaseDate,
                        firstAirDate: nil,
                        voteAverage: movie.voteAverage,
                        popularity: movie.popularity ?? 0.0,
                        adult: movie.adult,
                        genreIds: movie.genres.map { $0.id }
                    )
                    await MainActor.run {
                        deepLinkSearchResult = searchResult
                        showDeepLinkContent = true
                        deepLinkHandler.clearPendingDeepLink()
                    }
                    
                case .playEpisode(let tmdbId, _, _, _):
                    let tvShow = try await TMDBService.shared.getTVShowWithSeasons(id: tmdbId)
                    let searchResult = TMDBSearchResult(
                        id: tvShow.id,
                        mediaType: "tv",
                        title: nil,
                        name: tvShow.name,
                        overview: tvShow.overview,
                        posterPath: tvShow.posterPath,
                        backdropPath: tvShow.backdropPath,
                        releaseDate: nil,
                        firstAirDate: tvShow.firstAirDate,
                        voteAverage: tvShow.voteAverage,
                        popularity: tvShow.popularity ?? 0.0,
                        adult: nil,
                        genreIds: tvShow.genres.map { $0.id }
                    )
                    await MainActor.run {
                        deepLinkSearchResult = searchResult
                        showDeepLinkContent = true
                        deepLinkHandler.clearPendingDeepLink()
                    }
                    
                case .showDetails(let tmdbId, let mediaType) where mediaType == "tv":
                    let tvShow = try await TMDBService.shared.getTVShowWithSeasons(id: tmdbId)
                    let searchResult = TMDBSearchResult(
                        id: tvShow.id,
                        mediaType: "tv",
                        title: nil,
                        name: tvShow.name,
                        overview: tvShow.overview,
                        posterPath: tvShow.posterPath,
                        backdropPath: tvShow.backdropPath,
                        releaseDate: nil,
                        firstAirDate: tvShow.firstAirDate,
                        voteAverage: tvShow.voteAverage,
                        popularity: tvShow.popularity ?? 0.0,
                        adult: nil,
                        genreIds: tvShow.genres.map { $0.id }
                    )
                    await MainActor.run {
                        deepLinkSearchResult = searchResult
                        showDeepLinkContent = true
                        deepLinkHandler.clearPendingDeepLink()
                    }
                    
                default:
                    break
                }
            } catch {
                Logger.shared.log("Failed to handle deep link: \(error)", type: "Error")
                await MainActor.run {
                    deepLinkHandler.clearPendingDeepLink()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
