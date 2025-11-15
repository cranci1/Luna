//
//  CloudStore.swift
//  Luna
//
//  Created by Dominic on 07.11.25.
//

import CoreData

public final class ServiceStore {
    public static let shared = ServiceStore()

    // MARK: private - internal setup and update functions

    private var container: NSPersistentCloudKitContainer? = nil

    private init() {
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

        container?.loadPersistentStores { _, error in
            if let error = error {
                Logger.shared.log("Failed to load persistent store: \(error.localizedDescription)", type: "CloudKit")
            }
        }

        container?.viewContext.automaticallyMergesChangesFromParent = true
        container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: public - status, add, get, remove, save, syncManually functions

    public enum CloudStatus {
        case unavailable       // container not initialized
        case ready             // container initialized and loaded
        case unknown           // initialization failed
    }

    public func status() -> CloudStatus {
        guard let container = container else { return .unavailable }

        if container.persistentStoreCoordinator.persistentStores.first != nil {
            return .ready
        } else {
            return .unknown
        }
    }

    public func storeService(id: UUID, url: String, jsonMetadata: String, jsScript: String, isActive: Bool) {
        guard let container = container else {
            Logger.shared.log("Cloudkit container not initialized: storeService", type: "CloudKit")
            return
        }

        let service = ServiceEntity(context: container.viewContext)
        service.id = id
        service.url = url
        service.jsonMetadata = jsonMetadata
        service.jsScript = jsScript
        service.isActive = isActive

        save()
    }

    public func getEntities() -> [ServiceEntity] {
        guard let container = container else {
            Logger.shared.log("Cloudkit container not initialized: getEntities", type: "CloudKit")
            return []
        }

        do {
            let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
            request.sortDescriptors = [sort]
            return try container.viewContext.fetch(request)
        } catch {
            Logger.shared.log("Cloudkit fetch failed: \(error.localizedDescription)", type: "CloudKit")
        }

        return []
    }

    public func getServices() -> [Service] {
        guard let container = container else {
            Logger.shared.log("Cloudkit container not initialized: getServices", type: "CloudKit")
            return []
        }

        do {
            let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
            request.sortDescriptors = [sort]
            let entities = try container.viewContext.fetch(request)
            Logger.shared.log("Loaded \(entities.count) ServiceEntities", type: "CloudKit")
            return entities.compactMap { $0.asModel }
        } catch {
            Logger.shared.log("Cloudkit fetch failed: \(error.localizedDescription)", type: "CloudKit")
        }

        return []
    }

    public func remove(_ service: Service) {
        guard let container = container else {
            Logger.shared.log("Cloudkit container not initialized: remove", type: "CloudKit")
            return
        }

        let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", service.id as CVarArg)
        do {
            if let entity = try container.viewContext.fetch(request).first {
                container.viewContext.delete(entity)
                save()
            } else {
                Logger.shared.log("ServiceEntity not found for id: \(service.id)", type: "CloudKit")
            }
        } catch {
            Logger.shared.log("Failed to fetch ServiceEntity to delete: \(error.localizedDescription)", type: "CloudKit")
        }
    }

    public func save() {
        guard let container = container else {
            Logger.shared.log("Cloudkit container not initialized: save", type: "CloudKit")
            return
        }

        do {
            if container.viewContext.hasChanges {
                try container.viewContext.save()
            }
        } catch {
            Logger.shared.log("Cloudkit save failed: \(error.localizedDescription)", type: "CloudKit")
        }
    }

    public func syncManually() async {
        guard let container = container else {
            Logger.shared.log("Cloudkit container not initialized: syncManually", type: "CloudKit")
            return
        }

        do {
            try await container.viewContext.perform {
                try container.viewContext.save()
                let _ = ServiceStore.shared.getServices()
            }
        } catch {
            Logger.shared.log("Cloudkit sync failed: \(error.localizedDescription)", type: "CloudKit")
        }
    }
}
