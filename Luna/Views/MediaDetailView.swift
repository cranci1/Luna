//
//  MediaDetailView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct MediaDetailView: View {
    let searchResult: TMDBSearchResult
    
    @StateObject private var tmdbService = TMDBService.shared
    @State private var movieDetail: TMDBMovieDetail?
    @State private var tvShowDetail: TMDBTVShowWithSeasons?
    @State private var selectedSeason: TMDBSeason?
    @State private var seasonDetail: TMDBSeasonDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var ambientColor: Color = Color.black
    @State private var showFullSynopsis: Bool = false
    @State private var selectedEpisodeNumber: Int = 1
    @State private var selectedSeasonIndex: Int = 0
    @State private var synopsis: String = ""
    @State private var isBookmarked: Bool = false
    @State private var showingSearchResults = false
    @State private var showingAddToCollection = false
    @State private var selectedEpisodeForSearch: TMDBEpisode?
    @State private var romajiTitle: String?
    @State private var currentUserActivity: NSUserActivity?
    
    @StateObject private var serviceManager = ServiceManager.shared
    @ObservedObject private var libraryManager = LibraryManager.shared
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("useSolidBackgroundBehindHero") private var useSolidBackgroundBehindHero = false

    private var headerHeight: CGFloat {
#if os(tvOS)
        UIScreen.main.bounds.height * 0.8
#else
        550
#endif
    }


    private var minHeaderHeight: CGFloat {
#if os(tvOS)
        UIScreen.main.bounds.height * 0.8
#else
        400
#endif
    }

    private var isCompactLayout: Bool {
        return verticalSizeClass == .compact
    }

    private var continueProgressEntry: EpisodeProgressEntry? {
        guard let tvShowDetail else { return nil }

        return ProgressManager.shared.getEpisodesInProgress()
            .filter { $0.showId == tvShowDetail.id }
            .sorted {
                if $0.lastUpdated == $1.lastUpdated {
                    return ($0.seasonNumber, $0.episodeNumber) > ($1.seasonNumber, $1.episodeNumber)
                }
                return $0.lastUpdated > $1.lastUpdated
            }
            .first
    }
    
    private var continueEpisode: TMDBEpisode? {
        guard let seasonDetail, !seasonDetail.episodes.isEmpty else { return nil }
        guard let continueProgressEntry else { return nil }
        guard continueProgressEntry.seasonNumber == seasonDetail.seasonNumber else { return nil }

        return seasonDetail.episodes.first(where: {
            $0.seasonNumber == continueProgressEntry.seasonNumber
                && $0.episodeNumber == continueProgressEntry.episodeNumber
        })
    }

    private var playTargetEpisode: TMDBEpisode? {
        continueEpisode ?? selectedEpisodeForSearch ?? seasonDetail?.episodes.first
    }

    private var playButtonText: String {
        if searchResult.isMovie {
            return "Play"
        } else if let continueEpisode = continueEpisode {
            return "Continue S\(continueEpisode.seasonNumber)E\(continueEpisode.episodeNumber)"
        } else if let selectedEpisode = selectedEpisodeForSearch {
            return "Play S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber)"
        } else {
            return "Play"
        }
    }
    
    var body: some View {
#if os(tvOS)
        Group {
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else {
                TVOSDetailsSection(
                    tvShow: tvShowDetail,
                    movie: movieDetail,
                    selectedSeason: $selectedSeason,
                    seasonDetail: $seasonDetail,
                    selectedEpisodeForSearch: $selectedEpisodeForSearch,
                    tmdbService: tmdbService
                )
            }
        }
        .navigationBarHidden(true)
        .tvOSBackButton()
        .onAppear {
            loadMediaDetails()
            updateBookmarkStatus()
        }
        .onChangeComp(of: libraryManager.collections) { _, _ in
            updateBookmarkStatus()
        }
#else
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
            navigationOverlay
        }
        .navigationBarHidden(true)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 && abs(value.translation.height) < 50 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onAppear {
            loadMediaDetails()
            updateBookmarkStatus()
            setupUserActivity()
        }
        .onDisappear {
            invalidateUserActivity()
        }
        .onChangeComp(of: libraryManager.collections) { _, _ in
            updateBookmarkStatus()
        }
        .tvos({ view in
            view.fullScreenCover(isPresented: $showingSearchResults) {
                ModulesSearchResultsSheet(
                    mediaTitle: searchResult.displayTitle,
                    originalTitle: romajiTitle,
                    isMovie: searchResult.isMovie,
                    selectedEpisode: selectedEpisodeForSearch,
                    tmdbId: searchResult.id
                )
            }
        }, else: { view in
            view.sheet(isPresented: $showingSearchResults) {
                ModulesSearchResultsSheet(
                    mediaTitle: searchResult.displayTitle,
                    originalTitle: romajiTitle,
                    isMovie: searchResult.isMovie,
                    selectedEpisode: selectedEpisodeForSearch,
                    tmdbId: searchResult.id
                )
            }
        })
        .sheet(isPresented: $showingAddToCollection) {
            AddToCollectionView(searchResult: searchResult)
        }
#endif
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            MoonPhaseCoreAnimationLoader(iconSize: 30, spacing: 14, stepDuration: 0.3, isAnimating: true)
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .padding(.top)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                loadMediaDetails()
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var navigationOverlay: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .applyLiquidGlassBackground(cornerRadius: 16)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                heroImageSection
                contentContainer
            }
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }
    
    @ViewBuilder
    private var heroImageSection: some View {
        ZStack(alignment: .bottom) {
            StretchyHeaderView(
                backdropURL: {
                    if searchResult.isMovie {
                        return movieDetail?.fullBackdropURL ?? movieDetail?.fullPosterURL
                    } else {
                        return tvShowDetail?.fullBackdropURL ?? tvShowDetail?.fullPosterURL
                    }
                }(),
                isMovie: searchResult.isMovie,
                headerHeight: headerHeight,
                minHeaderHeight: minHeaderHeight,
                onAmbientColorExtracted: { color in
                    ambientColor = color
                }
            )
            
            gradientOverlay
            headerSection
        }
    }
    
    @ViewBuilder
    private var contentContainer: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                synopsisSection
                playAndBookmarkSection
                
                if searchResult.isMovie {
                    MovieDetailsSection(movie: movieDetail)
                } else {
                    episodesSection
                }
                
                Spacer(minLength: 50)
            }
            .background(Color.clear)
        }
    }
    
    @ViewBuilder
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: ambientColor.opacity(0.0), location: 0.0),
                .init(color: ambientColor.opacity(0.4), location: 0.2),
                .init(color: ambientColor.opacity(0.6), location: 0.5),
                .init(color: ambientColor.opacity(1), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(searchResult.displayTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 40)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !synopsis.isEmpty {
                Text(showFullSynopsis ? synopsis : String(synopsis.prefix(180)) + (synopsis.count > 180 ? "..." : ""))
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(showFullSynopsis ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFullSynopsis.toggle()
                        }
                    }
            } else if let overview = searchResult.isMovie ? movieDetail?.overview : tvShowDetail?.overview,
                      !overview.isEmpty {
                Text(showFullSynopsis ? overview : String(overview.prefix(200)) + (overview.count > 200 ? "..." : ""))
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(showFullSynopsis ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFullSynopsis.toggle()
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var playAndBookmarkSection: some View {
        HStack(spacing: 8) {
            Button(action: {
                searchInServices()
            }) {
                HStack {
                    Image(systemName: serviceManager.activeServices.isEmpty ? "exclamationmark.triangle" : "play.fill")
                    
                    Text(serviceManager.activeServices.isEmpty ? "No Services" : playButtonText)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 25)
                .applyLiquidGlassBackground(
                    cornerRadius: 12,
                    fallbackFill: serviceManager.activeServices.isEmpty ? Color.gray.opacity(0.3) : Color.black.opacity(0.2),
                    fallbackMaterial: serviceManager.activeServices.isEmpty ? .thinMaterial : .ultraThinMaterial,
                    glassTint: serviceManager.activeServices.isEmpty ? Color.gray.opacity(0.3) : nil
                )
                .foregroundColor(serviceManager.activeServices.isEmpty ? .secondary : .white)
                .cornerRadius(8)
            }
            .disabled(serviceManager.activeServices.isEmpty)
            
            Button(action: {
                toggleBookmark()
            }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .applyLiquidGlassBackground(cornerRadius: 12)
                    .foregroundColor(isBookmarked ? .yellow : .white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                showingAddToCollection = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .applyLiquidGlassBackground(cornerRadius: 12)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        if !searchResult.isMovie {
            TVShowSeasonsSection(
                tvShow: tvShowDetail,
                selectedSeason: $selectedSeason,
                seasonDetail: $seasonDetail,
                selectedEpisodeForSearch: $selectedEpisodeForSearch,
                tmdbService: tmdbService
            )
        }
    }
    
    private func toggleBookmark() {
        withAnimation(.easeInOut(duration: 0.2)) {
            libraryManager.toggleBookmark(for: searchResult)
            updateBookmarkStatus()
        }
    }
    
    private func updateBookmarkStatus() {
        isBookmarked = libraryManager.isBookmarked(searchResult)
    }
    
    private func searchInServices() {
        // This function will only be called when services are available
        // since the button is disabled when no services are active
        if searchResult.isMovie {
            selectedEpisodeForSearch = nil
        } else {
            if let continueEp = continueEpisode {
                selectedEpisodeForSearch = continueEp
            } else if let seasonDetail = seasonDetail, !seasonDetail.episodes.isEmpty {
                selectedEpisodeForSearch = seasonDetail.episodes.first
            } else {
                selectedEpisodeForSearch = nil
            }
        }
        showingSearchResults = true
    }
    
    private func loadMediaDetails() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if searchResult.isMovie {
                    let detail = try await tmdbService.getMovieDetails(id: searchResult.id)
                    let romaji = await tmdbService.getRomajiTitle(for: "movie", id: searchResult.id)
                    await MainActor.run {
                        self.movieDetail = detail
                        self.synopsis = detail.overview ?? ""
                        self.romajiTitle = romaji
                        self.isLoading = false
                    }
                } else {
                    let detail = try await tmdbService.getTVShowWithSeasons(id: searchResult.id)
                    let romaji = await tmdbService.getRomajiTitle(for: "tv", id: searchResult.id)
                    await MainActor.run {
                        self.tvShowDetail = detail
                        self.synopsis = detail.overview ?? ""
                        self.romajiTitle = romaji
                        if let continueEntry = ProgressManager.shared.getEpisodesInProgress()
                            .filter({ $0.showId == detail.id })
                            .sorted(by: {
                                if $0.lastUpdated == $1.lastUpdated {
                                    return ($0.seasonNumber, $0.episodeNumber) > ($1.seasonNumber, $1.episodeNumber)
                                }
                                return $0.lastUpdated > $1.lastUpdated
                            })
                            .first,
                           let continueSeason = detail.seasons.first(where: { $0.seasonNumber == continueEntry.seasonNumber }) {
                            self.selectedSeason = continueSeason
                        } else if let firstSeason = detail.seasons.first(where: { $0.seasonNumber > 0 }) {
                            self.selectedSeason = firstSeason
                        }
                        self.selectedEpisodeForSearch = nil
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Apple TV App Integration
    private func setupUserActivity() {
        let activity = NSUserActivity(activityType: "com.luna.details")
        
        // Set external media content identifier for TV app integration
        // This allows Siri to add content to Up Next
        let contentId = generateContentIdentifier()
        activity.externalMediaContentIdentifier = contentId
        
        // Set user-friendly title
        activity.title = searchResult.displayTitle
        
        // Enable for search and handoff
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        
        // Add user info for deep linking
        var userInfo: [String: Any] = [
            "tmdbId": searchResult.id,
            "mediaType": searchResult.isMovie ? "movie" : "tv"
        ]
        
        if !searchResult.isMovie, let episode = selectedEpisodeForSearch {
            userInfo["seasonNumber"] = episode.seasonNumber
            userInfo["episodeNumber"] = episode.episodeNumber
        }
        
        activity.userInfo = userInfo
        
        // Make it current
        activity.becomeCurrent()
        
        // Store strong reference
        currentUserActivity = activity
    }
    
    private func invalidateUserActivity() {
        currentUserActivity?.invalidate()
        currentUserActivity = nil
    }
    
    private func generateContentIdentifier() -> String {
        // Generate unique identifier for the content
        if searchResult.isMovie {
            return "movie_\(searchResult.id)"
        } else {
            if let episode = selectedEpisodeForSearch {
                return "tv_\(searchResult.id)_s\(episode.seasonNumber)_e\(episode.episodeNumber)"
            } else {
                return "tv_\(searchResult.id)"
            }
        }
    }
}
