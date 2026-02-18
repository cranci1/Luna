//
//  Shows-tvOS-Details.swift
//  Luna
//
//  Created by TrinityHades on 08/01/26.
//

import Kingfisher
import SwiftUI

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct TVOSDetailsSection: View {
    let tvShow: TMDBTVShowWithSeasons?
    let movie: TMDBMovieDetail?
    let isAnime: Bool = false
    @Binding var selectedSeason: TMDBSeason?
    @Binding var seasonDetail: TMDBSeasonDetail?
    @Binding var selectedEpisodeForSearch: TMDBEpisode?
    var animeEpisodes: [AniListEpisode]? = nil
    var animeSeasonTitles: [Int: String]? = nil
    let tmdbService: TMDBService

    @State private var isLoadingSeason = false
    @State private var showingSearchResults = false
    @State private var showingNoServicesAlert = false
    @State private var showingAddToCollection = false
    @State private var romajiTitle: String?
    @State private var currentSeasonTitle: String?
    @State private var isBookmarked: Bool = false
    @State private var watchedChangeCounter: Int = 0
    @FocusState private var focusedEpisode: Int?
    @FocusState private var focusedSeason: Int?
    @FocusState private var focusedButton: DetailButtonFocus?
    @FocusState private var focusedPersonId: Int?

    @StateObject private var serviceManager = ServiceManager.shared
    @ObservedObject private var libraryManager = LibraryManager.shared

    // Cast & Crew
    @State private var cast: [TMDBCastMember] = []
    @State private var crew: [TMDBCastMember] = []

    enum DetailButtonFocus: Hashable {
        case play
        case bookmark
        case addToList
        case overview
    }

    private let overviewFocusId = "overview-focus"

    private var overviewBorderOpacity: Double {
        focusedButton == .overview ? 0.28 : 0.12
    }

    private func backdropOverlayGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0), location: 0.0),
                .init(color: Color.black.opacity(0.06), location: 0.72),
                .init(color: Color.black.opacity(0.32), location: 0.90),
                .init(color: Color.black, location: 1.0),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func backdropMaskGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white, location: 0.86),
                .init(color: .white.opacity(0.75), location: 0.95),
                .init(color: .clear, location: 1.0),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var overviewText: String? {
        if let tvShow = tvShow {
            return tvShow.overview
        }
        if let movie = movie {
            return movie.overview
        }
        return nil
    }

    private var displayGenres: [TMDBGenre] {
        if let tvShow = tvShow {
            return tvShow.genres
        }
        if let movie = movie {
            return movie.genres
        }
        return []
    }

    private var continueProgressEntry: EpisodeProgressEntry? {
        guard let tvShow else { return nil }

        return ProgressManager.shared.getEpisodesInProgress()
            .filter { $0.showId == tvShow.id }
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
        if movie != nil {
            return "Play"
        } else if let continueEpisode {
            return "Continue S\(continueEpisode.seasonNumber)E\(continueEpisode.episodeNumber)"
        } else if let selectedEpisode = selectedEpisodeForSearch {
            return "Play S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber)"
        }
        return "Play"
    }

    private var displayTitle: String {
        tvShow?.name ?? movie?.title ?? "Unknown"
    }

    private func getSearchTitle() -> String {
        if isAnime, let seasonName = selectedSeason?.name, !seasonName.isEmpty {
            return seasonName
        }
        return tvShow?.name ?? movie?.title ?? "Unknown"
    }

    private var hasActiveServices: Bool {
        !serviceManager.activeServices.isEmpty
    }

    private var shouldShowOriginalTitle: Bool {
        guard let romajiTitle, !romajiTitle.isEmpty else { return false }
        return romajiTitle.localizedCaseInsensitiveCompare(displayTitle) != .orderedSame
    }

    private var bookmarkSearchResult: TMDBSearchResult? {
        if let tvShow = tvShow {
            return TMDBSearchResult(
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
                popularity: tvShow.popularity,
                adult: tvShow.adult,
                genreIds: tvShow.genres.map { $0.id }
            )
        } else if let movie = movie {
            return TMDBSearchResult(
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
                popularity: movie.popularity,
                adult: movie.adult,
                genreIds: movie.genres.map { $0.id }
            )
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            backdropView

            mainContentView
        }
        .background(Color.black)
        .onAppear(perform: handleOnAppear)
        .fullScreenCover(isPresented: $showingSearchResults) {
            ModulesSearchResultsSheet(
                mediaTitle: getSearchTitle(),
                seasonTitleOverride: currentSeasonTitle,
                originalTitle: romajiTitle,
                isMovie: movie != nil,
                selectedEpisode: selectedEpisodeForSearch,
                tmdbId: tvShow?.id ?? movie?.id ?? 0,
                animeSeasonTitle: isAnime ? currentSeasonTitle : nil,
                posterPath: movie?.posterPath ?? tvShow?.posterPath
            )
        }
        .alert("No Active Services", isPresented: $showingNoServicesAlert) {
            Button("OK") {}
        } message: {
            Text(
                "You don't have any active services. Please go to the Services tab to download and activate services."
            )
        }
        .sheet(isPresented: $showingAddToCollection) {
            if let result = bookmarkSearchResult {
                AddToCollectionView(searchResult: result)
            }
        }
    }

    private var backdropView: some View {
        GeometryReader { geometry in
            if let backdropURL = tvShow?.fullBackdropURL ?? movie?.fullBackdropURL {
                KFImage(URL(string: backdropURL))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: 600)
                    .clipped()
                    .overlay(backdropOverlayGradient())
                    .mask(backdropMaskGradient())
            }
        }
        .frame(height: 600)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: [.top, .horizontal])
    }

    private var mainContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 320)

                    if tvShow != nil || movie != nil {
                        heroHeader(proxy: proxy)
                        contentSection(proxy: proxy)
                    }
                }
                .onChange(of: focusedButton) { newValue in
                    guard newValue == .overview else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(overviewFocusId, anchor: .center)
                    }
                }
            }
        }
    }

    private func heroHeader(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .center, spacing: 10) {
                Text(displayTitle)
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 12, x: 0, y: 4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)

                if shouldShowOriginalTitle {
                    Text(romajiTitle ?? "")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                actionButtonsRow
                metadataRow
            }
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 26)
    }

    private func contentSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 30) {
            if !cast.isEmpty || !crew.isEmpty {
                castCrewSection
            }
            twoColumnLayout

            if let tvShow = tvShow, !tvShow.seasons.isEmpty {
                episodesSection(tvShow: tvShow)
            }
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 100)
    }

    private var actionButtonsRow: some View {
        HStack(spacing: 16) {
            playButton
            bookmarkButton
            addToListButton
        }
    }

    private var playButton: some View {
        Button {
            episodeTapAction(
                episode: playTargetEpisode)
        } label: {
            playButtonLabel
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedButton, equals: .play)
        .scaleEffect(focusedButton == .play ? 1.0 : 0.95)
        .shadow(
            color: hasActiveServices ? .black.opacity(0.35) : .white.opacity(0.55),
            radius: focusedButton == .play ? 14 : 0,
            x: 0,
            y: 10
        )
        .animation(.easeOut(duration: 0.14), value: focusedButton == .play)
    }

    @ViewBuilder
    private var playButtonLabel: some View {
        let isFocused = focusedButton == .play

        HStack(spacing: 12) {
            Image(systemName: hasActiveServices ? "play.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.white)

            Text(hasActiveServices ? playButtonText : "No Services")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Spacer(minLength: 0)
        }
        .frame(height: 72)
        .padding(.horizontal, 36)
        .frame(minWidth: 840)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if hasActiveServices {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.14),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.70))
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    hasActiveServices
                        ? Color.black.opacity(isFocused ? 0.18 : 0.08)
                        : Color.white.opacity(isFocused ? 0.38 : 0.18),
                    lineWidth: isFocused ? 3 : 1
                )
        )
        .opacity(hasActiveServices ? 1.0 : 0.92)
    }

    private var bookmarkButton: some View {
        Button {
            toggleBookmark()
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.title2)
                .frame(width: 66, height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.14),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            Color.black.opacity(focusedButton == .bookmark ? 0.18 : 0.08),
                            lineWidth: focusedButton == .bookmark ? 3 : 1
                        )
                )
                .foregroundColor(isBookmarked ? .yellow : .white)
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedButton, equals: .bookmark)
        .scaleEffect(focusedButton == .bookmark ? 1.08 : 1.0)
        .shadow(
            color: .black.opacity(0.25),
            radius: focusedButton == .bookmark ? 16 : 0
        )
        .animation(.easeOut(duration: 0.15), value: focusedButton == .bookmark)
    }

    private var addToListButton: some View {
        Button {
            showingAddToCollection = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .modifier(FontWeightModifier())
                .frame(width: 66, height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.14),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            Color.black.opacity(focusedButton == .addToList ? 0.18 : 0.08),
                            lineWidth: focusedButton == .addToList ? 3 : 1
                        )
                )
                .foregroundColor(.white)
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedButton, equals: .addToList)
        .scaleEffect(focusedButton == .addToList ? 1.08 : 1.0)
        .shadow(color: .black.opacity(0.25), radius: focusedButton == .addToList ? 16 : 0)
        .animation(.easeOut(duration: 0.15), value: focusedButton == .addToList)
    }

    private var metadataRow: some View {
        HStack(spacing: 14) {
            if let tvShow = tvShow {
                tvShowMetadata(tvShow)
            } else if let movie = movie {
                movieMetadata(movie)
            }
        }
    }

    @ViewBuilder
    private func tvShowMetadata(_ tvShow: TMDBTVShowWithSeasons) -> some View {
        // TMDB Rating
        if tvShow.voteAverage > 0 {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.callout)
                Text(String(format: "%.1f", tvShow.voteAverage))
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                if tvShow.voteCount > 0 {
                    Text("(\(formatVoteCount(tvShow.voteCount)))")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }

        // Divider
        if tvShow.voteAverage > 0
            && (tvShow.firstAirDate != nil
                || getAgeRating(from: tvShow.contentRatings) != nil)
        {
            Text("•")
                .font(.callout)
                .foregroundColor(.white.opacity(0.5))
        }

        // Year
        if let firstAirDate = tvShow.firstAirDate, !firstAirDate.isEmpty {
            let year = String(firstAirDate.prefix(4))
            Text(year)
                .font(.callout.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
        }

        // Content Rating
        if let ageRating = getAgeRating(from: tvShow.contentRatings) {
            Text("•")
                .font(.callout)
                .foregroundColor(.white.opacity(0.5))
            Text(ageRating)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private func movieMetadata(_ movie: TMDBMovieDetail) -> some View {
        // TMDB Rating
        if movie.voteAverage > 0 {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.callout)
                Text(String(format: "%.1f", movie.voteAverage))
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                if movie.voteCount > 0 {
                    Text("(\(formatVoteCount(movie.voteCount)))")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }

        // Divider
        if movie.voteAverage > 0
            && (movie.releaseDate != nil
                || getMovieAgeRating(from: movie.releaseDates) != nil)
        {
            Text("•")
                .font(.callout)
                .foregroundColor(.white.opacity(0.5))
        }

        // Year
        if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
            let year = String(releaseDate.prefix(4))
            Text(year)
                .font(.callout.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
        }

        // Runtime
        if let runtime = movie.runtime, runtime > 0 {
            Text("•")
                .font(.callout)
                .foregroundColor(.white.opacity(0.5))
            Text(movie.runtimeFormatted)
                .font(.callout.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
        }

        // Content Rating
        if let ageRating = getMovieAgeRating(from: movie.releaseDates) {
            Text("•")
                .font(.callout)
                .foregroundColor(.white.opacity(0.5))
            Text(ageRating)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var castCrewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cast & Crew")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    if let director = crew.first(where: {
                        ($0.job ?? "").localizedCaseInsensitiveContains(
                            "director")
                    }) {
                        CastBubble(
                            person: director,
                            subtitle: director.job,
                            isFocused: focusedPersonId == director.id
                        )
                        .focused($focusedPersonId, equals: director.id)
                    }

                    ForEach(
                        cast.filter { $0.fullProfileURL != nil }.prefix(10)
                    ) { member in
                        CastBubble(
                            person: member,
                            subtitle: member.character,
                            isFocused: focusedPersonId == member.id
                        )
                        .focused($focusedPersonId, equals: member.id)
                    }
                }
                #if os(tvOS)
                    .focusSection()
                #endif
            }
        }
    }

    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: 50) {
            leftColumn
            rightColumn
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let overview = overviewText, !overview.isEmpty {
                Button(action: {}) {
                    Text(overview)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    Color.white.opacity(overviewBorderOpacity),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(CardButtonStyle())
                .focused($focusedButton, equals: .overview)
                .id(overviewFocusId)
            }

            if !displayGenres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(displayGenres, id: \.id) { genre in
                            Text(genre.name)
                                .font(.caption)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .foregroundColor(.white.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                if let tvShow = tvShow {
                    tvShowDetailInfo(tvShow)
                } else if let movie = movie {
                    movieDetailInfo(movie)
                }
            }
        }
        .frame(
            minWidth: 420, idealWidth: 560, maxWidth: 800,
            alignment: .leading)
    }

    @ViewBuilder
    private func tvShowDetailInfo(_ tvShow: TMDBTVShowWithSeasons) -> some View {
        if let numberOfSeasons = tvShow.numberOfSeasons,
            numberOfSeasons > 0
        {
            TVDetailInfoRow(
                label: "Seasons", value: "\(numberOfSeasons)")
        }

        if let numberOfEpisodes = tvShow.numberOfEpisodes,
            numberOfEpisodes > 0
        {
            TVDetailInfoRow(
                label: "Episodes", value: "\(numberOfEpisodes)")
        }

        if let firstAirDate = tvShow.firstAirDate,
            !firstAirDate.isEmpty
        {
            TVDetailInfoRow(
                label: "First Aired",
                value: formatDate(firstAirDate))
        }

        if let lastAirDate = tvShow.lastAirDate,
            !lastAirDate.isEmpty
        {
            TVDetailInfoRow(
                label: "Last Aired", value: formatDate(lastAirDate))
        }

        if let status = tvShow.status {
            TVDetailInfoRow(label: "Status", value: status)
        }

        if let ageRating = getAgeRating(from: tvShow.contentRatings) {
            TVDetailInfoRow(label: "Rating", value: ageRating)
        }

        // TMDB Rating detailed
        if tvShow.voteAverage > 0 {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TMDB Rating")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .modifier(TrackingModifier(value: 0.5))
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", tvShow.voteAverage))
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                        Text("/10")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func movieDetailInfo(_ movie: TMDBMovieDetail) -> some View {
        if let runtime = movie.runtime, runtime > 0 {
            TVDetailInfoRow(
                label: "Runtime", value: movie.runtimeFormatted)
        }

        if let releaseDate = movie.releaseDate,
            !releaseDate.isEmpty
        {
            TVDetailInfoRow(
                label: "Release Date",
                value: formatDate(releaseDate))
        }

        if let status = movie.status {
            TVDetailInfoRow(label: "Status", value: status)
        }

        if let ageRating = getMovieAgeRating(from: movie.releaseDates) {
            TVDetailInfoRow(label: "Rating", value: ageRating)
        }

        if let tagline = movie.tagline, !tagline.isEmpty {
            TVDetailInfoRow(label: "Tagline", value: tagline)
        }

        // TMDB Rating detailed
        if movie.voteAverage > 0 {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TMDB Rating")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .modifier(TrackingModifier(value: 0.5))
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", movie.voteAverage))
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                        Text("/10")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func episodesSection(tvShow: TMDBTVShowWithSeasons) -> some View {
        Divider()
            .background(Color.white.opacity(0.2))
            .padding(.vertical, 10)

        Text("Episodes")
            .font(.title2.weight(.bold))
            .foregroundColor(.white)

        let seasons = tvShow.seasons.filter { $0.seasonNumber > 0 }
        if seasons.count > 0 {
            seasonSelectorSection(tvShow: tvShow, seasons: seasons)
        }

        if let seasonDetail = seasonDetail, !seasonDetail.episodes.isEmpty {
            episodeGridSection(tvShow: tvShow, seasonDetail: seasonDetail)
        } else if isLoadingSeason {
            loadingEpisodesView
        }
    }

    @ViewBuilder
    private func seasonSelectorSection(tvShow: TMDBTVShowWithSeasons, seasons: [TMDBSeason])
        -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text("Season")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    if isLoadingSeason {
                        ProgressView()
                            .scaleEffect(1.2)
                        MoonPhaseCoreAnimationLoader(iconSize: 30, spacing: 14, stepDuration: 0.3, isAnimating: true)
                    }
                    ForEach(seasons) { season in
                        seasonButton(tvShow: tvShow, season: season)
                    }
                }
                #if os(tvOS)
                    .focusSection()
                #endif
            }
            .frame(height: 420)
        }
    }

    private func seasonButton(tvShow: TMDBTVShowWithSeasons, season: TMDBSeason) -> some View {
        let isSelected = season.id == selectedSeason?.id
        return Button(action: {
            selectedSeason = season
            loadSeasonDetails(
                tvShowId: tvShow.id, season: season)
        }) {
            VStack(alignment: .center, spacing: 12) {
                // Season poster
                KFImage(URL(string: season.fullPosterURL ?? ""))
                    .placeholder {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                    .resizable()
                    .aspectRatio(2 / 3, contentMode: .fill)
                    .frame(width: 180, height: 270)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(alignment: .center, spacing: 6) {
                    Text(season.name)
                        .font(.callout.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if season.episodeCount > 0 {
                        Text("\(season.episodeCount) episodes")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(width: 180)
            }
            .padding(14)
            .background(
                isSelected
                    ? Color.white.opacity(0.15)
                    : Color.white.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        focusedSeason == season.seasonNumber
                            ? Color.white.opacity(0.4)
                            : Color.clear,
                        lineWidth: 3
                    )
            )
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedSeason, equals: season.seasonNumber)
        .animation(.easeOut(duration: 0.15), value: focusedSeason == season.seasonNumber)
    }

    @ViewBuilder
    private func episodeGridSection(tvShow: TMDBTVShowWithSeasons, seasonDetail: TMDBSeasonDetail)
        -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Episodes")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
            }

            let columns = [
                GridItem(
                    .adaptive(minimum: 280, maximum: 360), spacing: 32)
            ]
            LazyVGrid(
                columns: columns, alignment: .leading, spacing: 32
            ) {
                ForEach(seasonDetail.episodes) { episode in
                    episodeCard(tvShow: tvShow, episode: episode)
                }
            }
        }
    }

    private func episodeCard(tvShow: TMDBTVShowWithSeasons, episode: TMDBEpisode) -> some View {
        let _ = watchedChangeCounter
        let progress = ProgressManager.shared
            .getEpisodeProgress(
                showId: tvShow.id,
                seasonNumber: episode.seasonNumber,
                episodeNumber: episode.episodeNumber
            )
        let isWatched = ProgressManager.shared.isEpisodeWatched(
            showId: tvShow.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
        let isSelected =
            selectedEpisodeForSearch?.id == episode.id

        return Button(action: {
            selectedEpisodeForSearch = episode
            episodeTapAction(episode: episode)
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Episode thumbnail
                ZStack(alignment: .bottomLeading) {
                    KFImage(URL(string: episode.fullStillURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Image(systemName: "tv")
                                        .font(.title)
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Progress bar overlay
                    if progress > 0 && progress < ProgressManager.watchedProgressThreshold {
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
                                                width: geo.size.width * progress,
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
                .overlay(alignment: .topTrailing) {
                    if isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Episode \(episode.episodeNumber)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        if let runtime = episode.runtime, runtime > 0 {
                            Text("\(runtime)m")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Text(episode.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                isSelected
                    ? Color.white.opacity(0.15)
                    : Color.white.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        focusedEpisode == episode.episodeNumber
                            ? Color.white.opacity(0.4)
                            : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(CardButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.65)
                .onEnded { _ in
                    ProgressManager.shared.markEpisodeAsWatched(
                        showId: tvShow.id,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    watchedChangeCounter += 1
                }
        )
        .focused($focusedEpisode, equals: episode.episodeNumber)
        .scaleEffect(focusedEpisode == episode.episodeNumber ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: focusedEpisode == episode.episodeNumber)
    }

    private var loadingEpisodesView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading episodes...")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }

    private func handleOnAppear() {
        // Check bookmark status
        if let result = bookmarkSearchResult {
            isBookmarked = libraryManager.isBookmarked(result)
        }

        if let tvShow = tvShow {
            let seasons = tvShow.seasons.filter { $0.seasonNumber > 0 }
            if let continueProgressEntry,
               let continueSeason = seasons.first(where: { $0.seasonNumber == continueProgressEntry.seasonNumber }),
               selectedSeason?.seasonNumber != continueSeason.seasonNumber {
                selectedSeason = continueSeason
            } else if selectedSeason == nil {
                selectedSeason = seasons.first
            }

            if let season = selectedSeason {
                loadSeasonDetails(tvShowId: tvShow.id, season: season)
            }

            Task {
                let romaji = await tmdbService.getRomajiTitle(for: "tv", id: tvShow.id)
                await MainActor.run {
                    self.romajiTitle = romaji
                }

                // Load cast & crew
                await loadTVCredits(tvShowId: tvShow.id)
            }
        } else if let movie = movie {
            Task {
                let romaji = await tmdbService.getRomajiTitle(for: "movie", id: movie.id)
                await MainActor.run {
                    self.romajiTitle = romaji
                }

                // Load cast & crew
                await loadMovieCredits(movieId: movie.id)
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleBookmark() {
        guard let result = bookmarkSearchResult else { return }
        libraryManager.toggleBookmark(for: result)
        isBookmarked = libraryManager.isBookmarked(result)
    }

    private func episodeTapAction(episode: TMDBEpisode?) {
        if movie != nil {
            selectedEpisodeForSearch = nil

            if serviceManager.activeServices.isEmpty {
                showingNoServicesAlert = true
                return
            }

            showingSearchResults = true
            return
        }

        guard tvShow != nil, let episode else { return }
        selectedEpisodeForSearch = episode

        if serviceManager.activeServices.isEmpty {
            showingNoServicesAlert = true
            return
        }

        showingSearchResults = true
    }

    private func loadSeasonDetails(tvShowId: Int, season: TMDBSeason) {
        isLoadingSeason = true
        seasonDetail = nil
        selectedEpisodeForSearch = nil
        currentSeasonTitle = animeSeasonTitles?[season.seasonNumber] ?? season.name

        Task {
            do {
                if isAnime, let animeEpisodes = animeEpisodes {
                    let seasonEpisodes = animeEpisodes.filter { $0.seasonNumber == season.seasonNumber }

                    let tmdbEpisodes: [TMDBEpisode] = seasonEpisodes.map { aniEp in
                        TMDBEpisode(
                            id: tvShowId * 1000 + season.seasonNumber * 100 + aniEp.number,
                            name: aniEp.title,
                            overview: aniEp.description,
                            stillPath: aniEp.stillPath,
                            episodeNumber: aniEp.number,
                            seasonNumber: aniEp.seasonNumber,
                            airDate: aniEp.airDate,
                            runtime: nil,
                            voteAverage: 0,
                            voteCount: 0
                        )
                    }

                    let detail = TMDBSeasonDetail(
                        id: season.id,
                        name: season.name,
                        overview: season.overview ?? "",
                        posterPath: season.posterPath,
                        seasonNumber: season.seasonNumber,
                        airDate: season.airDate,
                        episodes: tmdbEpisodes
                    )

                    await MainActor.run {
                        self.seasonDetail = detail
                        self.isLoadingSeason = false
                        if self.selectedEpisodeForSearch == nil {
                            self.selectedEpisodeForSearch = detail.episodes.first
                        }
                    }
                } else {
                    let detail = try await tmdbService.getSeasonDetails(
                        tvShowId: tvShowId, seasonNumber: season.seasonNumber)
                    await MainActor.run {
                        self.seasonDetail = detail
                        self.isLoadingSeason = false
                        if self.selectedEpisodeForSearch == nil {
                            self.selectedEpisodeForSearch = detail.episodes.first
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSeason = false
                }
            }
        }
    }

    private func loadTVCredits(tvShowId: Int) async {
        do {
            let credits = try await tmdbService.getTVShowCredits(id: tvShowId)
            await MainActor.run {
                self.cast = credits.cast
                self.crew = credits.crew
            }
        } catch {
            print("Failed to load TV credits: \(error)")
        }
    }

    private func loadMovieCredits(movieId: Int) async {
        do {
            let credits = try await tmdbService.getMovieCredits(id: movieId)
            await MainActor.run {
                self.cast = credits.cast
                self.crew = credits.crew
            }
        } catch {
            print("Failed to load movie credits: \(error)")
        }
    }

    private func formatVoteCount(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        }
        return String(count)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func getAgeRating(from contentRatings: TMDBContentRatings?) -> String? {
        guard let contentRatings = contentRatings else { return nil }

        for rating in contentRatings.results {
            if rating.iso31661 == "US" && !rating.rating.isEmpty {
                return rating.rating
            }
        }

        for rating in contentRatings.results {
            if !rating.rating.isEmpty {
                return rating.rating
            }
        }

        return nil
    }

    private func getMovieAgeRating(from releaseDates: TMDBReleaseDates?) -> String? {
        guard let releaseDates = releaseDates else { return nil }

        for result in releaseDates.results {
            if result.iso31661 == "US" {
                for releaseDate in result.releaseDates {
                    if !releaseDate.certification.isEmpty {
                        return releaseDate.certification
                    }
                }
            }
        }

        for result in releaseDates.results {
            for releaseDate in result.releaseDates {
                if !releaseDate.certification.isEmpty {
                    return releaseDate.certification
                }
            }
        }

        return nil
    }
}

// MARK: - TV Detail Info Row Component

struct TVDetailInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .modifier(TrackingModifier(value: 0.5))

            Text(value)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Cast Bubble Component

struct CastBubble: View {
    let person: TMDBCastMember
    let subtitle: String?
    let isFocused: Bool

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 10) {
                KFImage(URL(string: person.fullProfileURL ?? ""))
                    .placeholder {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 160, height: 160)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)

                VStack(spacing: 2) {
                    Text(person.name)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 180)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 180)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isFocused)
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Compatibility View Modifiers

struct FontWeightModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            content.fontWeight(.bold)
        } else {
            content.font(.system(.body).weight(.bold))
        }
    }
}

struct TrackingModifier: ViewModifier {
    let value: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            content.tracking(value)
        } else {
            content // No tracking/kerning support on older versions
        }
    }
}