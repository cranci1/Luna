//
//  CloudStore.swift
//  Luna
//
//  Created by Dominic on 07.11.25.
//

import SwiftUI
import CoreData

public final class ServiceStore {
    public static let shared = ServiceStore()
    public static let criticalErrorNotification = Notification.Name("ServiceStoreCriticalError")
    static let remoteChangeNotification = Notification.Name("ServiceStoreRemoteChange")

    // MARK: private - internal setup and update functions

    private var container: NSPersistentContainer? = nil
    private var initializationFailed = false
    private var didAttemptStoreRecovery = false

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
    }

    private func initCloudKit() {
        Logger.shared.log("Using CloudKit Storage", type: "CloudKit")
        guard let containerID = Bundle.main.iCloudContainerID else {
            Logger.shared.log("Missing iCloud container id", type: "CloudKit")
            return
        }

        container = NSPersistentCloudKitContainer(name: "ServiceModels")

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
        container = NSPersistentContainer(name: "ServiceModels")

        if let description = container?.persistentStoreDescriptions.first {
            configureStoreDescription(description)
        }

        loadPersistentStores()
    }

    private func configureStoreDescription(_ description: NSPersistentStoreDescription) {
        // tvOS can fail to open the default sqlite path if the directory isn't created yet.
        // Always place the store in an app-writable Application Support subdirectory.
        var storeURL = makeStoreURL(preferred: .applicationSupport)
        if ensureParentDirectoryExists(for: storeURL) == false {
            // Fallback: caches is always writable and acceptable for non-critical local state.
            storeURL = makeStoreURL(preferred: .caches)
            _ = ensureParentDirectoryExists(for: storeURL)
        }

        description.url = storeURL
        lastStoreURL = storeURL
        Logger.shared.log("ServiceModels store URL: \(storeURL.path)", type: "CloudKit")
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

    private func makeStoreURL(preferred: StoreBaseDirectory) -> URL {
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
            .appendingPathComponent("ServiceModels", isDirectory: true)
            .appendingPathComponent("ServiceModels.sqlite", isDirectory: false)
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
            self.initializationFailed = true
            self.notifyUserOfCriticalError("Failed to access store description")
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
                        NotificationCenter.default.post(name: ServiceStore.remoteChangeNotification, object: nil)
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
                name: ServiceStore.criticalErrorNotification,
                object: nil,
                userInfo: ["error": message]
            )
        }
    }

    // MARK: public - status, add, get, remove, save, syncManually functions

    public enum StorageStatus {
        case ready             // container initialized and loaded
        case unavailable       // container not initialized -> local only
        case unknown           // initialization failed
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

    public func storeService(id: UUID, url: String, jsonMetadata: String, jsScript: String, isActive: Bool) {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: storeService", type: "CloudKit")
            return
        }

        container.viewContext.performAndWait {
            let context = container.viewContext

            // Check if a service with the same ID already exists
            let fetchRequest: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                let results = try context.fetch(fetchRequest)
                let service: ServiceEntity

                if let existing = results.first {
                    // Update existing service
                    service = existing
                } else {
                    // Create new service
                    service = ServiceEntity(context: context)
                    service.id = id

                    // Assign proper sort index so new services go to the bottom
                    let countRequest: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
                    countRequest.includesSubentities = false
                    let count = try context.count(for: countRequest)

                    service.sortIndex = Int64(count)
                }

                service.url = url
                service.jsonMetadata = jsonMetadata
                service.jsScript = jsScript
                service.isActive = isActive

                do {
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    Logger.shared.log("Save failed: \(error.localizedDescription)", type: "CloudKit")
                }
            } catch {
                Logger.shared.log("Failed to fetch existing service: \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    public func getEntities() -> [ServiceEntity] {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: getEntities", type: "CloudKit")
            return []
        }

        var result: [ServiceEntity] = []

        container.viewContext.performAndWait {
            do {
                let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
                let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
                request.sortDescriptors = [sort]
                result = try container.viewContext.fetch(request)
            } catch {
                Logger.shared.log("Fetch failed: \(error.localizedDescription)", type: "CloudKit")
            }
        }

        return result
    }

    public func getServices() -> [Service] {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: getServices", type: "CloudKit")
            return []
        }

        var result: [Service] = []

        container.viewContext.performAndWait {
            do {
                let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
                let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
                request.sortDescriptors = [sort]
                let entities = try container.viewContext.fetch(request)
                Logger.shared.log("Loaded \(entities.count) ServiceEntities", type: "CloudKit")
                result = entities.compactMap { $0.asModel }
            } catch {
                Logger.shared.log("Fetch failed: \(error.localizedDescription)", type: "CloudKit")
            }
        }

        return result
    }

    public func updateService(id: UUID, updates: (ServiceEntity) -> Void) {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: updateService", type: "CloudKit")
            return
        }

        container.viewContext.performAndWait {
            let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                if let entity = try container.viewContext.fetch(request).first {
                    updates(entity)  // Apply the updates via closure

                    if container.viewContext.hasChanges {
                        try container.viewContext.save()
                    }
                } else {
                    Logger.shared.log("ServiceEntity not found for id: \(id)", type: "CloudKit")
                }
            } catch {
                Logger.shared.log("Failed to update service: \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    public func updateMultipleServices(updates: [(id: UUID, update: (ServiceEntity) -> Void)]) {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: updateMultipleServices", type: "CloudKit")
            return
        }

        container.viewContext.performAndWait {
            for (id, updateClosure) in updates {
                let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1

                do {
                    if let entity = try container.viewContext.fetch(request).first {
                        updateClosure(entity)
                    }
                } catch {
                    Logger.shared.log("Failed to fetch service \(id): \(error.localizedDescription)", type: "CloudKit")
                }
            }

            do {
                if container.viewContext.hasChanges {
                    try container.viewContext.save()
                }
            } catch {
                Logger.shared.log("Failed to save batch updates: \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    public func remove(_ service: Service) {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: remove", type: "CloudKit")
            return
        }

        container.viewContext.performAndWait {
            let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", service.id as CVarArg)
            do {
                if let entity = try container.viewContext.fetch(request).first {
                    container.viewContext.delete(entity)
                    if container.viewContext.hasChanges {
                        try container.viewContext.save()
                    }
                } else {
                    Logger.shared.log("ServiceEntity not found for id: \(service.id)", type: "CloudKit")
                }
            } catch {
                Logger.shared.log("Failed to fetch ServiceEntity to delete: \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    public func save() {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: save", type: "CloudKit")
            return
        }

        container.viewContext.performAndWait {
            do {
                if container.viewContext.hasChanges {
                    try container.viewContext.save()
                }
            } catch {
                Logger.shared.log("Save failed: \(error.localizedDescription)", type: "CloudKit")
            }
        }
    }

    public func syncManually() async {
        waitForStoreIfNeeded()
        guard let container = container else {
            Logger.shared.log("Container not initialized: syncManually", type: "CloudKit")
            return
        }

        do {
            try await container.viewContext.perform {
                try container.viewContext.save()
                let _ = ServiceStore.shared.getServices()
            }
        } catch {
            Logger.shared.log("Sync failed: \(error.localizedDescription)", type: "CloudKit")
        }
    }
}

extension ServiceStore.StorageStatus {
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
