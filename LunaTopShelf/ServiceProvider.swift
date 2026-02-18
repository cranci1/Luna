import Foundation
import TVServices

private enum LunaAppGroup {
    static let identifier = "group.me.cranci.sora"

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

private enum ProfileScopedKeys {
    static let continueWatchingBaseV2 = "topShelf.continueWatching.v2"
    static let continueWatchingBaseV1 = "topShelf.continueWatching.v1"

    static func resolveContinueWatchingData(defaults: UserDefaults) -> Data? {
        let scopedV2 = scopedKey(continueWatchingBaseV2)
        let scopedV1 = scopedKey(continueWatchingBaseV1)

        if let data = defaults.data(forKey: scopedV2) { return data }
        if let data = defaults.data(forKey: scopedV1) { return data }

        // Legacy fallback (pre-profile)
        if let legacy = defaults.data(forKey: continueWatchingBaseV2) {
            defaults.set(legacy, forKey: scopedV2)
            return legacy
        }
        if let legacy = defaults.data(forKey: continueWatchingBaseV1) {
            defaults.set(legacy, forKey: scopedV1)
            return legacy
        }

        return nil
    }

    private static func scopedKey(_ base: String) -> String {
        let safe = sanitizedProfileIdentifier(currentProfileID())
        return "\(base).\(safe)"
    }

    private static func currentProfileID() -> String {
        let manager = TVUserManager()

        if #available(tvOS 16.0, *) {
            if let identifier = manager.currentUserIdentifier {
                return identifier
            }

            return manager.shouldStorePreferencesForCurrentUser ? "currentUser" : "default"
        } else {
            return manager.currentUserIdentifier ?? "default"
        }
    }

    private static func sanitizedProfileIdentifier(_ raw: String) -> String {
        guard raw.isEmpty == false else { return "default" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let trimmed = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let limited = trimmed.isEmpty ? "default" : String(trimmed.prefix(64))
        return limited
    }
}

private struct TopShelfContinueWatchingEntry: Codable, Identifiable {
    enum MediaKind: String, Codable {
        case movie
        case episode
    }

    let id: String
    let kind: MediaKind
    let tmdbId: Int
    let title: String
    let posterURL: String?
    let progress: Double
    let currentTime: Double
    let totalDuration: Double
    let lastUpdated: Date
    let displayLinkURL: String
    let playLinkURL: String
    let deepLinkURL: String?

    let seasonNumber: Int?
    let episodeNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind, tmdbId, title, posterURL, progress, currentTime, totalDuration, lastUpdated
        case displayLinkURL, playLinkURL
        case deepLinkURL
        case seasonNumber, episodeNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(MediaKind.self, forKey: .kind)
        tmdbId = try container.decode(Int.self, forKey: .tmdbId)
        title = try container.decode(String.self, forKey: .title)
        posterURL = try container.decodeIfPresent(String.self, forKey: .posterURL)
        progress = try container.decode(Double.self, forKey: .progress)
        currentTime = try container.decode(Double.self, forKey: .currentTime)
        totalDuration = try container.decode(Double.self, forKey: .totalDuration)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)

        let legacyDeepLink = try container.decodeIfPresent(String.self, forKey: .deepLinkURL)
        displayLinkURL = (try container.decodeIfPresent(String.self, forKey: .displayLinkURL)) ?? legacyDeepLink ?? "luna://"
        playLinkURL = (try container.decodeIfPresent(String.self, forKey: .playLinkURL)) ?? legacyDeepLink ?? "luna://"
        deepLinkURL = legacyDeepLink

        seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber)
        episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
    }
}

final class ServiceProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        guard let defaults = LunaAppGroup.userDefaults,
              let data = ProfileScopedKeys.resolveContinueWatchingData(defaults: defaults),
              let entries = try? JSONDecoder().decode([TopShelfContinueWatchingEntry].self, from: data)
        else {
            completionHandler(nil)
            return
        }

        let items: [TVTopShelfSectionedItem] = entries.map { entry in
            let item = TVTopShelfSectionedItem(identifier: entry.id)
            item.title = entry.title
            item.playbackProgress = max(0, min(entry.progress, 1))
            item.imageShape = .poster

            if let posterURLString = entry.posterURL,
               let posterURL = URL(string: posterURLString) {
                item.setImageURL(posterURL, for: .screenScale1x)
                item.setImageURL(posterURL, for: .screenScale2x)
            }

            if let displayURL = URL(string: entry.displayLinkURL) {
                item.displayAction = TVTopShelfAction(url: displayURL)
            }
            if let playURL = URL(string: entry.playLinkURL) {
                item.playAction = TVTopShelfAction(url: playURL)
            }

            return item
        }

        guard items.isEmpty == false else {
            completionHandler(nil)
            return
        }

        let collection = TVTopShelfItemCollection(items: items)
        collection.title = "Continue Watching"

        let content = TVTopShelfSectionedContent(sections: [collection])
        completionHandler(content)
    }
}
