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

    // MARK: private - internal setup and update functions

    private var container: NSPersistentContainer? = nil
    private var initializationFailed = false

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
        loadPersistentStores()
    }

    private func loadPersistentStores() {

        guard let description = container?.persistentStoreDescriptions.first else {
            self.initializationFailed = true
            self.notifyUserOfCriticalError("Failed to access store description")
            return
        }

        // enable automatic lightweight migration
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container?.loadPersistentStores { _, error in
            if let error = error {
                Logger.shared.log("Failed to load persistent store: \(error.localizedDescription)", type: "CloudKit")
                self.initializationFailed = true
                self.notifyUserOfCriticalError("Failed to load data store: \(error.localizedDescription)")
            } else {
                self.container?.viewContext.automaticallyMergesChangesFromParent = true
                self.container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            }
        }
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
