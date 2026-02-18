//
//  HomeView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct HomeView: View {
    @State private var showingSettings = false
    @State private var trendingContent: [TMDBSearchResult] = []
    @State private var popularMovies: [TMDBMovie] = []
    @State private var popularTVShows: [TMDBTVShow] = []
    @State private var popularAnime: [TMDBSearchResult] = []
    @State private var topRatedMovies: [TMDBMovie] = []
    @State private var topRatedTVShows: [TMDBTVShow] = []
    @State private var topRatedAnime: [TMDBSearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var heroContent: TMDBSearchResult?
    @State private var ambientColor: Color = Color.black
    @State private var isHoveringWatchNow = false
    @State private var isHoveringWatchlist = false
    
    @State private var hasLoadedContent = false
    @State private var continueWatchingItems: [WatchHistoryItem] = []
    
    @AppStorage("homeSections") private var homeSectionsData: Data = {
        if let data = try? JSONEncoder().encode(HomeSection.defaultSections) {
            return data
        }
        return Data()
    }()
    @AppStorage("animeCatalogSource") private var animeCatalogSource = AnimeCatalogSource.tmdb.rawValue
    
    private var homeSections: [HomeSection] {
        if let sections = try? JSONDecoder().decode([HomeSection].self, from: homeSectionsData) {
            return sections.sorted { $0.order < $1.order }
        }
        return HomeSection.defaultSections
    }
    
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var contentFilter = TMDBContentFilter.shared
    
    private var heroHeight: CGFloat {
#if os(tvOS)
        UIScreen.main.bounds.height * 0.8
#else
        580
#endif
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                homeContent
            }
        } else {
            NavigationView {
                homeContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var homeContent: some View {
        ZStack {
            Group {
                ambientColor
            }
            .ignoresSafeArea(.all)
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else {
                mainScrollView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !hasLoadedContent {
                loadContent()
            }
            // Always reload continue watching when returning to home
            loadContinueWatching()
        }
        .onChangeComp(of: contentFilter.filterHorror) { _, _ in
            if hasLoadedContent {
                loadContent()
            }
        }
        .onChangeComp(of: animeCatalogSource) { _, _ in
            if hasLoadedContent {
                loadContent()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            MoonPhaseCoreAnimationLoader(iconSize: 30, spacing: 14, stepDuration: 0.3, isAnimating: true)
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Connection Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                loadContent()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                heroSection
                contentSections
            }
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }
    
    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            StretchyHeaderView(
                backdropURL: heroContent?.fullBackdropURL ?? heroContent?.fullPosterURL,
                isMovie: heroContent?.isMovie ?? true,
                headerHeight: heroHeight,
                minHeaderHeight: 300,
                onAmbientColorExtracted: { color in
                    ambientColor = color
                }
            )
            
            heroGradientOverlay
            heroContentInfo
        }
    }
    
    @ViewBuilder
    private var heroGradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: ambientColor.opacity(0.0), location: 0.0),
                .init(color: ambientColor.opacity(0.4), location: 0.2),
                .init(color: ambientColor.opacity(0.7), location: 0.6),
                .init(color: ambientColor.opacity(1), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    @ViewBuilder
    private var heroContentInfo: some View {
        if let hero = heroContent {
            VStack(alignment: .center, spacing: isTvOS ? 30 : 12) {
                HStack {
                    Text(hero.isMovie ? "Movie" : "TV Series")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, isTvOS ? 16 : 8)
                        .padding(.vertical, isTvOS ? 10 : 4)
                        .applyLiquidGlassBackground(cornerRadius: 12)
                    
                    if (hero.voteAverage ?? 0.0) > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", hero.voteAverage ?? 0.0))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, isTvOS ? 16 : 8)
                        .padding(.vertical, isTvOS ? 10 : 4)
                        .applyLiquidGlassBackground(cornerRadius: 12)
                    }
                }
                
                Text(hero.displayTitle)
                    .font(.system(size: isTvOS ? 40 : 25))
                    .fontWeight(.bold)
                    .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let overview = hero.overview, !overview.isEmpty {
                    Text(String(overview.prefix(100)) + (overview.count > 100 ? "..." : ""))
                        .font(.system(size: isTvOS ? 30 : 15))
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                HStack(spacing: 16) {
                    NavigationLink(destination: MediaDetailView(searchResult: hero)) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.subheadline)
                            Text("Watch Now")
                                .fontWeight(.semibold)
                                .fixedSize()
                                .lineLimit(1)
                        }
                        .foregroundColor(isHoveringWatchNow ? .black : .white)
                        .tvos({ view in
                            view.frame(width: 200, height: 60)
                                .buttonStyle(PlainButtonStyle())
#if os(tvOS)
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(_): isHoveringWatchNow = true
                                    case .ended: isHoveringWatchNow = false
                                    }
                                }
#endif
                        }, else: { view in
                            view
                                .frame(width: 140, height: 42)
                                .buttonStyle(PlainButtonStyle())
                                .applyLiquidGlassBackground(cornerRadius: 12)
                        })
                    }
                    
                    Button(action: {
                        // TODO: Add to watchlist
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.subheadline)
                            Text("Watchlist")
                                .fontWeight(.semibold)
                                .fixedSize()
                                .lineLimit(1)
                        }
                        .foregroundColor(isHoveringWatchlist ? .black : .white)
                        .tvos({ view in
                            view.frame(width: 200, height: 60)
                                .buttonStyle(PlainButtonStyle())
#if os(tvOS)
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(_): isHoveringWatchlist = true
                                    case .ended: isHoveringWatchlist = false
                                    }
                                }
#endif
                        }, else: { view in
                            view.frame(width: 140, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.3))
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        })
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var contentSections: some View {
        VStack(spacing: 0) {
            // Continue Watching Section
            if !continueWatchingItems.isEmpty {
                ContinueWatchingSection(items: continueWatchingItems)
            }
            
            ForEach(homeSections.filter { $0.isEnabled }) { section in
                switch section.id {
                case "trending":
                    if !trendingContent.isEmpty {
                        let filteredTrending = trendingContent.filter { $0.id != heroContent?.id }
                        MediaSection(
                            title: section.title,
                            items: Array(filteredTrending.prefix(15))
                        )
                    }
                case "popularMovies":
                    if !popularMovies.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: popularMovies.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "popularTVShows":
                    if !popularTVShows.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: popularTVShows.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "popularAnime":
                    if !popularAnime.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: Array(popularAnime.prefix(15))
                        )
                    }
                case "topRatedMovies":
                    if !topRatedMovies.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: topRatedMovies.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "topRatedTVShows":
                    if !topRatedTVShows.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: topRatedTVShows.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "topRatedAnime":
                    if !topRatedAnime.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: Array(topRatedAnime.prefix(15))
                        )
                    }
                default:
                    EmptyView()
                }
            }
            
            Spacer(minLength: 50)
        }
        .background(Color.clear)
    }
    
    private func loadContent() {
        isLoading = true
        errorMessage = nil
        let selectedSource = AnimeCatalogSource(rawValue: animeCatalogSource) ?? .tmdb

        Task.detached(priority: .userInitiated) {
            do {
                async let trending = TMDBService.shared.getTrending()
                async let popularM = TMDBService.shared.getPopularMovies()
                async let popularTV = TMDBService.shared.getPopularTVShows()
                async let popularA = fetchPopularAnime(source: selectedSource)
                async let topRatedM = TMDBService.shared.getTopRatedMovies()
                async let topRatedTV = TMDBService.shared.getTopRatedTVShows()
                async let topRatedA = fetchTopRatedAnime(source: selectedSource)

                let (trendingResult, popularMoviesResult, popularTVResult, popularAnimeResult, topRatedMoviesResult, topRatedTVResult, topRatedAnimeResult) = try await (trending, popularM, popularTV, popularA, topRatedM, topRatedTV, topRatedA)

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.trendingContent = contentFilter.filterSearchResults(trendingResult)
                        self.popularMovies = contentFilter.filterMovies(popularMoviesResult)
                        self.popularTVShows = contentFilter.filterTVShows(popularTVResult)
                        self.popularAnime = contentFilter.filterSearchResults(popularAnimeResult)
                        self.topRatedMovies = contentFilter.filterMovies(topRatedMoviesResult)
                        self.topRatedTVShows = contentFilter.filterTVShows(topRatedTVResult)
                        self.topRatedAnime = contentFilter.filterSearchResults(topRatedAnimeResult)

                        self.heroContent = self.trendingContent.first { $0.backdropPath != nil } ?? self.trendingContent.first
                        self.isLoading = false
                        self.hasLoadedContent = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    Logger.shared.log("Error loading content: \(error)", type: "Error")
                }
            }
        }
    }

    private func fetchPopularAnime(source: AnimeCatalogSource) async throws -> [TMDBSearchResult] {
        switch source {
        case .anilist:
            return try await AniListService.shared.fetchAnimeCatalog(.popular, tmdbService: TMDBService.shared)
        case .tmdb:
            let results = try await TMDBService.shared.getPopularAnime()
            return results.map { $0.asSearchResult }
        }
    }

    private func fetchTopRatedAnime(source: AnimeCatalogSource) async throws -> [TMDBSearchResult] {
        switch source {
        case .anilist:
            return try await AniListService.shared.fetchAnimeCatalog(.topRated, tmdbService: TMDBService.shared)
        case .tmdb:
            let results = try await TMDBService.shared.getTopRatedAnime()
            return results.map { $0.asSearchResult }
        }
    }
    
    private func loadContinueWatching() {
        let moviesInProgress = ProgressManager.shared.getMoviesInProgress()
        let episodesInProgress = ProgressManager.shared.getEpisodesInProgress()
        
        Logger.shared.log("Loading Continue Watching: \(moviesInProgress.count) movies, \(episodesInProgress.count) episodes in progress", type: "Progress")
        
        var allItems: [WatchHistoryItem] = []
        allItems.append(contentsOf: moviesInProgress.map { WatchHistoryItem(from: $0) })
        allItems.append(contentsOf: episodesInProgress.map { WatchHistoryItem(from: $0) })
        
        // Filter out invalid or non-finite progress entries and clamp
        let validItems = allItems.compactMap { item -> WatchHistoryItem? in
            guard item.progress.isFinite,
                  item.currentTime.isFinite,
                  item.totalDuration.isFinite,
                  item.totalDuration > 0 else { return nil }
            let clampedProgress = max(0, min(item.progress, 1))
            return WatchHistoryItem(
                id: item.id,
                type: item.type,
                tmdbId: item.tmdbId,
                title: item.title,
                posterURL: item.posterURL,
                backdropURL: item.backdropURL,
                progress: clampedProgress,
                currentTime: min(max(0, item.currentTime), item.totalDuration),
                totalDuration: item.totalDuration,
                isWatched: item.isWatched,
                lastUpdated: item.lastUpdated,
                showId: item.showId,
                seasonNumber: item.seasonNumber,
                episodeNumber: item.episodeNumber,
                episodeTitle: item.episodeTitle
            )
        }
        
        // Deduplicate by id, keeping the most recently updated
        var unique: [String: WatchHistoryItem] = [:]
        for item in validItems {
            if let existing = unique[item.id] {
                if item.lastUpdated > existing.lastUpdated { unique[item.id] = item }
            } else {
                unique[item.id] = item
            }
        }
        
        let deduped = Array(unique.values)
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(20)
            .map { $0 }
        
        continueWatchingItems = deduped
        Logger.shared.log("Displaying \(continueWatchingItems.count) continue watching items", type: "Progress")
    }
}

struct MediaSection: View {
    let title: String
    let items: [TMDBSearchResult]
    let isLarge: Bool
    
    var gap: Double { isTvOS ? 50.0 : 20.0 }
    
    init(title: String, items: [TMDBSearchResult], isLarge: Bool = Bool.random()) {
        self.title = title
        self.items = items
        self.isLarge = isLarge
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(isTvOS ? .headline : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, isTvOS ? 40 : 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: gap) {
                    ForEach(items) { item in
                        MediaCard(result: item)
                    }
                }
                .padding(.horizontal, isTvOS ? 40 : 16)
            }
            .modifier(ScrollClipModifier())
            .buttonStyle(.borderless)
        }
        .padding(.top, isTvOS ? 40 : 24)
        .opacity(items.isEmpty ? 0 : 1)
    }
}

struct ScrollClipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollClipDisabled()
        } else {
            content
        }
    }
}

struct MediaCard: View {
    let result: TMDBSearchResult
    @State private var isHovering: Bool = false
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)) {
            VStack(alignment: .leading, spacing: 6) {
                KFImage(URL(string: result.fullPosterURL ?? ""))
                    .placeholder {
                        FallbackImageView(
                            isMovie: result.isMovie,
                            size: CGSize(width: 120, height: 180)
                        )
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .tvos({ view in
                        view
                            .frame(width: 280, height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .hoverEffect(.highlight)
                            .modifier(ContinuousHoverModifier(isHovering: $isHovering))
                            .padding(.vertical, 30)
                    }, else: { view in
                        view
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    })
                
                VStack(alignment: .leading, spacing: isTvOS ? 10 : 3) {
                    Text(result.displayTitle)
                        .tvos({ view in
                            view
                                .foregroundColor(isHovering ? .white : .secondary)
                                .fontWeight(.semibold)
                        }, else: { view in
                            view
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        })
                        .font(.caption)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack(alignment: .center, spacing: isTvOS ? 18 : 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", result.voteAverage ?? 0.0))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .fixedSize()
                        }
                            .padding(.horizontal, isTvOS ? 16 : 8)
                            .padding(.vertical, isTvOS ? 10 : 4)
                            .applyLiquidGlassBackground(cornerRadius: 12)

                        Spacer()

                        Text(result.isMovie ? "Movie" : "TV")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, isTvOS ? 16 : 8)
                            .padding(.vertical, isTvOS ? 10 : 4)
                            .applyLiquidGlassBackground(cornerRadius: 12)
                    }
                }
                .frame(width: isTvOS ? 280 : 120, alignment: .leading)
            }
        }
        .tvos({ view in
            view.buttonStyle(BorderlessButtonStyle())
        }, else: { view in
            view.buttonStyle(PlainButtonStyle())
        })
    }
}

struct ContinueWatchingSection: View {
    let items: [WatchHistoryItem]
    
    var gap: Double { isTvOS ? 50.0 : 20.0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Continue Watching")
                    .font(isTvOS ? .headline : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, isTvOS ? 40 : 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: gap) {
                    ForEach(items) { item in
                        ContinueWatchingCard(item: item)
                    }
                }
                .padding(.horizontal, isTvOS ? 40 : 16)
            }
#if os(tvOS)
            .focusSection()
#endif
            .modifier(ScrollClipModifier())
            .buttonStyle(.borderless)
        }
        .padding(.top, isTvOS ? 40 : 24)
    }
}

struct ContinueWatchingCard: View {
    let item: WatchHistoryItem
    @State private var searchResult: TMDBSearchResult?
    @State private var episode: TMDBEpisode?
    @FocusState private var isFocused: Bool

    private var fallbackSearchResult: TMDBSearchResult {
        switch item.type {
        case .movie:
            return TMDBSearchResult(
                id: item.tmdbId,
                mediaType: "movie",
                title: item.title,
                name: nil,
                overview: nil,
                posterPath: nil,
                backdropPath: nil,
                releaseDate: nil,
                firstAirDate: nil,
                voteAverage: 0,
                popularity: 0,
                adult: nil,
                genreIds: []
            )
        case .episode:
            let showId = item.showId ?? item.tmdbId
            return TMDBSearchResult(
                id: showId,
                mediaType: "tv",
                title: nil,
                name: item.title,
                overview: nil,
                posterPath: nil,
                backdropPath: nil,
                releaseDate: nil,
                firstAirDate: nil,
                voteAverage: 0,
                popularity: 0,
                adult: nil,
                genreIds: []
            )
        }
    }

    private var destinationResult: TMDBSearchResult {
        searchResult ?? fallbackSearchResult
    }
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: destinationResult)) {
            cardContent
        }
        .onAppear {
            if searchResult == nil {
                loadMediaDetails()
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
        let safeProgress = item.progress.isFinite ? max(0, min(item.progress, 1)) : 0

        VStack(alignment: .leading, spacing: 10) {
                // Episode thumbnail
                ZStack(alignment: .bottomLeading) {
                    KFImage(URL(string: searchResult?.fullPosterURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Image(systemName: item.type == .movie ? "film" : "tv")
                                        .font(.title)
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .tvos({ view in
                            view.frame(height: 180)
                        }, else: { view in
                            view.frame(height: 120)
                        })
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Progress bar overlay
                        if safeProgress > 0 && safeProgress < ProgressManager.watchedProgressThreshold {
                        VStack {
                            Spacer()
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(
                                                width: geo.size.width * safeProgress,
                                                height: 4
                                            ),
                                        alignment: .leading
                                    )
                            }
                            .frame(height: 4)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Show name and episode info
                    HStack {
                        if let season = item.seasonNumber, let episodeNum = item.episodeNumber {
                            Text("S\(season)E\(episodeNum)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text(item.type == .movie ? "Movie" : "TV Show")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Text("\(Int(safeProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Text(searchResult?.displayTitle ?? item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let episodeName = episode?.name, !episodeName.isEmpty {
                        Text(episodeName)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
        }
        .tvos({ view in
            view
                .frame(width: 320)
                .padding(14)
                .background(Color.white.opacity(isFocused ? 0.15 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.white.opacity(0.4) : Color.clear,
                            lineWidth: 2
                        )
                )
        }, else: { view in
            view
                .frame(width: 280)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        })
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
                    
                    if let ep = season.episodes.first(where: { $0.episodeNumber == episodeNum }) {
                        await MainActor.run {
                            episode = ep
                        }
                        // Create a new search result with episode-specific data
                        let baseResult = showData.asSearchResult
                        let episodeResult = TMDBSearchResult(
                            id: baseResult.id,
                            mediaType: baseResult.mediaType,
                            title: baseResult.title,
                            name: baseResult.name,
                            overview: baseResult.overview,
                            posterPath: ep.stillPath ?? baseResult.posterPath,
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
                Logger.shared.log("Failed to load media details for continue watching: \(error)", type: "Error")
            }
        }
    }
}

struct ContinuousHoverModifier: ViewModifier {
    @Binding var isHovering: Bool
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .onContinuousHover { phase in
                    switch phase {
                    case .active(_):
                        isHovering = true
                    case .ended:
                        isHovering = false
                    }
                }
        } else {
            content
        }
    }
}
