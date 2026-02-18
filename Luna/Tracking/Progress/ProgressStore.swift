import Foundation
import CoreData
import SwiftUI

public final class ProgressStore {
    public static let shared = ProgressStore()
    public static let criticalErrorNotification = Notification.Name("ProgressStoreCriticalError")
    static let remoteChangeNotification = Notification.Name("ProgressStoreRemoteChange")

    private var container: NSPersistentContainer? = nil
    private var initializationFailed = false
    private var didAttemptStoreRecovery = false

    private var currentProfileID: String = TVOSProfileManager.shared.currentProfileID
    private var profileObserver: NSObjectProtocol? = nil

    private var lastStoreURL: URL? = nil
    private var lastLoadError: String? = nil

    private var remoteChangeObserver: NSObjectProtocol? = nil

    private let storeLoadGroup = DispatchGroup()
    private var didEnterStoreLoadGroup = false
    private var didFinishStoreLoad = false

    private init() {
#if CLOUDKIT
        initCloudKit()
#else
        initLocal()
#endif

        setupProfileObserver()
    }

    private func initCloudKit() {
        Logger.shared.log("Using CloudKit Storage", type: "CloudKit")
        guard let containerID = Bundle.main.iCloudContainerID else {
            Logger.shared.log("Missing iCloud container id", type: "CloudKit")
            return
        }

        container = NSPersistentCloudKitContainer(name: "ProgressModels")

        guard let description = container?.persistentStoreDescriptions.first else {
            Logger.shared.log("Missing store description", type: "CloudKit")
            return
        }

        configureStoreDescription(description)

        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerID
        )

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        loadPersistentStores()
    }

    private func initLocal() {
        Logger.shared.log("Using Local Storage", type: "CloudKit")
        container = NSPersistentContainer(name: "ProgressModels")

        if let description = container?.persistentStoreDescriptions.first {
            configureStoreDescription(description)
        }

        loadPersistentStores()
    }

    private func configureStoreDescription(_ description: NSPersistentStoreDescription) {
        // tvOS can fail to open the default sqlite path if the directory isn't created yet.
        // Always place the store in an app-writable Application Support subdirectory.
        var storeURL = makeStoreURL(preferred: .applicationSupport, profileID: currentProfileID)
        if ensureParentDirectoryExists(for: storeURL) == false {
            // Fallback: caches is always writable and acceptable for non-critical local state.
            storeURL = makeStoreURL(preferred: .caches, profileID: currentProfileID)
            _ = ensureParentDirectoryExists(for: storeURL)
        }

        migrateLegacyStoreIfNeeded(preferred: .applicationSupport, targetURL: storeURL)
        migrateLegacyStoreIfNeeded(preferred: .caches, targetURL: storeURL)

        description.url = storeURL
        lastStoreURL = storeURL
        Logger.shared.log("ProgressModels store URL: \(storeURL.path)", type: "CloudKit")
    }

    // MARK: - Debug helpers

    func debugStoreURL() -> URL? {
        lastStoreURL ?? container?.persistentStoreDescriptions.first?.url
    }

    func debugLastLoadError() -> String? {
        lastLoadError
    }

    /// Deletes the local sqlite + sidecar files. This does not directly delete CloudKit data.
    /// The app should be force-quit/relaunched afterwards.
    func debugResetLocalStoreFiles() -> String? {
        guard let storeURL = debugStoreURL() else {
            return "Missing store URL"
        }

        let fm = FileManager.default
        let related = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]

        do {
            for url in related {
                if fm.fileExists(atPath: url.path) {
                    try fm.removeItem(at: url)
                }
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private enum StoreBaseDirectory {
        case applicationSupport
        case caches
    }

    private func makeStoreURL(preferred: StoreBaseDirectory, profileID: String) -> URL {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        let libraryBase = library ?? documents ?? fm.temporaryDirectory

        let base: URL
        switch preferred {
        case .applicationSupport:
            base = libraryBase.appendingPathComponent("Application Support", isDirectory: true)
        case .caches:
            let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            base = caches ?? libraryBase.appendingPathComponent("Caches", isDirectory: true)
        }

        let profileFolder = TVOSProfileManager.sanitizedProfileIdentifier(profileID)

        return base
            .appendingPathComponent("ProgressModels", isDirectory: true)
            .appendingPathComponent(profileFolder, isDirectory: true)
            .appendingPathComponent("ProgressModels.sqlite", isDirectory: false)
    }

    private func makeLegacyStoreURL(preferred: StoreBaseDirectory) -> URL {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        let libraryBase = library ?? documents ?? fm.temporaryDirectory

        let base: URL
        switch preferred {
        case .applicationSupport:
            base = libraryBase.appendingPathComponent("Application Support", isDirectory: true)
        case .caches:
            let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            base = caches ?? libraryBase.appendingPathComponent("Caches", isDirectory: true)
        }

        return base
            .appendingPathComponent("ProgressModels", isDirectory: true)
            .appendingPathComponent("ProgressModels.sqlite", isDirectory: false)
    }

    private func migrateLegacyStoreIfNeeded(preferred: StoreBaseDirectory, targetURL: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: targetURL.path) == false else { return }

        let legacyURL = makeLegacyStoreURL(preferred: preferred)
        guard fm.fileExists(atPath: legacyURL.path) else { return }

        _ = ensureParentDirectoryExists(for: targetURL)

        let legacySidecars = [legacyURL, sidecarURL(for: legacyURL, suffix: "-shm"), sidecarURL(for: legacyURL, suffix: "-wal")]
        let targetSidecars = [targetURL, sidecarURL(for: targetURL, suffix: "-shm"), sidecarURL(for: targetURL, suffix: "-wal")]

        for (src, dst) in zip(legacySidecars, targetSidecars) {
            guard fm.fileExists(atPath: src.path) else { continue }
            do {
                if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
                try fm.moveItem(at: src, to: dst)
            } catch {
                Logger.shared.log("Failed to migrate legacy progress store file \(src.lastPathComponent): \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    private func sidecarURL(for baseURL: URL, suffix: String) -> URL {
        URL(fileURLWithPath: baseURL.path + suffix)
    }

    private func setupProfileObserver() {
        #if os(tvOS)
        profileObserver = NotificationCenter.default.addObserver(
            forName: TVOSProfileManager.profileDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let newID = (notification.userInfo?["profileID"] as? String) ?? TVOSProfileManager.shared.currentProfileID
            self.switchToProfile(newID)
        }
        #endif
    }

    private func switchToProfile(_ profileID: String) {
        guard profileID != currentProfileID else { return }
        Logger.shared.log("Switching ProgressStore to profile: \(profileID)", type: "CloudKit")
        currentProfileID = profileID
        resetContainerForProfileChange()
    }

    private func resetContainerForProfileChange() {
        if let observer = remoteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            remoteChangeObserver = nil
        }

        if let container = container {
            container.viewContext.reset()
            let coordinator = container.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }

        container = nil
        initializationFailed = false
        didAttemptStoreRecovery = false
        didEnterStoreLoadGroup = false
        didFinishStoreLoad = false
        lastLoadError = nil
        lastStoreURL = nil

#if CLOUDKIT
        initCloudKit()
#else
        initLocal()
#endif
    }

    @discardableResult
    private func ensureParentDirectoryExists(for fileURL: URL) -> Bool {
        let directoryURL = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return true
        } catch {
            Logger.shared.log("Failed to create store directory \(directoryURL.path): \(error.localizedDescription)", type: "CloudKit")
            return false
        }
    }

    private func attemptStoreRecoveryIfPossible() {
        guard didAttemptStoreRecovery == false else { return }
        didAttemptStoreRecovery = true

        guard let storeURL = container?.persistentStoreDescriptions.first?.url else {
            Logger.shared.log("Recovery skipped: missing store URL", type: "CloudKit")
            return
        }

        Logger.shared.log("Attempting store recovery by deleting sqlite files", type: "CloudKit")

        let fm = FileManager.default
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]

        for url in relatedURLs {
            if fm.fileExists(atPath: url.path) {
                do {
                    try fm.removeItem(at: url)
                } catch {
                    Logger.shared.log("Failed to delete \(url.lastPathComponent): \(error.localizedDescription)", type: "CloudKit")
                }
            }
        }
    }

    private func loadPersistentStores() {
        if didEnterStoreLoadGroup == false {
            didEnterStoreLoadGroup = true
            storeLoadGroup.enter()
        }

        guard let description = container?.persistentStoreDescriptions.first else {
            initializationFailed = true
            notifyUserOfCriticalError("Failed to access store description")
            finishStoreLoadIfNeeded()
            return
        }

        // enable automatic lightweight migration
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container?.loadPersistentStores { _, error in
            if let error = error {
                let nsError = error as NSError
                let message = "\(nsError.domain) (\(nsError.code)) \(nsError.localizedDescription) userInfo=\(nsError.userInfo)"
                self.lastLoadError = message
                Logger.shared.log("Failed to load persistent store: \(message)", type: "CloudKit")
                // One-time recovery: delete existing sqlite and retry (helps with corrupted or unwritable store files).
                if self.didAttemptStoreRecovery == false {
                    self.attemptStoreRecoveryIfPossible()
                    self.loadPersistentStores()
                    return
                }

                self.initializationFailed = true
                self.notifyUserOfCriticalError("Failed to load data store: \(error.localizedDescription)")
                self.finishStoreLoadIfNeeded()
            } else {
                self.lastLoadError = nil
                self.container?.viewContext.automaticallyMergesChangesFromParent = true
                self.container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

                if self.remoteChangeObserver == nil, let coordinator = self.container?.persistentStoreCoordinator {
                    self.remoteChangeObserver = NotificationCenter.default.addObserver(
                        forName: .NSPersistentStoreRemoteChange,
                        object: coordinator,
                        queue: nil
                    ) { _ in
                        NotificationCenter.default.post(name: ProgressStore.remoteChangeNotification, object: nil)
                    }
                }

                self.finishStoreLoadIfNeeded()
            }
        }
    }

    private func finishStoreLoadIfNeeded() {
        guard didFinishStoreLoad == false else { return }
        didFinishStoreLoad = true
        storeLoadGroup.leave()
    }

    private func waitForStoreIfNeeded(timeoutSeconds: Double = 3.0) {
        // If called too early during startup, Core Data fetch/save can fail with
        // "...sqlite couldn't be opened" even though it will succeed moments later.
        guard status() != .ready else { return }
        guard Thread.isMainThread == false else { return }
        _ = storeLoadGroup.wait(timeout: .now() + timeoutSeconds)
    }

    private func notifyUserOfCriticalError(_ message: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: ProgressStore.criticalErrorNotification,
                object: nil,
                userInfo: ["error": message]
            )
        }
    }

    public enum StorageStatus {
        case ready
        case unavailable
        case unknown
    }

    public func status() -> StorageStatus {
        if initializationFailed || container == nil {
            return .unavailable
        } else if container?.persistentStoreCoordinator.persistentStores.first != nil {
            return .ready
        } else {
            return .unknown
        }
    }

    func getProgressData() -> ProgressData {
        waitForStoreIfNeeded()
        guard let container else {
            Logger.shared.log("Container not initialized: getProgressData", type: "CloudKit")
            return ProgressData()
        }

        var movies: [MovieProgressEntry] = []
        var episodes: [EpisodeProgressEntry] = []

        container.viewContext.performAndWait {
            do {
                let movieRequest: NSFetchRequest<MovieProgressEntity> = MovieProgressEntity.fetchRequest()
                movies = try container.viewContext.fetch(movieRequest).map { $0.asModel }
            } catch {
                Logger.shared.log("Fetch movie progress failed: \(error.localizedDescription)", type: "CloudKit")
            }

            do {
                let episodeRequest: NSFetchRequest<EpisodeProgressEntity> = EpisodeProgressEntity.fetchRequest()
                episodes = try container.viewContext.fetch(episodeRequest).map { $0.asModel }
            } catch {
                Logger.shared.log("Fetch episode progress failed: \(error.localizedDescription)", type: "CloudKit")
            }
        }

        return ProgressData(movieProgress: movies, episodeProgress: episodes)
    }

    func counts() -> (movies: Int, episodes: Int) {
        waitForStoreIfNeeded()
        guard let container else { return (0, 0) }

        var movieCount = 0
        var episodeCount = 0

        container.viewContext.performAndWait {
            do {
                movieCount = try container.viewContext.count(for: MovieProgressEntity.fetchRequest())
            } catch { }
            do {
                episodeCount = try container.viewContext.count(for: EpisodeProgressEntity.fetchRequest())
            } catch { }
        }

        return (movieCount, episodeCount)
    }

    func upsertMovie(_ entry: MovieProgressEntry) {
        waitForStoreIfNeeded()
        guard let container else {
            Logger.shared.log("Container not initialized: upsertMovie", type: "CloudKit")
            return
        }

        container.viewContext.performAndWait {
            let request: NSFetchRequest<MovieProgressEntity> = MovieProgressEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %lld", Int64(entry.id))
            request.fetchLimit = 1

            do {
                let entity = try container.viewContext.fetch(request).first ?? MovieProgressEntity(context: container.viewContext)
                entity.apply(from: entry)

                if container.viewContext.hasChanges {
                    try container.viewContext.save()
                }
            } catch {
                Logger.shared.log("Upsert movie progress failed: \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    func upsertEpisode(_ entry: EpisodeProgressEntry) {
        waitForStoreIfNeeded()
        guard let container else {
            Logger.shared.log("Container not initialized: upsertEpisode", type: "CloudKit")
            return
        }

        container.viewContext.performAndWait {
            let request: NSFetchRequest<EpisodeProgressEntity> = EpisodeProgressEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "showId == %lld AND seasonNumber == %lld AND episodeNumber == %lld",
                Int64(entry.showId),
                Int64(entry.seasonNumber),
                Int64(entry.episodeNumber)
            )
            request.fetchLimit = 1

            do {
                let entity = try container.viewContext.fetch(request).first ?? EpisodeProgressEntity(context: container.viewContext)
                entity.apply(from: entry)

                if container.viewContext.hasChanges {
                    try container.viewContext.save()
                }
            } catch {
                Logger.shared.log("Upsert episode progress failed: \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    func syncManually() async {
        waitForStoreIfNeeded()
        guard let container else {
            Logger.shared.log("Container not initialized: syncManually", type: "CloudKit")
            return
        }

        do {
            try await container.viewContext.perform {
                try container.viewContext.save()
                let _ = self.getProgressData()
            }
        } catch {
            Logger.shared.log("Sync failed: \(error.localizedDescription)", type: "CloudKit")
        }
    }
}

extension ProgressStore.StorageStatus {
    var description: String {
        switch self {
        case .ready:
            #if CLOUDKIT
                return "Synced and ready"
            #else
                return "Local Storage only"
            #endif
        case .unavailable:
            return "Unavailable"
        case .unknown:
            return "Unknown"
        }
    }

    var symbol: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .unavailable:
            return "tray.full.fill"
        case .unknown:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready:
            return .green
        case .unavailable:
            return .orange
        case .unknown:
            return .red
        }
    }
}
