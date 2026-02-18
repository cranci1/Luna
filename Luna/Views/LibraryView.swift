//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct LibraryView: View {
    @State private var showingCreateSheet = false
    @State private var watchHistoryItems: [WatchHistoryItem] = []
    
    @StateObject private var accentColorManager = AccentColorManager.shared
    @ObservedObject private var libraryManager = LibraryManager.shared

    private var sectionHorizontalPadding: CGFloat { isTvOS ? 40 : 16 }
    private var horizontalCardGap: CGFloat { isTvOS ? 50 : 12 }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                libraryContent
            }
        } else {
            NavigationView {
                libraryContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                watchHistorySection
                bookmarksSection
                collectionsSection
            }
            .padding(.top)
        }
        .navigationTitle("Library")
        .navigationBarItems(trailing: Button(action: {
            showingCreateSheet = true
        }) {
            Image(systemName: "plus")
                .foregroundColor(accentColorManager.currentAccentColor)
        })
        .sheet(isPresented: $showingCreateSheet) {
            CreateCollectionView()
        }
        .onAppear {
            loadWatchHistory()
        }
    }
    
    private var watchHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Watch History")
                        .font(isTvOS ? .headline : .title2)
                        .fontWeight(.bold)
                        .tvos({ view in
                            view.foregroundColor(.white)
                        }, else: { view in
                            view
                        })
                }
                Spacer()
                Text("\(watchHistoryItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, sectionHorizontalPadding)
            
            if !watchHistoryItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: horizontalCardGap) {
                        ForEach(watchHistoryItems.prefix(20)) { item in
                            WatchHistoryItemCard(item: item)
                        }
                    }
                    .padding(.horizontal, sectionHorizontalPadding)
                }
            } else {
                VStack {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No watch history")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("Start watching to see your history here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Bookmarks")
                        .font(isTvOS ? .headline : .title2)
                        .fontWeight(.bold)
                        .tvos({ view in
                            view.foregroundColor(.white)
                        }, else: { view in
                            view
                        })
                }
                Spacer()
                if let bookmarksCollection = libraryManager.collections.first(where: { $0.name == "Bookmarks" }) {
                    Text("\(bookmarksCollection.items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, sectionHorizontalPadding)
            
            if let bookmarksCollection = libraryManager.collections.first(where: { $0.name == "Bookmarks" }),
               !bookmarksCollection.items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: horizontalCardGap) {
                        // Show oldest bookmarks first so order is predictable
                        ForEach(bookmarksCollection.items.sorted(by: { $0.dateAdded < $1.dateAdded })) { item in
                            NavigationLink(destination: MediaDetailView(searchResult: item.searchResult)) {
                                BookmarkItemCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, sectionHorizontalPadding)
                }
            } else {
                VStack {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No bookmarks yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("Bookmark items to see them here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Collections")
                    .font(isTvOS ? .headline : .title2)
                    .fontWeight(.bold)
                    .tvos({ view in
                        view.foregroundColor(.white)
                    }, else: { view in
                        view
                    })
                Spacer()
                Text("\(libraryManager.collections.filter { $0.name != "Bookmarks" }.count) collections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, sectionHorizontalPadding)
            
            let nonBookmarkCollections = libraryManager.collections.filter { $0.name != "Bookmarks" }
            
            if !nonBookmarkCollections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: isTvOS ? 40 : 16) {
                        ForEach(nonBookmarkCollections) { collection in
                            NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                CollectionCard(collection: collection)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, sectionHorizontalPadding)
                }
            } else {
                VStack {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No collections yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("Create collections to organize your media")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    private func loadWatchHistory() {
        let (movies, episodes) = ProgressManager.shared.getAllProgressItems()
        
        Logger.shared.log("Loading Watch History: \(movies.count) movies, \(episodes.count) episodes", type: "Progress")
        
        var allItems: [WatchHistoryItem] = []
        allItems.append(contentsOf: movies.map { WatchHistoryItem(from: $0) })
        allItems.append(contentsOf: episodes.map { WatchHistoryItem(from: $0) })
        
        // Filter out invalid or non-finite progress entries and clamp
        let validItems = allItems.compactMap { item -> WatchHistoryItem? in
            guard item.progress.isFinite,
                  item.currentTime.isFinite,
                  item.totalDuration.isFinite,
                  item.totalDuration > 0 else { return nil }
            // Return the item as-is since WatchHistoryItem doesn't have a direct initializer
            return item
        }
        
        func groupKey(for item: WatchHistoryItem) -> String {
            switch item.type {
            case .movie:
                return "movie_\(item.tmdbId)"
            case .episode:
                let showId = item.showId ?? item.tmdbId
                return "tv_\(showId)"
            }
        }

        // Group by content, keeping the most recently updated.
        // For episodes, we group by show so the Library history shows one card per series.
        var grouped: [String: WatchHistoryItem] = [:]
        for item in validItems {
            let key = groupKey(for: item)
            if let existing = grouped[key] {
                if item.lastUpdated > existing.lastUpdated {
                    grouped[key] = item
                } else if item.lastUpdated == existing.lastUpdated {
                    // Prefer in-progress over watched when timestamps match
                    if existing.isWatched && !item.isWatched {
                        grouped[key] = item
                    }
                }
            } else {
                grouped[key] = item
            }
        }

        watchHistoryItems = Array(grouped.values)
            .sorted { $0.lastUpdated > $1.lastUpdated }
        
        Logger.shared.log("Total watch history items: \(watchHistoryItems.count)", type: "Progress")
    }
}

struct WatchHistoryItemCard: View {
    let item: WatchHistoryItem
    @State private var searchResult: TMDBSearchResult?
    @FocusState private var isFocused: Bool

    private var posterWidth: CGFloat { isTvOS ? 280 : 120 }
    private var posterHeight: CGFloat { isTvOS ? 380 : 180 }
    private var posterCornerRadius: CGFloat { isTvOS ? 20 : 10 }
    private var infoSpacing: CGFloat { isTvOS ? 10 : 2 }
    private var titleFont: Font { isTvOS ? .callout.weight(.semibold) : .caption.weight(.medium) }
    
    var body: some View {
        Group {
            if let result = searchResult {
                NavigationLink(destination: MediaDetailView(searchResult: result)) {
                    cardContent
                }
            } else {
                cardContent
                    .onAppear {
                        loadMediaDetails()
                    }
            }
        }
        .tvos({ view in
            view
                .buttonStyle(CardButtonStyle())
                .focused($isFocused)
                .scaleEffect(isFocused ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isFocused)
        }, else: { view in
            view.buttonStyle(PlainButtonStyle())
        })
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 8) {
            let safeProgress = item.progress.isFinite ? max(0, min(item.progress, 1)) : 0
            let safeProgressText = "\(Int(safeProgress * 100))%"
            
            ZStack(alignment: .bottomLeading) {
                // Use poster from loaded searchResult, fallback to placeholder
                KFImage(URL(string: searchResult?.fullPosterURL ?? ""))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: item.type == .movie ? "tv" : "tv.and.mediabox")
                                    .tvos({ view in
                                        view.font(.title)
                                    }, else: { view in
                                        view.font(.title2)
                                    })
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .tvos({ view in
                        view
                            .frame(width: posterWidth, height: posterHeight)
                            .clipShape(RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous))
                            .hoverEffect(.highlight)
                            .padding(.vertical, 30)
                    }, else: { view in
                        view
                            .frame(width: posterWidth, height: posterHeight)
                            .clipShape(RoundedRectangle(cornerRadius: posterCornerRadius))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    })
                
                // Progress bar for in-progress items
                if !item.isWatched {
                    VStack {
                        Spacer()
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * safeProgress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(width: posterWidth, height: posterHeight)
                } else {
                    // Watched checkmark overlay
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .tvos({ view in
                                    view.font(.title)
                                }, else: { view in
                                    view.font(.title2)
                                })
                                .foregroundColor(.green)
                                .padding(8)
                        }
                        Spacer()
                    }
                    .frame(width: posterWidth, height: posterHeight)
                }
            }
            
            VStack(alignment: .leading, spacing: infoSpacing) {
                // Display actual show/movie name from TMDB if loaded, otherwise use stored title
                Text(searchResult?.displayTitle ?? item.title)
                    .font(titleFont)
                    .lineLimit(1)
                    .tvos({ view in
                        view.foregroundColor(.white)
                    }, else: { view in
                        view.foregroundColor(.white)
                    })
                
                if let season = item.seasonNumber, let episode = item.episodeNumber {
                    Text("S\(season)E\(episode)")
                        .font(isTvOS ? .callout : .caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if !item.isWatched {
                    Text(safeProgressText)
                        .font(isTvOS ? .callout : .caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Watched")
                        .font(isTvOS ? .callout : .caption2)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
            .frame(width: posterWidth, alignment: .leading)
        }
    }
    
    private func loadMediaDetails() {
        Task {
            do {
                if item.type == .movie {
                    let movie = try await TMDBService.shared.getMovieDetails(id: item.tmdbId)
                    await MainActor.run {
                        searchResult = movie.asSearchResult
                    }
                } else if let showId = item.showId, let seasonNum = item.seasonNumber, let episodeNum = item.episodeNumber {
                    // Fetch TV show details first, then season details
                    let showData = try await TMDBService.shared.getTVShowDetails(id: showId)
                    let season = try await TMDBService.shared.getSeasonDetails(tvShowId: showId, seasonNumber: seasonNum)
                    
                    if let episode = season.episodes.first(where: { $0.episodeNumber == episodeNum }) {
                        // Create a new search result with episode-specific data
                        let baseResult = showData.asSearchResult
                        let episodeResult = TMDBSearchResult(
                            id: baseResult.id,
                            mediaType: baseResult.mediaType,
                            title: baseResult.title,
                            name: baseResult.name,
                            overview: baseResult.overview,
                            posterPath: episode.stillPath ?? baseResult.posterPath,
                            backdropPath: baseResult.backdropPath,
                            releaseDate: baseResult.releaseDate,
                            firstAirDate: baseResult.firstAirDate,
                            voteAverage: baseResult.voteAverage,
                            popularity: baseResult.popularity,
                            adult: baseResult.adult,
                            genreIds: baseResult.genreIds
                        )
                        
                        await MainActor.run {
                            searchResult = episodeResult
                        }
                    } else {
                        await MainActor.run {
                            searchResult = showData.asSearchResult
                        }
                    }
                }
            } catch {
                Logger.shared.log("Failed to load media details for watch history: \(error)", type: "Error")
            }
        }
    }
}

struct BookmarkItemCard: View {
    let item: LibraryItem

    @FocusState private var isFocused: Bool

    private var posterWidth: CGFloat { isTvOS ? 280 : 120 }
    private var posterHeight: CGFloat { isTvOS ? 380 : 180 }
    private var posterCornerRadius: CGFloat { isTvOS ? 20 : 10 }
    
    var body: some View {
        VStack(spacing: 8) {
            KFImage(URL(string: item.searchResult.fullPosterURL ?? ""))
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: item.searchResult.isMovie ? "tv" : "tv.and.mediabox")
                                .tvos({ view in
                                    view.font(.title)
                                }, else: { view in
                                    view.font(.title2)
                                })
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .tvos({ view in
                    view
                        .frame(width: posterWidth, height: posterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: posterCornerRadius, style: .continuous))
                        .hoverEffect(.highlight)
                        .padding(.vertical, 30)
                }, else: { view in
                    view
                        .frame(width: posterWidth, height: posterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: posterCornerRadius))
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                })
            
            Text(item.searchResult.displayTitle)
                .font(isTvOS ? .callout.weight(.semibold) : .caption.weight(.medium))
                .lineLimit(1)
                .foregroundColor(.white)
        }
        .frame(width: posterWidth, alignment: .leading)
        .tvos({ view in
            view
                //.buttonStyle(CardButtonStyle())
                .focused($isFocused)
                .scaleEffect(isFocused ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isFocused)
        }, else: { view in
            view
        })
    }
}

struct CollectionCard: View {
    @ObservedObject var collection: LibraryCollection

    private var previewSize: CGFloat { isTvOS ? 280 : 160 }
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: previewSize, height: previewSize)
                .overlay(
                    collectionPreview
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(spacing: 4) {
                Text(collection.name)
                    .font(isTvOS ? .callout.weight(.semibold) : .caption.weight(.semibold))
                    .lineLimit(1)
                
                Text("\(collection.items.count) items")
                    .font(isTvOS ? .callout : .caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: previewSize)
        }
        .contextMenu {
            if collection.name != "Bookmarks" {
                Button(role: .destructive) {
                    LibraryManager.shared.deleteCollection(collection)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    @MainActor
    private var collectionPreview: some View {
        let recentItems = Array(collection.items.sorted(by: { $0.dateAdded < $1.dateAdded }).suffix(4))
        let cellSpacing: CGFloat = 2
        let cellSize: CGFloat = (previewSize - cellSpacing) / 2
        
        if recentItems.isEmpty {
            VStack {
                Image(systemName: "folder")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Empty")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if recentItems.count == 1 {
            let single = recentItems[0]
            KFImage(URL(string: single.searchResult.fullPosterURL ?? ""))
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: single.searchResult.isMovie ? "tv" : "tv.and.mediabox")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: previewSize, height: previewSize)
                .id(single.id)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 2), spacing: cellSpacing) {
                ForEach(recentItems) { item in
                    KFImage(URL(string: item.searchResult.fullPosterURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: item.searchResult.isMovie ? "tv" : "tv.and.mediabox")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                )
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cellSize, height: cellSize)
                        .clipped()
                        .id(item.id)
                }
                
                ForEach(recentItems.count..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
    }
}

#Preview {
    LibraryView()
}
