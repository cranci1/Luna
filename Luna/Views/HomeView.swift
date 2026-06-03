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
    @State private var popularAnime: [TMDBTVShow] = []
    @State private var topRatedMovies: [TMDBMovie] = []
    @State private var topRatedTVShows: [TMDBTVShow] = []
    @State private var topRatedAnime: [TMDBTVShow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var heroContent: TMDBSearchResult?
    @State private var ambientColor: Color = Color.black
    @State private var isHoveringWatchNow = false
    @State private var isHoveringWatchlist = false
    
    @State private var hasLoadedContent = false
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @State private var heroLogoURL: String?
    
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    
    @AppStorage("homeSections") private var homeSectionsData: Data = {
        if let data = try? JSONEncoder().encode(HomeSection.defaultSections) {
            return data
        }
        return Data()
    }()
    
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
            } else {
                continueWatchingItems = ProgressManager.shared.getContinueWatchingItems()
            }
        }
        .onChangeComp(of: contentFilter.filterHorror) { _, _ in
            if hasLoadedContent {
                loadContent()
            }
        }
        .onChangeComp(of: contentFilter.filterNSFW) { _, _ in
            if hasLoadedContent {
                loadContent()
            }
        }
        .onChangeComp(of: contentFilter.animeOnlyMode) { _, _ in
            hasLoadedContent = false
            loadContent()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading amazing content...")
                .font(.caption)
                .foregroundColor(.secondary)
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
                continueWatchingSection
                contentSections
            }
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }
    
    @ViewBuilder
    private var continueWatchingSection: some View {
        if !continueWatchingItems.isEmpty {
            ContinueWatchingSection(
                items: continueWatchingItems,
                tmdbService: tmdbService
            )
        }
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
                
                if let heroLogoURL = heroLogoURL {
                    KFImage(URL(string: heroLogoURL))
                        .placeholder {
                            heroTitleText(hero)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: isTvOS ? 400 : 280, maxHeight: isTvOS ? 120 : 80)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                } else {
                    heroTitleText(hero)
                }
                
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
    private func heroTitleText(_ hero: TMDBSearchResult) -> some View {
        Text(hero.displayTitle)
            .font(.system(size: isTvOS ? 40 : 25))
            .fontWeight(.bold)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
            .foregroundColor(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
    }
    
    @ViewBuilder
    private var contentSections: some View {
        VStack(spacing: 0) {
            ForEach(homeSections.filter { $0.isEnabled }) { section in
                if contentFilter.animeOnlyMode && contentFilter.isNonAnimeSection(section.id) {
                    EmptyView()
                } else {
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
                                items: popularAnime.prefix(15).map { $0.asSearchResult }
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
                                items: topRatedAnime.prefix(15).map { $0.asSearchResult }
                            )
                        }
                    default:
                        EmptyView()
                    }
                }
            }
            
            Spacer(minLength: 50)
        }
        .background(Color.clear)
    }
    
    private func loadContent() {
        isLoading = true
        errorMessage = nil
        continueWatchingItems = ProgressManager.shared.getContinueWatchingItems()
        
        Task {
            do {
                if contentFilter.animeOnlyMode {
                    async let popularA = tmdbService.getPopularAnime()
                    async let topRatedA = tmdbService.getTopRatedAnime()
                    
                    let (popularAnimeResult, topRatedAnimeResult) = try await (popularA, topRatedA)
                    
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.trendingContent = []
                            self.popularMovies = []
                            self.popularTVShows = []
                            self.popularAnime = contentFilter.filterTVShows(popularAnimeResult)
                            self.topRatedMovies = []
                            self.topRatedTVShows = []
                            self.topRatedAnime = contentFilter.filterTVShows(topRatedAnimeResult)
                            
                            self.heroContent = self.popularAnime
                                .first { $0.backdropPath != nil }
                                .map { $0.asSearchResult }
                            ?? self.popularAnime.first.map { $0.asSearchResult }
                            
                            self.isLoading = false
                            self.hasLoadedContent = true
                        }
                    }
                } else {
                    async let trending = tmdbService.getTrending()
                    async let popularM = tmdbService.getPopularMovies()
                    async let popularTV = tmdbService.getPopularTVShows()
                    async let popularA = tmdbService.getPopularAnime()
                    async let topRatedM = tmdbService.getTopRatedMovies()
                    async let topRatedTV = tmdbService.getTopRatedTVShows()
                    async let topRatedA = tmdbService.getTopRatedAnime()
                    
                    let (trendingResult, popularMoviesResult, popularTVResult, popularAnimeResult, topRatedMoviesResult, topRatedTVResult, topRatedAnimeResult) = try await (trending, popularM, popularTV, popularA, topRatedM, topRatedTV, topRatedA)
                    
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.trendingContent = contentFilter.filterSearchResults(trendingResult)
                            self.popularMovies = contentFilter.filterMovies(popularMoviesResult)
                            self.popularTVShows = contentFilter.filterTVShows(popularTVResult)
                            self.popularAnime = contentFilter.filterTVShows(popularAnimeResult)
                            self.topRatedMovies = contentFilter.filterMovies(topRatedMoviesResult)
                            self.topRatedTVShows = contentFilter.filterTVShows(topRatedTVResult)
                            self.topRatedAnime = contentFilter.filterTVShows(topRatedAnimeResult)
                            
                            self.heroContent = self.trendingContent.first { $0.backdropPath != nil } ?? self.trendingContent.first
                            self.isLoading = false
                            self.hasLoadedContent = true
                        }
                    }
                }
                
                if let hero = await MainActor.run(body: { self.heroContent }) {
                    await loadHeroLogo(for: hero)
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
    
    private func loadHeroLogo(for hero: TMDBSearchResult) async {
        do {
            let images: TMDBImagesResponse
            if hero.isMovie {
                images = try await tmdbService.getMovieImages(id: hero.id, preferredLanguage: selectedLanguage)
            } else {
                images = try await tmdbService.getTVShowImages(id: hero.id, preferredLanguage: selectedLanguage)
            }
            
            if let logo = tmdbService.getBestLogo(from: images, preferredLanguage: selectedLanguage) {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.heroLogoURL = logo.fullURL
                    }
                }
            }
        } catch {
            Logger.shared.log("Error loading hero logo: \(error)", type: "Warning")
        }
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

// MARK: - Continue Watching Section

struct ContinueWatchingSection: View {
    let items: [ContinueWatchingItem]
    let tmdbService: TMDBService
    
    var gap: Double { isTvOS ? 50.0 : 16.0 }
    
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
                        ContinueWatchingCard(item: item, tmdbService: tmdbService)
                    }
                }
                .padding(.horizontal, isTvOS ? 40 : 16)
            }
            .modifier(ScrollClipModifier())
            .buttonStyle(.borderless)
        }
        .padding(.top, isTvOS ? 40 : 24)
    }
}

struct ContinueWatchingCard: View {
    let item: ContinueWatchingItem
    let tmdbService: TMDBService
    
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    
    @State private var backdropURL: String?
    @State private var logoURL: String?
    @State private var title: String = ""
    @State private var isHovering: Bool = false
    @State private var isLoaded: Bool = false
    @State private var showingSearchResults = false
    
    private var cardWidth: CGFloat { isTvOS ? 380 : 260 }
    private var cardHeight: CGFloat { isTvOS ? 220 : 146 }
    private var logoMaxWidth: CGFloat { isTvOS ? 200 : 140 }
    private var logoMaxHeight: CGFloat { isTvOS ? 60 : 40 }
    
    private var displayTitle: String {
        title.isEmpty ? item.title : title
    }
    
    private var selectedEpisodeForSearch: TMDBEpisode? {
        guard !item.isMovie,
              let seasonNumber = item.seasonNumber,
              let episodeNumber = item.episodeNumber else {
            return nil
        }
        
        return TMDBEpisode(
            id: Int("\(item.tmdbId)\(seasonNumber)\(episodeNumber)") ?? item.tmdbId,
            name: "",
            overview: nil,
            stillPath: nil,
            episodeNumber: episodeNumber,
            seasonNumber: seasonNumber,
            airDate: nil,
            runtime: nil,
            voteAverage: 0,
            voteCount: 0
        )
    }
    
    var body: some View {
        Button {
            showingSearchResults = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    if let backdropURL = backdropURL {
                        KFImage(URL(string: backdropURL))
                            .placeholder {
                                backdropPlaceholder
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        backdropPlaceholder
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
                
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.3), location: 0.4),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: isTvOS ? 10 : 6) {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: isTvOS ? 12 : 8) {
                        if let logoURL = logoURL {
                            KFImage(URL(string: logoURL))
                                .placeholder {
                                    titleText
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: logoMaxWidth, maxHeight: logoMaxHeight, alignment: .leading)
                        } else {
                            titleText
                        }
                        
                        Spacer()
                        
                        if !item.isMovie, let season = item.seasonNumber, let episode = item.episodeNumber {
                            Text("S\(season) E\(episode)")
                                .font(isTvOS ? .subheadline : .caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    HStack(spacing: isTvOS ? 12 : 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: isTvOS ? 6 : 4)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * item.progress, height: isTvOS ? 6 : 4)
                            }
                        }
                        .frame(height: isTvOS ? 6 : 4)
                        
                        Text(item.remainingTime)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize()
                    }
                }
                .padding(isTvOS ? 16 : 12)
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: isTvOS ? 16 : 12))
            .overlay(
                RoundedRectangle(cornerRadius: isTvOS ? 16 : 12)
                    .stroke(Color.white.opacity(isHovering ? 0.5 : 0.2), lineWidth: isHovering ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.3), radius: isHovering ? 12 : 6, x: 0, y: isHovering ? 8 : 4)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .modifier(ContinuousHoverModifier(isHovering: $isHovering))
        }
        .tvos({ view in
            view.buttonStyle(BorderlessButtonStyle())
        }, else: { view in
            view.buttonStyle(PlainButtonStyle())
        })
        .task {
            await loadMediaDetails()
        }
        .sheet(isPresented: $showingSearchResults) {
            ModulesSearchResultsSheet(
                mediaTitle: displayTitle,
                originalTitle: nil,
                isMovie: item.isMovie,
                selectedEpisode: selectedEpisodeForSearch,
                tmdbId: item.tmdbId
            )
        }
    }
    
    @ViewBuilder
    private var titleText: some View {
        Text(title)
            .font(isTvOS ? .title3 : .subheadline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var backdropPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: item.isMovie ? "film" : "tv")
                    .font(isTvOS ? .largeTitle : .title)
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
    
    private func loadMediaDetails() async {
        guard !isLoaded else { return }
        
        do {
            if item.isMovie {
                async let detailsTask = tmdbService.getMovieDetails(id: item.tmdbId)
                async let imagesTask = tmdbService.getMovieImages(id: item.tmdbId, preferredLanguage: selectedLanguage)
                
                let (details, images) = try await (detailsTask, imagesTask)
                
                await MainActor.run {
                    self.title = details.title
                    self.backdropURL = details.fullBackdropURL ?? details.fullPosterURL
                    if let logo = tmdbService.getBestLogo(from: images, preferredLanguage: selectedLanguage) {
                        self.logoURL = logo.fullURL
                    }
                    self.isLoaded = true
                }
            } else {
                async let detailsTask = tmdbService.getTVShowDetails(id: item.tmdbId)
                async let imagesTask = tmdbService.getTVShowImages(id: item.tmdbId, preferredLanguage: selectedLanguage)
                
                let (details, images) = try await (detailsTask, imagesTask)
                
                await MainActor.run {
                    self.title = details.name
                    self.backdropURL = details.fullBackdropURL ?? details.fullPosterURL
                    if let logo = tmdbService.getBestLogo(from: images, preferredLanguage: selectedLanguage) {
                        self.logoURL = logo.fullURL
                    }
                    self.isLoaded = true
                }
            }
        } catch {
            await MainActor.run {
                self.title = item.isMovie ? "Movie" : "TV Show"
                self.isLoaded = true
            }
        }
    }
}
