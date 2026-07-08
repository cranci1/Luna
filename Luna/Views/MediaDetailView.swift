//
//  MediaDetailView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import AVKit
import Sybau
import SwiftUI
import SoraCore
import Kingfisher

private struct ModuleDetailContext {
    let item: SearchItem
    let service: Service
}

struct MediaDetailView: View {
    let searchResult: TMDBSearchResult
    private let moduleContext: ModuleDetailContext?
    private let preselectedEpisode: TMDBEpisode?
    private let directPlayOnLoad: Bool
    
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
    @State private var logoURL: String?
    @State private var moduleDetails: [MediaItem] = []
    @State private var moduleEpisodes: [EpisodeLink] = []
    @State private var selectedModuleEpisodeIndex: Int = 0
    @State private var moduleStreamError: String?
    @State private var showingModuleStreamError = false
    @State private var isDirectStreaming = false
    @State private var activeJSController: JSController?
    
    @State private var tmdbMatch: TMDBSearchResult?
    @State private var isMatchingTMDB: Bool = false
    @State private var tmdbMatchAttempted: Bool = false
    
    @State private var streamOptions: [StreamOption] = []
    @State private var showingStreamMenu = false
    @State private var pendingSubtitles: [String]?
    @State private var pendingService: Service?
    @State private var pendingStreamURL: String?
    @State private var pendingHeaders: [String: String]?
    @State private var pendingDefaultSubtitle: String?
    @State private var subtitleOptions: [(title: String, url: String)] = []
    @State private var showingSubtitlePicker = false
    
    @StateObject private var serviceManager = ServiceManager.shared
    @ObservedObject private var libraryManager = LibraryManager.shared
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("useSolidBackgroundBehindHero") private var useSolidBackgroundBehindHero = false
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    
    init(searchResult: TMDBSearchResult) {
        self.searchResult = searchResult
        self.moduleContext = nil
        self.preselectedEpisode = nil
        self.directPlayOnLoad = false
    }
    
    init(searchResult: TMDBSearchResult, preselectedEpisode: TMDBEpisode) {
        self.searchResult = searchResult
        self.moduleContext = nil
        self.preselectedEpisode = preselectedEpisode
        self.directPlayOnLoad = true
    }
    
    init(moduleItem: SearchItem, service: Service) {
        self.searchResult = TMDBSearchResult(
            id: abs(moduleItem.href.hashValue),
            mediaType: "tv",
            title: moduleItem.title,
            name: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: nil,
            voteAverage: nil,
            popularity: 0,
            adult: nil,
            genreIds: nil
        )
        self.moduleContext = ModuleDetailContext(item: moduleItem, service: service)
        self.preselectedEpisode = nil
        self.directPlayOnLoad = false
    }
    
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
    
    private var isModuleMode: Bool {
        moduleContext != nil
    }
    
    private var librarySearchResult: TMDBSearchResult {
        tmdbMatch ?? searchResult
    }
    
    private var displayTitle: String {
        if isModuleMode {
            return tvShowDetail?.name ?? movieDetail?.title ?? tmdbMatch?.displayTitle ?? searchResult.displayTitle
        }
        return searchResult.displayTitle
    }
    
    private var isMovieContent: Bool {
        if isModuleMode {
            return moduleEpisodes.isEmpty
        }
        return searchResult.isMovie
    }
    
    private var canPlayModule: Bool {
        if !isModuleMode {
            return !serviceManager.activeServices.isEmpty
        }
        if moduleEpisodes.isEmpty {
            return moduleContext != nil
        }
        return selectedModuleEpisodeIndex >= 0 && selectedModuleEpisodeIndex < moduleEpisodes.count
    }
    
    private var playButtonText: String {
        if isModuleMode {
            if moduleEpisodes.isEmpty {
                return "Play"
            }
            let safeIndex = min(max(selectedModuleEpisodeIndex, 0), max(moduleEpisodes.count - 1, 0))
            let episodeNumber = moduleEpisodes[safeIndex].number
            return "Play Episode \(episodeNumber)"
        }
        
        if searchResult.isMovie {
            return "Play"
        } else if let selectedEpisode = selectedEpisodeForSearch {
            return "Play S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber)"
        } else {
            return "Play"
        }
    }
    
    var body: some View {
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
#if !os(tvOS)
            navigationOverlay
#endif
            
            if isDirectStreaming {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                        Text("Finding stream…")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .navigationBarHidden(true)
#if !os(tvOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    if horizontal > 100 && horizontal > abs(vertical) * 2 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        )
#else
        .onExitCommand {
            presentationMode.wrappedValue.dismiss()
        }
#endif
        .onAppear {
            loadMediaDetails()
            updateBookmarkStatus()
            if let episode = preselectedEpisode {
                selectedEpisodeForSearch = episode
            }
        }
        .onChangeComp(of: isLoading) { _, newValue in
            if !newValue && directPlayOnLoad && !isDirectStreaming {
                isDirectStreaming = true
                directPlayWithFirstService()
            }
        }
        .onChangeComp(of: libraryManager.collections) { _, _ in
            updateBookmarkStatus()
        }
        .onChangeComp(of: tmdbMatch?.id) { _, _ in
            updateBookmarkStatus()
        }
        .sheet(isPresented: $showingSearchResults) {
            ModulesSearchResultsSheet(
                mediaTitle: displayTitle,
                originalTitle: romajiTitle,
                isMovie: isMovieContent,
                selectedEpisode: selectedEpisodeForSearch,
                tmdbId: librarySearchResult.id
            )
        }
        .sheet(isPresented: $showingAddToCollection) {
            AddToCollectionView(searchResult: librarySearchResult)
        }
        .alert("Stream Error", isPresented: $showingModuleStreamError) {
            Button("OK", role: .cancel) {
                moduleStreamError = nil
            }
        } message: {
            Text(moduleStreamError ?? "Failed to start playback")
        }
        .adaptiveConfirmationDialog("Select Server", isPresented: $showingStreamMenu, titleVisibility: .visible) {
            ForEach(streamOptions) { option in
                Button(option.name) {
                    if let service = pendingService {
                        resolveSubtitleSelection(
                            subtitles: pendingSubtitles,
                            defaultSubtitle: option.subtitle,
                            service: service,
                            streamURL: option.url,
                            headers: option.headers
                        )
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose a server to stream from")
        }
        .adaptiveConfirmationDialog("Select Subtitle", isPresented: $showingSubtitlePicker, titleVisibility: .visible) {
            ForEach(subtitleOptions, id: \.url) { option in
                Button(option.title) {
                    showingSubtitlePicker = false
                    if let service = pendingService, let url = pendingStreamURL {
                        playStreamURL(url, service: service, subtitle: option.url, headers: pendingHeaders)
                    }
                }
            }
            Button("No Subtitles") {
                showingSubtitlePicker = false
                if let service = pendingService, let url = pendingStreamURL {
                    playStreamURL(url, service: service, subtitle: nil, headers: pendingHeaders)
                }
            }
            Button("Cancel", role: .cancel) {
                subtitleOptions = []; pendingStreamURL = nil; pendingHeaders = nil
            }
        } message: {
            Text("Choose a subtitle track")
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
                    if isModuleMode {
                        return movieDetail?.fullBackdropURL
                        ?? tvShowDetail?.fullBackdropURL
                        ?? movieDetail?.fullPosterURL
                        ?? tvShowDetail?.fullPosterURL
                        ?? moduleContext?.item.imageUrl
                    }
                    
                    if searchResult.isMovie {
                        return movieDetail?.fullBackdropURL ?? movieDetail?.fullPosterURL
                    } else {
                        return tvShowDetail?.fullBackdropURL ?? tvShowDetail?.fullPosterURL
                    }
                }(),
                isMovie: isMovieContent,
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
                
                if isModuleMode {
                    moduleTMDBDetailsSection
                    moduleDetailsSection
                    episodesSection
                } else if searchResult.isMovie {
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
        VStack(alignment: .center, spacing: 8) {
            if let logoURL = logoURL {
                KFImage(URL(string: logoURL))
                    .placeholder {
                        titleText
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 100)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            } else {
                titleText
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 10)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var titleText: some View {
        Text(displayTitle)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            .frame(maxWidth: .infinity, alignment: .center)
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
            } else if let overview = isMovieContent ? movieDetail?.overview : tvShowDetail?.overview,
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
                    Image(systemName: canPlayModule ? "play.fill" : "exclamationmark.triangle")
                    
                    Text(canPlayModule ? playButtonText : "No Services")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 25)
                .applyLiquidGlassBackground(
                    cornerRadius: 12,
                    fallbackFill: canPlayModule ? Color.black.opacity(0.2) : Color.gray.opacity(0.3),
                    fallbackMaterial: canPlayModule ? .ultraThinMaterial : .thinMaterial,
                    glassTint: canPlayModule ? nil : Color.gray.opacity(0.3)
                )
                .foregroundColor(canPlayModule ? .white : .secondary)
                .cornerRadius(8)
            }
            .disabled(!canPlayModule)
            
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
        if isModuleMode {
            if !moduleEpisodes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Episodes")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Picker("Episode", selection: $selectedModuleEpisodeIndex) {
                        ForEach(Array(moduleEpisodes.enumerated()), id: \.offset) { index, episode in
                            Text("Episode \(episode.number)").tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
                .padding(.horizontal)
            }
        } else if !searchResult.isMovie {
            TVShowSeasonsSection(
                tvShow: tvShowDetail,
                selectedSeason: $selectedSeason,
                seasonDetail: $seasonDetail,
                selectedEpisodeForSearch: $selectedEpisodeForSearch,
                tmdbService: tmdbService
            )
        }
    }
    
    @ViewBuilder
    private var moduleTMDBDetailsSection: some View {
        if let movieDetail {
            MovieDetailsSection(movie: movieDetail)
        } else if let tvShowDetail {
            VStack(alignment: .leading, spacing: 8) {
                Text("Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    if let numberOfSeasons = tvShowDetail.numberOfSeasons, numberOfSeasons > 0 {
                        DetailRow(title: "Seasons", value: "\(numberOfSeasons)")
                    }
                    
                    if let numberOfEpisodes = tvShowDetail.numberOfEpisodes, numberOfEpisodes > 0 {
                        DetailRow(title: "Episodes", value: "\(numberOfEpisodes)")
                    }
                    
                    if !tvShowDetail.genres.isEmpty {
                        DetailRow(title: "Genres", value: tvShowDetail.genres.map { $0.name }.joined(separator: ", "))
                    }
                    
                    if tvShowDetail.voteAverage > 0 {
                        DetailRow(title: "Rating", value: String(format: "%.1f/10", tvShowDetail.voteAverage))
                    }
                    
                    if let firstAirDate = tvShowDetail.firstAirDate, !firstAirDate.isEmpty {
                        DetailRow(title: "First Aired", value: firstAirDate)
                    }
                    
                    if let status = tvShowDetail.status {
                        DetailRow(title: "Status", value: status)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .applyLiquidGlassBackground(cornerRadius: 12)
                .padding(.horizontal)
            }
        } else if isMatchingTMDB {
            HStack(spacing: 8) {
                ProgressView()
                Text("Matching with TMDB…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var moduleDetailsSection: some View {
        if let detail = moduleDetails.first {
            VStack(alignment: .leading, spacing: 8) {
                if !detail.aliases.isEmpty {
                    Text("Aliases: \(detail.aliases)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                if !detail.airdate.isEmpty {
                    Text("Airdate: \(detail.airdate)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func toggleBookmark() {
        withAnimation(.easeInOut(duration: 0.2)) {
            libraryManager.toggleBookmark(for: librarySearchResult)
            updateBookmarkStatus()
        }
    }
    
    private func updateBookmarkStatus() {
        isBookmarked = libraryManager.isBookmarked(librarySearchResult)
    }
    
    private func directPlayWithFirstService() {
        guard let service = serviceManager.activeServices.first else {
            moduleStreamError = "No active services. Please activate a service in the Services tab."
            showingModuleStreamError = true
            isDirectStreaming = false
            return
        }
        
        let episode = selectedEpisodeForSearch ?? preselectedEpisode
        let title = searchResult.displayTitle
        let isMovie = searchResult.isMovie
        
        let jsController = JSController()
        jsController.loadScript(service.jsScript)
        activeJSController = jsController
        
        jsController.fetchJsSearchResults(keyword: title, module: service) { [self] items in
            guard let firstItem = items.first else {
                DispatchQueue.main.async {
                    self.moduleStreamError = "No results found in \(service.metadata.sourceName) for \"\(title)\""
                    self.showingModuleStreamError = true
                    self.isDirectStreaming = false
                }
                return
            }
            
            jsController.fetchDetailsJS(url: firstItem.href) { details, episodes in
                let targetHref: String
                if isMovie || episodes.isEmpty {
                    targetHref = firstItem.href
                } else if let episode = episode {
                    let match = episodes.first { $0.number == episode.episodeNumber } ?? episodes.first
                    targetHref = match?.href ?? firstItem.href
                } else {
                    targetHref = episodes.first?.href ?? firstItem.href
                }
                
                jsController.fetchStreamUrlJS(
                    episodeUrl: targetHref,
                    softsub: service.metadata.softsub ?? false,
                    module: service
                ) { streamResult in
                    Task { @MainActor in
                        self.isDirectStreaming = false
                        self.processStreamResult(
                            streams: streamResult.streams,
                            subtitles: streamResult.subtitles,
                            sources: streamResult.sources,
                            service: service
                        )
                    }
                }
            }
        }
    }
    
    private func searchInServices() {
        if isModuleMode {
            searchInModuleService()
            return
        }
        
        if !searchResult.isMovie {
            if selectedEpisodeForSearch != nil {
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
    
    private func loadMediaDetails() {
        isLoading = true
        errorMessage = nil
        
        if isModuleMode {
            loadModuleDetails()
            return
        }
        
        Task {
            do {
                if searchResult.isMovie {
                    async let detailTask = tmdbService.getMovieDetails(id: searchResult.id)
                    async let imagesTask = tmdbService.getMovieImages(id: searchResult.id, preferredLanguage: selectedLanguage)
                    async let romajiTask = tmdbService.getRomajiTitle(for: "movie", id: searchResult.id)
                    
                    let (detail, images, romaji) = try await (detailTask, imagesTask, romajiTask)
                    
                    await MainActor.run {
                        self.movieDetail = detail
                        self.synopsis = detail.overview ?? ""
                        self.romajiTitle = romaji
                        if let logo = tmdbService.getBestLogo(from: images, preferredLanguage: selectedLanguage) {
                            self.logoURL = logo.fullURL
                        }
                        self.isLoading = false
                    }
                } else {
                    async let detailTask = tmdbService.getTVShowWithSeasons(id: searchResult.id)
                    async let imagesTask = tmdbService.getTVShowImages(id: searchResult.id, preferredLanguage: selectedLanguage)
                    async let romajiTask = tmdbService.getRomajiTitle(for: "tv", id: searchResult.id)
                    
                    let (detail, images, romaji) = try await (detailTask, imagesTask, romajiTask)
                    
                    await MainActor.run {
                        self.tvShowDetail = detail
                        self.synopsis = detail.overview ?? ""
                        self.romajiTitle = romaji
                        if let logo = tmdbService.getBestLogo(from: images, preferredLanguage: selectedLanguage) {
                            self.logoURL = logo.fullURL
                        }
                        if let firstSeason = detail.seasons.first(where: { $0.seasonNumber > 0 }) {
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
    
    private func loadModuleDetails() {
        guard let moduleContext else {
            errorMessage = "Missing module context"
            isLoading = false
            return
        }
        
        let jsController = JSController()
        jsController.loadScript(moduleContext.service.jsScript)
        
        jsController.fetchDetailsJS(url: moduleContext.item.href) { details, episodes in
            DispatchQueue.main.async {
                self.moduleDetails = details
                self.moduleEpisodes = episodes
                self.selectedModuleEpisodeIndex = 0
                if let firstDetail = details.first {
                    self.synopsis = firstDetail.description
                }
                self.isLoading = false
                self.matchTMDBMetadata()
            }
        }
    }
    
    // MARK: - Single-module TMDB matching
    
    private func matchTMDBMetadata() {
        guard let moduleContext, !tmdbMatchAttempted, tmdbMatch == nil else { return }
        tmdbMatchAttempted = true
        isMatchingTMDB = true
        
        let queryTitle = moduleContext.item.title
        let preferMovie = moduleEpisodes.isEmpty
        
        Task {
            let match = await findBestTMDBMatch(title: queryTitle, preferMovie: preferMovie)
            
            guard let match else {
                await MainActor.run { self.isMatchingTMDB = false }
                return
            }
            
            await MainActor.run {
                self.tmdbMatch = match
            }
            
            await loadTMDBMatchDetails(match)
            
            await MainActor.run {
                self.isMatchingTMDB = false
            }
        }
    }
    
    private func findBestTMDBMatch(title: String, preferMovie: Bool) async -> TMDBSearchResult? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        
        guard let results = try? await tmdbService.searchMulti(query: trimmedTitle), !results.isEmpty else {
            return nil
        }
        
        let normalizedQuery = normalizeTitleForMatching(trimmedTitle)
        let sameTypeResults = results.filter { preferMovie ? $0.isMovie : $0.isTVShow }
        let candidates = sameTypeResults.isEmpty ? results : sameTypeResults
        
        if let exactMatch = candidates.first(where: { normalizeTitleForMatching($0.displayTitle) == normalizedQuery }) {
            return exactMatch
        }
        
        if let popularMatch = candidates.sorted(by: { $0.popularity > $1.popularity }).first {
            return popularMatch
        }
        
        return results.sorted(by: { $0.popularity > $1.popularity }).first
    }
    
    private func normalizeTitleForMatching(_ title: String) -> String {
        let lowered = title.lowercased()
        let filteredScalars = lowered.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " "
        }
        let collapsed = String(String.UnicodeScalarView(filteredScalars))
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }
    
    private func loadTMDBMatchDetails(_ match: TMDBSearchResult) async {
        do {
            if match.isMovie {
                async let detailTask = tmdbService.getMovieDetails(id: match.id)
                async let imagesTask = tmdbService.getMovieImages(id: match.id, preferredLanguage: selectedLanguage)
                let (detail, images) = try await (detailTask, imagesTask)
                
                await MainActor.run {
                    self.movieDetail = detail
                    if let overview = detail.overview, !overview.isEmpty {
                        self.synopsis = overview
                    }
                    if let logo = self.tmdbService.getBestLogo(from: images, preferredLanguage: self.selectedLanguage) {
                        self.logoURL = logo.fullURL
                    }
                }
            } else {
                async let detailTask = tmdbService.getTVShowWithSeasons(id: match.id)
                async let imagesTask = tmdbService.getTVShowImages(id: match.id, preferredLanguage: selectedLanguage)
                let (detail, images) = try await (detailTask, imagesTask)
                
                await MainActor.run {
                    self.tvShowDetail = detail
                    if let overview = detail.overview, !overview.isEmpty {
                        self.synopsis = overview
                    }
                    if let logo = self.tmdbService.getBestLogo(from: images, preferredLanguage: self.selectedLanguage) {
                        self.logoURL = logo.fullURL
                    }
                }
            }
        } catch {
            Logger.shared.log("Failed to load matched TMDB details: \(error.localizedDescription)", type: "Warning")
        }
    }
    
    private func searchInModuleService() {
        guard let moduleContext else { return }
        
        isDirectStreaming = true
        let jsController = JSController()
        jsController.loadScript(moduleContext.service.jsScript)
        activeJSController = jsController
        
        if !moduleEpisodes.isEmpty {
            let safeIndex = min(max(selectedModuleEpisodeIndex, 0), moduleEpisodes.count - 1)
            let targetHref = moduleEpisodes[safeIndex].href
            streamFromHref(targetHref, service: moduleContext.service, jsController: jsController)
            return
        }
        
        jsController.fetchDetailsJS(url: moduleContext.item.href) { details, episodes in
            DispatchQueue.main.async {
                let targetHref: String
                if episodes.isEmpty {
                    targetHref = moduleContext.item.href
                } else {
                    self.moduleEpisodes = episodes
                    self.selectedModuleEpisodeIndex = 0
                    targetHref = episodes[0].href
                }
                self.streamFromHref(targetHref, service: moduleContext.service, jsController: jsController)
            }
        }
    }
    
    private func streamFromHref(_ href: String, service: Service, jsController: JSController) {
        jsController.fetchStreamUrlJS(
            episodeUrl: href,
            softsub: service.metadata.softsub ?? false,
            module: service
        ) { streamResult in
            Task { @MainActor in
                self.isDirectStreaming = false
                self.processStreamResult(
                    streams: streamResult.streams,
                    subtitles: streamResult.subtitles,
                    sources: streamResult.sources,
                    service: service
                )
            }
        }
    }
    
    // MARK: - Single module stream proces
    
    @MainActor
    private func processStreamResult(streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?, service: Service) {
        let availableStreams = parseStreamOptions(streams: streams, sources: sources)
        
        if availableStreams.count > 1 {
            streamOptions = availableStreams
            pendingSubtitles = subtitles
            pendingService = service
            showingStreamMenu = true
            return
        }
        
        if let first = availableStreams.first {
            resolveSubtitleSelection(subtitles: subtitles, defaultSubtitle: first.subtitle, service: service, streamURL: first.url, headers: first.headers)
        } else if let single = extractSingleStreamURL(streams: streams, sources: sources) {
            resolveSubtitleSelection(subtitles: subtitles, defaultSubtitle: nil, service: service, streamURL: single.url, headers: single.headers)
        } else {
            moduleStreamError = "No valid stream URL returned. The source may be temporarily unavailable."
            showingModuleStreamError = true
        }
    }
    
    private func parseStreamOptions(streams: [String]?, sources: [[String: Any]]?) -> [StreamOption] {
        var result: [StreamOption] = []
        if let sources = sources, !sources.isEmpty {
            for (idx, source) in sources.enumerated() {
                guard let rawUrl = source["streamUrl"] as? String ?? source["url"] as? String, !rawUrl.isEmpty else { continue }
                let title = (source["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                result.append(StreamOption(
                    name: title?.isEmpty == false ? title! : "Stream \(idx + 1)",
                    url: rawUrl,
                    headers: safeConvertToHeaders(source["headers"]),
                    subtitle: source["subtitle"] as? String
                ))
            }
        } else if let streams = streams, streams.count > 1 {
            var index = 0; var n = 1
            while index < streams.count {
                let entry = streams[index]
                if isStreamURL(entry) {
                    result.append(StreamOption(name: "Stream \(n)", url: entry, headers: nil, subtitle: nil)); n += 1; index += 1
                } else if index + 1 < streams.count, isStreamURL(streams[index + 1]) {
                    result.append(StreamOption(name: entry, url: streams[index + 1], headers: nil, subtitle: nil)); index += 2
                } else { index += 1 }
            }
        }
        return result
    }
    
    private func extractSingleStreamURL(streams: [String]?, sources: [[String: Any]]?) -> (url: String, headers: [String: String]?)? {
        if let src = sources?.first {
            if let u = src["streamUrl"] as? String { return (u, safeConvertToHeaders(src["headers"])) }
            if let u = src["url"] as? String        { return (u, safeConvertToHeaders(src["headers"])) }
        }
        if let streams = streams, !streams.isEmpty {
            return (streams.first(where: { $0.hasPrefix("http") }) ?? streams[0], nil)
        }
        return nil
    }
    
    @MainActor
    private func resolveSubtitleSelection(subtitles: [String]?, defaultSubtitle: String?, service: Service, streamURL: String, headers: [String: String]?) {
        guard let subtitles = subtitles, !subtitles.isEmpty else {
            playStreamURL(streamURL, service: service, subtitle: defaultSubtitle, headers: headers); return
        }
        let options = parseSubtitleOptions(from: subtitles)
        guard options.count > 1 else {
            playStreamURL(streamURL, service: service, subtitle: options.first?.url ?? defaultSubtitle, headers: headers); return
        }
        subtitleOptions = options
        pendingStreamURL = streamURL
        pendingHeaders = headers
        pendingService = service
        pendingDefaultSubtitle = defaultSubtitle
        showingSubtitlePicker = true
    }
    
    private func parseSubtitleOptions(from subtitles: [String]) -> [(title: String, url: String)] {
        var result: [(String, String)] = []; var i = 0; var n = 1
        while i < subtitles.count {
            let e = subtitles[i]
            if isStreamURL(e) { result.append(("Subtitle \(n)", e)); n += 1; i += 1 }
            else if i + 1 < subtitles.count, isStreamURL(subtitles[i + 1]) { result.append((e, subtitles[i + 1])); n += 1; i += 2 }
            else { i += 1 }
        }
        return result
    }
    
    private func isStreamURL(_ s: String) -> Bool { s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") }
    
    private func extractPreferredStream(streams: [String]?, sources: [[String: Any]]?) -> (url: String, headers: [String: String]?)? {
        if let source = sources?.first,
           let url = source["url"] as? String,
           !url.isEmpty {
            return (url, safeConvertToHeaders(source["headers"]))
        }
        
        if let streamUrl = streams?.first,
           !streamUrl.isEmpty {
            return (streamUrl, nil)
        }
        
        return nil
    }
    
    private func currentMediaInfo() -> MediaInfo? {
        if isModuleMode {
            guard let tmdbId = tmdbMatch?.id else { return nil }
            let title = tmdbMatch?.displayTitle ?? displayTitle
            
            if moduleEpisodes.isEmpty {
                return .movie(id: tmdbId, title: title)
            }
            
            let safeIndex = min(max(selectedModuleEpisodeIndex, 0), max(moduleEpisodes.count - 1, 0))
            guard moduleEpisodes.indices.contains(safeIndex) else { return nil }
            let episodeNumber = moduleEpisodes[safeIndex].number
            return .episode(showId: tmdbId, showTitle: title, seasonNumber: 1, episodeNumber: episodeNumber)
        }
        
        if searchResult.isMovie {
            return .movie(id: searchResult.id, title: searchResult.displayTitle)
        } else if let episode = selectedEpisodeForSearch {
            return .episode(showId: searchResult.id, showTitle: searchResult.displayTitle, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
        }
        return nil
    }
    
    private func playStreamURL(_ url: String, service: Service, subtitle: String?, headers: [String: String]?) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard let streamURL = URL(string: url) else {
                Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
                moduleStreamError = "Invalid stream URL. The source returned a malformed URL."
                showingModuleStreamError = true
                return
            }
            
            let externalRaw = UserDefaults.standard.string(forKey: "externalPlayer") ?? ExternalPlayer.none.rawValue
            let external = ExternalPlayer(rawValue: externalRaw) ?? .none
            let schemeUrl = external.schemeURL(for: url)
            
            if let scheme = schemeUrl, UIApplication.shared.canOpenURL(scheme) {
                UIApplication.shared.open(scheme, options: [:], completionHandler: nil)
                Logger.shared.log("Opening external player with scheme: \(scheme)", type: "General")
                return
            }
            
            let serviceURL = service.metadata.baseUrl
            var finalHeaders: [String: String] = [
                "Origin": serviceURL,
                "Referer": serviceURL,
                "User-Agent": URLSession.randomUserAgent
            ]
            
            if let custom = headers {
                for (k, v) in custom {
                    finalHeaders[k] = v
                }
                if finalHeaders["User-Agent"] == nil {
                    finalHeaders["User-Agent"] = URLSession.randomUserAgent
                }
            }
            
            let inAppRaw = UserDefaults.standard.string(forKey: "inAppPlayer") ?? "Normal"
            let inAppPlayer = (inAppRaw == "mpv") ? "mpv" : "Normal"
            
            if inAppPlayer == "mpv" {
                let preset = PlayerPreset.presets.first
                let subtitleArray: [String]? = subtitle.map { [$0] }
                let pvc = PlayerViewController(
                    url: streamURL,
                    preset: preset ?? PlayerPreset(title: displayTitle, summary: "", stream: nil, commands: []),
                    headers: finalHeaders,
                    subtitles: subtitleArray
                )
                if let mediaInfo = currentMediaInfo() {
                    pvc.mediaInfo = mediaInfo
                }
                pvc.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.topmostViewController().present(pvc, animated: true, completion: nil)
                } else {
                    Logger.shared.log("Failed to find root view controller to present MPV player", type: "Error")
                }
                return
            }
            
            let playerVC = NormalPlayer()
            let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": finalHeaders])
            let item = AVPlayerItem(asset: asset)
            playerVC.player = AVPlayer(playerItem: item)
            if let mediaInfo = currentMediaInfo() {
                playerVC.mediaInfo = mediaInfo
            }
            playerVC.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.topmostViewController().present(playerVC, animated: true) {
                    playerVC.player?.play()
                }
            } else {
                playerVC.player?.play()
            }
        }
    }
    
    private func safeConvertToHeaders(_ value: Any?) -> [String: String]? {
        guard let value = value else { return nil }
        if value is NSNull { return nil }
        
        if let headers = value as? [String: String] {
            return headers
        }
        
        if let headersAny = value as? [String: Any] {
            var safeHeaders: [String: String] = [:]
            for (key, val) in headersAny {
                if let stringValue = val as? String {
                    safeHeaders[key] = stringValue
                } else if let numberValue = val as? NSNumber {
                    safeHeaders[key] = numberValue.stringValue
                } else if !(val is NSNull) {
                    safeHeaders[key] = String(describing: val)
                }
            }
            return safeHeaders.isEmpty ? nil : safeHeaders
        }
        
        if let headersAny = value as? [AnyHashable: Any] {
            var safeHeaders: [String: String] = [:]
            for (key, val) in headersAny {
                let stringKey = String(describing: key)
                if let stringValue = val as? String {
                    safeHeaders[stringKey] = stringValue
                } else if let numberValue = val as? NSNumber {
                    safeHeaders[stringKey] = numberValue.stringValue
                } else if !(val is NSNull) {
                    safeHeaders[stringKey] = String(describing: val)
                }
            }
            return safeHeaders.isEmpty ? nil : safeHeaders
        }
        
        return nil
    }
}
