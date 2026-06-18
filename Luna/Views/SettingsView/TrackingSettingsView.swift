//
//  TrackingSyncSettingsView.swift
//  Luna
//
//  Created by Francesco.
//

import Sybau
import SwiftUI
import Kingfisher

struct TrackingSettingsView: View {
    @StateObject private var syncManager = ProgressSyncManager.shared

    @State private var traktSyncEnabled = false
    @State private var aniListSyncEnabled = false

    @State private var isTraktLoading = false
    @State private var isAniListLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            traktSection
            aniListSection
            infoSection
        }
        .navigationTitle("Tracking Sync")
        .task {
            loadState()
        }
        .onChange(of: traktSyncEnabled) { value in
            syncManager.setTraktSyncEnabled(value)
        }
        .onChange(of: aniListSyncEnabled) { value in
            syncManager.setAniListSyncEnabled(value)
        }
        .alert("Sync Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var traktSection: some View {
        Section {
            providerCard(
                logoURL: URL(string: "https://cdn.iconscout.com/icon/free/png-512/free-trakt-logo-icon-download-in-svg-png-gif-file-formats--technology-social-media-company-vol-7-pack-logos-icons-2945267.png?f=webp&w=512"),
                providerName: "Trakt.tv",
                isLoading: isTraktLoading,
                isLoggedIn: syncManager.isTraktLoggedIn,
                username: syncManager.traktUsername,
                syncTitle: "Sync shows/movies progress",
                isSyncEnabled: $traktSyncEnabled,
                loginTitle: "Log In with Trakt",
                logoutTitle: "Log Out from Trakt",
                onLogin: {
#if os(iOS)
                    Task {
                        await loginTrakt()
                    }
#endif
                },
                onLogout: {
                    syncManager.logoutTrakt()
                    syncManager.setTraktSyncEnabled(false)
                    traktSyncEnabled = false
                }
            )
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Trakt")
        }
    }

    private var aniListSection: some View {
        Section {
            providerCard(
                logoURL: URL(string: "https://raw.githubusercontent.com/cranci1/Ryu/2f10226aa087154974a70c1ec78aa83a47daced9/Ryu/Assets.xcassets/Listing/Anilist.imageset/anilist.png"),
                providerName: "AniList.co",
                isLoading: isAniListLoading,
                isLoggedIn: syncManager.isAniListLoggedIn,
                username: syncManager.aniListUsername,
                syncTitle: "Sync anime progress",
                isSyncEnabled: $aniListSyncEnabled,
                loginTitle: "Log In with AniList",
                logoutTitle: "Log Out from AniList",
                onLogin: {
#if os(iOS)
                    Task {
                        await loginAniList()
                    }
#endif
                },
                onLogout: {
                    syncManager.logoutAniList()
                    syncManager.setAniListSyncEnabled(false)
                    aniListSyncEnabled = false
                }
            )
            .listRowInsets(EdgeInsets())
        } header: {
            Text("AniList")
        } footer: {
            Text("AniList progress sync is completion-based to avoid incorrect episode counts.")
        }
    }

    private var infoSection: some View {
        Section {
            Text("Trakt receives watch progress updates. AniList updates when an episode/movie reaches completion.\n\ncranci1 and Luna are not affiliated with AniList nor Trakt, push updates may be incorrect sometimes.")
                .font(.footnote)
        } header: {
            Text("How It Works")
        }
    }

    private func loadState() {
        syncManager.reloadState()

        traktSyncEnabled = syncManager.traktSyncEnabled
        aniListSyncEnabled = syncManager.aniListSyncEnabled
    }

    private func loginTrakt() async {
        isTraktLoading = true
        defer { isTraktLoading = false }

        do {
            try await syncManager.loginTrakt()
            syncManager.reloadState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loginAniList() async {
        isAniListLoading = true
        defer { isAniListLoading = false }

        do {
            try await syncManager.loginAniList()
            syncManager.reloadState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func providerCard(
        logoURL: URL?,
        providerName: String,
        isLoading: Bool,
        isLoggedIn: Bool,
        username: String?,
        syncTitle: String,
        isSyncEnabled: Binding<Bool>,
        loginTitle: String,
        logoutTitle: String,
        onLogin: @escaping () -> Void,
        onLogout: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                KFImage(logoURL)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .resizable()
                    .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, 10)

                VStack(alignment: .leading, spacing: 4) {
                    let loginStatusText = {
                        guard let username, !username.isEmpty else { return "Logged in" }
                        return "Logged in as \(username)"
                    }()

                    Text(providerName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(height: 18)
                    } else if isLoggedIn {
                        Text(loginStatusText)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.accentColor)
                            .frame(height: 18)
                    } else {
                        Text("You are not logged in")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .frame(height: 18)
                    }
                }
                .frame(height: 60, alignment: .center)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: 84)

            if isLoggedIn {
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)

                    Toggle(syncTitle, isOn: isSyncEnabled)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
            }

            Divider()
                .padding(.horizontal, 16)

            Button {
#if os(iOS)
                if isLoggedIn {
                    onLogout()
                } else {
                    onLogin()
                }
#endif
            } label: {
                HStack {
                    Image(systemName: isLoggedIn ? "rectangle.portrait.and.arrow.right" : "person.badge.key")
                        .frame(width: 24, height: 24)
                        .foregroundStyle(isLoggedIn ? .red : .accentColor)

                    Text(isLoggedIn ? logoutTitle : loginTitle)
                        .foregroundStyle(isLoggedIn ? .red : .accentColor)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 48)
            }
            .buttonStyle(.borderless)
#if os(iOS)
            .disabled(isLoading)
#else
            .disabled(true)
#endif
        }
    }
}
