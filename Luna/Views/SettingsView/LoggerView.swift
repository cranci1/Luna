//
//  LoggerView.swift
//  Sora
//
//  Created by Francesco on 10/08/25.
//

import SwiftUI

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: String
    
    var typeColor: Color {
        switch type.lowercased() {
        case "error":
            return .red
        case "warning":
            return .orange
        case "stream":
            return .blue
        case "servicemanager":
            return .purple
        case "debug":
            return .gray
        default:
            return .primary
        }
    }
    
    var typeIcon: String {
        switch type.lowercased() {
        case "error":
            return "exclamationmark.triangle.fill"
        case "warning":
            return "exclamationmark.triangle"
        case "stream":
            return "play.circle"
        case "servicemanager":
            return "gear.circle"
        case "debug":
            return "ladybug"
        default:
            return "info.circle"
        }
    }
}

struct LoggerView: View {
    @StateObject private var loggerManager = LoggerManager.shared
    @State private var selectedLogTypes: Set<String> = []
    @State private var searchText = ""
    @State private var isAutoScrollEnabled = true
    @State private var showingFilterSheet = false
    
    private var filteredLogs: [LogEntry] {
        var logs = loggerManager.logs
        
        if !selectedLogTypes.isEmpty {
            logs = logs.filter { selectedLogTypes.contains($0.type) }
        }
        
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs.sorted { $0.timestamp > $1.timestamp }
    }
    
    private var availableLogTypes: [String] {
        Array(Set(loggerManager.logs.map { $0.type })).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if filteredLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No logs found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredLogs) { log in
                            LogEntryRow(log: log)
                                .id(log.id)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .navigationTitle(NSLocalizedString("Logs", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        loggerManager.clearLogs()
                    }) {
                        Label("Clear All Logs", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let log: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: log.typeIcon)
                    .foregroundColor(log.typeColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.type)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(log.typeColor.opacity(0.2))
                            .foregroundColor(log.typeColor)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(DateFormatter.logTimeFormatter.string(from: log.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(log.message)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 3)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    if log.message.count > 100 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Text(isExpanded ? "Show Less" : "Show More")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if log.message.count > 100 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
        .contextMenu {
            Button(action: {
#if !os(tvOS)
                UIPasteboard.general.string = log.message
#endif
            }) {
                Label("Copy Log Message", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Logger Manager
class LoggerManager: ObservableObject {
    static let shared = LoggerManager()
    
    @Published var logs: [LogEntry] = []
    private let maxLogs = 1000
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogNotification),
            name: NSNotification.Name("LoggerNotification"),
            object: nil
        )

        DispatchQueue.main.async {
            self.loadExistingLogs()
        }
    }

    @MainActor
    private func loadExistingLogs() {
        Task {
            let existingLogsString = await Logger.shared.getLogsAsync()
            if !existingLogsString.isEmpty {
                let logEntries = parseLogsString(existingLogsString)
                DispatchQueue.main.async {
                    self.logs = logEntries
                }
            }
        }
    }
    
    private func parseLogsString(_ logsString: String) -> [LogEntry] {
        let logSections = logsString.components(separatedBy: "\n----\n")
        var parsedLogs: [LogEntry] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        
        for section in logSections {
            guard !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            
            let pattern = #"\[([^\]]+)\] \[([^\]]+)\] (.+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: section, options: [], range: NSRange(section.startIndex..., in: section)) {
                
                let timestampRange = Range(match.range(at: 1), in: section)!
                let typeRange = Range(match.range(at: 2), in: section)!
                let messageRange = Range(match.range(at: 3), in: section)!
                
                let timestampString = String(section[timestampRange])
                let type = String(section[typeRange])
                let message = String(section[messageRange])
                
                if let timestamp = dateFormatter.date(from: timestampString) {
                    let logEntry = LogEntry(timestamp: timestamp, message: message, type: type)
                    parsedLogs.append(logEntry)
                }
            }
        }
        
        return parsedLogs.sorted { $0.timestamp > $1.timestamp }
    }
    
    @objc private func handleLogNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? String,
              let type = userInfo["type"] as? String else { return }
        
        DispatchQueue.main.async {
            self.addLog(message: message, type: type)
        }
    }
    
    func addLog(message: String, type: String) {
        let log = LogEntry(timestamp: Date(), message: message, type: type)
        logs.insert(log, at: 0)
        
        if logs.count > maxLogs {
            logs = Array(logs.prefix(maxLogs))
        }
    }
    
    func clearLogs() {
        logs.removeAll()
        Task {
            await Logger.shared.clearLogsAsync()
        }
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
