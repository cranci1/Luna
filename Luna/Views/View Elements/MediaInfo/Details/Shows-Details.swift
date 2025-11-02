//
//  ShowsDetails.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct TVShowSeasonsSection: View {
    let tvShow: TMDBTVShowWithSeasons?
    @Binding var selectedSeason: TMDBSeason?
    @Binding var seasonDetail: TMDBSeasonDetail?
    @Binding var selectedEpisodeForSearch: TMDBEpisode?
    let tmdbService: TMDBService
    
    @State private var isLoadingSeason = false
    @State private var showingSearchResults = false
    @State private var showingNoServicesAlert = false
    @State private var romajiTitle: String?
    
    @StateObject private var serviceManager = ServiceManager.shared
    @AppStorage("horizontalEpisodeList") private var horizontalEpisodeList: Bool = false
    
    private var isGroupedBySeasons: Bool {
        return tvShow?.seasons.filter { $0.seasonNumber > 0 }.count ?? 0 > 1
    }
    
    private var useSeasonMenu: Bool {
        return UserDefaults.standard.bool(forKey: "seasonMenu")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let tvShow = tvShow {
                Text("Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    if let numberOfSeasons = tvShow.numberOfSeasons, numberOfSeasons > 0 {
                        DetailRow(title: "Seasons", value: "\(numberOfSeasons)")
                    }
                    
                    if let numberOfEpisodes = tvShow.numberOfEpisodes, numberOfEpisodes > 0 {
                        DetailRow(title: "Episodes", value: "\(numberOfEpisodes)")
                    }
                    
                    if !tvShow.genres.isEmpty {
                        DetailRow(title: "Genres", value: tvShow.genres.map { $0.name }.joined(separator: ", "))
                    }
                    
                    if tvShow.voteAverage > 0 {
                        DetailRow(title: "Rating", value: String(format: "%.1f/10", tvShow.voteAverage))
                    }
                    
                    if let ageRating = getAgeRating(from: tvShow.contentRatings) {
                        DetailRow(title: "Age Rating", value: ageRating)
                    }
                    
                    if let firstAirDate = tvShow.firstAirDate, !firstAirDate.isEmpty {
                        DetailRow(title: "First aired", value: "\(firstAirDate)")
                    }
                    
                    if let lastAirDate = tvShow.lastAirDate, !lastAirDate.isEmpty {
                        DetailRow(title: "Last aired", value: "\(lastAirDate)")
                    }
                    
                    if let status = tvShow.status {
                        DetailRow(title: "Status", value: status)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .applyLiquidGlassBackground(cornerRadius: 12)
                
                if !tvShow.seasons.isEmpty {
                    if isGroupedBySeasons && !useSeasonMenu {
                        HStack {
                            Text("Seasons")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        seasonSelectorStyled
                        
                        HStack {
                            Text("Episodes")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    } else {
                        episodesSectionHeader
                    }
                    
                    episodeListSection
                }
            }
        }
        .onAppear {
            if let tvShow = tvShow, let selectedSeason = selectedSeason {
                loadSeasonDetails(tvShowId: tvShow.id, season: selectedSeason)
                Task {
                    let romaji = await tmdbService.getRomajiTitle(for: "tv", id: tvShow.id)
                    await MainActor.run {
                        self.romajiTitle = romaji
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearchResults) {
            ModulesSearchResultsSheet(
                mediaTitle: tvShow?.name ?? "Unknown Show",
                originalTitle: romajiTitle,
                isMovie: false,
                selectedEpisode: selectedEpisodeForSearch,
                tmdbId: tvShow?.id ?? 0
            )
        }
        .alert("No Active Services", isPresented: $showingNoServicesAlert) {
            Button("OK") { }
        } message: {
            Text("You don't have any active services. Please go to the Services tab to download and activate services.")
        }
    }
    
    @ViewBuilder
    private var episodesSectionHeader: some View {
        HStack {
            Text("Episodes")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            if let tvShow = tvShow, isGroupedBySeasons && useSeasonMenu {
                seasonMenu(for: tvShow)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    @ViewBuilder
    private func seasonMenu(for tvShow: TMDBTVShowWithSeasons) -> some View {
        let seasons = tvShow.seasons.filter { $0.seasonNumber > 0 }
        
        if seasons.count > 1 {
            Menu {
                ForEach(seasons) { season in
                    Button(action: {
                        selectedSeason = season
                        loadSeasonDetails(tvShowId: tvShow.id, season: season)
                    }) {
                        HStack {
                            Text(season.name)
                            if selectedSeason?.id == season.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedSeason?.name ?? "Season 1")
                    
                    Image(systemName: "chevron.down")
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private var seasonSelectorStyled: some View {
        if let tvShow = tvShow {
            let seasons = tvShow.seasons.filter { $0.seasonNumber > 0 }
            if seasons.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(seasons) { season in
                            Button(action: {
                                selectedSeason = season
                                loadSeasonDetails(tvShowId: tvShow.id, season: season)
                            }) {
                                VStack(spacing: 8) {
                                    KFImage(URL(string: season.fullPosterURL ?? ""))
                                        .placeholder {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 80, height: 120)
                                                .overlay(
                                                    VStack {
                                                        Image(systemName: "tv")
                                                            .font(.title2)
                                                            .foregroundColor(.white.opacity(0.7))
                                                        Text("S\(season.seasonNumber)")
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                )
                                        }
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fill)
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedSeason?.id == season.id ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                    
                                    Text(season.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 80)
                                        .foregroundColor(selectedSeason?.id == season.id ? .accentColor : .primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private var episodeListSection: some View {
        Group {
            if let seasonDetail = seasonDetail {
                if horizontalEpisodeList {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 15) {
                            ForEach(Array(seasonDetail.episodes.enumerated()), id: \.element.id) { index, episode in
                                createEpisodeCell(episode: episode, index: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 15) {
                        ForEach(Array(seasonDetail.episodes.enumerated()), id: \.element.id) { index, episode in
                            createEpisodeCell(episode: episode, index: index)
                        }
                    }
                    .padding(.horizontal)
                }
            } else if isLoadingSeason {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading episodes...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    @ViewBuilder
    private func createEpisodeCell(episode: TMDBEpisode, index: Int) -> some View {
        if let tvShow = tvShow {
            let progress = ProgressManager.shared.getEpisodeProgress(
                showId: tvShow.id,
                seasonNumber: episode.seasonNumber,
                episodeNumber: episode.episodeNumber
            )
            let isSelected = selectedEpisodeForSearch?.id == episode.id
            
            EpisodeCell(
                episode: episode,
                showId: tvShow.id,
                progress: progress,
                isSelected: isSelected,
                onTap: { episodeTapAction(episode: episode) },
                onMarkWatched: { markAsWatched(episode: episode) },
                onResetProgress: { resetProgress(episode: episode) }
            )
        } else {
            EmptyView()
        }
    }
    
    private func episodeTapAction(episode: TMDBEpisode) {
        selectedEpisodeForSearch = episode
        searchInServicesForEpisode(episode: episode)
    }
    
    private func searchInServicesForEpisode(episode: TMDBEpisode) {
        guard (tvShow?.name) != nil else { return }
        
        if serviceManager.activeServices.isEmpty {
            showingNoServicesAlert = true
            return
        }
        
        showingSearchResults = true
    }
    
    private func markAsWatched(episode: TMDBEpisode) {
        guard let tvShow = tvShow else { return }
        ProgressManager.shared.markEpisodeAsWatched(
            showId: tvShow.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
    
    private func resetProgress(episode: TMDBEpisode) {
        guard let tvShow = tvShow else { return }
        ProgressManager.shared.resetEpisodeProgress(
            showId: tvShow.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
    
    private func loadSeasonDetails(tvShowId: Int, season: TMDBSeason) {
        isLoadingSeason = true
        
        Task {
            do {
                let detail = try await tmdbService.getSeasonDetails(tvShowId: tvShowId, seasonNumber: season.seasonNumber)
                await MainActor.run {
                    self.seasonDetail = detail
                    self.isLoadingSeason = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSeason = false
                }
            }
        }
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
}
