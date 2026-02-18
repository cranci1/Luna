//
//  ModulesSearchResultsSheet.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import AVFoundation
import AVKit
import CoreMedia
import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

private struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: Placeholder

    init(_ urlString: String?, @ViewBuilder placeholder: () -> Placeholder) {
        if let urlString, let url = URL(string: urlString) {
            self.url = url
        } else {
            self.url = nil
        }
        self.placeholder = placeholder()
    }

    var body: some View {
#if canImport(Kingfisher)
        KFImage(url)
            .placeholder {
                placeholder
            }
            .resizable()
#else
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable()
            default:
                placeholder
            }
        }
#endif
    }
}

struct StreamOption {
    let id = UUID()
    let name: String
    let url: String
    let headers: [String: String]?
}

struct ModulesSearchResultsSheet: View {
    let mediaTitle: String
    let seasonTitleOverride: String?
    let originalTitle: String?
    let isMovie: Bool
    let selectedEpisode: TMDBEpisode?
    let tmdbId: Int
    let animeSeasonTitle: String?
    let posterPath: String?

    init(
        mediaTitle: String,
        seasonTitleOverride: String? = nil,
        originalTitle: String?,
        isMovie: Bool,
        selectedEpisode: TMDBEpisode?,
        tmdbId: Int,
        animeSeasonTitle: String? = nil,
        posterPath: String? = nil
    ) {
        self.mediaTitle = mediaTitle
        self.seasonTitleOverride = seasonTitleOverride
        self.originalTitle = originalTitle
        self.isMovie = isMovie
        self.selectedEpisode = selectedEpisode
        self.tmdbId = tmdbId
        self.animeSeasonTitle = animeSeasonTitle
        self.posterPath = posterPath
    }
    
    @Environment(\.presentationMode) var presentationMode
    @State private var moduleResults: [(service: Service, results: [SearchItem])] = []
    @State private var selectedResult: SearchItem?
    @State private var showingPlayAlert = false
    @State private var expandedServices: Set<UUID> = []
    @State private var isSearching = true
    @State private var searchedServices: Set<UUID> = []
    @State private var failedServices: Set<UUID> = []
    @State private var totalServicesCount = 0
    @State private var player: AVPlayer?
    @State private var playerViewController: NormalPlayer?
    @State private var streamOptions: [StreamOption] = []
    @State private var pendingSubtitles: [String]?
    @State private var pendingService: Service?
    @State private var showingStreamMenu = false
    @State private var isFetchingStreams = false
    @State private var currentFetchingTitle = ""
    @State private var streamFetchProgress = ""
    @State private var activeStreamFetchToken: UUID? = nil
    @State private var showingStreamError = false
    @State private var streamErrorMessage = ""
    @State private var showingAlgorithmPicker = false
    @State private var showingFilterEditor = false
    @State private var highQualityThreshold: Double = 0.9
    @State private var showingSeasonPicker = false
    @State private var showingEpisodePicker = false
    @State private var availableSeasons: [[EpisodeLink]] = []
    @State private var selectedSeasonIndex = 0
    @State private var pendingEpisodes: [EpisodeLink] = []
    @State private var pendingResult: SearchItem?
    @State private var pendingJSController: JSController?
    @State private var activeStreamJSController: JSController? = nil
    
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var algorithmManager = AlgorithmManager.shared

    private static let rfc3986AllowedURLCharacters: CharacterSet = {
        // RFC 3986 reserved + unreserved characters.
        // Keep '%' to preserve already-encoded URLs.
        CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%")
    }()

    private var tvSheetWidth: CGFloat { 1200 }
    private var tvSheetHeight: CGFloat { 820 }
    
    private var servicesWithResults: [(service: Service, results: [SearchItem])] {
        moduleResults.filter { !$0.results.isEmpty }
    }
    
    private var shouldShowOriginalTitle: Bool {
        guard let originalTitle = originalTitle else { return false }
        return !originalTitle.isEmpty && originalTitle.lowercased() != effectiveTitle.lowercased()
    }

    private var effectiveTitle: String { seasonTitleOverride ?? mediaTitle }

    private var animeEffectiveTitle: String {
        guard animeSeasonTitle != nil else { return effectiveTitle }
        let stripped = effectiveTitle
            .replacingOccurrences(of: "(?i)season\\s+\\d+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? effectiveTitle : stripped
    }
    
    private var displayTitle: String {
        if let episode = selectedEpisode {
            if animeSeasonTitle != nil {
                return "\(animeEffectiveTitle) E\(episode.episodeNumber)"
            }
            return "\(effectiveTitle) S\(episode.seasonNumber)E\(episode.episodeNumber)"
        }
        return effectiveTitle
    }
    
    private var episodeSeasonInfo: String {
        if let episode = selectedEpisode {
            if animeSeasonTitle != nil {
                return "E\(episode.episodeNumber)"
            }
            return "S\(episode.seasonNumber)E\(episode.episodeNumber)"
        }
        return ""
    }
    
    private var mediaTypeText: String {
        return isMovie ? "Movie" : "TV Show"
    }
    
    private var mediaTypeColor: Color {
        return isMovie ? .purple : .green
    }
    
    private var searchStatusText: String {
        if isSearching {
            return "Searching... (\(searchedServices.count)/\(totalServicesCount))"
        } else {
            return "Search complete"
        }
    }
    
    private var searchStatusColor: Color {
        return isSearching ? .secondary : .green
    }
    
    private func lowerQualityResultsText(count: Int) -> String {
        let plural = count == 1 ? "" : "s"
        let threshold = Int(highQualityThreshold * 100)
        return "\(count) lower quality result\(plural) (<\(threshold)%)"
    }
    
    @ViewBuilder
    private var searchInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Searching for:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(displayTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let episode = selectedEpisode, !episode.name.isEmpty {
                    HStack {
                        Text(episode.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(episodeSeasonInfo)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .cornerRadius(8)
                    }
                }
                
                statusBar
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var statusBar: some View {
        HStack {
            Text(mediaTypeText)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(mediaTypeColor.opacity(0.2))
                .foregroundColor(mediaTypeColor)
                .cornerRadius(8)
            
            Spacer()
            
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(searchStatusText)
                        .font(.caption)
                        .foregroundColor(searchStatusColor)
                }
            } else {
                Text(searchStatusText)
                    .font(.caption)
                    .foregroundColor(searchStatusColor)
            }
        }
    }
    
    @ViewBuilder
    private var noActiveServicesSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("No Active Services")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("You don't have any active services. Please go to the Services tab to download and activate services.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var servicesResultsSection: some View {
        ForEach(Array(serviceManager.activeServices.enumerated()), id: \.element.id) { index, service in
            serviceSection(service: service)
        }
    }
    
    @ViewBuilder
    private func serviceSection(service: Service) -> some View {
        let moduleResult = moduleResults.first { $0.service.id == service.id }
        let hasSearched = searchedServices.contains(service.id)
        let isCurrentlySearching = isSearching && !hasSearched
        
        if let result = moduleResult {
            let filteredResults = filterResults(for: result.results)
            
            Section(header: serviceHeader(for: service, highQualityCount: filteredResults.highQuality.count, lowQualityCount: filteredResults.lowQuality.count, isSearching: false)) {
                if result.results.isEmpty {
                    noResultsRow
                } else {
                    serviceResultsContent(filteredResults: filteredResults, service: service)
                }
            }
        } else if isCurrentlySearching {
            Section(header: serviceHeader(for: service, highQualityCount: 0, lowQualityCount: 0, isSearching: true)) {
                searchingRow
            }
        } else if !isSearching && !hasSearched {
            Section(header: serviceHeader(for: service, highQualityCount: 0, lowQualityCount: 0, isSearching: false)) {
                notSearchedRow
            }
        }
    }
    
    @ViewBuilder
    private var noResultsRow: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("No results found")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var searchingRow: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Searching...")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var notSearchedRow: some View {
        HStack {
            Image(systemName: "minus.circle")
                .foregroundColor(.gray)
            Text("Not searched")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func serviceResultsContent(filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]), service: Service) -> some View {
        ForEach(filteredResults.highQuality, id: \.id) { searchResult in
            EnhancedMediaResultRow(
                result: searchResult,
                originalTitle: mediaTitle,
                alternativeTitle: originalTitle,
                episode: selectedEpisode,
                onTap: {
                    selectedResult = searchResult
                    showingPlayAlert = true
                }, highQualityThreshold: highQualityThreshold
            )
        }
        
        if !filteredResults.lowQuality.isEmpty {
            lowQualityResultsSection(filteredResults: filteredResults, service: service)
        }
    }
    
    @ViewBuilder
    private func lowQualityResultsSection(filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]), service: Service) -> some View {
        let isExpanded = expandedServices.contains(service.id)
        
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                if isExpanded {
                    expandedServices.remove(service.id)
                } else {
                    expandedServices.insert(service.id)
                }
            }
        }) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
                
                Text(lowerQualityResultsText(count: filteredResults.lowQuality.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        
        if isExpanded {
            ForEach(filteredResults.lowQuality, id: \.id) { searchResult in
                CompactMediaResultRow(
                    result: searchResult,
                    originalTitle: mediaTitle,
                    alternativeTitle: originalTitle,
                    episode: selectedEpisode,
                    onTap: {
                        selectedResult = searchResult
                        showingPlayAlert = true
                    }, highQualityThreshold: highQualityThreshold
                )
            }
        }
    }
    
    @ViewBuilder
    private var playAlertButtons: some View {
        Button("Play") {
            showingPlayAlert = false
            if let result = selectedResult {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    playContent(result)
                }
            }
        }
        Button("Cancel", role: .cancel) {
            showingPlayAlert = false
            selectedResult = nil
        }
    }
    
    @ViewBuilder
    private var playAlertMessage: some View {
        if let result = selectedResult, let episode = selectedEpisode {
            Text("Play Episode \(episode.episodeNumber) of '\(result.title)'?")
        } else if let result = selectedResult {
            Text("Play '\(result.title)'?")
        }
    }
    
    @ViewBuilder
    private var streamFetchingOverlay: some View {
        Group {
            if isFetchingStreams {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 8) {
                            Text("Fetching Streams")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(currentFetchingTitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            if !streamFetchProgress.isEmpty {
                                Text(streamFetchProgress)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(30)
                    .applyLiquidGlassBackground(cornerRadius: 16)
                    .padding(.horizontal, 40)
                }
            }
        }
    }
    
    @ViewBuilder
    private var qualityThresholdAlertContent: some View {
        TextField("Threshold (0.0 - 1.0)", value: $highQualityThreshold, format: .number)
            .keyboardType(.decimalPad)
        
        Button("Save") {
            highQualityThreshold = max(0.0, min(1.0, highQualityThreshold))
            UserDefaults.standard.set(highQualityThreshold, forKey: "highQualityThreshold")
        }
        
        Button("Cancel", role: .cancel) {
            highQualityThreshold = UserDefaults.standard.object(forKey: "highQualityThreshold") as? Double ?? 0.9
        }
    }
    
    @ViewBuilder
    private var qualityThresholdAlertMessage: some View {
        Text("Set the minimum similarity score (0.0 to 1.0) for results to be considered high quality. Current: \(String(format: "%.2f", highQualityThreshold)) (\(Int(highQualityThreshold * 100))%)")
    }
    
    @ViewBuilder
    private var serverSelectionDialogContent: some View {
        ForEach(Array(streamOptions.enumerated()), id: \.element.id) { index, option in
            Button(option.name) {
                if let service = pendingService {
                    playStreamURL(option.url, service: service, subtitles: pendingSubtitles, headers: option.headers)
                }
            }
        }
        Button("Cancel", role: .cancel) { }
    }
    
    @ViewBuilder
    private var serverSelectionDialogMessage: some View {
        Text("Choose a server to stream from")
    }
    
    @ViewBuilder
    private var seasonPickerDialogContent: some View {
        ForEach(Array(availableSeasons.enumerated()), id: \.offset) { index, season in
            Button("Season \(index + 1) (\(season.count) episodes)") {
                selectedSeasonIndex = index
                pendingEpisodes = season
                showingSeasonPicker = false
                showingEpisodePicker = true
            }
        }
        Button("Cancel", role: .cancel) {
            resetPickerState()
        }
    }
    
    @ViewBuilder
    private var seasonPickerDialogMessage: some View {
        Text("Season \(selectedEpisode?.seasonNumber ?? 1) not found. Please choose the correct season:")
    }
    
    @ViewBuilder
    private var episodePickerDialogContent: some View {
        ForEach(pendingEpisodes, id: \.href) { episode in
            Button("Episode \(episode.number)") {
                proceedWithSelectedEpisode(episode)
            }
        }
        Button("Cancel", role: .cancel) {
            resetPickerState()
        }
    }
    
    @ViewBuilder
    private var episodePickerDialogMessage: some View {
        if let episode = selectedEpisode {
            Text("Choose the correct episode for S\(episode.seasonNumber)E\(episode.episodeNumber):")
        } else {
            Text("Choose an episode:")
        }
    }
    
    private func filterResults(for results: [SearchItem]) -> (highQuality: [SearchItem], lowQuality: [SearchItem]) {
        let sortedResults = results.map { result in
            let primarySimilarity = calculateSimilarity(original: mediaTitle, result: result.title)
            let originalSimilarity = originalTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
            let bestSimilarity = max(primarySimilarity, originalSimilarity)
            
            return (result: result, similarity: bestSimilarity)
        }.sorted { $0.similarity > $1.similarity }
        
        let highQuality = sortedResults.filter { $0.similarity >= highQualityThreshold }.map { $0.result }
        let lowQuality = sortedResults.filter { $0.similarity < highQualityThreshold }.map { $0.result }
        
        return (highQuality, lowQuality)
    }

    @ViewBuilder
    private var tvSearchInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Searching for:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(displayTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if shouldShowOriginalTitle, let originalTitle {
                Text(originalTitle)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let episode = selectedEpisode, !episode.name.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Text(episode.name)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 16)

                    Text(episodeSeasonInfo)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .applyLiquidGlassBackground(cornerRadius: 10)
                        .fixedSize()
                }
            }

            statusBar
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .applyLiquidGlassBackground(cornerRadius: 24)
    }

    @ViewBuilder
    private var tvHeaderControls: some View {
        HStack(spacing: 18) {
            Menu {
                Section("Matching Algorithm") {
                    ForEach(SimilarityAlgorithm.allCases, id: \.self) { algorithm in
                        Button(action: {
                            algorithmManager.selectedAlgorithm = algorithm
                        }) {
                            HStack {
                                Text(algorithm.displayName)
                                if algorithmManager.selectedAlgorithm == algorithm {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Section("Filter Settings") {
                    Button(action: {
                        showingFilterEditor = true
                    }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Quality Threshold")
                            Spacer()
                            Text("\(Int(highQualityThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                    Text("Options")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .applyLiquidGlassBackground(cornerRadius: 16)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Services")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .applyLiquidGlassBackground(
                    cornerRadius: 16,
                    fallbackFill: Color.white.opacity(0.06),
                    fallbackMaterial: .ultraThinMaterial
                )

            Spacer()

            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.title3)
                    Text("Done")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .applyLiquidGlassBackground(cornerRadius: 16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .applyLiquidGlassBackground(
            cornerRadius: 26,
            fallbackFill: Color.black.opacity(0.25),
            fallbackMaterial: .ultraThinMaterial
        )
    }

    @ViewBuilder
    private var tvNoActiveServicesCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("No Active Services")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You don't have any active services. Please go to the Services tab to download and activate services.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .applyLiquidGlassBackground(cornerRadius: 24)
    }

    @ViewBuilder
    private var tvServicesResultsContent: some View {
        LazyVStack(alignment: .leading, spacing: 40) {
            ForEach(Array(serviceManager.activeServices.enumerated()), id: \.element.id) { _, service in
                tvServiceBlock(service: service)
            }
        }
    }

    @ViewBuilder
    private func tvServiceBlock(service: Service) -> some View {
        let moduleResult = moduleResults.first { $0.service.id == service.id }
        let hasSearched = searchedServices.contains(service.id)
        let isCurrentlySearching = isSearching && !hasSearched

        VStack(alignment: .leading, spacing: 18) {
            tvServiceHeader(service: service, moduleResult: moduleResult, isCurrentlySearching: isCurrentlySearching)

            if let result = moduleResult {
                let filtered = filterResults(for: result.results)

                if result.results.isEmpty {
                    tvInfoRow(icon: "magnifyingglass", text: "No results")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 40) {
                            ForEach(filtered.highQuality, id: \.id) { searchResult in
                                if #available(iOS 16.0, *) {
                                    TVServiceResultCard(
                                        result: searchResult,
                                        originalTitle: mediaTitle,
                                        alternativeTitle: originalTitle,
                                        episode: selectedEpisode,
                                        highQualityThreshold: highQualityThreshold,
                                        onTap: {
                                            selectedResult = searchResult
                                            showingPlayAlert = true
                                        }
                                    )
                                } else {
                                    // Fallback on earlier versions
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 4)
                    }
#if os(tvOS)
                    .focusSection()
#endif

                    if !filtered.lowQuality.isEmpty {
                        tvLowQualityResultsBlock(filteredResults: filtered, service: service)
                    }
                }
            } else if isCurrentlySearching {
                tvInfoRow(icon: "hourglass", text: "Searching…")
            } else if !isSearching && !hasSearched {
                tvInfoRow(icon: "minus.circle", text: "Not searched")
            } else {
                tvInfoRow(icon: "exclamationmark.circle", text: "No data")
            }
        }
        .padding(26)
        .applyLiquidGlassBackground(
            cornerRadius: 28,
            fallbackFill: Color.white.opacity(0.06),
            fallbackMaterial: .ultraThinMaterial
        )
    }

    @ViewBuilder
    private func tvServiceHeader(
        service: Service,
        moduleResult: (service: Service, results: [SearchItem])?,
        isCurrentlySearching: Bool
    ) -> some View {
        let resultCount = moduleResult?.results.count ?? 0
        let filteredCounts = moduleResult.map { filterResults(for: $0.results) }
        let highCount = filteredCounts?.highQuality.count ?? 0
        let lowCount = filteredCounts?.lowQuality.count ?? 0

        HStack(spacing: 16) {
            RemoteImage(service.metadata.iconUrl) {
                Image(systemName: "tv.circle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(service.metadata.sourceName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if failedServices.contains(service.id) {
                    Text("Failed to fetch")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if isCurrentlySearching {
                    Text("Searching…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(resultCount) result\(resultCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 20)

            if isCurrentlySearching {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                HStack(spacing: 12) {
                    if highCount > 0 {
                        Text("\(highCount) High")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if lowCount > 0 {
                        Text("\(lowCount) Low")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func tvLowQualityResultsBlock(
        filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]),
        service: Service
    ) -> some View {
        let isExpanded = expandedServices.contains(service.id)

        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                if isExpanded {
                    expandedServices.remove(service.id)
                } else {
                    expandedServices.insert(service.id)
                }
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)

                Text(lowerQualityResultsText(count: filteredResults.lowQuality.count))
                    .font(.callout)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(BorderlessButtonStyle())

        if isExpanded {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(filteredResults.lowQuality, id: \.id) { searchResult in
                        if #available(iOS 16.0, *) {
                            TVServiceResultCard(
                                result: searchResult,
                                originalTitle: mediaTitle,
                                alternativeTitle: originalTitle,
                                episode: selectedEpisode,
                                highQualityThreshold: highQualityThreshold,
                                onTap: {
                                    selectedResult = searchResult
                                    showingPlayAlert = true
                                }
                            )
                        } else {
                            // Fallback on earlier versions
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 4)
            }
#if os(tvOS)
            .focusSection()
#endif
        }
    }

    @ViewBuilder
    private func tvInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isTvOS {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.96),
                                Color.black.opacity(0.88),
                                Color.black.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        
                        ScrollView {
                            VStack(spacing: 36) {
                                tvHeaderControls
                                tvSearchInfoCard

                                if serviceManager.activeServices.isEmpty {
                                    tvNoActiveServicesCard
                                } else {
                                    tvServicesResultsContent
                                }
                            }
                            .padding(.horizontal, 50)
                            .padding(.vertical, 40)
                        }
#if os(tvOS)
                        .focusSection()
#endif
                    }
                } else {
                    List {
                        searchInfoSection
                        
                        if serviceManager.activeServices.isEmpty {
                            noActiveServicesSection
                        } else {
                            servicesResultsSection
                        }
                    }
                }
            }
            .navigationTitle(isTvOS ? "" : "Services Result")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
#if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section("Matching Algorithm") {
                            ForEach(SimilarityAlgorithm.allCases, id: \.self) { algorithm in
                                Button(action: {
                                    algorithmManager.selectedAlgorithm = algorithm
                                }) {
                                    HStack {
                                        Text(algorithm.displayName)
                                        if algorithmManager.selectedAlgorithm == algorithm {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section("Filter Settings") {
                            Button(action: {
                                showingFilterEditor = true
                            }) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Quality Threshold")
                                    Spacer()
                                    Text("\(Int(highQualityThreshold * 100))%")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
#endif
        }
        .adaptiveConfirmationDialog("Play", isPresented: $showingPlayAlert, titleVisibility: .visible) {
            playAlertButtons
        } message: {
            playAlertMessage
        }
        .alert("Stream Error", isPresented: $showingStreamError) {
            Button("OK", role: .cancel) {
                showingStreamError = false
                streamErrorMessage = ""
            }
        } message: {
            Text(streamErrorMessage)
        }
        .overlay(streamFetchingOverlay)
        .onAppear {
            startProgressiveSearch()
            highQualityThreshold = UserDefaults.standard.object(forKey: "highQualityThreshold") as? Double ?? 0.9
        }
        .alert("Quality Threshold", isPresented: $showingFilterEditor) {
            qualityThresholdAlertContent
        } message: {
            qualityThresholdAlertMessage
        }
        .adaptiveConfirmationDialog("Select Server", isPresented: $showingStreamMenu, titleVisibility: .visible) {
            serverSelectionDialogContent
        } message: {
            serverSelectionDialogMessage
        }
        .adaptiveConfirmationDialog("Select Season", isPresented: $showingSeasonPicker, titleVisibility: .visible) {
            seasonPickerDialogContent
        } message: {
            seasonPickerDialogMessage
        }
        .adaptiveConfirmationDialog("Select Episode", isPresented: $showingEpisodePicker, titleVisibility: .visible) {
            episodePickerDialogContent
        } message: {
            episodePickerDialogMessage
        }
    }
    
    private func startProgressiveSearch() {
        let activeServices = serviceManager.activeServices
        totalServicesCount = activeServices.count
        
        guard !activeServices.isEmpty else {
            isSearching = false
            return
        }
        let searchQuery = mediaTitle
        
        Task {
            await serviceManager.searchInActiveServicesProgressively(
                query: searchQuery,
                onResult: { service, results in
                    Task { @MainActor in
                        var newModuleResults = moduleResults
                        
                        if let existingIndex = newModuleResults.firstIndex(where: { $0.service.id == service.id }) {
                            newModuleResults[existingIndex] = (service: service, results: results ?? [])
                        } else {
                            newModuleResults.append((service: service, results: results ?? []))
                        }
                        
                        moduleResults = newModuleResults
                        searchedServices.insert(service.id)
                        
                        if results == nil {
                            failedServices.insert(service.id)
                        } else {
                            failedServices.remove(service.id)
                        }
                    }
                },
                onComplete: {
                    if let originalTitle = self.originalTitle,
                       !originalTitle.isEmpty,
                       originalTitle.lowercased() != self.mediaTitle.lowercased() {
                        
                        Task {
                            await self.serviceManager.searchInActiveServicesProgressively(
                                query: originalTitle,
                                onResult: { service, additionalResults in
                                    Task { @MainActor in
                                        let additional = additionalResults ?? []
                                        
                                        if let existingIndex = self.moduleResults.firstIndex(where: { $0.service.id == service.id }) {
                                            let existingResults = self.moduleResults[existingIndex].results
                                            let existingHrefs = Set(existingResults.map { $0.href })
                                            let newResults = additional.filter { !existingHrefs.contains($0.href) }
                                            let mergedResults = existingResults + newResults
                                            self.moduleResults[existingIndex] = (service: service, results: mergedResults)
                                        } else {
                                            self.moduleResults.append((service: service, results: additional))
                                        }
                                        
                                        if additionalResults == nil {
                                            failedServices.insert(service.id)
                                        } else {
                                            failedServices.remove(service.id)
                                        }
                                    }
                                },
                                onComplete: {
                                    Task { @MainActor in
                                        self.isSearching = false
                                    }
                                }
                            )
                        }
                    } else {
                        Task { @MainActor in
                            self.isSearching = false
                        }
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private func serviceHeader(for service: Service, highQualityCount: Int, lowQualityCount: Int, isSearching: Bool = false) -> some View {
        HStack {
            RemoteImage(service.metadata.iconUrl) {
                Image(systemName: "tv.circle")
                    .foregroundColor(.secondary)
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            
            Text(service.metadata.sourceName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if failedServices.contains(service.id) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.leading, 6)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    if highQualityCount > 0 {
                        Text("\(highQualityCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    
                    if lowQualityCount > 0 {
                        Text("\(lowQualityCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private func getResultCount(for service: Service) -> Int {
        return moduleResults.first { $0.service.id == service.id }?.results.count ?? 0
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return algorithmManager.calculateSimilarity(original: original, result: result)
    }
    
    private func resetPickerState() {
        availableSeasons = []
        pendingEpisodes = []
        pendingResult = nil
        pendingJSController = nil
        selectedSeasonIndex = 0
        isFetchingStreams = false
        activeStreamFetchToken = nil
        activeStreamJSController = nil
    }
    
    private func proceedWithSelectedEpisode(_ episode: EpisodeLink) {
        showingEpisodePicker = false
        
        guard let jsController = pendingJSController,
              let service = pendingService else {
            Logger.shared.log("Missing controller or service for episode selection", type: "Error")
            resetPickerState()
            return
        }
        
        isFetchingStreams = true
        streamFetchProgress = "Fetching selected episode stream..."
        
        fetchStreamForEpisode(episode.href, jsController: jsController, service: service)
    }
    
    private func fetchStreamForEpisode(_ episodeHref: String, jsController: JSController, service: Service) {
        let token = UUID()
        activeStreamFetchToken = token
        activeStreamJSController = jsController
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            if self.activeStreamFetchToken == token && self.isFetchingStreams {
                Logger.shared.log("Stream fetch timed out", type: "Error")
                self.isFetchingStreams = false
                self.activeStreamFetchToken = nil
                self.activeStreamJSController = nil
                self.streamErrorMessage = "Timed out while fetching streams. Please try again or choose another service."
                self.showingStreamError = true
            }
        }

        jsController.fetchStreamUrlJS(episodeUrl: episodeHref, module: service) { streamResult in
            DispatchQueue.main.async {
                self.activeStreamFetchToken = nil
                self.activeStreamJSController = nil
                let (streams, subtitles, sources) = streamResult
                
                Logger.shared.log("Stream fetch result - Streams: \(streams?.count ?? 0), Sources: \(sources?.count ?? 0)", type: "Stream")
                self.streamFetchProgress = "Processing stream data..."
                
                self.processStreamResult(streams: streams, subtitles: subtitles, sources: sources, service: service)
                self.resetPickerState()
            }
        }
    }
    
    private func playContent(_ result: SearchItem) {
        Logger.shared.log("Starting playback for: \(result.title)", type: "Stream")
        
        isFetchingStreams = true
        currentFetchingTitle = result.title
        streamFetchProgress = "Initializing..."
        
        guard let service = serviceManager.activeServices.first(where: { service in
            moduleResults.contains { $0.service.id == service.id && $0.results.contains { $0.id == result.id } }
        }) else {
            Logger.shared.log("Could not find service for result: \(result.title)", type: "Error")
            isFetchingStreams = false
            streamErrorMessage = "Could not find the service for this content."
            showingStreamError = true
            return
        }
        
        Logger.shared.log("Using service: \(service.metadata.sourceName)", type: "Stream")
        streamFetchProgress = "Loading service: \(service.metadata.sourceName)"

        let jsController = JSController()
        activeStreamJSController = jsController

        jsController.loadScript(service.jsScript)
        Logger.shared.log("JavaScript loaded successfully", type: "Stream")
        
        streamFetchProgress = "Fetching episodes..."
        
        jsController.fetchEpisodesJS(url: result.href) { episodes in
            DispatchQueue.main.async {
                Logger.shared.log("Fetched \(episodes.count) episodes for: \(result.title)", type: "Stream")
                self.streamFetchProgress = "Found \(episodes.count) episode\(episodes.count == 1 ? "" : "s")"
                
                if episodes.isEmpty {
                    Logger.shared.log("No episodes found for: \(result.title)", type: "Error")
                    self.isFetchingStreams = false
                    self.activeStreamFetchToken = nil
                    self.activeStreamJSController = nil
                    self.streamErrorMessage = "No episodes or streams found for this content. It may not be available on this service."
                    self.showingStreamError = true
                    return
                }
                
                let targetHref: String
                
                if self.isMovie {
                    targetHref = episodes.first?.href ?? result.href
                    Logger.shared.log("Movie - Using href: \(targetHref)", type: "Stream")
                    self.streamFetchProgress = "Preparing movie stream..."
                } else {
                    guard let selectedEpisode = self.selectedEpisode else {
                        Logger.shared.log("No episode selected for TV show", type: "Error")
                        self.isFetchingStreams = false
                        self.activeStreamFetchToken = nil
                        self.activeStreamJSController = nil
                        self.streamErrorMessage = "No episode was selected for this TV show."
                        self.showingStreamError = true
                        return
                    }
                    
                    self.streamFetchProgress = "Finding episode S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber)..."
                    
                    var seasons: [[EpisodeLink]] = []
                    var currentSeason: [EpisodeLink] = []
                    var lastEpisodeNumber = 0
                    
                    for episode in episodes {
                        if episode.number == 1 || episode.number <= lastEpisodeNumber {
                            if !currentSeason.isEmpty {
                                seasons.append(currentSeason)
                                currentSeason = []
                            }
                        }
                        currentSeason.append(episode)
                        lastEpisodeNumber = episode.number
                    }
                    
                    if !currentSeason.isEmpty {
                        seasons.append(currentSeason)
                    }
                    
                    let targetSeasonIndex = selectedEpisode.seasonNumber - 1
                    let targetEpisodeNumber = selectedEpisode.episodeNumber
                    
                    // Try to find the episode in the expected season first
                    var foundEpisode: EpisodeLink? = nil
                    
                    if targetSeasonIndex >= 0 && targetSeasonIndex < seasons.count {
                        let season = seasons[targetSeasonIndex]
                        if let targetEpisode = season.first(where: { $0.number == targetEpisodeNumber }) {
                            foundEpisode = targetEpisode
                            Logger.shared.log("TV Show - S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber) - Using href: \(targetEpisode.href)", type: "Stream")
                        } else {
                            Logger.shared.log("Episode \(targetEpisodeNumber) not found in season \(selectedEpisode.seasonNumber). Available episodes: \(season.map { $0.number })", type: "Warning")
                        }
                    } else {
                        Logger.shared.log("Season \(selectedEpisode.seasonNumber) not found. Available seasons: \(seasons.count)", type: "Warning")
                    }
                    
                    // If not found in expected season, search all seasons
                    if foundEpisode == nil {
                        for season in seasons {
                            if let episode = season.first(where: { $0.number == targetEpisodeNumber }) {
                                foundEpisode = episode
                                Logger.shared.log("Found episode \(targetEpisodeNumber) in a different season, auto-playing", type: "Stream")
                                break
                            }
                        }
                    }
                    
                    // If episode found, use it
                    if let episode = foundEpisode {
                        targetHref = episode.href
                        Logger.shared.log("TV Show - Using episode href: \(targetHref)", type: "Stream")
                        self.streamFetchProgress = "Found episode, fetching stream..."
                    } else {
                        // Episode not found - show picker
                        Logger.shared.log("Episode \(targetEpisodeNumber) not found in any season", type: "Warning")
                        
                        if targetSeasonIndex >= 0 && targetSeasonIndex < seasons.count {
                            // Show episode picker for the expected season
                            self.pendingEpisodes = seasons[targetSeasonIndex]
                            self.pendingResult = result
                            self.pendingJSController = jsController
                            self.pendingService = service
                            self.isFetchingStreams = false
                            self.activeStreamFetchToken = nil
                            self.activeStreamJSController = nil
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.showingEpisodePicker = true
                            }
                            return
                        } else if seasons.count > 1 {
                            // Show season picker
                            self.availableSeasons = seasons
                            self.pendingResult = result
                            self.pendingJSController = jsController
                            self.pendingService = service
                            self.isFetchingStreams = false
                            self.activeStreamFetchToken = nil
                            self.activeStreamJSController = nil
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.showingSeasonPicker = true
                            }
                            return
                        } else if let firstSeason = seasons.first, !firstSeason.isEmpty {
                            // Show episode picker for the only season
                            self.pendingEpisodes = firstSeason
                            self.pendingResult = result
                            self.pendingJSController = jsController
                            self.pendingService = service
                            self.isFetchingStreams = false
                            self.activeStreamFetchToken = nil
                            self.activeStreamJSController = nil
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.showingEpisodePicker = true
                            }
                            return
                        } else {
                            Logger.shared.log("No episodes found in any season", type: "Error")
                            self.isFetchingStreams = false
                            self.activeStreamFetchToken = nil
                            self.activeStreamJSController = nil
                            self.streamErrorMessage = "No episodes found for this show."
                            self.showingStreamError = true
                            return
                        }
                    }
                }
                
                let token = UUID()
                self.activeStreamFetchToken = token
                self.activeStreamJSController = jsController
                DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                    if self.activeStreamFetchToken == token && self.isFetchingStreams {
                        Logger.shared.log("Stream fetch timed out", type: "Error")
                        self.isFetchingStreams = false
                        self.activeStreamFetchToken = nil
                        self.activeStreamJSController = nil
                        self.streamErrorMessage = "Timed out while fetching streams. Please try again or choose another service."
                        self.showingStreamError = true
                    }
                }

                jsController.fetchStreamUrlJS(episodeUrl: targetHref, module: service) { streamResult in
                    DispatchQueue.main.async {
                        self.activeStreamFetchToken = nil
                        self.activeStreamJSController = nil
                        let (streams, subtitles, sources) = streamResult
                        self.processStreamResult(streams: streams, subtitles: subtitles, sources: sources, service: service)
                    }
                }
            }
        }
    }
    
    private func processStreamResult(streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?, service: Service) {
        Logger.shared.log("Stream fetch result - Streams: \(streams?.count ?? 0), Subtitles: \(subtitles?.count ?? 0), Sources: \(sources?.count ?? 0)", type: "Stream")
        Logger.shared.log("[SUBTITLE] Received subtitles from JS: \(subtitles ?? [])", type: "Stream")
        self.streamFetchProgress = "Processing stream data..."

        func bestStreamURLString(from source: [String: Any]) -> String? {
            if let streamUrl = source["streamUrl"] as? String, !streamUrl.isEmpty {
                return streamUrl
            }
            if let urlString = source["url"] as? String, !urlString.isEmpty {
                return urlString
            }
            if let nestedStream = source["stream"] as? [String: Any] {
                return bestStreamURLString(from: nestedStream)
            }
            if let qualities = source["qualities"] as? [String: Any] {
                // Try to select the highest numeric quality (e.g., 1080, 720, 360)
                var best: (q: Int, url: String)? = nil
                for (key, value) in qualities {
                    guard let q = Int(key) else { continue }
                    if let dict = value as? [String: Any],
                       let url = dict["url"] as? String,
                       !url.isEmpty {
                        if best == nil || q > best!.q {
                            best = (q: q, url: url)
                        }
                    }
                }
                return best?.url
            }
            return nil
        }

        func makeStreamURL(from raw: String) -> URL? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if let direct = URL(string: trimmed) {
                return direct
            }

            if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: Self.rfc3986AllowedURLCharacters),
               let encodedURL = URL(string: encoded) {
                return encodedURL
            }

            return nil
        }
        
        var availableStreams: [StreamOption] = []
        
        if let sources = sources, !sources.isEmpty {
            Logger.shared.log("Processing \(sources.count) sources with potential headers", type: "Stream")

            // Build stream options in a tolerant way. Different providers use:
            // - { title, streamUrl, headers }
            // - { server, url }
            // - { qualities: {"1080": {url: ...}} }
            for (index, source) in sources.enumerated() {
                guard let urlString = bestStreamURLString(from: source) else { continue }

                let rawTitle = (source["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let rawServer = (source["server"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = (rawTitle?.isEmpty == false ? rawTitle : nil)
                    ?? (rawServer?.isEmpty == false ? rawServer : nil)
                    ?? "Stream \(index + 1)"

                let headers = safeConvertToHeaders(source["headers"])
                availableStreams.append(StreamOption(name: displayName, url: urlString, headers: headers))
            }

            if availableStreams.isEmpty {
                let keys = sources.first?.keys.sorted().joined(separator: ", ") ?? "(none)"
                Logger.shared.log("Sources present but no playable URL extracted. Keys: \(keys)", type: "Error")
            }
        }
        else if let streams = streams, streams.count > 1 {
            var streamNames: [String] = []
            var streamURLs: [String] = []
            
            for (_, stream) in streams.enumerated() {
                if stream.hasPrefix("http") {
                    streamURLs.append(stream)
                } else {
                    streamNames.append(stream)
                }
            }
            
            if !streamNames.isEmpty && !streamURLs.isEmpty {
                let maxPairs = min(streamNames.count, streamURLs.count)
                for i in 0..<maxPairs {
                    availableStreams.append(StreamOption(name: streamNames[i], url: streamURLs[i], headers: nil))
                }
                
                if streamURLs.count > streamNames.count {
                    for i in streamNames.count..<streamURLs.count {
                        availableStreams.append(StreamOption(name: "Stream \(i + 1)", url: streamURLs[i], headers: nil))
                    }
                }
            } else if streamURLs.count > 1 {
                for (index, url) in streamURLs.enumerated() {
                    availableStreams.append(StreamOption(name: "Stream \(index + 1)", url: url, headers: nil))
                }
            } else if streams.count > 1 {
                let urls = streams.filter { $0.hasPrefix("http") }
                if urls.count > 1 {
                    for (index, url) in urls.enumerated() {
                        availableStreams.append(StreamOption(name: "Stream \(index + 1)", url: url, headers: nil))
                    }
                }
            }
        }
        
        if availableStreams.count > 1 {
            Logger.shared.log("Found \(availableStreams.count) stream options, showing selection", type: "Stream")
            self.streamOptions = availableStreams
            self.pendingSubtitles = subtitles
            self.pendingService = service
            self.isFetchingStreams = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingStreamMenu = true
            }
            return
        }
        
        var streamURL: URL?
        var streamHeaders: [String: String]? = nil
        
        if let sources = sources, !sources.isEmpty {
            let firstSource = sources.first!

            if let urlString = bestStreamURLString(from: firstSource) {
                Logger.shared.log("Found single stream URL from sources: \(urlString)", type: "Stream")
                streamURL = makeStreamURL(from: urlString)
                streamHeaders = safeConvertToHeaders(firstSource["headers"])
            } else {
                let keys = firstSource.keys.sorted().joined(separator: ", ")
                Logger.shared.log("Sources present but no playable URL extracted. Keys: \(keys)", type: "Error")
            }
        } else if let streams = streams, !streams.isEmpty {
            let urlCandidates = streams.filter { $0.hasPrefix("http") }
            if let firstURL = urlCandidates.first {
                Logger.shared.log("Found single stream URL: \(firstURL)", type: "Stream")
                streamURL = makeStreamURL(from: firstURL)
            } else {
                Logger.shared.log("First stream URL: \(streams.first!)", type: "Stream")
                streamURL = makeStreamURL(from: streams.first!)
            }
        } else {
            Logger.shared.log("No streams or sources found in result", type: "Error")
            self.isFetchingStreams = false
            self.streamErrorMessage = "No streams or sources found. The content may not be available on this service."
            self.showingStreamError = true
            return
        }
        
        if let url = streamURL {
            self.playStreamURL(url.absoluteString, service: service, subtitles: subtitles, headers: streamHeaders)
        } else {
            Logger.shared.log("Failed to create URL from stream string", type: "Error")
            self.isFetchingStreams = false
            self.streamErrorMessage = "Failed to create a valid stream URL. Please try another source."
            self.showingStreamError = true
        }
    }
    
    private func playStreamURL(_ url: String, service: Service, subtitles: [String]?, headers: [String: String]?) {
        Logger.shared.log("[SUBTITLE] playStreamURL called with subtitles: \(subtitles ?? [])", type: "Stream")
        isFetchingStreams = false
        activeStreamFetchToken = nil
        activeStreamJSController = nil
        showingStreamMenu = false
        pendingSubtitles = nil
        pendingService = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            let streamURL = URL(string: trimmed)
                ?? trimmed.addingPercentEncoding(withAllowedCharacters: Self.rfc3986AllowedURLCharacters).flatMap(URL.init(string:))

            guard let streamURL else {
                Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
                self.streamErrorMessage = "Invalid stream URL format. Please try another source."
                self.showingStreamError = true
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
                Logger.shared.log("Using custom headers: \(custom)", type: "Stream")
                for (k, v) in custom {
                    finalHeaders[k] = v
                }
                
                if finalHeaders["User-Agent"] == nil {
                    finalHeaders["User-Agent"] = URLSession.randomUserAgent
                }
            }
            
            Logger.shared.log("Final headers: \(finalHeaders)", type: "Stream")
            
            let inAppRaw = UserDefaults.standard.string(forKey: "inAppPlayer") ?? "Normal"
            let inAppPlayer = (inAppRaw == "mpv") ? "mpv" : "Normal"
            
            if inAppPlayer == "mpv" {
                let preset = PlayerPreset.presets.first
                let pvc = PlayerViewController(
                    url: streamURL,
                    preset: preset ?? PlayerPreset(id: .sdrRec709, title: "Default", summary: "", stream: nil, commands: []),
                    headers: finalHeaders,
                    subtitles: subtitles
                )
                if isMovie {
                    pvc.mediaInfo = .movie(id: tmdbId, title: mediaTitle)
                } else if let episode = selectedEpisode {
                    pvc.mediaInfo = .episode(showId: tmdbId, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
                }
                
                // Set metadata for Apple TV app integration
                Task {
                    let artwork = await loadArtworkImage()
                    await MainActor.run {
                        pvc.setMediaMetadata(title: mediaTitle, artwork: artwork)
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
            } else {
                let normalizedSubtitles = injectingOverlaySubtitle(into: subtitles)
                Logger.shared.log("[SUBTITLE] Creating NormalPlayer with subtitles: \(normalizedSubtitles ?? [])", type: "Stream")
                let playerVC = NormalPlayer()
                playerVC.streamHeaders = finalHeaders
                playerVC.subtitles = normalizedSubtitles
                
                // Create player with native AVPlayer (inject overlay subtitle track when possible)
                let asset: AVURLAsset
                if shouldUseSubtitleInterceptor(for: streamURL, subtitles: normalizedSubtitles) {
                    let interceptor = HLSManifestInterceptor(subtitles: normalizedSubtitles, headers: finalHeaders)
                    let interceptedURL = interceptor.prepareURL(streamURL)
                    asset = AVURLAsset(url: interceptedURL, options: ["AVURLAssetHTTPHeaderFieldsKey": finalHeaders])
                    asset.resourceLoader.setDelegate(interceptor, queue: DispatchQueue.main)
                    playerVC.setHLSInterceptor(interceptor)
                    Logger.shared.log("[SUBTITLE] Using HLS interceptor for overlay track injection", type: "Stream")
                } else {
                    asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": finalHeaders])
                    Logger.shared.log("[SUBTITLE] HLS interceptor not used; overlay track injection unavailable", type: "Stream")
                }
                let item = AVPlayerItem(asset: asset)
                item.externalMetadata = buildExternalMetadata(title: mediaTitle, artwork: nil)
                playerVC.player = AVPlayer(playerItem: item)
                
                Logger.shared.log("[SUBTITLE] NormalPlayer setup complete, subtitles assigned: \(playerVC.subtitles != nil)", type: "Stream")
                if isMovie {
                    playerVC.mediaInfo = .movie(id: tmdbId, title: mediaTitle)
                } else if let episode = selectedEpisode {
                    playerVC.mediaInfo = .episode(showId: tmdbId, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
                }

                // Provide title/artwork metadata to AVKit's Now Playing session (shown on iPhone).
                Task {
                    let artwork = await loadArtworkImage()
                    await MainActor.run {
                        item.externalMetadata = buildExternalMetadata(title: mediaTitle, artwork: artwork)
                    }
                }
                playerVC.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.topmostViewController().present(playerVC, animated: true) {
                        playerVC.player?.play()
                    }
                } else {
                    Logger.shared.log("Failed to find root view controller to present player", type: "Error")
                    playerVC.player?.play()
                }
            }
        }
    }

    private func shouldUseSubtitleInterceptor(for url: URL, subtitles: [String]?) -> Bool {
        guard let subs = subtitles, !subs.isEmpty else { return false }
        let lowercased = url.absoluteString.lowercased()
        if url.pathExtension.lowercased() == "m3u8" { return true }
        return lowercased.contains("m3u8")
    }

    private func injectingOverlaySubtitle(into subtitles: [String]?) -> [String]? {
        guard var subs = subtitles, !subs.isEmpty else { return subtitles }

        let overlayName = SubtitleController.overlayTrackName
        if subs.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(overlayName) == .orderedSame }) {
            return subs
        }

        guard let overlayURL = firstSubtitleURL(in: subs) else { return subs }
        subs.append(overlayName)
        subs.append(overlayURL)
        return subs
    }

    private func firstSubtitleURL(in subtitles: [String]) -> String? {
        return subtitles.first(where: { isSubtitleURL($0) })
    }

    private func isSubtitleURL(_ value: String) -> Bool {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
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
        
        Logger.shared.log("Unable to safely convert headers of type: \(type(of: value))", type: "Warning")
        return nil
    }

    private func buildExternalMetadata(title: String, artwork: UIImage?) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []

        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        titleItem.extendedLanguageTag = "und"
        items.append(titleItem.copy() as! AVMetadataItem)

        guard let artwork else { return items }
        guard let prepared = prepareNowPlayingArtwork(artwork) else { return items }
        guard let data = prepared.jpegData(compressionQuality: 0.92) else { return items }

        let artworkItem = AVMutableMetadataItem()
        artworkItem.identifier = .commonIdentifierArtwork
        artworkItem.value = data as NSData
        artworkItem.dataType = kCMMetadataBaseDataType_JPEG as String
        items.append(artworkItem.copy() as! AVMetadataItem)

        return items
    }

    private func prepareNowPlayingArtwork(_ image: UIImage) -> UIImage? {
        // iOS lock screen / Control Center artwork tends to behave best with a square, reasonably sized image.
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        // Center-crop to square
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        let cropped = UIGraphicsImageRenderer(size: cropRect.size).image { _ in
            image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }

        // Downscale (helps avoid silent rejection on some system surfaces)
        let maxSide: CGFloat = 800
        let currentMax = max(cropped.size.width, cropped.size.height)
        guard currentMax > maxSide else { return cropped }

        let scale = maxSide / currentMax
        let targetSize = CGSize(width: cropped.size.width * scale, height: cropped.size.height * scale)
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // MARK: - Apple TV App Integration Helper
    private func loadArtworkImage() async -> UIImage? {
        // Fetch poster image from TMDB
        do {
            let resolvedPath: String?
            if let posterPath {
                resolvedPath = posterPath
            } else if isMovie {
                let movie = try await TMDBService.shared.getMovieDetails(id: tmdbId)
                resolvedPath = movie.posterPath
            } else {
                let tvShow = try await TMDBService.shared.getTVShowWithSeasons(id: tmdbId)
                resolvedPath = tvShow.posterPath
            }

            guard let resolvedPath else { return nil }
            let posterURL: URL?
            if resolvedPath.hasPrefix("http") {
                posterURL = URL(string: resolvedPath)
            } else {
                posterURL = URL(string: "\(TMDBService.tmdbImageBaseURL)\(resolvedPath)")
            }
            
            guard let url = posterURL else { return nil }

            // Cache for Top Shelf Continue Watching
            TopShelfStore.shared.updateArtworkCache(
                tmdbId: tmdbId,
                kind: isMovie ? .movie : .episode,
                title: effectiveTitle,
                posterURL: url.absoluteString
            )
            
            #if canImport(Kingfisher)
            return await withCheckedContinuation { continuation in
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    switch result {
                    case .success(let imageResult):
                        continuation.resume(returning: imageResult.image)
                    case .failure:
                        continuation.resume(returning: nil)
                    }
                }
            }
            #else
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return UIImage(data: data)
            } catch {
                return nil
            }
            #endif
        } catch {
            return nil
        }
    }
}

struct CompactMediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let alternativeTitle: String?
    let episode: TMDBEpisode?
    let onTap: () -> Void
    let highQualityThreshold: Double
    
    private var similarityScore: Double {
        let primarySimilarity = calculateSimilarity(original: originalTitle, result: result.title)
        let alternativeSimilarity = alternativeTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
        return max(primarySimilarity, alternativeSimilarity)
    }
    
    private var scoreColor: Color {
        if similarityScore >= highQualityThreshold { return .green }
        else if similarityScore >= 0.75 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RemoteImage(result.imageUrl) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        )
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 55)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text("\(Int(similarityScore * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(scoreColor)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle")
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return AlgorithmManager.shared.calculateSimilarity(original: original, result: result)
    }
}

@available(iOS 16.0, *)
struct TVServiceResultCard: View {
    let result: SearchItem
    let originalTitle: String
    let alternativeTitle: String?
    let episode: TMDBEpisode?
    let highQualityThreshold: Double
    let onTap: () -> Void

    @State private var isFocused: Bool = false

    private var similarityScore: Double {
        let primarySimilarity = calculateSimilarity(original: originalTitle, result: result.title)
        let alternativeSimilarity = alternativeTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
        return max(primarySimilarity, alternativeSimilarity)
    }

    private var scoreColor: Color {
        if similarityScore >= highQualityThreshold { return .green }
        else if similarityScore >= 0.75 { return .orange }
        else { return .red }
    }

    private var matchQuality: String {
        if similarityScore >= highQualityThreshold { return "Excellent" }
        else if similarityScore >= 0.75 { return "Good" }
        else { return "Fair" }
    }

    private let cardWidth: CGFloat = 560
    private let cardHeight: CGFloat = 400
    private let posterWidth: CGFloat = 190
    private let posterHeight: CGFloat = 300
    private let contentWidth: CGFloat = 320

    private var focusScale: CGFloat { isFocused ? 1.07 : 1.0 }
    private var focusShadowOpacity: CGFloat { isFocused ? 0.55 : 0.18 }
    private var focusStrokeOpacity: CGFloat { isFocused ? 0.55 : 0.18 }
    private var focusStrokeWidth: CGFloat { isFocused ? 2.0 : 1.0 }
    private var focusGlowColor: Color {
        isFocused ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.10)
    }

    @available(iOS 16.0, *)
    @ViewBuilder
    private var cardContent: some View {
        HStack(alignment: .top, spacing: 18) {
            RemoteImage(result.imageUrl) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            .aspectRatio(2/3, contentMode: .fill)
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .tvos({ view in
                    view.hoverEffect(.highlight)
                })

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let episode = episode {
                        Text("Episode \(episode.episodeNumber)" + (episode.name.isEmpty ? "" : " • \(episode.name)"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(scoreColor)
                            .frame(width: 10, height: 10)

                        Text(matchQuality)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor)

                        Spacer(minLength: 10)
                    }

                    Text("\(Int(similarityScore * 100))% Match")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .applyLiquidGlassBackground(
                            cornerRadius: 14,
                            fallbackFill: Color.white.opacity(0.06),
                            fallbackMaterial: .ultraThinMaterial
                        )

                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            // Avoid clipping when titles/episode names are long.
            .frame(width: contentWidth, alignment: .leading)
        }
        .padding(22)
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .applyLiquidGlassBackground(
            cornerRadius: 26,
            fallbackFill: Color.white.opacity(0.06),
            fallbackMaterial: .ultraThinMaterial
        )
        .shadow(color: focusGlowColor, radius: isFocused ? 26 : 16, x: 0, y: isFocused ? 18 : 12)
        .shadow(color: Color.black.opacity(focusShadowOpacity), radius: isFocused ? 30 : 20, x: 0, y: isFocused ? 18 : 12)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    var body: some View {
        #if os(tvOS)
        cardContent
            // On tvOS, combining `Button` + explicit `focusable` can result in Select only
            // moving focus (highlight) without firing the primary action. Use a focusable
            // view with a tap action instead.
            .focusable(true) { focused in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isFocused = focused
                }
            }
            .onTapGesture(perform: onTap)
            .scaleEffect(focusScale)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFocused)
            .accessibilityLabel(Text("Play \(result.title)"))
            .accessibilityAddTraits(.isButton)
        #else
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Play \(result.title)"))
        #endif
    }

    private func calculateSimilarity(original: String, result: String) -> Double {
        AlgorithmManager.shared.calculateSimilarity(original: original, result: result)
    }
}

struct EnhancedMediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let alternativeTitle: String?
    let episode: TMDBEpisode?
    let onTap: () -> Void
    let highQualityThreshold: Double
    
    private var similarityScore: Double {
        let primarySimilarity = calculateSimilarity(original: originalTitle, result: result.title)
        let alternativeSimilarity = alternativeTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
        return max(primarySimilarity, alternativeSimilarity)
    }
    
    private var scoreColor: Color {
        if similarityScore >= highQualityThreshold { return .green }
        else if similarityScore >= 0.75 { return .orange }
        else { return .red }
    }
    
    private var matchQuality: String {
        if similarityScore >= highQualityThreshold { return "Excellent" }
        else if similarityScore >= 0.75 { return "Good" }
        else { return "Fair" }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RemoteImage(result.imageUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 70, height: 95)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    if let episode = episode {
                        HStack {
                            Image(systemName: "tv")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Episode \(episode.episodeNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !episode.name.isEmpty {
                                Text("• \(episode.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(scoreColor)
                                .frame(width: 6, height: 6)
                            
                            Text(matchQuality)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(scoreColor)
                        }
                        
                        Text("• \(Int(similarityScore * 100))% match")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .tint(Color.accentColor)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return AlgorithmManager.shared.calculateSimilarity(original: original, result: result)
    }
}
