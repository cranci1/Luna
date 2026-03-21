//
//  ProgressSyncManager.swift
//  Luna
//
//  Created by Francesco.
//

import Foundation
import SwiftUI
#if os(iOS)
import AuthenticationServices
#endif

private enum SyncProvider: String {
    case trakt
    case anilist
}

private struct OAuthTokenResponse: Codable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
    let refresh_token: String?
    let scope: String?
    let created_at: Int?
}

private struct ProviderSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    var shouldRefreshSoon: Bool {
        guard let expiresAt else { return false }
        return Date().addingTimeInterval(120) >= expiresAt
    }
}

@MainActor
final class ProgressSyncManager: NSObject, ObservableObject {
    static let shared = ProgressSyncManager()

    @Published private(set) var isTraktLoggedIn = false
    @Published private(set) var isAniListLoggedIn = false
    @Published private(set) var traktUsername: String?
    @Published private(set) var aniListUsername: String?
    @Published private(set) var traktSyncEnabled = false
    @Published private(set) var aniListSyncEnabled = false

    private let userDefaults = UserDefaults.standard
    private let networkSession = URLSession.shared

    private var lastPushedProgress: [String: Double] = [:]
    private var lastPushedDate: [String: Date] = [:]

#if os(iOS)
    private var authSession: ASWebAuthenticationSession?
#endif

    private enum DefaultsKey {
        static let traktClientId = "sync.trakt.clientId"
        static let traktClientSecret = "sync.trakt.clientSecret"
        static let aniListClientId = "sync.anilist.clientId"
        static let aniListClientSecret = "sync.anilist.clientSecret"
        static let traktEnabled = "sync.trakt.enabled"
        static let aniListEnabled = "sync.anilist.enabled"
        static let traktUsername = "sync.trakt.username"
        static let aniListUsername = "sync.anilist.username"
    }

    private enum BundledCredentials {
        static let traktClientId = "fab57469b621696ab2a5260010a6c6f7d60ee57c64ab0f4843176fefd33dc19a"
        static let traktClientSecret = "674e7be215c3d49e559963550eb6dbb43582d180834ae0b0bb3b35790db88eb6"
        static let aniListClientId = "36343"
        static let aniListClientSecret = "O0NM6sU1Qlk3CA0wDL0eyenQrnvVN5Gv0Zqtejzw"
    }

    private enum KeychainKey {
        static let traktSession = "sync.trakt.session"
        static let aniListSession = "sync.anilist.session"
    }

    private let callbackScheme = "luna"
    private let traktRedirectURI = "luna://trakt-callback"
    private let aniListRedirectURI = "luna://anilist-callback"

    private override init() {
        super.init()
        reloadState()
    }

    func reloadState() {
        isTraktLoggedIn = loadSession(for: .trakt) != nil
        isAniListLoggedIn = loadSession(for: .anilist) != nil
        traktSyncEnabled = userDefaults.bool(forKey: DefaultsKey.traktEnabled)
        aniListSyncEnabled = userDefaults.bool(forKey: DefaultsKey.aniListEnabled)
        traktUsername = userDefaults.string(forKey: DefaultsKey.traktUsername)
        aniListUsername = userDefaults.string(forKey: DefaultsKey.aniListUsername)

        if isTraktLoggedIn, (traktUsername?.isEmpty ?? true) {
            Task { await refreshTraktUsername() }
        }

        if isAniListLoggedIn, (aniListUsername?.isEmpty ?? true) {
            Task { await refreshAniListUsername() }
        }
    }

    func traktClientId() -> String {
        let value = userDefaults.string(forKey: DefaultsKey.traktClientId)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value! : BundledCredentials.traktClientId
    }

    func traktClientSecret() -> String {
        let value = userDefaults.string(forKey: DefaultsKey.traktClientSecret)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value! : BundledCredentials.traktClientSecret
    }

    func aniListClientId() -> String {
        let value = userDefaults.string(forKey: DefaultsKey.aniListClientId)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value! : BundledCredentials.aniListClientId
    }

    func aniListClientSecret() -> String {
        let value = userDefaults.string(forKey: DefaultsKey.aniListClientSecret)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value! : BundledCredentials.aniListClientSecret
    }

    func saveTraktClientCredentials(clientId: String, clientSecret: String) {
        userDefaults.set(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKey.traktClientId)
        userDefaults.set(clientSecret.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKey.traktClientSecret)
    }

    func saveAniListClientCredentials(clientId: String, clientSecret: String) {
        userDefaults.set(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKey.aniListClientId)
        userDefaults.set(clientSecret.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKey.aniListClientSecret)
    }

    func setTraktSyncEnabled(_ enabled: Bool) {
        traktSyncEnabled = enabled
        userDefaults.set(enabled, forKey: DefaultsKey.traktEnabled)
    }

    func setAniListSyncEnabled(_ enabled: Bool) {
        aniListSyncEnabled = enabled
        userDefaults.set(enabled, forKey: DefaultsKey.aniListEnabled)
    }

    func logoutTrakt() {
        SyncKeychainStore.remove(KeychainKey.traktSession)
        isTraktLoggedIn = false
        traktUsername = nil
        userDefaults.removeObject(forKey: DefaultsKey.traktUsername)
    }

    func logoutAniList() {
        SyncKeychainStore.remove(KeychainKey.aniListSession)
        isAniListLoggedIn = false
        aniListUsername = nil
        userDefaults.removeObject(forKey: DefaultsKey.aniListUsername)
    }

#if os(iOS)
    func loginTrakt() async throws {
        let clientId = traktClientId()
        let clientSecret = traktClientSecret()
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            throw SyncError.missingClientCredentials("Trakt client id/secret are required")
        }

        let state = UUID().uuidString
        var components = URLComponents(string: "https://trakt.tv/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: traktRedirectURI),
            URLQueryItem(name: "state", value: state)
        ]

        guard let authURL = components?.url else { throw SyncError.invalidAuthURL }

        let callbackURL = try await runAuthSession(url: authURL)
        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = callbackComponents.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw SyncError.authorizationFailed("Trakt authorization response is invalid")
        }

        let payload: [String: Any] = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": traktRedirectURI,
            "grant_type": "authorization_code"
        ]

        let token: OAuthTokenResponse = try await postJSON(
            url: "https://api.trakt.tv/oauth/token",
            payload: payload,
            additionalHeaders: [:]
        )

        saveSession(token, for: .trakt)
        isTraktLoggedIn = true
        await refreshTraktUsername()
        Logger.shared.log("Trakt login successful", type: "Sync")
    }

    func loginAniList() async throws {
        let clientId = aniListClientId()
        let clientSecret = aniListClientSecret()
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            throw SyncError.missingClientCredentials("AniList client id/secret are required")
        }

        var components = URLComponents(string: "https://anilist.co/api/v2/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: aniListRedirectURI),
            URLQueryItem(name: "response_type", value: "code")
        ]

        guard let authURL = components?.url else { throw SyncError.invalidAuthURL }

        let callbackURL = try await runAuthSession(url: authURL)
        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw SyncError.authorizationFailed("AniList authorization response is invalid")
        }

        let payload: [String: Any] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": aniListRedirectURI,
            "code": code
        ]

        let token: OAuthTokenResponse = try await postJSON(
            url: "https://anilist.co/api/v2/oauth/token",
            payload: payload,
            additionalHeaders: [:]
        )

        saveSession(token, for: .anilist)
        isAniListLoggedIn = true
        await refreshAniListUsername()
        Logger.shared.log("AniList login successful", type: "Sync")
    }

    private func runAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(throwing: SyncError.authorizationFailed("Authentication was cancelled"))
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            if authSession?.start() != true {
                continuation.resume(throwing: SyncError.authorizationFailed("Unable to start authentication"))
            }
        }
    }
#else
    func loginTrakt() async throws { throw SyncError.unsupportedPlatform }
    func loginAniList() async throws { throw SyncError.unsupportedPlatform }
#endif

    private func refreshTraktUsername() async {
        do {
            let token = try await validToken(for: .trakt)
            let clientId = traktClientId()
            guard !clientId.isEmpty else { return }

            let data = try await getRaw(
                url: "https://api.trakt.tv/users/settings",
                additionalHeaders: [
                    "Authorization": "Bearer \(token)",
                    "trakt-api-version": "2",
                    "trakt-api-key": clientId
                ]
            )

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let user = json["user"] as? [String: Any] else {
                return
            }

            let resolvedName = (user["username"] as? String) ?? (user["name"] as? String)
            let cleanName = resolvedName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cleanName, !cleanName.isEmpty {
                traktUsername = cleanName
                userDefaults.set(cleanName, forKey: DefaultsKey.traktUsername)
            }
        } catch {
            Logger.shared.log("Failed to load Trakt username: \(error.localizedDescription)", type: "Sync")
        }
    }

    private func refreshAniListUsername() async {
        do {
            let token = try await validToken(for: .anilist)
            let payload: [String: Any] = [
                "query": "query { Viewer { name } }"
            ]

            let data = try await postJSONRaw(
                url: "https://graphql.anilist.co",
                payload: payload,
                additionalHeaders: [
                    "Authorization": "Bearer \(token)"
                ]
            )

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObject = json["data"] as? [String: Any],
                  let viewer = dataObject["Viewer"] as? [String: Any],
                  let name = viewer["name"] as? String else {
                return
            }

            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanName.isEmpty {
                aniListUsername = cleanName
                userDefaults.set(cleanName, forKey: DefaultsKey.aniListUsername)
            }
        } catch {
            Logger.shared.log("Failed to load AniList username: \(error.localizedDescription)", type: "Sync")
        }
    }

    func pushMovieProgress(tmdbId: Int, title: String, progress: Double) {
        Task {
            await pushToProviders(movieId: tmdbId, title: title, progress: progress)
        }
    }

    func pushEpisodeProgress(showId: Int, showTitle: String?, seasonNumber: Int, episodeNumber: Int, progress: Double) {
        Task {
            await pushToProviders(showId: showId, showTitle: showTitle, seasonNumber: seasonNumber, episodeNumber: episodeNumber, progress: progress)
        }
    }

    private func pushToProviders(movieId: Int, title: String, progress: Double) async {
        let safeProgress = min(max(progress, 0), 1)
        guard shouldPush(identifier: "movie_\(movieId)", progress: safeProgress) else { return }

        if traktSyncEnabled {
            do {
                try await pushTraktMovieProgress(tmdbId: movieId, progress: safeProgress)
            } catch {
                Logger.shared.log("Trakt movie push failed: \(error.localizedDescription)", type: "Sync")
            }
        }

        if aniListSyncEnabled {
            do {
                try await pushAniListMovieProgress(title: title, progress: safeProgress)
            } catch {
                Logger.shared.log("AniList movie push failed: \(error.localizedDescription)", type: "Sync")
            }
        }
    }

    private func pushToProviders(showId: Int, showTitle: String?, seasonNumber: Int, episodeNumber: Int, progress: Double) async {
        let safeProgress = min(max(progress, 0), 1)
        let identifier = "episode_\(showId)_\(seasonNumber)_\(episodeNumber)"
        guard shouldPush(identifier: identifier, progress: safeProgress) else { return }

        if traktSyncEnabled {
            do {
                try await pushTraktEpisodeProgress(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber, progress: safeProgress)
            } catch {
                Logger.shared.log("Trakt episode push failed: \(error.localizedDescription)", type: "Sync")
            }
        }

        if aniListSyncEnabled, let showTitle, !showTitle.isEmpty {
            do {
                try await pushAniListEpisodeProgress(showTitle: showTitle, episodeNumber: episodeNumber, progress: safeProgress)
            } catch {
                Logger.shared.log("AniList episode push failed: \(error.localizedDescription)", type: "Sync")
            }
        }
    }

    private func shouldPush(identifier: String, progress: Double) -> Bool {
        let now = Date()
        let previousProgress = lastPushedProgress[identifier] ?? 0
        let previousDate = lastPushedDate[identifier] ?? .distantPast

        let madeLargeProgressJump = abs(progress - previousProgress) >= 0.03
        let isCompletionEdge = progress >= 0.95 && previousProgress < 0.95
        let hasIntervalElapsed = now.timeIntervalSince(previousDate) >= 45

        let shouldPush = isCompletionEdge || (madeLargeProgressJump && hasIntervalElapsed)
        if shouldPush {
            lastPushedProgress[identifier] = progress
            lastPushedDate[identifier] = now
        }

        return shouldPush
    }

    private func pushTraktMovieProgress(tmdbId: Int, progress: Double) async throws {
        guard isTraktLoggedIn else { return }
        let token = try await validToken(for: .trakt)
        let clientId = traktClientId()
        guard !clientId.isEmpty else { throw SyncError.missingClientCredentials("Trakt client id is missing") }

        let endpoint = progress >= 0.95 ? "stop" : "pause"
        let payload: [String: Any] = [
            "movie": [
                "ids": ["tmdb": tmdbId]
            ],
            "progress": max(0.1, min(progress * 100, 100))
        ]

        _ = try await postJSONRaw(
            url: "https://api.trakt.tv/scrobble/\(endpoint)",
            payload: payload,
            additionalHeaders: [
                "Authorization": "Bearer \(token)",
                "trakt-api-version": "2",
                "trakt-api-key": clientId
            ]
        )
    }

    private func pushTraktEpisodeProgress(showId: Int, seasonNumber: Int, episodeNumber: Int, progress: Double) async throws {
        guard isTraktLoggedIn else { return }
        let token = try await validToken(for: .trakt)
        let clientId = traktClientId()
        guard !clientId.isEmpty else { throw SyncError.missingClientCredentials("Trakt client id is missing") }

        let endpoint = progress >= 0.95 ? "stop" : "pause"
        let payload: [String: Any] = [
            "show": [
                "ids": ["tmdb": showId]
            ],
            "episode": [
                "season": seasonNumber,
                "number": episodeNumber
            ],
            "progress": max(0.1, min(progress * 100, 100))
        ]

        _ = try await postJSONRaw(
            url: "https://api.trakt.tv/scrobble/\(endpoint)",
            payload: payload,
            additionalHeaders: [
                "Authorization": "Bearer \(token)",
                "trakt-api-version": "2",
                "trakt-api-key": clientId
            ]
        )
    }

    private func pushAniListMovieProgress(title: String, progress: Double) async throws {
        guard progress >= 0.95, isAniListLoggedIn else { return }
        let token = try await validToken(for: .anilist)
        guard let mediaId = try await resolveAniListMediaId(title: title, token: token) else { return }

        _ = try await upsertAniListProgress(mediaId: mediaId, progress: 1, token: token)
    }

    private func pushAniListEpisodeProgress(showTitle: String, episodeNumber: Int, progress: Double) async throws {
        guard progress >= 0.95, isAniListLoggedIn else { return }
        let token = try await validToken(for: .anilist)
        guard let mediaId = try await resolveAniListMediaId(title: showTitle, token: token) else { return }

        _ = try await upsertAniListProgress(mediaId: mediaId, progress: episodeNumber, token: token)
    }

    private func resolveAniListMediaId(title: String, token: String) async throws -> Int? {
        let query = "query ($search: String) { Media(search: $search, type: ANIME) { id } }"
        let payload: [String: Any] = [
            "query": query,
            "variables": ["search": title]
        ]

        let responseData = try await postJSONRaw(
            url: "https://graphql.anilist.co",
            payload: payload,
            additionalHeaders: [
                "Authorization": "Bearer \(token)"
            ]
        )

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let media = data["Media"] as? [String: Any],
              let mediaId = media["id"] as? Int else {
            return nil
        }

        return mediaId
    }

    private func upsertAniListProgress(mediaId: Int, progress: Int, token: String) async throws -> Data {
        let mutation = "mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus) { SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status) { id } }"
        let payload: [String: Any] = [
            "query": mutation,
            "variables": [
                "mediaId": mediaId,
                "progress": max(progress, 1),
                "status": "CURRENT"
            ]
        ]

        return try await postJSONRaw(
            url: "https://graphql.anilist.co",
            payload: payload,
            additionalHeaders: [
                "Authorization": "Bearer \(token)"
            ]
        )
    }

    private func validToken(for provider: SyncProvider) async throws -> String {
        guard var session = loadSession(for: provider) else {
            throw SyncError.notLoggedIn(provider.rawValue)
        }

        if session.shouldRefreshSoon || session.isExpired {
            if let refreshed = try await refreshSession(for: provider, current: session) {
                session = refreshed
            } else if session.isExpired {
                clearSession(for: provider)
                throw SyncError.tokenExpired(provider.rawValue)
            }
        }

        return session.accessToken
    }

    private func refreshSession(for provider: SyncProvider, current: ProviderSession) async throws -> ProviderSession? {
        guard let refreshToken = current.refreshToken, !refreshToken.isEmpty else {
            return nil
        }

        switch provider {
        case .trakt:
            let payload: [String: Any] = [
                "refresh_token": refreshToken,
                "client_id": traktClientId(),
                "client_secret": traktClientSecret(),
                "redirect_uri": traktRedirectURI,
                "grant_type": "refresh_token"
            ]

            let token: OAuthTokenResponse = try await postJSON(
                url: "https://api.trakt.tv/oauth/token",
                payload: payload,
                additionalHeaders: [:]
            )

            let newSession = sessionFromTokenResponse(token)
            saveSession(newSession, for: provider)
            Logger.shared.log("Trakt token refreshed", type: "Sync")
            return newSession

        case .anilist:
            let payload: [String: Any] = [
                "grant_type": "refresh_token",
                "client_id": aniListClientId(),
                "client_secret": aniListClientSecret(),
                "refresh_token": refreshToken
            ]

            let token: OAuthTokenResponse = try await postJSON(
                url: "https://anilist.co/api/v2/oauth/token",
                payload: payload,
                additionalHeaders: [:]
            )

            let newSession = sessionFromTokenResponse(token)
            saveSession(newSession, for: provider)
            Logger.shared.log("AniList token refreshed", type: "Sync")
            return newSession
        }
    }

    private func postJSON<T: Decodable>(url: String, payload: [String: Any], additionalHeaders: [String: String]) async throws -> T {
        let data = try await postJSONRaw(url: url, payload: payload, additionalHeaders: additionalHeaders)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<empty>"
            throw SyncError.requestFailed("Decoding failed: \(raw)")
        }
    }

    private func postJSONRaw(url: String, payload: [String: Any], additionalHeaders: [String: String]) async throws -> Data {
        guard let endpoint = URL(string: url) else { throw SyncError.invalidEndpoint(url) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (header, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await networkSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.requestFailed("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw SyncError.requestFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        return data
    }

    private func getRaw(url: String, additionalHeaders: [String: String]) async throws -> Data {
        guard let endpoint = URL(string: url) else { throw SyncError.invalidEndpoint(url) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        for (header, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await networkSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.requestFailed("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw SyncError.requestFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        return data
    }

    private func saveSession(_ token: OAuthTokenResponse, for provider: SyncProvider) {
        let session = sessionFromTokenResponse(token)
        saveSession(session, for: provider)
    }

    private func saveSession(_ session: ProviderSession, for provider: SyncProvider) {
        do {
            let data = try JSONEncoder().encode(session)
            guard let text = String(data: data, encoding: .utf8) else { return }
            SyncKeychainStore.set(text, for: keychainKey(for: provider))
        } catch {
            Logger.shared.log("Failed to encode \(provider.rawValue) session: \(error.localizedDescription)", type: "Sync")
        }
    }

    private func clearSession(for provider: SyncProvider) {
        SyncKeychainStore.remove(keychainKey(for: provider))
        switch provider {
        case .trakt:
            isTraktLoggedIn = false
            traktUsername = nil
            userDefaults.removeObject(forKey: DefaultsKey.traktUsername)
        case .anilist:
            isAniListLoggedIn = false
            aniListUsername = nil
            userDefaults.removeObject(forKey: DefaultsKey.aniListUsername)
        }
    }

    private func loadSession(for provider: SyncProvider) -> ProviderSession? {
        guard let text = SyncKeychainStore.get(keychainKey(for: provider)),
              let data = text.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(ProviderSession.self, from: data)
    }

    private func keychainKey(for provider: SyncProvider) -> String {
        switch provider {
        case .trakt:
            return KeychainKey.traktSession
        case .anilist:
            return KeychainKey.aniListSession
        }
    }

    private func sessionFromTokenResponse(_ token: OAuthTokenResponse) -> ProviderSession {
        let expiresAt: Date?
        if let expiresIn = token.expires_in {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            expiresAt = nil
        }

        return ProviderSession(
            accessToken: token.access_token,
            refreshToken: token.refresh_token,
            expiresAt: expiresAt
        )
    }
}

enum SyncError: LocalizedError {
    case unsupportedPlatform
    case missingClientCredentials(String)
    case invalidAuthURL
    case invalidEndpoint(String)
    case authorizationFailed(String)
    case requestFailed(String)
    case notLoggedIn(String)
    case tokenExpired(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "This feature is currently available on iOS only."
        case .missingClientCredentials(let value):
            return value
        case .invalidAuthURL:
            return "Unable to build authentication URL."
        case .invalidEndpoint(let endpoint):
            return "Invalid endpoint: \(endpoint)"
        case .authorizationFailed(let reason):
            return reason
        case .requestFailed(let reason):
            return reason
        case .notLoggedIn(let provider):
            return "You are not logged in to \(provider)."
        case .tokenExpired(let provider):
            return "\(provider) token has expired. Please login again."
        }
    }
}

#if os(iOS)
extension ProgressSyncManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let activeScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = activeScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        return ASPresentationAnchor()
    }
}
#endif
