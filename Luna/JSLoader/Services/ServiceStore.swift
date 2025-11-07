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
            print("Missing iCloud container id")
            return
        }

        container = NSPersistentCloudKitContainer(name: "ServiceModels")

        guard let description = container?.persistentStoreDescriptions.first else {
            print("Missing store description")
            return
        }

        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerID
        )

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container?.loadPersistentStores { _, error in
            if let error = error {
                print("Failed to load persistent store:", error)
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
            print("Cloudkit container not initialized")
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
            print("Cloudkit container not initialized")
            return []
        }

        do {
            let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
            request.sortDescriptors = [sort]
            return try container.viewContext.fetch(request)
        } catch {
            print("Cloudkit fetch failed:", error)
        }

        return []
    }

    public func getServices() -> [Service] {
        guard let container = container else {
            print("Cloudkit container not initialized")
            return []
        }

        do {
            let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
            request.sortDescriptors = [sort]
            let entities = try container.viewContext.fetch(request)
            print("Loaded \(entities.count) ServiceEntities")
            return entities.compactMap { $0.asModel }
        } catch {
            print("Cloudkit fetch failed:", error)
        }

        return []
    }

    public func remove(_ service: Service) {
        guard let container = container else {
            print("Cloudkit container not initialized")
            return
        }

        let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", service.id as CVarArg)
        do {
            if let entity = try container.viewContext.fetch(request).first {
                container.viewContext.delete(entity)
                save()
            } else {
                print("ServiceEntity not found for id:", service.id)
            }
        } catch {
            print("Failed to fetch ServiceEntity to delete:", error)
        }
    }

    public func save() {
        guard let container = container else {
            print("Cloudkit container not initialized")
            return
        }

        do {
            if container.viewContext.hasChanges {
                try container.viewContext.save()
            }
        } catch {
            print("Cloudkit save failed:", error)
        }
    }

    public func syncManually() async {
        guard let container = container else {
            print("Cloudkit container not initialized")
            return
        }

        do {
            try await container.viewContext.perform {
                try container.viewContext.save()
                let _ = ServiceStore.shared.getServices()
            }
        } catch {
            print("Cloudkit sync failed:", error)
        }
    }
}
