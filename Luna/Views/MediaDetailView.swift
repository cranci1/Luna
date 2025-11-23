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
                    Color(UIColor.systemBackground)
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
        .onChange(of: libraryManager.collections) { _ in
            updateBookmarkStatus()
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
            VStack(alignment: .leading, spacing: 20) {
                synopsisSection
                playAndBookmarkSection

                if searchResult.isMovie {
                    MovieDetailsSection(movie: movieDetail, useSolidBackground: useSolidBackgroundBehindHero)
                } else {
                    TVShowSeasonsSection(
                        tvShow: tvShowDetail,
                        selectedSeason: $selectedSeason,
                        seasonDetail: $seasonDetail,
                        selectedEpisodeForSearch: $selectedEpisodeForSearch,
                        tmdbService: tmdbService,
                        useSolidBackground: useSolidBackgroundBehindHero
                    )
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
                if showFullSynopsis && synopsis.count > 180 {
                    let attributedString = {
                        let mainColor = useSolidBackgroundBehindHero ? UIColor.label : UIColor.white
                        var attr = AttributedString(synopsis, attributes: AttributeContainer([.foregroundColor: mainColor]))
                        attr.append(AttributedString("\nShow less...", attributes: AttributeContainer([.foregroundColor: UIColor(Color.accentColor)])))
                        return attr
                    }()
                    Text(attributedString)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showFullSynopsis.toggle()
                            }
                        }
                } else {
                    if synopsis.count > 180 {
                        let truncated = String(synopsis.prefix(180))
                        let mainColor = useSolidBackgroundBehindHero ? UIColor.label : UIColor.white
                        let attr = {
                            var a = AttributedString(truncated, attributes: AttributeContainer([.foregroundColor: mainColor]))
                            a.append(AttributedString("\nShow more...", attributes: AttributeContainer([.foregroundColor: UIColor(Color.accentColor)])))
                            return a
                        }()
                        Text(attr)
                            .font(.body)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showFullSynopsis.toggle()
                                }
                            }
                    } else {
                        Text(synopsis)
                            .font(.body)
                            .foregroundColor(useSolidBackgroundBehindHero ? .primary : .white)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .padding(.top, 20)
                    }
                }
            } else if let overview = searchResult.isMovie ? movieDetail?.overview : tvShowDetail?.overview,
                      !overview.isEmpty {
                if showFullSynopsis && overview.count > 200 {
                    let attributedString = {
                        let mainColor = useSolidBackgroundBehindHero ? UIColor.label : UIColor.white
                        var attr = AttributedString(overview, attributes: AttributeContainer([.foregroundColor: mainColor]))
                        attr.append(AttributedString("\nShow less...", attributes: AttributeContainer([.foregroundColor: UIColor(Color.accentColor)])))
                        return attr
                    }()
                    Text(attributedString)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showFullSynopsis.toggle()
                            }
                        }
                } else {
                    if overview.count > 200 {
                        let truncated = String(overview.prefix(200))
                        let mainColor = useSolidBackgroundBehindHero ? UIColor.label : UIColor.white
                        let attr = {
                            var a = AttributedString(truncated, attributes: AttributeContainer([.foregroundColor: mainColor]))
                            a.append(AttributedString("\nShow more...", attributes: AttributeContainer([.foregroundColor: UIColor(Color.accentColor)])))
                            return a
                        }()
                        Text(attr)
                            .font(.body)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showFullSynopsis.toggle()
                                }
                            }
                    } else {
                        Text(overview)
                            .font(.body)
                            .foregroundColor(useSolidBackgroundBehindHero ? .primary : .white)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .padding(.top, 20)
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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
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
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .foregroundColor(isBookmarked ? .yellow : .white)
                    .cornerRadius(8)
            }

            Button(action: {
                // Watchlist action - same as bookmark for now
                toggleBookmark()
            }) {
                Image(systemName: "list.star")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.white)
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
                            .fill(Color.black)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
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
                tmdbService: tmdbService,
                useSolidBackground: useSolidBackgroundBehindHero
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
