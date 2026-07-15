//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import Sybau
import Combine
import Foundation

final class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    
    @Published var collections: [LibraryCollection] = [] {
        didSet {
            collections.forEach { observeCollection($0) }
            save()
        }
    }
    
    private let collectionsKey = "libraryCollections"
    private var collectionCancellables: [UUID: AnyCancellable] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private let saveTrigger = PassthroughSubject<[LibraryCollection], Never>()
    private let persistenceQueue = DispatchQueue(label: "com.cranci.librarymanager.persistence", qos: .utility)
    
    private init() {
        setupPersistence()
        load()
        createDefaultBookmarksCollection()
        
        collections.forEach { observeCollection($0) }
    }
    
    private func setupPersistence() {
        saveTrigger
            .debounce(for: .milliseconds(500), scheduler: persistenceQueue)
            .sink { [weak self] snapshot in
                self?.persist(snapshot)
            }
            .store(in: &cancellables)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: collectionsKey) else { return }
        
        do { collections = try JSONDecoder().decode([LibraryCollection].self, from: data) }
        catch { backupCorruptedData(data, error: error) }
    }
    
    private func persist(_ snapshot: [LibraryCollection]) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: collectionsKey)
    }
    
    private func save() {
        saveTrigger.send(collections)
    }
    
    func flushPendingSave() {
        persist(collections)
    }
    
    // MARK: - Data recovery
    
    private func backupCorruptedData(_ data: Data, error: Error) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupKey = "\(collectionsKey).corrupted.\(timestamp)"
        UserDefaults.standard.set(data, forKey: backupKey)
        Logger.shared.log("LibraryManager: failed to decode collections (\(error)). Raw data backed up under key '\(backupKey)'.", type: "Error")
    }
    
    func corruptedBackupKeys() -> [String] {
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("\(collectionsKey).corrupted.") }
            .sorted()
    }
    
    @discardableResult
    func restoreFromBackup(key: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LibraryCollection].self, from: data) else {
            return false
        }
        collections = decoded
        return true
    }
    
    private func createDefaultBookmarksCollection() {
        if !collections.contains(where: { $0.name == "Bookmarks" }) {
            let bookmarksCollection = LibraryCollection(name: "Bookmarks", description: "Your bookmarked items")
            collections.insert(bookmarksCollection, at: 0)
        }
    }
    
    func createCollection(name: String, description: String? = nil) {
        let new = LibraryCollection(name: name, description: description)
        collections.append(new)
    }
    
    func deleteCollection(_ collection: LibraryCollection) {
        guard collection.name != "Bookmarks" else { return }
        collectionCancellables[collection.id] = nil
        collections.removeAll { $0.id == collection.id }
    }
    
    func addItem(to collectionId: UUID, item: LibraryItem) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }),
              !collections[index].items.contains(where: { $0.id == item.id }) else { return }
        collections[index].items.append(item)
    }
    
    func removeItem(from collectionId: UUID, item: LibraryItem) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[index].items.removeAll { $0.id == item.id }
    }
    
    func isItemInCollection(_ collectionId: UUID, item: LibraryItem) -> Bool {
        guard let col = collections.first(where: { $0.id == collectionId }) else { return false }
        return col.items.contains { $0.id == item.id }
    }
    
    func collectionsContainingItem(_ item: LibraryItem) -> [LibraryCollection] {
        return collections.filter { $0.items.contains { $0.id == item.id } }
    }
    
    // MARK: - Bookmark Functions
    func toggleBookmark(for searchResult: TMDBSearchResult) {
        let item = LibraryItem(searchResult: searchResult)
        
        if let bookmarksCollection = collections.first(where: { $0.name == "Bookmarks" }) {
            if isItemInCollection(bookmarksCollection.id, item: item) {
                removeItem(from: bookmarksCollection.id, item: item)
            } else {
                var newItem = item
                newItem.dateAdded = Date()
                addItem(to: bookmarksCollection.id, item: newItem)
            }
        }
    }
    
    func isBookmarked(_ searchResult: TMDBSearchResult) -> Bool {
        let item = LibraryItem(searchResult: searchResult)
        guard let bookmarksCollection = collections.first(where: { $0.name == "Bookmarks" }) else { return false }
        return isItemInCollection(bookmarksCollection.id, item: item)
    }
    
    // MARK: - Observation
    private func observeCollection(_ collection: LibraryCollection) {
        if collectionCancellables[collection.id] != nil { return }
        
        let cancellable = collection.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.save()
                }
            }
        
        collectionCancellables[collection.id] = cancellable
    }
}
