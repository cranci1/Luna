import Foundation

enum AnimeCatalogSource: String, CaseIterable, Identifiable, Codable {
    case tmdb
    case anilist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tmdb:
            return "TMDB"
        case .anilist:
            return "AniList"
        }
    }

    var subtitle: String {
        switch self {
        case .tmdb:
            return "Movies & TV data (default)"
        case .anilist:
            return "Anime-focused catalogs"
        }
    }
}
