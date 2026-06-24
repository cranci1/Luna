//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct SearchView: View {
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 3
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 5
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    @AppStorage("searchHistory") private var searchHistoryData: Data = Data()
    
    @State private var searchText = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchFilter: SearchFilter = .all
    @State private var showServiceDownloadAlert = false
    @State private var serviceDownloadError: String?
    @State private var searchHistory: [String] = []
    
    @State private var searchMode: SearchMode = .tmdb
    @State private var selectedService: Service? = nil
    @State private var serviceSearchResults: [SearchItem] = []
    
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var contentFilter = TMDBContentFilter.shared
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var jsController = JSController.shared
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    enum SearchMode {
        case tmdb, service
    }
    
    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case movies = "Movies"
        case tvShows = "TV Shows"
    }
    
    var filteredResults: [TMDBSearchResult] {
        switch searchFilter {
        case .all:
            return searchResults
        case .movies:
            return searchResults.filter { $0.isMovie }
        case .tvShows:
            return searchResults.filter { $0.isTVShow }
        }
    }
    
    var filterIcon: String {
        switch searchFilter {
        case .all:
            return "square.grid.2x2"
        case .movies:
            return "tv"
        case .tvShows:
            return "tv.fill"
        }
    }
    
    var hasResults: Bool {
        searchMode == .tmdb ? !searchResults.isEmpty : !serviceSearchResults.isEmpty
    }
    
    private var columnsCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            guard
                let screen = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.screen })
                    .first
            else {
                fatalError("⚠️ No active screen found — app may not have a visible window yet.")
            }
            
            let isLandscape = screen.bounds.width > screen.bounds.height
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                searchContent
            }
        } else {
            NavigationView {
                searchContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var searchContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    SearchBarLuna(text: $searchText) {
                        performSearch()
                    }
                    .onChangeComp(of: searchText) { _, newValue in
                        if newValue.isEmpty {
                            searchResults = []
                            serviceSearchResults = []
                            errorMessage = nil
                        }
                    }
                    
                    if searchMode == .tmdb && !searchResults.isEmpty {
                        Menu {
                            ForEach(SearchFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    searchFilter = filter
                                }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if searchFilter == filter {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: searchFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: hasResults)
            }
            .padding()
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Error")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(.top)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        performSearch()
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                if searchMode == .service && selectedService == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension")
                            .imageScale(.large)
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Select a Service")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Tap the source button at the top right to pick a service")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else if searchHistory.isEmpty {
                    let servicePrompt = "Search via \(selectedService?.metadata.sourceName ?? "Service")"
                    let defaultPrompt = contentFilter.animeOnlyMode ? "Search Anime" : "Search Movies & TV Shows"
                    
                    VStack {
                        Image(systemName: "magnifyingglass.circle")
                            .imageScale(.large)
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text(searchMode == .service ? servicePrompt : defaultPrompt)
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Recent Searches")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("Clear") {
                                clearSearchHistory()
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(searchHistory.enumerated()), id: \.offset) { index, historyItem in
                                Button(action: {
                                    searchText = historyItem
                                    performSearch()
                                }) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                        
                                        Text(historyItem)
                                            .foregroundColor(.primary)
                                            .font(.body)
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            removeFromSearchHistory(at: index)
                                        }) {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if index < searchHistory.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .clipped()
                        
                        Spacer()
                    }
                }
            } else if searchMode == .service {
                if serviceSearchResults.isEmpty {
                    VStack {
                        Image(systemName: "questionmark.circle")
                            .imageScale(.large)
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No results found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Text("Try searching for something else")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let service = selectedService {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                        ForEach(serviceSearchResults) { item in
                            NavigationLink(destination: MediaDetailView(moduleItem: item, service: service)) {
                                ServiceSearchResultCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
            } else if filteredResults.isEmpty && !searchResults.isEmpty {
                VStack {
                    Image(systemName: "tv.and.hifispeaker.fill")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No \(searchFilter.rawValue.lowercased()) found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("Try adjusting your filter or search for something else")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack {
                    Image(systemName: "questionmark.circle")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No results found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("Try searching for a different movie or TV show")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                    ForEach(filteredResults) { result in
                        SearchResultCard(result: result)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sourceMenu
            }
        }
        .alert("Service Downloaded", isPresented: $showServiceDownloadAlert) {
            Button("OK") { }
        } message: {
            Text("The service has been successfully downloaded and saved to your documents folder.")
        }
        .alert("Download Error", isPresented: .constant(serviceDownloadError != nil)) {
            Button("OK") {
                serviceDownloadError = nil
            }
        } message: {
            Text(serviceDownloadError ?? "")
        }
        .onChangeComp(of: selectedLanguage) { _, _ in
            if !searchText.isEmpty && !searchResults.isEmpty {
                performSearch()
            }
        }
        .onChangeComp(of: contentFilter.filterHorror) { _, _ in
            if !searchText.isEmpty && !searchResults.isEmpty {
                performSearch()
            }
        }
        .onChangeComp(of: contentFilter.filterNSFW) { _, _ in
            if !searchText.isEmpty && !searchResults.isEmpty {
                performSearch()
            }
        }
        .onChangeComp(of: contentFilter.animeOnlyMode) { _, _ in
            if !searchText.isEmpty {
                performSearch()
            }
        }
        .onAppear {
            loadSearchHistory()
        }
    }
    
    // MARK: - Source Menu
    private var navigationTitle: String {
        switch searchMode {
        case .tmdb:
            return "Search"
        case .service:
            return selectedService.map { $0.metadata.sourceName } ?? "Search"
        }
    }
    
    @ViewBuilder
    private var sourceMenu: some View {
        Menu {
            Button(action: {
                searchMode = .tmdb
                selectedService = nil
                searchText = ""
                searchResults = []
                serviceSearchResults = []
                errorMessage = nil
            }) {
                Label("TMDB", systemImage: searchMode == .tmdb ? "checkmark" : "magnifyingglass")
            }
            
            if !serviceManager.services.isEmpty {
                Divider()
                ForEach(0..<serviceManager.services.count, id: \.self) { index in
                    sourceMenuServiceButton(index: index)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(searchMode == .tmdb ? "TMDB" : (selectedService?.metadata.sourceName ?? "Source"))
                    .font(.subheadline)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.accentColor)
        }
    }
    
    @ViewBuilder
    private func sourceMenuServiceButton(index: Int) -> some View {
        let service = serviceManager.services[index]
        let isSelected = searchMode == .service && selectedService?.id == service.id
        Button(action: {
            selectService(service)
        }) {
            Label(service.metadata.sourceName, systemImage: isSelected ? "checkmark" : "puzzlepiece.extension")
        }
    }
    
    // MARK: - Service Selection
    private func selectService(_ service: Service) {
        searchMode = .service
        selectedService = service
        jsController.loadScript(service.jsScript)
        searchResults = []
        serviceSearchResults = []
        errorMessage = nil
        if !searchText.isEmpty {
            performSearch()
        }
    }
    
    // MARK: - Search History Management
    
    private func loadSearchHistory() {
        if let decodedHistory = try? JSONDecoder().decode([String].self, from: searchHistoryData) {
            searchHistory = decodedHistory
        }
    }
    
    private func saveSearchHistory() {
        if let encodedHistory = try? JSONEncoder().encode(searchHistory) {
            searchHistoryData = encodedHistory
        }
    }
    
    private func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        searchHistory.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        searchHistory.insert(trimmedQuery, at: 0)
        
        if searchHistory.count > 10 {
            searchHistory = Array(searchHistory.prefix(10))
        }
        
        saveSearchHistory()
    }
    
    private func removeFromSearchHistory(at index: Int) {
        guard index < searchHistory.count else { return }
        searchHistory.remove(at: index)
        saveSearchHistory()
    }
    
    private func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    
    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if searchMode == .service {
            performServiceSearch()
        } else {
            performTMDBSearch()
        }
    }
    
    private func performTMDBSearch() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await tmdbService.searchMulti(query: searchText)
                
                await MainActor.run {
                    let filteredResults = contentFilter.filterSearchResults(results)
                    self.searchResults = filteredResults
                    self.isLoading = false
                    if !filteredResults.isEmpty {
                        self.addToSearchHistory(self.searchText)
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
    
    private func performServiceSearch() {
        guard let service = selectedService else {
            errorMessage = "Please select a service first."
            return
        }
        
        isLoading = true
        errorMessage = nil
        serviceSearchResults = []
        
        jsController.fetchJsSearchResults(keyword: searchText, module: service) { items in
            self.isLoading = false
            if items.isEmpty {
                self.serviceSearchResults = []
            } else {
                self.serviceSearchResults = items
                self.addToSearchHistory(self.searchText)
            }
        }
    }
}

struct SearchBarLuna: View {
    @State private var debounceTimer: Timer?
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search...", text: $text, onCommit: onSearchButtonClicked)
                .padding(7)
                .padding(.horizontal, 25)
#if !os(tvOS)
                .background(Color(.systemGray6))
#endif
                .cornerRadius(8)
                .contentShape(Rectangle())
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
    }
}

struct ServiceSearchResultCard: View {
    let item: SearchItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(URL(string: item.imageUrl))
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .cornerRadius(10)
                .clipped()
            
            Text(item.title)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}
