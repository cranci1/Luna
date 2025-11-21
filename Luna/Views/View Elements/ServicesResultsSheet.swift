//
//  ModulesSearchResultsSheet.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import AVKit
import SwiftUI
import Kingfisher

struct StreamOption {
    let id = UUID()
    let name: String
    let url: String
    let headers: [String: String]?
}

struct ModulesSearchResultsSheet: View {
    let mediaTitle: String
    let originalTitle: String?
    let isMovie: Bool
    let selectedEpisode: TMDBEpisode?
    let tmdbId: Int
    
    @Environment(\.presentationMode) var presentationMode
    @State private var moduleResults: [(service: Services, results: [SearchItem])] = []
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
    @State private var pendingService: Services?
    @State private var showingStreamMenu = false
    @State private var isFetchingStreams = false
    @State private var currentFetchingTitle = ""
    @State private var streamFetchProgress = ""
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
    
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var algorithmManager = AlgorithmManager.shared
    
    private var servicesWithResults: [(service: Services, results: [SearchItem])] {
        moduleResults.filter { !$0.results.isEmpty }
    }
    
    private var shouldShowOriginalTitle: Bool {
        guard let originalTitle = originalTitle else { return false }
        return !originalTitle.isEmpty && originalTitle.lowercased() != mediaTitle.lowercased()
    }
    
    private var displayTitle: String {
        if let episode = selectedEpisode {
            return "\(mediaTitle) S\(episode.seasonNumber)E\(episode.episodeNumber)"
        } else {
            return mediaTitle
        }
    }
    
    private var episodeSeasonInfo: String {
        if let episode = selectedEpisode {
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
    private func serviceSection(service: Services) -> some View {
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
    private func serviceResultsContent(filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]), service: Services) -> some View {
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
    private func lowQualityResultsSection(filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]), service: Services) -> some View {
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
        }
        .alert("Play Content", isPresented: $showingPlayAlert) {
            playAlertButtons
        } message: {
            playAlertMessage
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
        .confirmationDialog("Select Server", isPresented: $showingStreamMenu, titleVisibility: .visible) {
            serverSelectionDialogContent
        } message: {
            serverSelectionDialogMessage
        }
        .confirmationDialog("Select Season", isPresented: $showingSeasonPicker, titleVisibility: .visible) {
            seasonPickerDialogContent
        } message: {
            seasonPickerDialogMessage
        }
        .confirmationDialog("Select Episode", isPresented: $showingEpisodePicker, titleVisibility: .visible) {
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
    private func serviceHeader(for service: Services, highQualityCount: Int, lowQualityCount: Int, isSearching: Bool = false) -> some View {
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
    
    private func getResultCount(for service: Services) -> Int {
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
    
    private func fetchStreamForEpisode(_ episodeHref: String, jsController: JSController, service: Services) {
        jsController.fetchStreamUrlJS(episodeUrl: episodeHref, module: service) { streamResult in
            DispatchQueue.main.async {
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
            return
        }
        
        Logger.shared.log("Using service: \(service.metadata.sourceName)", type: "Stream")
        streamFetchProgress = "Loading service: \(service.metadata.sourceName)"
        
        let jsController = JSController()
        let servicePath = serviceManager.servicesDirectory.appendingPathComponent(service.localPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        
        Logger.shared.log("JavaScript path: \(jsPath.path)", type: "Stream")
        
        guard FileManager.default.fileExists(atPath: jsPath.path) else {
            Logger.shared.log("JavaScript file not found for service: \(service.metadata.sourceName)", type: "Error")
            isFetchingStreams = false
            return
        }
        
        do {
            let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
            jsController.loadScript(jsContent)
            Logger.shared.log("JavaScript loaded successfully", type: "Stream")
            streamFetchProgress = "JavaScript loaded successfully"
        } catch {
            Logger.shared.log("Failed to load JavaScript for service \(service.metadata.sourceName): \(error.localizedDescription)", type: "Error")
            isFetchingStreams = false
            return
        }
        
        streamFetchProgress = "Fetching episodes..."
        
        jsController.fetchEpisodesJS(url: result.href) { episodes in
            DispatchQueue.main.async {
                Logger.shared.log("Fetched \(episodes.count) episodes for: \(result.title)", type: "Stream")
                self.streamFetchProgress = "Found \(episodes.count) episode\(episodes.count == 1 ? "" : "s")"
                
                if episodes.isEmpty {
                    Logger.shared.log("No episodes found for: \(result.title)", type: "Error")
                    self.isFetchingStreams = false
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
                    
                    if targetSeasonIndex >= 0 && targetSeasonIndex < seasons.count {
                        let season = seasons[targetSeasonIndex]
                        if let targetEpisode = season.first(where: { $0.number == targetEpisodeNumber }) {
                            targetHref = targetEpisode.href
                            Logger.shared.log("TV Show - S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber) - Using href: \(targetHref)", type: "Stream")
                            self.streamFetchProgress = "Found episode, fetching stream..."
                        } else {
                            Logger.shared.log("Episode \(targetEpisodeNumber) not found in season \(selectedEpisode.seasonNumber). Available episodes: \(season.map { $0.number })", type: "Warning")
                            
                            var foundEpisode: EpisodeLink? = nil
                            for otherSeason in seasons {
                                if let episode = otherSeason.first(where: { $0.number == targetEpisodeNumber }) {
                                    foundEpisode = episode
                                    Logger.shared.log("Found episode \(targetEpisodeNumber) in a different season, auto-playing", type: "Stream")
                                    break
                                }
                            }
                            
                            if let episode = foundEpisode {
                                targetHref = episode.href
                                Logger.shared.log("TV Show - Auto-selected E\(targetEpisodeNumber) - Using href: \(targetHref)", type: "Stream")
                                self.streamFetchProgress = "Found episode, fetching stream..."
                            } else {
                                self.pendingEpisodes = season
                                self.pendingResult = result
                                self.pendingJSController = jsController
                                self.pendingService = service
                                self.isFetchingStreams = false
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.showingEpisodePicker = true
                                }
                                return
                            }
                        }
                    } else {
                        Logger.shared.log("Season \(selectedEpisode.seasonNumber) not found. Available seasons: \(seasons.count)", type: "Warning")
                        
                        var foundEpisode: EpisodeLink? = nil
                        for season in seasons {
                            if let episode = season.first(where: { $0.number == targetEpisodeNumber }) {
                                foundEpisode = episode
                                Logger.shared.log("Found episode \(targetEpisodeNumber) in a different season, auto-playing", type: "Stream")
                                break
                            }
                        }
                        
                        if let episode = foundEpisode {
                            targetHref = episode.href
                            Logger.shared.log("TV Show - Auto-selected E\(targetEpisodeNumber) - Using href: \(targetHref)", type: "Stream")
                            self.streamFetchProgress = "Found episode, fetching stream..."
                        } else {
                            if seasons.count > 1 {
                                self.availableSeasons = seasons
                                self.pendingResult = result
                                self.pendingJSController = jsController
                                self.pendingService = service
                                self.isFetchingStreams = false
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.showingSeasonPicker = true
                                }
                                return
                            } else {
                                let season = seasons.first ?? []
                                if !season.isEmpty {
                                    self.pendingEpisodes = season
                                    self.pendingResult = result
                                    self.pendingJSController = jsController
                                    self.pendingService = service
                                    self.isFetchingStreams = false
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        self.showingEpisodePicker = true
                                    }
                                    return
                                } else {
                                    Logger.shared.log("No episodes found in any season", type: "Error")
                                    self.isFetchingStreams = false
                                    return
                                }
                            }
                        }
                    }
                }
                
                jsController.fetchStreamUrlJS(episodeUrl: targetHref, module: service) { streamResult in
                    DispatchQueue.main.async {
                        let (streams, subtitles, sources) = streamResult
                        self.processStreamResult(streams: streams, subtitles: subtitles, sources: sources, service: service)
                    }
                }
            }
        }
    }
    
    private func processStreamResult(streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?, service: Services) {
        Logger.shared.log("Stream fetch result - Streams: \(streams?.count ?? 0), Sources: \(sources?.count ?? 0)", type: "Stream")
        self.streamFetchProgress = "Processing stream data..."
        
        var availableStreams: [StreamOption] = []
        
        if let sources = sources, !sources.isEmpty {
            Logger.shared.log("Processing \(sources.count) sources with potential headers", type: "Stream")
            
            var hasNewFormat = false
            for source in sources {
                if source["title"] is String && source["streamUrl"] is String {
                    hasNewFormat = true
                    break
                }
            }
            
            if hasNewFormat {
                Logger.shared.log("Detected new stream format with titles and headers", type: "Stream")
                for source in sources {
                    if let title = source["title"] as? String,
                       let streamUrl = source["streamUrl"] as? String {
                        let headers = safeConvertToHeaders(source["headers"])
                        availableStreams.append(StreamOption(name: title, url: streamUrl, headers: headers))
                        Logger.shared.log("Added stream: \(title) with headers: \(headers?.keys.joined(separator: ", ") ?? "none")", type: "Stream")
                    }
                }
            } else {
                Logger.shared.log("Using legacy source format", type: "Stream")
                for (index, source) in sources.enumerated() {
                    if let urlString = source["url"] as? String {
                        let headers = safeConvertToHeaders(source["headers"])
                        availableStreams.append(StreamOption(name: "Stream \(index + 1)", url: urlString, headers: headers))
                    }
                }
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
            
            if let streamUrl = firstSource["streamUrl"] as? String {
                Logger.shared.log("Found single stream URL from new format: \(streamUrl)", type: "Stream")
                streamURL = URL(string: streamUrl)
                streamHeaders = safeConvertToHeaders(firstSource["headers"])
            } else if let urlString = firstSource["url"] as? String {
                Logger.shared.log("Found single stream URL from legacy format: \(urlString)", type: "Stream")
                streamURL = URL(string: urlString)
                streamHeaders = safeConvertToHeaders(firstSource["headers"])
            }
        } else if let streams = streams, !streams.isEmpty {
            let urlCandidates = streams.filter { $0.hasPrefix("http") }
            if let firstURL = urlCandidates.first {
                Logger.shared.log("Found single stream URL: \(firstURL)", type: "Stream")
                streamURL = URL(string: firstURL)
            } else {
                Logger.shared.log("First stream URL: \(streams.first!)", type: "Stream")
                streamURL = URL(string: streams.first!)
            }
        } else {
            Logger.shared.log("No streams or sources found in result", type: "Error")
        }
        
        if let url = streamURL {
            self.playStreamURL(url.absoluteString, service: service, subtitles: subtitles, headers: streamHeaders)
        } else {
            Logger.shared.log("Failed to create URL from stream string", type: "Error")
            self.isFetchingStreams = false
        }
    }
    
    private func playStreamURL(_ url: String, service: Services, subtitles: [String]?, headers: [String: String]?) {
        isFetchingStreams = false
        showingStreamMenu = false
        pendingSubtitles = nil
        pendingService = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let streamURL = URL(string: url) else {
                Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
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
                pvc.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.topmostViewController().present(pvc, animated: true, completion: nil)
                } else {
                    Logger.shared.log("Failed to find root view controller to present MPV player", type: "Error")
                }
                return
            } else {
                let playerVC = NormalPlayer(subtitles: subtitles)
                let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": finalHeaders])
                let item = AVPlayerItem(asset: asset)
                playerVC.player = AVPlayer(playerItem: item)
                if isMovie {
                    playerVC.mediaInfo = .movie(id: tmdbId, title: mediaTitle)
                } else if let episode = selectedEpisode {
                    playerVC.mediaInfo = .episode(showId: tmdbId, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
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
