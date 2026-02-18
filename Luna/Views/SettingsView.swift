//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import Foundation
import SwiftUI
import CloudKit

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    @AppStorage("animeCatalogSource") private var animeCatalogSource = AnimeCatalogSource.tmdb.rawValue
    @AppStorage("showKanzen") private var showKanzen: Bool = false

    @StateObject private var algorithmManager = AlgorithmManager.shared

    let languages = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es-ES", "Spanish (Spain)"),
        ("es-MX", "Spanish (Mexico)"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("zh-CN", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)"),
        ("ru-RU", "Russian"),
        ("ar-SA", "Arabic"),
        ("hi-IN", "Hindi"),
        ("th-TH", "Thai"),
        ("tr-TR", "Turkish"),
        ("pl-PL", "Polish"),
        ("nl-NL", "Dutch"),
        ("sv-SE", "Swedish"),
        ("da-DK", "Danish"),
        ("no-NO", "Norwegian"),
        ("fi-FI", "Finnish")
    ]
    
    var body: some View {
        #if os(tvOS)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    sidebarView
                        .frame(width: geometry.size.width * 0.4)
                        .frame(maxHeight: .infinity)

                    NavigationStack {
                        settingsContent
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        #else
            if #available(iOS 16.0, *) {
                NavigationStack {
                    settingsContent
                }
            } else {
                NavigationView {
                    settingsContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        #endif
    }

    private var sidebarView: some View {
        VStack(spacing: 30) {
            Image("Luna")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 500, height: 500)
                .background(colorScheme == .dark ? .black : .white)
                .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                .shadow(radius: 10)

            VStack(spacing: 15) {
                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)

                Text("Copyright © \(String(Calendar.current.component(.year, from: Date()))) Luna by Cranci")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
    }

    private var settingsContent: some View {
        List {
            Section {
                NavigationLink(destination: LanguageSelectionView(selectedLanguage: $selectedLanguage, languages: languages)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Informations Language")
                        }
                        
                        Spacer()
                        
                        Text(languages.first { $0.0 == selectedLanguage }?.1 ?? "English (US)")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(destination: TMDBFiltersView()) {
                    Text("Content Filters")
                }

                NavigationLink(destination: AnimeCatalogSourceView(selectedSource: $animeCatalogSource)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Anime Catalog Source")
                        }

                        Spacer()

                        Text(AnimeCatalogSource(rawValue: animeCatalogSource)?.displayName ?? AnimeCatalogSource.tmdb.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("TMDB SETTINGS")
                    .fontWeight(.bold)
            } footer: {
                Text("Configure language preferences, content filtering, and the source used for anime catalogs.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            
            Section {
                NavigationLink(destination: AlgorithmSelectionView()) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Matching Algorithm")
                        }
                        
                        Spacer()
                        
                        Text(algorithmManager.selectedAlgorithm.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("SEARCH SETTINGS")
                    .fontWeight(.bold)
            } footer: {
                Text("Choose the algorithm used to match and rank search results.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            
            Section {
                NavigationLink(destination: PlayerSettingsView()) {
                    Text("Media Player")
                }
                
                NavigationLink(destination: AlternativeUIView()) {
                    Text("Appearance")
                }
                
                NavigationLink(destination: ServicesView()) {
                    Text("Services")
                }

                NavigationLink(destination: StorageView()) {
                    Text("Storage")
                }

                NavigationLink(destination: CloudKitDiagnosticsView()) {
                    Text("CloudKit Sync & Debug")
                }

                NavigationLink(destination: LoggerView()) {
                    Text("Logger")
                }
            } header: {
                Text("MISCELLANEOUS")
                    .fontWeight(.bold)
            } footer: {
                Text("")
                    .padding(.bottom)
            }

            #if !os(tvOS)
            Section{
                Text("Switch to Kanzen")
                    .onTapGesture {
                        showKanzen = true
                    }
            }
            header:{
                Text("OTHERS")
                    .fontWeight(.bold)
            }
            #endif
        }
        #if !os(tvOS)
            .navigationTitle("Settings")
        #else
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #endif
    }
}

// MARK: - CloudKit Diagnostics

private struct CloudKitDiagnosticsView: View {
    @State private var iCloudContainerID: String = Bundle.main.iCloudContainerID ?? "—"
    @State private var accountStatusText: String = "—"
    @State private var profileID: String = TVOSProfileManager.shared.currentProfileID

    @State private var servicesStatus: ServiceStore.StorageStatus = ServiceStore.shared.status()
    @State private var servicesCount: Int = 0
    @State private var servicesStorePath: String = "—"
    @State private var servicesLastError: String? = nil

    @State private var progressStatus: ProgressStore.StorageStatus = ProgressStore.shared.status()
    @State private var progressMoviesCount: Int = 0
    @State private var progressEpisodesCount: Int = 0
    @State private var progressStorePath: String = "—"
    @State private var progressLastError: String? = nil
    @State private var legacyProgressBytes: Int = 0

    @State private var showResetServicesConfirm = false
    @State private var showResetProgressConfirm = false
    @State private var actionMessage: String? = nil

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Build Storage")
                    Spacer()
                    #if CLOUDKIT
                        Text("CLOUDKIT")
                            .foregroundColor(.green)
                    #else
                        Text("LOCAL")
                            .foregroundColor(.orange)
                    #endif
                }

                HStack {
                    Text("iCloud Container")
                    Spacer()
                    Text(iCloudContainerID)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .maybeTextSelectionEnabled(true)
                }

                #if os(tvOS)
                HStack {
                    Text("Apple TV Profile")
                    Spacer()
                    Text(profileID)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .maybeTextSelectionEnabled(true)
                }

                HStack {
                    Text("tvOS User Identifier")
                    Spacer()
                    Text(TVOSProfileManager.debugCurrentUserIdentifier() ?? "nil")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .maybeTextSelectionEnabled(true)
                }

                if let shouldStore = TVOSProfileManager.debugShouldStorePreferencesForCurrentUser() {
                    HStack {
                        Text("Store Prefs for Current User")
                        Spacer()
                        Text(shouldStore ? "Yes" : "No")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                #endif

                HStack {
                    Text("Account Status")
                    Spacer()
                    Text(accountStatusText)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("CLOUDKIT")
                    .fontWeight(.bold)
            } footer: {
                Text("If Account Status is not ‘Available’, CloudKit sync will not work.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }

            Section {
                statusRow(title: "Status", status: servicesStatus.description, symbol: servicesStatus.symbol, tint: servicesStatus.tint)
                keyValueRow(title: "Entities", value: "\(servicesCount)")
                keyValueRow(title: "Store Path", value: servicesStorePath, selectable: true)

                if let servicesLastError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last Load Error")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(servicesLastError)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .maybeTextSelectionEnabled(true)
                    }
                }

                Button("Manual Sync") {
                    Task {
                        await ServiceStore.shared.syncManually()
                        refresh()
                        actionMessage = "ServiceStore: sync requested"
                    }
                }

                Button(role: .destructive) {
                    showResetServicesConfirm = true
                } label: {
                    Text("Reset Local Services Store")
                }
            } header: {
                Text("SERVICES")
                    .fontWeight(.bold)
            } footer: {
                Text("Reset deletes the local sqlite cache. After reset, force-quit and relaunch to re-create the store and re-sync from CloudKit.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }

            Section {
                statusRow(title: "Status", status: progressStatus.description, symbol: progressStatus.symbol, tint: progressStatus.tint)
                keyValueRow(title: "Movies", value: "\(progressMoviesCount)")
                keyValueRow(title: "Episodes", value: "\(progressEpisodesCount)")
                keyValueRow(title: "Store Path", value: progressStorePath, selectable: true)
                keyValueRow(title: "Legacy UserDefaults", value: legacyProgressBytes > 0 ? ByteCountFormatter.string(fromByteCount: Int64(legacyProgressBytes), countStyle: .file) : "—")

                if let progressLastError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last Load Error")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(progressLastError)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .maybeTextSelectionEnabled(true)
                    }
                }

                Button("Manual Sync") {
                    Task {
                        await ProgressStore.shared.syncManually()
                        refresh()
                        actionMessage = "ProgressStore: sync requested"
                    }
                }

                Button("Clear Legacy UserDefaults Progress", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: "watchProgressData")
                    refresh()
                    actionMessage = "Cleared legacy progress key"
                }

                Button(role: .destructive) {
                    showResetProgressConfirm = true
                } label: {
                    Text("Reset Local Progress Store")
                }
            } header: {
                Text("PROGRESS")
                    .fontWeight(.bold)
            } footer: {
                Text("If progress doesn’t appear across devices, check that Status is ‘Synced and ready’, and that the store path exists. Resetting the local store often fixes stuck migrations or corrupted sqlite caches.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .foregroundColor(.secondary)
                }
            }
        }
        #if os(tvOS)
            .listStyle(.grouped)
            .padding(.horizontal, 50)
            .scrollClipDisabled()
        #else
            .navigationTitle("CloudKit Sync & Debug")
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            refresh()
        }
        #if os(tvOS)
        .onReceive(NotificationCenter.default.publisher(for: TVOSProfileManager.profileDidChangeNotification)) { _ in
            refresh()
        }
        #endif
        .alert("Reset Local Services Store?", isPresented: $showResetServicesConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                let err = ServiceStore.shared.debugResetLocalStoreFiles()
                refresh()
                actionMessage = err == nil ? "Services store files deleted. Force-quit and relaunch." : "Reset failed: \(err ?? "Unknown error")"
            }
        } message: {
            Text("This deletes the local sqlite cache for services. It does not directly delete your CloudKit data. After reset, force-quit and relaunch.")
        }
        .alert("Reset Local Progress Store?", isPresented: $showResetProgressConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                let err = ProgressStore.shared.debugResetLocalStoreFiles()
                refresh()
                actionMessage = err == nil ? "Progress store files deleted. Force-quit and relaunch." : "Reset failed: \(err ?? "Unknown error")"
            }
        } message: {
            Text("This deletes the local sqlite cache for progress. It does not directly delete your CloudKit data. After reset, force-quit and relaunch.")
        }
    }

    private func refresh() {
        iCloudContainerID = Bundle.main.iCloudContainerID ?? "—"
        profileID = TVOSProfileManager.shared.currentProfileID

        servicesStatus = ServiceStore.shared.status()
        servicesCount = ServiceStore.shared.getEntities().count
        servicesStorePath = ServiceStore.shared.debugStoreURL()?.path ?? "—"
        servicesLastError = ServiceStore.shared.debugLastLoadError()

        progressStatus = ProgressStore.shared.status()
        let counts = ProgressStore.shared.counts()
        progressMoviesCount = counts.movies
        progressEpisodesCount = counts.episodes
        progressStorePath = ProgressStore.shared.debugStoreURL()?.path ?? "—"
        progressLastError = ProgressStore.shared.debugLastLoadError()
        legacyProgressBytes = UserDefaults.standard.data(forKey: "watchProgressData")?.count ?? 0

        Task {
            await refreshAccountStatus()
        }
    }

    private func refreshAccountStatus() async {
        #if CLOUDKIT
        guard iCloudContainerID != "—" else {
            await MainActor.run { accountStatusText = "Missing container ID" }
            return
        }

        do {
            let status = try await CKContainer(identifier: iCloudContainerID).accountStatus()
            let text: String
            switch status {
            case .available: text = "Available"
            case .noAccount: text = "No iCloud Account"
            case .restricted: text = "Restricted"
            case .couldNotDetermine: text = "Could Not Determine"
            case .temporarilyUnavailable: text = "Temporarily Unavailable"
            @unknown default: text = "Unknown"
            }
            await MainActor.run { accountStatusText = text }
        } catch {
            await MainActor.run { accountStatusText = "Error: \(error.localizedDescription)" }
        }
        #else
        await MainActor.run { accountStatusText = "LOCAL build" }
        #endif
    }

    private func statusRow(title: String, status: String, symbol: String, tint: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundColor(tint)
                Text(status)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func keyValueRow(title: String, value: String, selectable: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            valueText(value, selectable: selectable)
        }
    }

    @ViewBuilder
    private func valueText(_ value: String, selectable: Bool) -> some View {
        let text = Text(value)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.trailing)

        text.maybeTextSelectionEnabled(selectable)
    }
}

private extension View {
    @ViewBuilder
    func maybeTextSelectionEnabled(_ enabled: Bool) -> some View {
        #if os(tvOS)
        self
        #else
        if enabled {
            self.textSelection(.enabled)
        } else {
            self
        }
        #endif
    }
}
