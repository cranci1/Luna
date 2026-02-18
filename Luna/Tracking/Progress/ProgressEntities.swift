import Foundation
import CoreData

@objc(MovieProgressEntity)
public class MovieProgressEntity: NSManagedObject { }

extension MovieProgressEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MovieProgressEntity> {
        NSFetchRequest<MovieProgressEntity>(entityName: "MovieProgressEntity")
    }

    @NSManaged public var id: Int64
    @NSManaged public var title: String?
    @NSManaged public var currentTime: Double
    @NSManaged public var totalDuration: Double
    @NSManaged public var isWatched: Bool
    @NSManaged public var lastUpdated: Date?
}

extension MovieProgressEntity: Identifiable { }

extension MovieProgressEntity {
    var asModel: MovieProgressEntry {
        var model = MovieProgressEntry(id: Int(id), title: title ?? "")
        model.currentTime = currentTime
        model.totalDuration = totalDuration
        model.isWatched = isWatched
        model.lastUpdated = lastUpdated ?? Date()
        return model
    }

    func apply(from model: MovieProgressEntry) {
        id = Int64(model.id)
        title = model.title
        currentTime = model.currentTime
        totalDuration = model.totalDuration
        isWatched = model.isWatched
        lastUpdated = model.lastUpdated
    }
}

@objc(EpisodeProgressEntity)
public class EpisodeProgressEntity: NSManagedObject { }

extension EpisodeProgressEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EpisodeProgressEntity> {
        NSFetchRequest<EpisodeProgressEntity>(entityName: "EpisodeProgressEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var showId: Int64
    @NSManaged public var seasonNumber: Int64
    @NSManaged public var episodeNumber: Int64
    @NSManaged public var currentTime: Double
    @NSManaged public var totalDuration: Double
    @NSManaged public var isWatched: Bool
    @NSManaged public var lastUpdated: Date?
}

extension EpisodeProgressEntity: Identifiable { }

extension EpisodeProgressEntity {
    var asModel: EpisodeProgressEntry {
        let showIdInt = Int(showId)
        let seasonInt = Int(seasonNumber)
        let episodeInt = Int(episodeNumber)

        // If id was never persisted (older versions), reconstruct it.
        let resolvedId = id ?? "ep_\(showIdInt)_s\(seasonInt)_e\(episodeInt)"

        return EpisodeProgressEntry(
            id: resolvedId,
            showId: showIdInt,
            seasonNumber: seasonInt,
            episodeNumber: episodeInt,
            currentTime: currentTime,
            totalDuration: totalDuration,
            isWatched: isWatched,
            lastUpdated: lastUpdated ?? Date()
        )
    }

    func apply(from model: EpisodeProgressEntry) {
        id = model.id
        showId = Int64(model.showId)
        seasonNumber = Int64(model.seasonNumber)
        episodeNumber = Int64(model.episodeNumber)
        currentTime = model.currentTime
        totalDuration = model.totalDuration
        isWatched = model.isWatched
        lastUpdated = model.lastUpdated
    }
}
