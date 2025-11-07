//
//  Services.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import Foundation
import CoreData

public struct ServiceMetadata: Codable, Hashable {
    let sourceName: String
    let author: Author
    let iconUrl: String
    let version: String
    let language: String
    let baseUrl: String
    let streamType: String
    let quality: String
    let searchBaseUrl: String
    let scriptUrl: String
    let softsub: Bool?
    let multiStream: Bool?
    let multiSubs: Bool?
    let type: String?
    let novel: Bool?
    let settings: Bool?

    struct Author: Codable, Hashable {
        let name: String
        let icon: String
    }
}

public struct Service: Identifiable, Hashable {
    public let id: UUID
    let metadata: ServiceMetadata
    let jsScript: String
    let url: String
    let isActive: Bool
    let sortIndex: Int64
}

@objc(ServiceEntity)
public class ServiceEntity: NSManagedObject { }

public typealias ServiceEntityCoreDataPropertiesSet = NSSet

extension ServiceEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ServiceEntity> {
        return NSFetchRequest<ServiceEntity>(entityName: "ServiceEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var jsonMetadata: String?
    @NSManaged public var jsScript: String?
    @NSManaged public var url: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var sortIndex: Int64
}

extension ServiceEntity: Identifiable { }

extension ServiceEntity {
    var asModel: Service? {
        guard
            let id = self.id,
            let jsonMetadata = self.jsonMetadata,
            let jsScript = self.jsScript,
            let url = self.url
        else {
            return nil
        }

        guard let data = jsonMetadata.data(using: .utf8) else {
            print("ServiceEntity jsonMetadata is empty")
            return nil
        }

        var metadata: ServiceMetadata? = nil
        do {
            metadata = try JSONDecoder().decode(ServiceMetadata.self, from: data)
        } catch {
            print("Failed to decode ServicesMetadata for ServiceEntity \(id.uuidString): \(error)")
            return nil
        }

        guard let metadata else {
            print("ServiceEntity jsonMetadata is malformed")
            return nil
        }

        return Service(
            id: id,
            metadata: metadata,
            jsScript: jsScript,
            url: url,
            isActive: isActive,
            sortIndex: sortIndex
        )
    }
}
