//
//  Module.swift
//  Kanzen
//
//  Created by Dawud Osman on 13/05/2025.
//
import Foundation
import Kingfisher
struct ModuleData: Codable, Equatable
{

    
    let sourceName: String
    let author: Author
    let iconURL: String
    let version: String
    let language: String
    let scriptURL: String
    // Optional manifest key carrying the module site's origin (e.g.
    // "https://allmanga.to/"). Manga CDNs that gate image requests on a
    // platform Referer/Origin header need this; modules without it decode
    // with baseUrl == nil and behave exactly as before.
    let baseUrl: String?
    
    struct Author: Codable, Equatable
    {
        let name: String
        let iconURL: String
    }
}

/// Attaches the active manga module's `baseUrl` as `Referer` to every
/// Kingfisher image request (search covers, detail header, reader pages and
/// the prefetcher). Some chapter-image CDNs (e.g. allmanga's
/// youtube-anime.com hosts) answer 403 unless the platform Referer/Origin is
/// present; module JS cannot set image headers itself — it only returns URL
/// strings — so the app has to do it.
///
/// The modifier is installed once and stays a no-op until a module whose
/// manifest declares `baseUrl` is loaded. Loading a module without `baseUrl`
/// clears the header again. Note the modifier applies app-wide (including the
/// anime side); the header is only attached while a manga module with
/// `baseUrl` was the last one loaded, and CDNs that don't expect a Referer
/// simply ignore it.
enum ModuleImageHeaders {
    // Written on the main thread (activate), read on Kingfisher downloader
    // threads (modifier closure) — guard with a lock.
    private static let lock = NSLock()
    private static var _referer: String?
    private static var installed = false

    private(set) static var referer: String? {
        get { lock.lock(); defer { lock.unlock() }; return _referer }
        set { lock.lock(); _referer = newValue; lock.unlock() }
    }

    private static let modifier = AnyModifier { request in
        var request = request
        if let referer = referer, !referer.isEmpty,
           request.value(forHTTPHeaderField: "Referer") == nil {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return request
    }

    /// Call whenever a module's script is loaded for browsing/reading.
    static func activate(for moduleData: ModuleData?) {
        referer = moduleData?.baseUrl
        lock.lock()
        let shouldInstall = !installed
        installed = true
        lock.unlock()
        if shouldInstall {
            KingfisherManager.shared.defaultOptions += [.requestModifier(modifier)]
        }
    }

    /// The modifier as an options item for Kingfisher entry points that do
    /// NOT consult `KingfisherManager.defaultOptions` — notably
    /// `ImagePrefetcher`, which builds a private manager from its own
    /// options (KF 8.x). Pass explicitly there or prefetches 403.
    static var kingfisherOptions: KingfisherOptionsInfo {
        [.requestModifier(modifier)]
    }
}
struct ModuleDataContainer: Codable, Identifiable,Hashable
{
    let id: UUID
    let moduleData: ModuleData
    let localPath: String
    let moduleurl: String
    var isActive: Bool
    init(id:UUID = UUID(), moduleData: ModuleData, localPath: String, moduleurl: String, isActive: Bool = false) {
        self.id = id
        self.moduleData = moduleData
        self.localPath = localPath
        self.moduleurl = moduleurl
        self.isActive = isActive
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: ModuleDataContainer, rhs: ModuleDataContainer) -> Bool {
        return lhs.id == rhs.id
    }
}
