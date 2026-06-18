//
//  ModulesSearchResultsSheet.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import AVKit
import Sybau
import SwiftUI
import Kingfisher

struct StreamOption: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let headers: [String: String]?
    let subtitle: String?
}

@MainActor
final class ModulesSearchResultsViewModel: ObservableObject {
    @Published var moduleResults: [UUID: [SearchItem]] = [:]
    @Published var isSearching = true
    @Published var searchedServices: Set<UUID> = []
    @Published var failedServices: Set<UUID> = []
    @Published var totalServicesCount = 0
    
    @Published var isFetchingStreams = false
    @Published var currentFetchingTitle = ""
    @Published var streamFetchProgress = ""
    @Published var streamOptions: [StreamOption] = []
    @Published var streamError: String?
    @Published var showingStreamError = false
    @Published var showingStreamMenu = false
    
    @Published var selectedResult: SearchItem?
    @Published var showingPlayAlert = false
    @Published var expandedServices: Set<UUID> = []
    @Published var showingFilterEditor = false
    @Published var highQualityThreshold: Double = 0.9
    
    @Published var showingSeasonPicker = false
    @Published var showingEpisodePicker = false
    @Published var showingSubtitlePicker = false
    @Published var availableSeasons: [[EpisodeLink]] = []
    @Published var selectedSeasonIndex = 0
    @Published var pendingEpisodes: [EpisodeLink] = []
    @Published var subtitleOptions: [(title: String, url: String)] = []
    
    var pendingSubtitles: [String]?
    var pendingService: Service?
    var pendingResult: SearchItem?
    var pendingJSController: JSController?
    var pendingStreamURL: String?
    var pendingHeaders: [String: String]?
    var pendingDefaultSubtitle: String?
    
    init() {
        highQualityThreshold = UserDefaults.standard.object(forKey: "highQualityThreshold") as? Double ?? 0.9
    }
    
    func resetPickerState() {
        availableSeasons = []
        pendingEpisodes = []
        pendingResult = nil
        pendingJSController = nil
        selectedSeasonIndex = 0
        isFetchingStreams = false
    }
    
    func resetStreamState() {
        isFetchingStreams = false
        showingStreamMenu = false
        pendingSubtitles = nil
        pendingService = nil
    }
}

struct ModulesSearchResultsSheet: View {
    let mediaTitle: String
    let originalTitle: String?
    let isMovie: Bool
    let selectedEpisode: TMDBEpisode?
    let tmdbId: Int
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = ModulesSearchResultsViewModel()
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var algorithmManager = AlgorithmManager.shared
    
    private var displayTitle: String {
        if let episode = selectedEpisode {
            return "\(mediaTitle) S\(episode.seasonNumber)E\(episode.episodeNumber)"
        }
        return mediaTitle
    }
    
    private var episodeSeasonInfo: String {
        guard let episode = selectedEpisode else { return "" }
        return "S\(episode.seasonNumber)E\(episode.episodeNumber)"
    }
    
    private var mediaTypeText: String { isMovie ? "Movie" : "TV Show" }
    private var mediaTypeColor: Color { isMovie ? .purple : .green }
    
    private var searchStatusText: String {
        viewModel.isSearching
        ? "Searching... (\(viewModel.searchedServices.count)/\(viewModel.totalServicesCount))"
        : "Search complete"
    }
    
    private var searchStatusColor: Color {
        viewModel.isSearching ? .secondary : .green
    }
    
    private func lowerQualityResultsText(count: Int) -> String {
        "\(count) lower quality result\(count == 1 ? "" : "s") (<\(Int(viewModel.highQualityThreshold * 100))%)"
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
            
            if viewModel.isSearching {
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
        let results = viewModel.moduleResults[service.id]
        let hasSearched = viewModel.searchedServices.contains(service.id)
        let isCurrentlySearching = viewModel.isSearching && !hasSearched
        
        if let results = results {
            let filteredResults = filterResults(for: results)
            
            Section(header: serviceHeader(for: service, highQualityCount: filteredResults.highQuality.count, lowQualityCount: filteredResults.lowQuality.count, isSearching: false)) {
                if results.isEmpty {
                    noResultsRow
                } else {
                    serviceResultsContent(filteredResults: filteredResults, service: service)
                }
            }
        } else if isCurrentlySearching {
            Section(header: serviceHeader(for: service, highQualityCount: 0, lowQualityCount: 0, isSearching: true)) {
                searchingRow
            }
        } else if !viewModel.isSearching && !hasSearched {
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
                    viewModel.selectedResult = searchResult
                    viewModel.showingPlayAlert = true
                }, highQualityThreshold: viewModel.highQualityThreshold
            )
        }
        
        if !filteredResults.lowQuality.isEmpty {
            lowQualityResultsSection(filteredResults: filteredResults, service: service)
        }
    }
    
    @ViewBuilder
    private func lowQualityResultsSection(filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]), service: Service) -> some View {
        let isExpanded = viewModel.expandedServices.contains(service.id)
        
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                if isExpanded {
                    viewModel.expandedServices.remove(service.id)
                } else {
                    viewModel.expandedServices.insert(service.id)
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
                        viewModel.selectedResult = searchResult
                        viewModel.showingPlayAlert = true
                    }, highQualityThreshold: viewModel.highQualityThreshold
                )
            }
        }
    }
    
    @ViewBuilder
    private var playAlertButtons: some View {
        Button("Play") {
            viewModel.showingPlayAlert = false
            if let result = viewModel.selectedResult {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await playContent(result)
                }
            }
        }
        Button("Cancel", role: .cancel) {
            viewModel.selectedResult = nil
        }
    }
    
    @ViewBuilder
    private var playAlertMessage: some View {
        if let result = viewModel.selectedResult, let episode = selectedEpisode {
            Text("Play Episode \(episode.episodeNumber) of '\(result.title)'?")
        } else if let result = viewModel.selectedResult {
            Text("Play '\(result.title)'?")
        }
    }
    
    @ViewBuilder
    private var streamFetchingOverlay: some View {
        if viewModel.isFetchingStreams {
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
                        
                        Text(viewModel.currentFetchingTitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        if !viewModel.streamFetchProgress.isEmpty {
                            Text(viewModel.streamFetchProgress)
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
    
    @ViewBuilder
    private var qualityThresholdAlertContent: some View {
        TextField("Threshold (0.0 - 1.0)", value: $viewModel.highQualityThreshold, format: .number)
            .keyboardType(.decimalPad)
        
        Button("Save") {
            viewModel.highQualityThreshold = max(0.0, min(1.0, viewModel.highQualityThreshold))
            UserDefaults.standard.set(viewModel.highQualityThreshold, forKey: "highQualityThreshold")
        }
        
        Button("Cancel", role: .cancel) {
            viewModel.highQualityThreshold = UserDefaults.standard.object(forKey: "highQualityThreshold") as? Double ?? 0.9
        }
    }
    
    @ViewBuilder
    private var qualityThresholdAlertMessage: some View {
        Text("Set the minimum similarity score (0.0 to 1.0) for results to be considered high quality. Current: \(String(format: "%.2f", viewModel.highQualityThreshold)) (\(Int(viewModel.highQualityThreshold * 100))%)")
    }
    
    @ViewBuilder
    private var serverSelectionDialogContent: some View {
        ForEach(viewModel.streamOptions) { option in
            Button(option.name) {
                if let service = viewModel.pendingService {
                    resolveSubtitleSelection(
                        subtitles: viewModel.pendingSubtitles,
                        defaultSubtitle: option.subtitle,
                        service: service,
                        streamURL: option.url,
                        headers: option.headers
                    )
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
        ForEach(Array(viewModel.availableSeasons.enumerated()), id: \.offset) { index, season in
            Button("Season \(index + 1) (\(season.count) episodes)") {
                viewModel.selectedSeasonIndex = index
                viewModel.pendingEpisodes = season
                viewModel.showingSeasonPicker = false
                viewModel.showingEpisodePicker = true
            }
        }
        Button("Cancel", role: .cancel) {
            viewModel.resetPickerState()
        }
    }
    
    @ViewBuilder
    private var seasonPickerDialogMessage: some View {
        Text("Season \(selectedEpisode?.seasonNumber ?? 1) not found. Please choose the correct season:")
    }
    
    @ViewBuilder
    private var episodePickerDialogContent: some View {
        ForEach(viewModel.pendingEpisodes, id: \.href) { episode in
            Button("Episode \(episode.number)") {
                proceedWithSelectedEpisode(episode)
            }
        }
        Button("Cancel", role: .cancel) {
            viewModel.resetPickerState()
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
    
    @ViewBuilder
    private var subtitlePickerDialogContent: some View {
        ForEach(viewModel.subtitleOptions, id: \.url) { option in
            Button(option.title) {
                viewModel.showingSubtitlePicker = false
                if let service = viewModel.pendingService,
                   let streamURL = viewModel.pendingStreamURL {
                    playStreamURL(streamURL, service: service, subtitle: option.url, headers: viewModel.pendingHeaders)
                }
            }
        }
        Button("No Subtitles") {
            viewModel.showingSubtitlePicker = false
            if let service = viewModel.pendingService,
               let streamURL = viewModel.pendingStreamURL {
                playStreamURL(streamURL, service: service, subtitle: nil, headers: viewModel.pendingHeaders)
            }
        }
        Button("Cancel", role: .cancel) {
            viewModel.subtitleOptions = []
            viewModel.pendingStreamURL = nil
            viewModel.pendingHeaders = nil
        }
    }
    
    @ViewBuilder
    private var subtitlePickerDialogMessage: some View {
        Text("Choose a subtitle track")
    }
    
    private func filterResults(for results: [SearchItem]) -> (highQuality: [SearchItem], lowQuality: [SearchItem]) {
        let sortedResults = results.map { result -> (result: SearchItem, similarity: Double) in
            let primarySimilarity = algorithmManager.calculateSimilarity(original: mediaTitle, result: result.title)
            let originalSimilarity = originalTitle.map { algorithmManager.calculateSimilarity(original: $0, result: result.title) } ?? 0.0
            return (result: result, similarity: max(primarySimilarity, originalSimilarity))
        }.sorted { $0.similarity > $1.similarity }
        
        let threshold = viewModel.highQualityThreshold
        let highQuality = sortedResults.filter { $0.similarity >= threshold }.map { $0.result }
        let lowQuality = sortedResults.filter { $0.similarity < threshold }.map { $0.result }
        
        return (highQuality, lowQuality)
    }
    
    var body: some View {
        NavigationView {
            List {
                searchInfoSection
                
                if serviceManager.activeServices.isEmpty {
                    noActiveServicesSection
                } else {
                    servicesResultsSection
                }
            }
            .navigationTitle("Services Result")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
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
                                viewModel.showingFilterEditor = true
                            }) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Quality Threshold")
                                    Spacer()
                                    Text("\(Int(viewModel.highQualityThreshold * 100))%")
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
        }
        .alert("Play Content", isPresented: $viewModel.showingPlayAlert) {
            playAlertButtons
        } message: {
            playAlertMessage
        }
        .overlay(streamFetchingOverlay)
        .onAppear {
            startProgressiveSearch()
        }
        .alert("Quality Threshold", isPresented: $viewModel.showingFilterEditor) {
            qualityThresholdAlertContent
        } message: {
            qualityThresholdAlertMessage
        }
        .adaptiveConfirmationDialog("Select Server", isPresented: $viewModel.showingStreamMenu, titleVisibility: .visible) {
            serverSelectionDialogContent
        } message: {
            serverSelectionDialogMessage
        }
        .adaptiveConfirmationDialog("Select Season", isPresented: $viewModel.showingSeasonPicker, titleVisibility: .visible) {
            seasonPickerDialogContent
        } message: {
            seasonPickerDialogMessage
        }
        .adaptiveConfirmationDialog("Select Episode", isPresented: $viewModel.showingEpisodePicker, titleVisibility: .visible) {
            episodePickerDialogContent
        } message: {
            episodePickerDialogMessage
        }
        .adaptiveConfirmationDialog("Select Subtitle", isPresented: $viewModel.showingSubtitlePicker, titleVisibility: .visible) {
            subtitlePickerDialogContent
        } message: {
            subtitlePickerDialogMessage
        }
        .alert("Stream Error", isPresented: $viewModel.showingStreamError) {
            Button("OK", role: .cancel) {
                viewModel.streamError = nil
            }
        } message: {
            if let error = viewModel.streamError {
                Text(error)
            }
        }
    }
    
    private func startProgressiveSearch() {
        let activeServices = serviceManager.activeServices
        viewModel.totalServicesCount = activeServices.count
        
        guard !activeServices.isEmpty else {
            viewModel.isSearching = false
            return
        }
        
        let searchQuery = mediaTitle
        let hasAlternativeTitle = originalTitle.map { !$0.isEmpty && $0.lowercased() != mediaTitle.lowercased() } ?? false
        
        Task {
            await serviceManager.searchInActiveServicesProgressively(
                query: searchQuery,
                onResult: { service, results in
                    Task { @MainActor in
                        self.viewModel.moduleResults[service.id] = results ?? []
                        self.viewModel.searchedServices.insert(service.id)
                        
                        if results == nil {
                            self.viewModel.failedServices.insert(service.id)
                        } else {
                            self.viewModel.failedServices.remove(service.id)
                        }
                    }
                },
                onComplete: {
                    if hasAlternativeTitle, let altTitle = self.originalTitle {
                        Task {
                            await self.serviceManager.searchInActiveServicesProgressively(
                                query: altTitle,
                                onResult: { service, additionalResults in
                                    Task { @MainActor in
                                        let additional = additionalResults ?? []
                                        let existing = self.viewModel.moduleResults[service.id] ?? []
                                        let existingHrefs = Set(existing.map { $0.href })
                                        let newResults = additional.filter { !existingHrefs.contains($0.href) }
                                        self.viewModel.moduleResults[service.id] = existing + newResults
                                        
                                        if additionalResults == nil {
                                            self.viewModel.failedServices.insert(service.id)
                                        }
                                    }
                                },
                                onComplete: {
                                    Task { @MainActor in
                                        self.viewModel.isSearching = false
                                    }
                                }
                            )
                        }
                    } else {
                        Task { @MainActor in
                            self.viewModel.isSearching = false
                        }
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private func serviceHeader(for service: Service, highQualityCount: Int, lowQualityCount: Int, isSearching: Bool = false) -> some View {
        HStack {
            KFImage(URL(string: service.metadata.iconUrl))
                .placeholder {
                    Image(systemName: "tv.circle")
                        .foregroundColor(.secondary)
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            
            Text(service.metadata.sourceName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if viewModel.failedServices.contains(service.id) {
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
        return viewModel.moduleResults[service.id]?.count ?? 0
    }
    
    private func proceedWithSelectedEpisode(_ episode: EpisodeLink) {
        viewModel.showingEpisodePicker = false
        
        guard let jsController = viewModel.pendingJSController,
              let service = viewModel.pendingService else {
            Logger.shared.log("Missing controller or service for episode selection", type: "Error")
            viewModel.resetPickerState()
            return
        }
        
        viewModel.isFetchingStreams = true
        viewModel.streamFetchProgress = "Fetching selected episode stream..."
        
        fetchStreamForEpisode(episode.href, jsController: jsController, service: service)
    }
    
    private func fetchStreamForEpisode(_ episodeHref: String, jsController: JSController, service: Service) {
        let softsub = service.metadata.softsub ?? false
        jsController.fetchStreamUrlJS(episodeUrl: episodeHref, softsub: softsub, module: service) { streamResult in
            Task { @MainActor in
                let (streams, subtitles, sources) = streamResult
                
                Logger.shared.log("Stream fetch result - Streams: \(streams?.count ?? 0), Sources: \(sources?.count ?? 0)", type: "Stream")
                self.viewModel.streamFetchProgress = "Processing stream data..."
                
                self.processStreamResult(streams: streams, subtitles: subtitles, sources: sources, service: service)
                self.viewModel.resetPickerState()
            }
        }
    }
    
    @MainActor
    private func playContent(_ result: SearchItem) async {
        Logger.shared.log("Starting playback for: \(result.title)", type: "Stream")
        
        viewModel.isFetchingStreams = true
        viewModel.currentFetchingTitle = result.title
        viewModel.streamFetchProgress = "Initializing..."
        
        guard let service = serviceManager.activeServices.first(where: { service in
            viewModel.moduleResults[service.id]?.contains { $0.id == result.id } ?? false
        }) else {
            Logger.shared.log("Could not find service for result: \(result.title)", type: "Error")
            viewModel.isFetchingStreams = false
            viewModel.streamError = "Could not find the service for '\(result.title)'. Please try again."
            viewModel.showingStreamError = true
            return
        }
        
        Logger.shared.log("Using service: \(service.metadata.sourceName)", type: "Stream")
        viewModel.streamFetchProgress = "Loading service: \(service.metadata.sourceName)"
        
        let jsController = JSController()
        jsController.loadScript(service.jsScript)
        Logger.shared.log("JavaScript loaded successfully", type: "Stream")
        
        viewModel.streamFetchProgress = "Fetching episodes..."
        
        jsController.fetchEpisodesJS(url: result.href) { episodes in
            Task { @MainActor in
                self.handleEpisodesFetched(episodes, result: result, service: service, jsController: jsController)
            }
        }
    }
    
    @MainActor
    private func handleEpisodesFetched(_ episodes: [EpisodeLink], result: SearchItem, service: Service, jsController: JSController) {
        Logger.shared.log("Fetched \(episodes.count) episodes for: \(result.title)", type: "Stream")
        viewModel.streamFetchProgress = "Found \(episodes.count) episode\(episodes.count == 1 ? "" : "s")"
        
        if episodes.isEmpty {
            Logger.shared.log("No episodes found for: \(result.title)", type: "Error")
            viewModel.isFetchingStreams = false
            viewModel.streamError = "No episodes found for '\(result.title)'. The source may be unavailable."
            viewModel.showingStreamError = true
            return
        }
        
        if isMovie {
            let targetHref = episodes.first?.href ?? result.href
            Logger.shared.log("Movie - Using href: \(targetHref)", type: "Stream")
            viewModel.streamFetchProgress = "Preparing movie stream..."
            fetchFinalStream(href: targetHref, jsController: jsController, service: service)
            return
        }
        
        guard let selectedEp = selectedEpisode else {
            Logger.shared.log("No episode selected for TV show", type: "Error")
            viewModel.isFetchingStreams = false
            viewModel.streamError = "No episode selected. Please select an episode first."
            viewModel.showingStreamError = true
            return
        }
        
        viewModel.streamFetchProgress = "Finding episode S\(selectedEp.seasonNumber)E\(selectedEp.episodeNumber)..."
        let seasons = parseSeasons(from: episodes)
        let targetSeasonIndex = selectedEp.seasonNumber - 1
        let targetEpisodeNumber = selectedEp.episodeNumber
        
        if let targetHref = findEpisodeHref(seasons: seasons, seasonIndex: targetSeasonIndex, episodeNumber: targetEpisodeNumber) {
            viewModel.streamFetchProgress = "Found episode, fetching stream..."
            fetchFinalStream(href: targetHref, jsController: jsController, service: service)
        } else {
            showEpisodePicker(seasons: seasons, result: result, jsController: jsController, service: service)
        }
    }
    
    private func parseSeasons(from episodes: [EpisodeLink]) -> [[EpisodeLink]] {
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
        
        return seasons
    }
    
    private func findEpisodeHref(seasons: [[EpisodeLink]], seasonIndex: Int, episodeNumber: Int) -> String? {
        if seasonIndex >= 0 && seasonIndex < seasons.count {
            if let episode = seasons[seasonIndex].first(where: { $0.number == episodeNumber }) {
                Logger.shared.log("Found exact match: S\(seasonIndex + 1)E\(episodeNumber)", type: "Stream")
                return episode.href
            }
        }
        
        for season in seasons {
            if let episode = season.first(where: { $0.number == episodeNumber }) {
                Logger.shared.log("Found episode \(episodeNumber) in different season, auto-playing", type: "Stream")
                return episode.href
            }
        }
        
        return nil
    }
    
    @MainActor
    private func showEpisodePicker(seasons: [[EpisodeLink]], result: SearchItem, jsController: JSController, service: Service) {
        viewModel.pendingResult = result
        viewModel.pendingJSController = jsController
        viewModel.pendingService = service
        viewModel.isFetchingStreams = false
        
        if seasons.count > 1 {
            viewModel.availableSeasons = seasons
            viewModel.showingSeasonPicker = true
        } else if let firstSeason = seasons.first, !firstSeason.isEmpty {
            viewModel.pendingEpisodes = firstSeason
            viewModel.showingEpisodePicker = true
        } else {
            Logger.shared.log("No episodes found in any season", type: "Error")
            viewModel.streamError = "No episodes found in any season. The source may have incomplete data."
            viewModel.showingStreamError = true
        }
    }
    
    private func fetchFinalStream(href: String, jsController: JSController, service: Service) {
        let softsub = service.metadata.softsub ?? false
        jsController.fetchStreamUrlJS(episodeUrl: href, softsub: softsub, module: service) { streamResult in
            Task { @MainActor in
                let (streams, subtitles, sources) = streamResult
                self.processStreamResult(streams: streams, subtitles: subtitles, sources: sources, service: service)
            }
        }
    }
    
    @MainActor
    private func processStreamResult(streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?, service: Service) {
        Logger.shared.log("Stream fetch result - Streams: \(streams?.count ?? 0), Sources: \(sources?.count ?? 0)", type: "Stream")
        viewModel.streamFetchProgress = "Processing stream data..."
        
        let availableStreams = parseStreamOptions(streams: streams, sources: sources)
        
        if availableStreams.count > 1 {
            Logger.shared.log("Found \(availableStreams.count) stream options, showing selection", type: "Stream")
            viewModel.streamOptions = availableStreams
            viewModel.pendingSubtitles = subtitles
            viewModel.pendingService = service
            viewModel.isFetchingStreams = false
            viewModel.showingStreamMenu = true
            return
        }
        
        if let firstStream = availableStreams.first {
            resolveSubtitleSelection(
                subtitles: subtitles,
                defaultSubtitle: firstStream.subtitle,
                service: service,
                streamURL: firstStream.url,
                headers: firstStream.headers
            )
        } else if let streamURL = extractSingleStreamURL(streams: streams, sources: sources) {
            resolveSubtitleSelection(
                subtitles: subtitles,
                defaultSubtitle: nil,
                service: service,
                streamURL: streamURL.url,
                headers: streamURL.headers
            )
        } else {
            Logger.shared.log("Failed to create URL from stream string", type: "Error")
            viewModel.isFetchingStreams = false
            viewModel.streamError = "Failed to get a valid stream URL. The source may be temporarily unavailable."
            viewModel.showingStreamError = true
        }
    }
    
    private func parseStreamOptions(streams: [String]?, sources: [[String: Any]]?) -> [StreamOption] {
        var availableStreams: [StreamOption] = []
        
        if let sources = sources, !sources.isEmpty {
            for (idx, source) in sources.enumerated() {
                guard let rawUrl = source["streamUrl"] as? String ?? source["url"] as? String, !rawUrl.isEmpty else { continue }
                let title = (source["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let headers = safeConvertToHeaders(source["headers"])
                let subtitle = source["subtitle"] as? String
                let option = StreamOption(
                    name: title?.isEmpty == false ? title! : "Stream \(idx + 1)",
                    url: rawUrl,
                    headers: headers,
                    subtitle: subtitle
                )
                availableStreams.append(option)
            }
        } else if let streams = streams, streams.count > 1 {
            availableStreams = parseStreamStrings(streams)
        }
        
        return availableStreams
    }
    
    private func parseStreamStrings(_ streams: [String]) -> [StreamOption] {
        var options: [StreamOption] = []
        var index = 0
        var unnamedCount = 1
        
        while index < streams.count {
            let entry = streams[index]
            if isURL(entry) {
                options.append(StreamOption(name: "Stream \(unnamedCount)", url: entry, headers: nil, subtitle: nil))
                unnamedCount += 1
                index += 1
            } else {
                let nextIndex = index + 1
                if nextIndex < streams.count, isURL(streams[nextIndex]) {
                    options.append(StreamOption(name: entry, url: streams[nextIndex], headers: nil, subtitle: nil))
                    index += 2
                } else {
                    index += 1
                }
            }
        }
        
        return options
    }
    
    private func isURL(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }
    
    private func extractSingleStreamURL(streams: [String]?, sources: [[String: Any]]?) -> (url: String, headers: [String: String]?)? {
        if let sources = sources, let firstSource = sources.first {
            if let streamUrl = firstSource["streamUrl"] as? String {
                return (streamUrl, safeConvertToHeaders(firstSource["headers"]))
            } else if let urlString = firstSource["url"] as? String {
                return (urlString, safeConvertToHeaders(firstSource["headers"]))
            }
        } else if let streams = streams, !streams.isEmpty {
            let urlCandidates = streams.filter { $0.hasPrefix("http") }
            if let firstURL = urlCandidates.first {
                return (firstURL, nil)
            } else if let first = streams.first {
                return (first, nil)
            }
        }
        return nil
    }
    
    @MainActor
    private func resolveSubtitleSelection(subtitles: [String]?, defaultSubtitle: String?, service: Service, streamURL: String, headers: [String: String]?) {
        guard let subtitles = subtitles, !subtitles.isEmpty else {
            playStreamURL(streamURL, service: service, subtitle: defaultSubtitle, headers: headers)
            return
        }
        
        let options = parseSubtitleOptions(from: subtitles)
        guard !options.isEmpty else {
            playStreamURL(streamURL, service: service, subtitle: defaultSubtitle, headers: headers)
            return
        }
        
        if options.count == 1 {
            playStreamURL(streamURL, service: service, subtitle: options[0].url, headers: headers)
            return
        }
        
        viewModel.subtitleOptions = options
        viewModel.pendingStreamURL = streamURL
        viewModel.pendingHeaders = headers
        viewModel.pendingService = service
        viewModel.pendingDefaultSubtitle = defaultSubtitle
        viewModel.isFetchingStreams = false
        viewModel.showingSubtitlePicker = true
    }
    
    private func parseSubtitleOptions(from subtitles: [String]) -> [(title: String, url: String)] {
        var options: [(String, String)] = []
        var index = 0
        var fallbackIndex = 1
        
        while index < subtitles.count {
            let entry = subtitles[index]
            if isURL(entry) {
                options.append(("Subtitle \(fallbackIndex)", entry))
                fallbackIndex += 1
                index += 1
            } else {
                let nextIndex = index + 1
                if nextIndex < subtitles.count, isURL(subtitles[nextIndex]) {
                    options.append((entry, subtitles[nextIndex]))
                    fallbackIndex += 1
                    index += 2
                } else {
                    index += 1
                }
            }
        }
        return options
    }
    
    private func playStreamURL(_ url: String, service: Service, subtitle: String?, headers: [String: String]?) {
        viewModel.resetStreamState()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard let streamURL = URL(string: url) else {
                Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
                viewModel.streamError = "Invalid stream URL. The source returned a malformed URL."
                viewModel.showingStreamError = true
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
                let subtitleArray: [String]? = subtitle.map { [$0] }
                let pvc = PlayerViewController(
                    url: streamURL,
                    preset: preset ?? PlayerPreset(title: "Default", summary: "", stream: nil, commands: []),
                    headers: finalHeaders,
                    subtitles: subtitleArray
                )
                if isMovie {
                    pvc.mediaInfo = .movie(id: tmdbId, title: mediaTitle)
                } else if let episode = selectedEpisode {
                    pvc.mediaInfo = .episode(showId: tmdbId, showTitle: mediaTitle, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
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
                let playerVC = NormalPlayer()
                let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": finalHeaders])
                let item = AVPlayerItem(asset: asset)
                playerVC.player = AVPlayer(playerItem: item)
                if isMovie {
                    playerVC.mediaInfo = .movie(id: tmdbId, title: mediaTitle)
                } else if let episode = selectedEpisode {
                    playerVC.mediaInfo = .episode(showId: tmdbId, showTitle: mediaTitle, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
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
                KFImage(URL(string: result.imageUrl))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 55)
                    .cornerRadius(6)
                
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
                KFImage(URL(string: result.imageUrl))
                    .placeholder {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 95)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
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
