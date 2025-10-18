//
//  MediaDetailView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher
import os

struct MediaDetailView: View {
    let logger = os.Logger(subsystem: "Sora", category: "MediaDetailView")
    
    let searchResult: TMDBSearchResult
    
    @State private var movieDetail: TMDBMovieDetail?
    @State private var tvShowDetail: TMDBTVShowWithSeasons?
    @State private var selectedSeason: TMDBSeason?
    @State private var seasonDetail: TMDBSeasonDetail?
    private let tmdbService = TMDBService.shared
    
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
    @State private var nextEpisodeToWatch: TMDBEpisode?
    @State private var romajiTitle: String?
    
    @State private var progressResetTrigger: UUID = UUID()
    @State private var showingResetConfirmation = false
    
    @StateObject private var serviceManager = ServiceManager.shared
    @ObservedObject private var libraryManager = LibraryManager.shared
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("useSolidBackgroundBehindHero") private var useSolidBackgroundBehindHero = false
    
    private let headerHeight: CGFloat = 550
    private let minHeaderHeight: CGFloat = 400
    
    private var isCompactLayout: Bool {
        return verticalSizeClass == .compact
    }
    
    private var playButtonText: String {
        if searchResult.isMovie {
            return "Play"
        } else if let nextEpisode = nextEpisodeToWatch {
            return "Watch S\(nextEpisode.seasonNumber)E\(nextEpisode.episodeNumber)"
        } else if let selectedEpisode = selectedEpisodeForSearch {
            return "Play S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber)"
        } else {
            return "Play"
        }
    }
    
    var body: some View {
        ZStack {
            Group {
                if useSolidBackgroundBehindHero {
                    Color(.systemBackground)
                } else {
                    ambientColor
                }
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
#if !os(tvOS)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 && abs(value.translation.height) < 50 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
#endif
        .onAppear {
            loadMediaDetails()
            updateBookmarkStatus()
        }
        .onChange(of: progressResetTrigger, perform: { _ in
            updateNextEpisodeToWatch()
        })
        .onChange(of: libraryManager.collections) { _ in
            updateBookmarkStatus()
        }
        .sheet(isPresented: $showingSearchResults, onDismiss: {
            updateNextEpisodeToWatch()
            progressResetTrigger = UUID()
        }) {
            ModulesSearchResultsSheet(
                mediaTitle: searchResult.displayTitle,
                originalTitle: romajiTitle,
                isMovie: searchResult.isMovie,
                selectedEpisode: selectedEpisodeForSearch,
                tmdbId: searchResult.id
            )
        }
        .sheet(isPresented: $showingAddToCollection) {
            AddToCollectionView(searchResult: searchResult)
        }
        .confirmationDialog(
            "Reset Show Progress",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All Episodes", role: .destructive) {
                resetEntireShowProgress()
            }
            Button("Cancel", role: .cancel) { }
        }
        message: {
            Text("Are you sure you want to reset progress for all episodes?")
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
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
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial.opacity(0.9))
                        )
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
                .foregroundColor(.primary)
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
        HStack(spacing: 12) {
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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(serviceManager.activeServices.isEmpty ? Color.gray.opacity(0.3) : Color.black.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(serviceManager.activeServices.isEmpty ? .thinMaterial : .ultraThinMaterial)
                        )
                )
                .foregroundColor(serviceManager.activeServices.isEmpty ? .secondary : .primary)
                .cornerRadius(8)
            }
            .disabled(serviceManager.activeServices.isEmpty)
            
            Button(action: {
                toggleBookmark()
            }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                    )
                    .foregroundColor(isBookmarked ? .yellow : .primary)
                    .cornerRadius(8)
            }
            
            Button(action: {
                showingAddToCollection = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                    )
                    .foregroundColor(.primary)
                    .cornerRadius(8)
            }
            Button(action: {
                showResetConfirmation()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                    )
                    .foregroundColor(.primary)
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
                progressUpdateTrigger: progressResetTrigger,
                updateProgressTrigger: {
                    progressResetTrigger = UUID()
                },
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
    
    private func showResetConfirmation() {
        showingResetConfirmation = true
    }
    
    private func resetEntireShowProgress() {
        if let show = tvShowDetail, show.id > 0 {
            ProgressManager.shared.resetEntireShowProgress(showId: show.id)
            progressResetTrigger = UUID() // This will force views to update
        }
    }
    
    // 2) Prefer the computed "nextEpisodeToWatch" when searching services
    private func searchInServices() {
        if !searchResult.isMovie {
            if let next = nextEpisodeToWatch {
                selectedEpisodeForSearch = next
            } else if let seasonDetail = seasonDetail, !seasonDetail.episodes.isEmpty {
                selectedEpisodeForSearch = seasonDetail.episodes.first
            } else {
                selectedEpisodeForSearch = nil
            }
        } else {
            selectedEpisodeForSearch = nil
        }
        showingSearchResults = true
    }
    
    private func updateNextEpisodeToWatch() {
        guard !searchResult.isMovie, let show = tvShowDetail else {
            nextEpisodeToWatch = nil
            return
        }

        Task {
            let showId = show.id

            if let latest = ProgressManager.shared.getLatestWatchedEpisode(showId: showId) {
                do {
                    // Current season detail
                    let currentSeasonDetail = try await tmdbService.getSeasonDetails(
                        tvShowId: showId,
                        seasonNumber: latest.season
                    )
                    
                    logger.debug("Latest watched episode: S\(latest.season)E\(latest.episode)")

                    // If "before first episode", pick the first episode of this season
                    if latest.episode <= 0 {
                        await MainActor.run {
                            self.nextEpisodeToWatch = currentSeasonDetail.episodes.first
                        }
                        return
                    }

                    // Find next episode in the same season
                    if let idx = currentSeasonDetail.episodes.firstIndex(where: { $0.episodeNumber == latest.episode }),
                       idx + 1 < currentSeasonDetail.episodes.count {
                        let next = currentSeasonDetail.episodes[idx + 1]
                        await MainActor.run {
                            self.nextEpisodeToWatch = next
                        }
                        return
                    }

                    // Move to first episode of next non-special season
                    let orderedSeasons = show.seasons
                        .filter { $0.seasonNumber > 0 }
                        .sorted { $0.seasonNumber < $1.seasonNumber }

                    if let sIdx = orderedSeasons.firstIndex(where: { $0.seasonNumber == latest.season }),
                       sIdx + 1 < orderedSeasons.count {
                        let nextSeasonNumber = orderedSeasons[sIdx + 1].seasonNumber
                        let nextSeasonDetail = try await tmdbService.getSeasonDetails(
                            tvShowId: showId,
                            seasonNumber: nextSeasonNumber
                        )
                        await MainActor.run {
                            self.nextEpisodeToWatch = nextSeasonDetail.episodes.first
                        }
                        return
                    }

                    await MainActor.run { self.nextEpisodeToWatch = nil }
                } catch {
                    await MainActor.run { self.nextEpisodeToWatch = nil }
                }
            } else {
                // No latest watched: pick first episode of first non-special season
                if let firstSeason = show.seasons
                    .filter({ $0.seasonNumber > 0 })
                    .sorted(by: { $0.seasonNumber < $1.seasonNumber })
                    .first {
                    do {
                        let sd = try await tmdbService.getSeasonDetails(
                            tvShowId: showId,
                            seasonNumber: firstSeason.seasonNumber
                        )
                        await MainActor.run { self.nextEpisodeToWatch = sd.episodes.first }
                        return
                    } catch {
                        await MainActor.run { self.nextEpisodeToWatch = nil }
                    }
                } else {
                    await MainActor.run { self.nextEpisodeToWatch = nil }
                }
            }
        }
    }

    private func refreshAfterPlayback() {
        // Notify dependent views (e.g., episodes section) to recompute progress
        progressResetTrigger = UUID()
        updateNextEpisodeToWatch()

        // Optionally reload the currently selected season’s episodes
        if let show = tvShowDetail, let season = selectedSeason {
            Task {
                do {
                    let sd = try await tmdbService.getSeasonDetails(
                        tvShowId: show.id,
                        seasonNumber: season.seasonNumber
                    )
                    await MainActor.run {
                        self.seasonDetail = sd
                    }
                } catch {
                    // Ignore reload errors for now
                }
            }
        }
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
                        if let firstSeason = detail.seasons.first(where: { $0.seasonNumber > 0 }) {
                            self.selectedSeason = firstSeason
                        }
                        self.selectedEpisodeForSearch = nil
                        self.isLoading = false
                    }
                    updateNextEpisodeToWatch()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
}
