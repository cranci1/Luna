//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

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
    
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var contentFilter = TMDBContentFilter.shared
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
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
                    HStack(spacing: 8) {
                        TextField("Search...", text: $searchText)
#if os(iOS)
                            .padding(7)
                            .padding(.horizontal, 25)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                                    
                                    if !searchText.isEmpty {
                                        Button(action: {
                                            searchText = ""
                                            searchResults = []
                                            errorMessage = nil
                                        }) {
                                            Image(systemName: "multiply.circle.fill")
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 8)
                                        }
                                    }
                                }
                            )
#endif
                            .onSubmit {
                                performSearchOrDownloadService()
                            }
                            .onChangeComp(of: searchText) { _, newValue in
                                if newValue.isEmpty {
                                    searchResults = []
                                    errorMessage = nil
                                }
                            }
                    }
                    
                    if !searchResults.isEmpty {
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
                .animation(.easeInOut(duration: 0.2), value: searchResults.isEmpty)
            }
            .padding()
            
            if isLoading || serviceManager.isDownloading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    if serviceManager.isDownloading {
                        DownloadProgressView(
                            progress: serviceManager.downloadProgress,
                            message: serviceManager.downloadMessage
                        )
                            .padding(.top, 8)
                    } else {
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
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
                        performSearchOrDownloadService()
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                if searchHistory.isEmpty {
                    VStack {
                        Image(systemName: "magnifyingglass.circle")
                            .imageScale(.large)
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Search Movies & TV Shows")
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
                                    performSearchOrDownloadService()
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
        .navigationTitle("Search")
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
        .onAppear {
            loadSearchHistory()
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
    
    
    private func performSearchOrDownloadService() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        if isJSONURL(searchText) {
            downloadServiceFromURL()
        } else {
            performSearch()
        }
    }
    
    private func isJSONURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        
        return url.scheme != nil &&
        (url.pathExtension.lowercased() == "json" ||
         text.lowercased().contains(".json"))
    }
    
    private func downloadServiceFromURL() {
        Task {
            do {
                let wasHandled = await serviceManager.handlePotentialServiceURL(searchText)
                if wasHandled {
                    await MainActor.run {
                        searchText = ""
                        showServiceDownloadAlert = true
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
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
}

#Preview {
    SearchView()
}
