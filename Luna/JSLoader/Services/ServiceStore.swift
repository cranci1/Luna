//
//  CloudStore.swift
//  Luna
//
//  Created by Dominic on 07.11.25.
//

import Sybau
import CoreData

public final class ServiceStore {
    public static let shared = ServiceStore()
    
    // MARK: private - internal setup and update functions
    
    private var container: NSPersistentContainer? = nil
    
    private init() {
        container = NSPersistentContainer(name: "ServiceModels")
        
        guard let description = container?.persistentStoreDescriptions.first else {
            Logger.shared.log("Missing store description", type: "ServiceStore")
            return
        }
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container?.loadPersistentStores { _, error in
            if let error = error {
                Logger.shared.log("Failed to load local persistent store: \(error.localizedDescription)", type: "ServiceStore")
            } else {
                self.container?.viewContext.automaticallyMergesChangesFromParent = true
                self.container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            }
        }
    }
    
    // MARK: public - status, add, get, remove, save, syncManually functions
    
    public enum CloudStatus {
        case unavailable
        case ready
        case unknown
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
            Logger.shared.log("Local store not initialized: storeService", type: "ServiceStore")
            return
        }
        
        container.viewContext.performAndWait {
            let context = container.viewContext
            
            let fetchRequest: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                let service: ServiceEntity
                
                if let existing = results.first {
                    service = existing
                } else {
                    service = ServiceEntity(context: context)
                    service.id = id
                    
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
                    Logger.shared.log("Local save failed: \(error.localizedDescription)", type: "ServiceStore")
                }
            } catch {
                Logger.shared.log("Failed to fetch existing service: \(error.localizedDescription)", type: "ServiceStore")
            }
        }
    }
    
    public func getEntities() -> [ServiceEntity] {
        guard let container = container else {
            Logger.shared.log("Local store not initialized: getEntities", type: "ServiceStore")
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
                Logger.shared.log("Local fetch failed: \(error.localizedDescription)", type: "ServiceStore")
            }
        }
        
        return result
    }
    
    public func getServices() -> [Service] {
        guard let container = container else {
            Logger.shared.log("Local store not initialized: getServices", type: "ServiceStore")
            return []
        }
        
        var result: [Service] = []
        
        container.viewContext.performAndWait {
            do {
                let request: NSFetchRequest<ServiceEntity> = ServiceEntity.fetchRequest()
                let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
                request.sortDescriptors = [sort]
                let entities = try container.viewContext.fetch(request)
                Logger.shared.log("Loaded \(entities.count) ServiceEntities", type: "ServiceStore")
                result = entities.compactMap { $0.asModel }
            } catch {
                Logger.shared.log("Local fetch failed: \(error.localizedDescription)", type: "ServiceStore")
            }
        }
        
        return result
    }
    
    public func remove(_ service: Service) {
        guard let container = container else {
            Logger.shared.log("Local store not initialized: remove", type: "ServiceStore")
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
                    Logger.shared.log("ServiceEntity not found for id: \(service.id)", type: "ServiceStore")
                }
            } catch {
                Logger.shared.log("Failed to fetch ServiceEntity to delete: \(error.localizedDescription)", type: "ServiceStore")
            }
        }
    }
    
    public func save() {
        guard let container = container else {
            Logger.shared.log("Local store not initialized: save", type: "ServiceStore")
            return
        }
        
        container.viewContext.performAndWait {
            do {
                if container.viewContext.hasChanges {
                    try container.viewContext.save()
                }
            } catch {
                Logger.shared.log("Local save failed: \(error.localizedDescription)", type: "ServiceStore")
            }
        }
    }
    
    public func syncManually() async {
        guard let container = container else {
            Logger.shared.log("Local store not initialized: syncManually", type: "ServiceStore")
            return
        }
        
        do {
            try await container.viewContext.perform {
                try container.viewContext.save()
                let _ = ServiceStore.shared.getServices()
            }
        } catch {
            Logger.shared.log("Local sync failed: \(error.localizedDescription)", type: "ServiceStore")
        }
    }
}
