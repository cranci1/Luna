//
//  ServiceManager.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import CryptoKit
import Foundation

struct ServiceSetting {
    let key: String
    let value: String
    let type: SettingType
    let comment: String?
    let options: [String]?
    
    enum SettingType {
        case string, bool, int, float
    }
}

class ServiceManager: ObservableObject {
    static let shared = ServiceManager()
    
    @Published var services: [Services] = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadMessage: String = ""
    
    let documentsDirectory: URL
    let servicesDirectory: URL
    
    private init() {
#if os(tvOS)
        documentsDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
#else
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
#endif
        servicesDirectory = documentsDirectory.appendingPathComponent("Services")
        
        createServicesDirectoryIfNeeded()
        loadExistingServices()
        loadServiceOrder()
        
        let activeCount = services.filter { $0.isActive }.count
        Logger.shared.log("ServiceManager initialized with \(services.count) services, \(activeCount) active", type: "ServiceManager")
    }
    
    // MARK: - Private Helpers
    
    private func generateServiceUUID(from metadata: ServicesMetadata, folderName: String) -> UUID {
        let identifier = "\(metadata.sourceName)_\(metadata.author.name)_\(metadata.version)"
        let hash = identifier.sha256
        
        let uuidString = String(hash.prefix(32))
        let formattedUUID = "\(uuidString.prefix(8))-\(uuidString.dropFirst(8).prefix(4))-\(uuidString.dropFirst(12).prefix(4))-\(uuidString.dropFirst(16).prefix(4))-\(uuidString.dropFirst(20).prefix(12))"
        
        return UUID(uuidString: formattedUUID) ?? UUID()
    }
    
    private func saveServiceStates() {
        let serviceStates = services.reduce(into: [String: Bool]()) { result, service in
            result[service.id.uuidString] = service.isActive
        }
        UserDefaults.standard.set(serviceStates, forKey: "ServiceActiveStates")
        UserDefaults.standard.synchronize()
        Logger.shared.log("Saved service states: \(serviceStates)", type: "ServiceManager")
    }
    
    private func loadServiceState(for serviceId: UUID) -> Bool {
        let serviceStates = UserDefaults.standard.object(forKey: "ServiceActiveStates") as? [String: Bool]
        let state = serviceStates?[serviceId.uuidString] ?? false
        Logger.shared.log("Loading state for \(serviceId.uuidString): \(state)", type: "ServiceManager")
        return state
    }
    
    // MARK: - Public Methods
    
    func handlePotentialServiceURL(_ text: String) async -> Bool {
        guard isValidJSONURL(text) else { return false }
        await downloadService(from: text)
        return true
    }
    
    func downloadService(from jsonURL: String) async {
        await updateProgress(0.0, "Starting download...")
        
        do {
            await updateProgress(0.2, "Downloading metadata...")
            let metadata = try await downloadAndParseMetadata(from: jsonURL)
            
            await updateProgress(0.5, "Downloading JavaScript...")
            let jsContent = try await downloadJavaScript(from: metadata.scriptUrl)
            
            await updateProgress(0.8, "Saving files...")
            let service = try await saveuPdateService(metadata: metadata, jsContent: jsContent, metadataUrl: jsonURL)
            
            await MainActor.run {
                if !self.services.contains(where: { $0.id == service.id }) {
                    self.services.append(service)
                }
                self.saveServiceStates()
                self.downloadProgress = 1.0
                self.downloadMessage = "Service downloaded successfully!"
            }
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await resetDownloadState()
            
        } catch {
            await resetDownloadState()
            Logger.shared.log("Failed to download service: \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    func removeService(_ service: Services) {
        do {
            let servicePath = servicesDirectory.appendingPathComponent(service.localPath)
            if FileManager.default.fileExists(atPath: servicePath.path) {
                try FileManager.default.removeItem(at: servicePath)
            }
            
            services.removeAll { $0.id == service.id }
            saveServiceOrder()
            
            var serviceStates = UserDefaults.standard.object(forKey: "ServiceActiveStates") as? [String: Bool] ?? [:]
            serviceStates.removeValue(forKey: service.id.uuidString)
            UserDefaults.standard.set(serviceStates, forKey: "ServiceActiveStates")
            
        } catch {
            Logger.shared.log("Failed to remove service: \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    func setServiceState(_ service: Services, isActive: Bool) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else {
            Logger.shared.log("Could not find service with ID: \(service.id.uuidString)", type: "ServiceManager")
            return
        }
        services[index].isActive = isActive
        saveServiceStates()
        Logger.shared.log("Set service \(service.metadata.sourceName) (\(service.id.uuidString)) to \(isActive ? "active" : "inactive")", type: "ServiceManager")
    }
    
    func moveServices(fromOffsets offsets: IndexSet, toOffset: Int) {
        var mutable = services
        mutable.move(fromOffsets: offsets, toOffset: toOffset)
        services = mutable
        saveServiceOrder()
        Logger.shared.log("Moved services - new order: \(services.map { $0.localPath })", type: "ServiceManager")
    }
    
    func toggleServiceState(_ service: Services) {
        setServiceState(service, isActive: !service.isActive)
    }
    
    var activeServices: [Services] {
        services.filter(\.isActive)
    }
    
    // MARK: - Service Order Persistence
    
    private func saveServiceOrder() {
        let order = services.map { $0.localPath }
        UserDefaults.standard.set(order, forKey: "ServiceOrder")
        UserDefaults.standard.synchronize()
        Logger.shared.log("Saved service order: \(order)", type: "ServiceManager")
    }
    
    private func loadServiceOrder() {
        guard let saved = UserDefaults.standard.stringArray(forKey: "ServiceOrder"), !saved.isEmpty else { return }
        
        var ordered: [Services] = []
        var remaining = services
        
        for path in saved {
            if let idx = remaining.firstIndex(where: { $0.localPath == path }) {
                ordered.append(remaining.remove(at: idx))
            }
        }
        
        ordered.append(contentsOf: remaining)
        
        if ordered.map({ $0.localPath }) != services.map({ $0.localPath }) {
            services = ordered
            Logger.shared.log("Loaded and applied saved service order: \(saved)", type: "ServiceManager")
        }
    }
    
    // MARK: - Search Methods
    
    func searchInActiveServices(query: String) async -> [(service: Services, results: [SearchItem])] {
        let activeServicesList = activeServices
        guard !activeServicesList.isEmpty else { return [] }
        
        await updateProgress(0.0, "Searching...")
        
        var resultsMap: [UUID: [SearchItem]] = [:]
        
        await withTaskGroup(of: (UUID, [SearchItem]).self) { group in
            for service in activeServicesList {
                group.addTask { [weak self] in
                    guard let self = self else { return (service.id, []) }
                    return await withTaskCancellationHandler(
                        operation: {
                            let timeoutSeconds: UInt64 = 10
                            return await ServiceManager.withTimeout(seconds: timeoutSeconds) {
                                let found = await self.searchInService(service: service, query: query)
                                return (service.id, found)
                            } ?? (service.id, [])
                        },
                        onCancel: {}
                    )
                }
            }
            
            for await (serviceId, results) in group {
                resultsMap[serviceId] = results
            }
        }
        
        let orderedResults = activeServicesList.map { service in
            (service: service, results: resultsMap[service.id] ?? [])
        }
        
        await resetDownloadState()
        return orderedResults
    }
    
    func searchInActiveServicesProgressively(query: String, onResult: @escaping @MainActor (Services, [SearchItem]?) -> Void, onComplete: @escaping @MainActor () -> Void) async {
        let activeServicesList = activeServices
        guard !activeServicesList.isEmpty else {
            await MainActor.run { onComplete() }
            return
        }
        
        await withTaskGroup(of: (Services, [SearchItem]?).self) { group in
            for service in activeServicesList {
                group.addTask { [weak self] in
                    guard let self = self else { return (service, []) }
                    let timeoutSeconds: UInt64 = 10
                    let res = await ServiceManager.withTimeout(seconds: timeoutSeconds) {
                        return await self.searchInService(service: service, query: query)
                    }
                    return (service, res)
                }
            }
            
            for await (service, results) in group {
                await MainActor.run { onResult(service, results) }
            }
        }
        
        await MainActor.run { onComplete() }
    }
    
    private func searchInService(service: Services, query: String) async -> [SearchItem] {
        let jsController = JSController()
        let jsPath = servicesDirectory.appendingPathComponent(service.localPath).appendingPathComponent("script.js")
        
        guard FileManager.default.fileExists(atPath: jsPath.path),
              let jsContent = try? String(contentsOf: jsPath, encoding: .utf8) else {
            return []
        }
        
        jsController.loadScript(jsContent)
        
        return await withCheckedContinuation { continuation in
            jsController.fetchJsSearchResults(keyword: query, module: service) { results in
                continuation.resume(returning: results)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidJSONURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else { return false }
        return url.pathExtension.lowercased() == "json" || text.lowercased().contains(".json")
    }
    
    private func downloadAndParseMetadata(from urlString: String) async throws -> ServicesMetadata {
        guard let url = URL(string: urlString) else { throw ServiceError.invalidURL }
        
        let (data, response) = try await URLSession.custom.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.downloadFailed }
        
        return try JSONDecoder().decode(ServicesMetadata.self, from: data)
    }
    
    private func downloadJavaScript(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { throw ServiceError.invalidScriptURL }
        
        let (data, response) = try await URLSession.custom.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.scriptDownloadFailed }
        guard let jsContent = String(data: data, encoding: .utf8) else { throw ServiceError.invalidScriptContent }
        
        return jsContent
    }
    
    private func saveService(metadata: ServicesMetadata, jsContent: String, metadataUrl: String) async throws -> Services {
        let tempServiceId = UUID()
        let serviceFolderName = "\(metadata.sourceName.replacingOccurrences(of: " ", with: "_"))_\(tempServiceId.uuidString.prefix(8))"
        let servicePath = servicesDirectory.appendingPathComponent(serviceFolderName)
        
        try FileManager.default.createDirectory(at: servicePath, withIntermediateDirectories: true)
        
        let jsonData = try JSONEncoder().encode(metadata)
        try jsonData.write(to: servicePath.appendingPathComponent("metadata.json"))
        try jsContent.write(to: servicePath.appendingPathComponent("script.js"), atomically: true, encoding: .utf8)
        
        let serviceId = generateServiceUUID(from: metadata, folderName: serviceFolderName)
        
#if os(tvOS)
        let activeOnAdd = true
#else
        let activeOnAdd = false
#endif
        
        return Services(
            id: serviceId,
            metadata: metadata,
            localPath: serviceFolderName,
            metadataUrl: metadataUrl,
            isActive: activeOnAdd
        )
    }
    
    private func saveuPdateService(metadata: ServicesMetadata, jsContent: String, metadataUrl: String) async throws -> Services {
        if let existingIndex = services.firstIndex(where: { $0.metadata.sourceName == metadata.sourceName && $0.metadata.author.name == metadata.author.name }) {
            let existingService = services[existingIndex]
            
            if existingService.metadata.version == metadata.version {
                return existingService
            }
            
            let cmp = comparVersions(metadata.version, existingService.metadata.version)
            if cmp == 1 {
                let servicePath = servicesDirectory.appendingPathComponent(existingService.localPath)
                let jsonData = try JSONEncoder().encode(metadata)
                try jsonData.write(to: servicePath.appendingPathComponent("metadata.json"))
                try jsContent.write(to: servicePath.appendingPathComponent("script.js"), atomically: true, encoding: .utf8)
                
                let updatedService = Services(
                    id: existingService.id,
                    metadata: metadata,
                    localPath: existingService.localPath,
                    metadataUrl: metadataUrl,
                    isActive: existingService.isActive
                )
                
                await MainActor.run {
                    self.services[existingIndex] = updatedService
                }
                
                Logger.shared.log("Updated service to version: \(metadata.sourceName) v\(metadata.version)", type: "ServiceManager")
                return updatedService
            } else {
                return existingService
            }
        }
        
        let newService = try await saveService(metadata: metadata, jsContent: jsContent, metadataUrl: metadataUrl)
        await MainActor.run { self.services.append(newService) }
        return newService
    }
    
    private func createServicesDirectoryIfNeeded() {
        guard !FileManager.default.fileExists(atPath: servicesDirectory.path) else { return }
        try? FileManager.default.createDirectory(at: servicesDirectory, withIntermediateDirectories: true)
    }
    
    private func loadExistingServices() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: servicesDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        
        services = contents.compactMap { folder in
            folder.hasDirectoryPath ? loadService(from: folder) : nil
        }
    }
    
    private func loadService(from folderURL: URL) -> Services? {
        let metadataPath = folderURL.appendingPathComponent("metadata.json")
        guard FileManager.default.fileExists(atPath: metadataPath.path),
              let data = try? Data(contentsOf: metadataPath),
              let metadata = try? JSONDecoder().decode(ServicesMetadata.self, from: data) else {
            return nil
        }
        
        let serviceId = generateServiceUUID(from: metadata, folderName: folderURL.lastPathComponent)
        let savedState = loadServiceState(for: serviceId)
        
        Logger.shared.log("Loaded service \(metadata.sourceName) with ID: \(serviceId.uuidString), active: \(savedState)", type: "ServiceManager")
        
        return Services(
            id: serviceId,
            metadata: metadata,
            localPath: folderURL.lastPathComponent,
            metadataUrl: "",
            isActive: savedState
        )
    }
    
    private func comparVersions(_ a: String, _ b: String) -> Int {
        let aParts = a.split(separator: ".").map { Int($0) ?? 0 }
        let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
        let maxLen = max(aParts.count, bParts.count)
        
        for i in 0..<maxLen {
            let ai = i < aParts.count ? aParts[i] : 0
            let bi = i < bParts.count ? bParts[i] : 0
            if ai < bi { return -1 }
            if ai > bi { return 1 }
        }
        return 0
    }
    
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            self.isDownloading = true
            self.downloadProgress = progress
            self.downloadMessage = message
        }
    }
    
    private func resetDownloadState() async {
        await MainActor.run {
            self.isDownloading = false
            self.downloadProgress = 0.0
            self.downloadMessage = ""
        }
    }
    
    // MARK: - Service Settings
    
    func getServiceSettings(_ service: Services) -> [ServiceSetting] {
        let jsPath = servicesDirectory.appendingPathComponent(service.localPath).appendingPathComponent("script.js")
        guard let jsContent = try? String(contentsOf: jsPath, encoding: .utf8) else { return [] }
        return parseSettingsFromJS(jsContent)
    }
    
    func updateServiceSettings(_ service: Services, settings: [ServiceSetting]) -> Bool {
        let jsPath = servicesDirectory.appendingPathComponent(service.localPath).appendingPathComponent("script.js")
        
        guard let jsContent = try? String(contentsOf: jsPath, encoding: .utf8) else { return false }
        let updatedJS = updateSettingsInJS(jsContent, with: settings)
        
        return (try? updatedJS.write(to: jsPath, atomically: true, encoding: .utf8)) != nil
    }
    
    private func parseSettingsFromJS(_ jsContent: String) -> [ServiceSetting] {
        let lines = jsContent.components(separatedBy: .newlines)
        var settings: [ServiceSetting] = []
        var inSettingsSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains("// Settings start") {
                inSettingsSection = true
                continue
            } else if trimmedLine.contains("// Settings end") {
                break
            }
            
            if inSettingsSection && trimmedLine.hasPrefix("const "),
               let setting = parseSettingLine(trimmedLine) {
                settings.append(setting)
            }
        }
        
        return settings
    }
    
    private func parseSettingLine(_ line: String) -> ServiceSetting? {
        let settingRegex = try! NSRegularExpression(pattern: #"const\s+(\w+)\s*=\s*([^;]+);"#)
        let commentRegex = try! NSRegularExpression(pattern: #"//\s*(.+)$"#)
        let range = NSRange(location: 0, length: line.utf16.count)
        
        guard let match = settingRegex.firstMatch(in: line, range: range),
              let keyRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        
        let key = String(line[keyRange])
        let valueString = String(line[valueRange]).trimmingCharacters(in: .whitespaces)
        
        let rawComment = commentRegex.firstMatch(in: line, range: range).flatMap { match in
            Range(match.range(at: 1), in: line).map { String(line[$0]) }
        }
        
        var comment: String? = nil
        var options: [String]? = nil
        if let rc = rawComment {
            if let start = rc.firstIndex(of: "["), let end = rc.firstIndex(of: "]"), end > start {
                let optsSub = rc[rc.index(after: start)..<end]
                let rawOpts = optsSub.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                let cleaned = rawOpts.map { opt -> String in
                    var s = opt.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let first = s.first, let last = s.last,
                       "\"'“”‘’".contains(first), "\"'“”‘’".contains(last) {
                        s = String(s[s.index(after: s.startIndex)..<s.index(before: s.endIndex)])
                    }
                    return s
                }.filter { !$0.isEmpty }
                
                if !cleaned.isEmpty {
                    options = cleaned
                }
                
                var temp = rc
                temp.removeSubrange(start...end)
                let trimmed = temp.trimmingCharacters(in: .whitespacesAndNewlines)
                comment = trimmed.isEmpty ? nil : trimmed
            } else {
                comment = rc.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        let (type, cleanValue) = determineSettingType(from: valueString)
        
        return ServiceSetting(key: key, value: cleanValue, type: type, comment: comment, options: options)
    }
    
    private func determineSettingType(from valueString: String) -> (ServiceSetting.SettingType, String) {
        func stripQuotes(_ s: String) -> String {
            var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.count >= 2, let first = t.first, let last = t.last,
               "\"'“”‘’".contains(first), "\"'“”‘’".contains(last) {
                t = String(t[t.index(after: t.startIndex)..<t.index(before: t.endIndex)])
            }
            return t
        }
        
        let trimmed = valueString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first, let last = trimmed.last, "\"'“”‘’".contains(first) && "\"'“”‘’".contains(last) {
            return (.string, stripQuotes(trimmed))
        } else if valueString.lowercased() == "true" || valueString.lowercased() == "false" {
            return (.bool, valueString.lowercased())
        } else if valueString.contains(".") {
            return (.float, valueString)
        } else if Int(valueString) != nil {
            return (.int, valueString)
        } else {
            return (.string, stripQuotes(valueString))
        }
    }
    
    private func updateSettingsInJS(_ jsContent: String, with settings: [ServiceSetting]) -> String {
        var lines = jsContent.components(separatedBy: .newlines)
        let settingRegex = try! NSRegularExpression(pattern: #"const\s+(\w+)\s*=\s*([^;]+);"#)
        let settingsMap = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0) })
        
        var inSettingsSection = false
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains("// Settings start") {
                inSettingsSection = true
                continue
            } else if trimmedLine.contains("// Settings end") {
                break
            }
            
            if inSettingsSection && trimmedLine.hasPrefix("const ") {
                let range = NSRange(location: 0, length: trimmedLine.utf16.count)
                
                if let match = settingRegex.firstMatch(in: trimmedLine, range: range),
                   let keyRange = Range(match.range(at: 1), in: trimmedLine) {
                    let key = String(trimmedLine[keyRange])
                    
                    if let setting = settingsMap[key] {
                        let formattedValue = formatSettingValue(setting)
                        
                        var commentParts: [String] = []
                        if let c = setting.comment, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            commentParts.append(c)
                        }
                        if let opts = setting.options, !opts.isEmpty {
                            let optsEscaped = opts.map { "\"\($0)\"" }.joined(separator: ", ")
                            commentParts.append("[\(optsEscaped)]")
                        }
                        
                        let commentPart = commentParts.isEmpty ? "" : " // " + commentParts.joined(separator: " ")
                        let leadingWhitespace = String(line.prefix(while: \.isWhitespace))
                        lines[index] = "\(leadingWhitespace)const \(setting.key) = \(formattedValue);\(commentPart)"
                    }
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatSettingValue(_ setting: ServiceSetting) -> String {
        switch setting.type {
        case .string:
            return "\"\(setting.value)\""
        case .bool, .int, .float:
            return setting.value
        }
    }
}

// MARK: - Extensions

extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Service Errors

enum ServiceError: LocalizedError {
    case invalidURL, invalidScriptURL, downloadFailed, scriptDownloadFailed, invalidJSON, invalidScriptContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL provided"
        case .invalidScriptURL: return "Invalid script URL in metadata"
        case .downloadFailed: return "Failed to download metadata"
        case .scriptDownloadFailed: return "Failed to download JavaScript file"
        case .invalidJSON: return "Invalid JSON format"
        case .invalidScriptContent: return "Invalid JavaScript content"
        }
    }
}

// MARK: - Concurrency Helpers

extension ServiceManager {
    fileprivate static func withTimeout<T>(seconds: UInt64, operation: @escaping () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                return await operation()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                return nil
            }
            
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
