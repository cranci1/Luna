//
//  MediaDetailView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import AVKit
import Sybau
import SwiftUI
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
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 && abs(value.translation.height) < 50 {
                        presentationMode.wrappedValue.dismiss()
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
            if !isModuleMode {
                updateBookmarkStatus()
            }
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
            if !isModuleMode {
                updateBookmarkStatus()
            }
        }
        .sheet(isPresented: $showingSearchResults) {
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
        .alert("Stream Error", isPresented: $showingModuleStreamError) {
            Button("OK", role: .cancel) {
                moduleStreamError = nil
            }
        } message: {
            Text(moduleStreamError ?? "Failed to start playback")
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
                        return moduleContext?.item.imageUrl
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
        Text(searchResult.displayTitle)
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
            
            if !isModuleMode {
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
        guard !isModuleMode else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            libraryManager.toggleBookmark(for: searchResult)
            updateBookmarkStatus()
        }
    }
    
    private func updateBookmarkStatus() {
        guard !isModuleMode else { return }
        isBookmarked = libraryManager.isBookmarked(searchResult)
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
        
        jsController.fetchJsSearchResults(keyword: title, module: service) { [self] items in
            guard let firstItem = items.first else {
                DispatchQueue.main.async {
                    self.moduleStreamError = "No results found in \(service.sourceName) for \"\(title)\""
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
                    let match = episodes.first {
                        $0.number == episode.episodeNumber
                    } ?? episodes.first
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
                        guard let stream = self.extractPreferredStream(
                            streams: streamResult.streams,
                            sources: streamResult.sources
                        ) else {
                            self.moduleStreamError = "No valid stream returned by \(service.sourceName)"
                            self.showingModuleStreamError = true
                            return
                        }
                        let subtitle = streamResult.subtitles?.first
                        self.playStreamURL(stream.url, service: service, subtitle: subtitle, headers: stream.headers)
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
            }
        }
    }
    
    private func searchInModuleService() {
        guard let moduleContext else { return }
        
        let jsController = JSController()
        jsController.loadScript(moduleContext.service.jsScript)
        
        let targetHref: String
        if moduleEpisodes.isEmpty {
            targetHref = moduleContext.item.href
        } else {
            let safeIndex = min(max(selectedModuleEpisodeIndex, 0), moduleEpisodes.count - 1)
            targetHref = moduleEpisodes[safeIndex].href
        }
        
        jsController.fetchStreamUrlJS(
            episodeUrl: targetHref,
            softsub: moduleContext.service.metadata.softsub ?? false,
            module: moduleContext.service
        ) { streamResult in
            Task { @MainActor in
                guard let stream = self.extractPreferredStream(streams: streamResult.streams, sources: streamResult.sources) else {
                    self.moduleStreamError = "No valid stream returned by this service"
                    self.showingModuleStreamError = true
                    return
                }
                
                let subtitle = streamResult.subtitles?.first
                self.playStreamURL(stream.url, service: moduleContext.service, subtitle: subtitle, headers: stream.headers)
            }
        }
    }
    
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
                    preset: preset ?? PlayerPreset(title: "Default", summary: "", stream: nil, commands: []),
                    headers: finalHeaders,
                    subtitles: subtitleArray
                )
                if !isModuleMode {
                    if searchResult.isMovie {
                        pvc.mediaInfo = .movie(id: searchResult.id, title: searchResult.displayTitle)
                    } else if let episode = selectedEpisodeForSearch {
                        pvc.mediaInfo = .episode(showId: searchResult.id, showTitle: searchResult.displayTitle, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
                    }
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
            if !isModuleMode {
                if searchResult.isMovie {
                    playerVC.mediaInfo = .movie(id: searchResult.id, title: searchResult.displayTitle)
                } else if let episode = selectedEpisodeForSearch {
                    playerVC.mediaInfo = .episode(showId: searchResult.id, showTitle: searchResult.displayTitle, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
                }
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
