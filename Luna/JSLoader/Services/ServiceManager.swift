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

@MainActor
class ServiceManager: ObservableObject {
    static let shared = ServiceManager()

    @Published var services: [Service] = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadMessage: String = ""

    private init() {
        loadServicesFromStore()
    }

    // MARK: - Public Functions

    let delay: UInt64 = 300_000_000 // 300ms

    func updateServices() async {
        guard !services.isEmpty else { return }

        isDownloading = true
        downloadProgress = 0.0
        downloadMessage = "Updating services..."

        let total = Double(services.count)
        var completed: Double = 0

        for service in services {
            await updateProgress(downloadProgress, "Updating \(service.metadata.sourceName)...")
            try? await Task.sleep(nanoseconds: delay)

            do {
                // Download metadata
                await updateProgress(downloadProgress + 0.1 / total, "Downloading metadata for \(service.metadata.sourceName)...")
                let metadata = try await downloadAndParseMetadata(from: service.url)
                try? await Task.sleep(nanoseconds: delay)

                // Download JavaScript
                await updateProgress(downloadProgress + 0.5 / total, "Downloading JavaScript for \(service.metadata.sourceName)...")
                let jsContent = try await downloadJavaScript(from: metadata.scriptUrl)
                try? await Task.sleep(nanoseconds: delay)

                // Save service using existing ID
                ServiceStore.shared.storeService(
                    id: service.id,
                    url: service.url,
                    jsonMetadata: String(data: try JSONEncoder().encode(metadata), encoding: .utf8) ?? "",
                    jsScript: jsContent,
                    isActive: service.isActive
                )

                Logger.shared.log("Service \(service.metadata.sourceName) updated successfully", type: "ServiceManager")
            } catch {
                Logger.shared.log("Failed to update service \(service.metadata.sourceName): \(error.localizedDescription)", type: "ServiceManager")
            }

            // Update global progress
            completed += 1
            downloadProgress = completed / total
            try? await Task.sleep(nanoseconds: delay)
        }

        // Cleanup
        loadServicesFromStore()
        downloadMessage = "All services updated!"
        try? await Task.sleep(nanoseconds: delay)
        await resetDownloadState()
    }

    // MARK: - Download single service from JSON URL
    func downloadService(from jsonURL: String) async {
        await updateProgress(0.0, "Starting download...")
        try? await Task.sleep(nanoseconds: delay)

        do {
            await updateProgress(0.2, "Downloading metadata...")
            let metadata = try await downloadAndParseMetadata(from: jsonURL)
            try? await Task.sleep(nanoseconds: delay)

            await updateProgress(0.5, "Downloading JavaScript...")
            let jsContent = try await downloadJavaScript(from: metadata.scriptUrl)
            try? await Task.sleep(nanoseconds: delay)

            await updateProgress(0.8, "Saving service...")
            let serviceId = generateServiceUUID(from: metadata)
            ServiceStore.shared.storeService(
                id: serviceId,
                url: jsonURL,
                jsonMetadata: String(data: try JSONEncoder().encode(metadata), encoding: .utf8) ?? "",
                jsScript: jsContent,
                isActive: false
            )
            try? await Task.sleep(nanoseconds: delay)

            loadServicesFromStore()

            await MainActor.run {
                self.downloadProgress = 1.0
                self.downloadMessage = "Service downloaded successfully!"
            }

            try? await Task.sleep(nanoseconds: delay)
            await resetDownloadState()
        } catch {
            await resetDownloadState()
            Logger.shared.log("Failed to download service: \(error.localizedDescription)", type: "ServiceManager")
        }
    }

    func handlePotentialServiceURL(_ text: String) async -> Bool {
        guard isValidJSONURL(text) else { return false }
        await downloadService(from: text)
        return true
    }

    func removeService(_ service: Service) {
        if let entity = ServiceStore.shared.getServices().first(where: { $0.id == service.id }) {
            ServiceStore.shared.remove(entity)
        }
        loadServicesFromStore()
    }

    func toggleServiceState(_ service: Service) {
        ServiceStore.shared.updateService(id: service.id) { entity in
            entity.isActive.toggle()
        }
        loadServicesFromStore()
    }

    func setServiceState(_ service: Service, isActive: Bool) {
        ServiceStore.shared.updateService(id: service.id) { entity in
            entity.isActive = isActive
        }
        loadServicesFromStore()
    }

    func updateServiceSettings(_ service: Service, settings: [ServiceSetting]) -> Bool {
        let jsScript = updateSettingsInJS(service.jsScript, with: settings)

        ServiceStore.shared.updateService(id: service.id) { entity in
            entity.jsScript = jsScript
        }
        loadServicesFromStore()

        return true
    }

    func moveServices(fromOffsets offsets: IndexSet, toOffset: Int) {
        var mutable = services
        mutable.move(fromOffsets: offsets, toOffset: toOffset)

        let updates = mutable.enumerated().map { (index, service) in
            (id: service.id, update: { (entity: ServiceEntity) in
                entity.sortIndex = Int64(index)
            })
        }

        ServiceStore.shared.updateMultipleServices(updates: updates)
        loadServicesFromStore()
    }

    var activeServices: [Service] {
        services.filter(\.isActive)
    }

    func searchInActiveServices(query: String) async -> [(service: Service, results: [SearchItem])] {
        let activeList = activeServices
        guard !activeList.isEmpty else { return [] }

        await updateProgress(0.0, "Searching...")

        var resultsMap: [UUID: [SearchItem]] = [:]

        await withTaskGroup(of: (UUID, [SearchItem]).self) { group in
            for service in activeList {
                group.addTask {
                    let timeoutSeconds: UInt64 = 20_000_000_000 // 20sec
                    return await self.withTimeout(nanoseconds: timeoutSeconds) {
                        let found = await self.searchInService(service: service, query: query)
                        return (service.id, found)
                    } ?? (service.id, [])
                }
            }

            for await (id, results) in group {
                resultsMap[id] = results
            }
        }

        let orderedResults = activeList.map { service in
            (service: service, results: resultsMap[service.id] ?? [])
        }

        await resetDownloadState()
        return orderedResults
    }

    func searchInActiveServicesProgressively(query: String,
                                             onResult: @escaping @MainActor (Service, [SearchItem]?) -> Void,
                                             onComplete: @escaping @MainActor () -> Void) async
    {
        let activeList = activeServices
        guard !activeList.isEmpty else {
            await MainActor.run { onComplete() }
            return
        }

        await withTaskGroup(of: (Service, [SearchItem]?).self) { group in
            for service in activeList {
                group.addTask {
                    let timeoutSeconds: UInt64 = 20_000_000_000 // 20sec
                    return await self.withTimeout(nanoseconds: timeoutSeconds) {
                        let found = await self.searchInService(service: service, query: query)
                        return (service, found)
                    } ?? (service, [])
                }
            }

            for await (service, results) in group {
                await MainActor.run { onResult(service, results) }
            }
        }

        await MainActor.run { onComplete() }
    }

    func getServiceSettings(_ service: Service) -> [ServiceSetting] {
        return parseSettingsFromJS(service.jsScript)
    }

    public func getStatus() -> ServiceStore.StorageStatus {
        return ServiceStore.shared.status()
    }

    // MARK: - Private Helpers

    private func isValidJSONURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else { return false }
        return url.pathExtension.lowercased() == "json" || text.lowercased().contains(".json")
    }

    private func downloadAndParseMetadata(from urlString: String) async throws -> ServiceMetadata {
        guard let url = URL(string: urlString) else { throw ServiceError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.downloadFailed }
        return try JSONDecoder().decode(ServiceMetadata.self, from: data)
    }

    private func downloadJavaScript(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { throw ServiceError.invalidScriptURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.scriptDownloadFailed }
        guard let jsContent = String(data: data, encoding: .utf8) else { throw ServiceError.invalidScriptContent }
        return jsContent
    }

    private func loadServicesFromStore() {
        services = ServiceStore.shared.getServices()
    }

    private func generateServiceUUID(from metadata: ServiceMetadata) -> UUID {
        let identifier = "\(metadata.sourceName)_\(metadata.author.name)_\(metadata.version)"
        let hash = identifier.sha256
        let uuidString = String(hash.prefix(32))
        let formattedUUID = "\(uuidString.prefix(8))-\(uuidString.dropFirst(8).prefix(4))-\(uuidString.dropFirst(12).prefix(4))-\(uuidString.dropFirst(16).prefix(4))-\(uuidString.dropFirst(20).prefix(12))"
        return UUID(uuidString: formattedUUID) ?? UUID()
    }

    private func searchInService(service: Service, query: String) async -> [SearchItem] {
        let jsController = JSController()
        jsController.loadScript(service.jsScript)

        return await withCheckedContinuation { continuation in
            jsController.fetchJsSearchResults(keyword: query, module: service) { results in
                continuation.resume(returning: results)
            }
        }
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

    func withTimeout<T>(nanoseconds: UInt64, operation: @escaping @Sendable () async throws -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in

            // Main task
            group.addTask {
                try? await operation()
            }

            // Timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: nanoseconds)
                return nil
            }

            // Return the first completed result and cancel all other tasks
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
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
