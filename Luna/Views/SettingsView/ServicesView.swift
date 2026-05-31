//
//  ServicesView.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import SwiftUI
import Kingfisher

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ServicesView: View {
    @StateObject private var serviceManager = ServiceManager.shared
    @Environment(\.editMode) private var editMode
    @State private var showDownloadAlert = false
    @State private var downloadURL = ""
    @State private var showServiceDownloadAlert = false
    
    var body: some View {
        ZStack {
            VStack {
                if serviceManager.services.isEmpty {
                    emptyStateView
                } else {
                    servicesList
                }
            }
            .navigationTitle("Services")
#if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if editMode?.wrappedValue != .active {
                        Button {
                            showAddServiceAlert()
                        } label: {
                            Image(systemName: "plus.app")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            editMode?.wrappedValue =
                            (editMode?.wrappedValue == .active) ? .inactive : .active
                        }
                    } label: {
                        Image(systemName:
                                editMode?.wrappedValue == .active ? "checkmark" : "pencil")
                    }
                }
            }
#endif
            .refreshable {
                await serviceManager.updateServices()
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Services")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var servicesList: some View {
        List {
            ForEach(serviceManager.services, id: \.id) { service in
                ServiceRow(service: service, serviceManager: serviceManager)
            }
            .onDelete(perform: deleteServices)
            .onMove { indices, newOffset in
                serviceManager.moveServices(fromOffsets: indices, toOffset: newOffset)
            }
        }
    }
    
    private func deleteServices(offsets: IndexSet) {
        for index in offsets {
            let service = serviceManager.services[index]
            serviceManager.removeService(service)
        }
    }
    
    private func showAddServiceAlert() {
#if os(iOS)
        let pasteboardString = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if !pasteboardString.isEmpty {
            presentClipboardAlert(clipboardText: pasteboardString)
        } else {
            presentManualURLAlert()
        }
#else
        showDownloadAlert = true
#endif
    }
    
#if os(iOS)
    @MainActor
    private func presentClipboardAlert(clipboardText: String) {
        let clipboardAlert = UIAlertController(
            title: "Clipboard Detected",
            message: "We found some text in your clipboard. Would you like to use it as the service URL?",
            preferredStyle: .alert
        )
        
        clipboardAlert.addAction(UIAlertAction(title: "Use Clipboard", style: .default, handler: { _ in
            downloadServiceFromURL(clipboardText)
        }))
        
        clipboardAlert.addAction(UIAlertAction(title: "Enter Manually", style: .default, handler: { _ in
            presentManualURLAlert()
        }))
        
        topViewController()?.present(clipboardAlert, animated: true)
    }
    
    @MainActor
    private func presentManualURLAlert() {
        let alert = UIAlertController(title: "Add Service", message: "Enter the URL of the service JSON file", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "https://real.url/service.json"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            let url = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !url.isEmpty else { return }
            downloadServiceFromURL(url)
        }))
        
        topViewController()?.present(alert, animated: true)
    }
    
    @MainActor
    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        
        var current = rootViewController
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
#endif
    
    private func downloadServiceFromURL() {
        downloadServiceFromURL(downloadURL)
    }
    
    private func downloadServiceFromURL(_ urlString: String) {
        let sanitizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitizedURL.isEmpty else {
            return
        }
        
        Task {
            do {
                let wasHandled = await serviceManager.handlePotentialServiceURL(sanitizedURL)
                if wasHandled {
                    await MainActor.run {
                        downloadURL = ""
                        showServiceDownloadAlert = true
                    }
                }
            }
        }
    }
}


struct ServiceRow: View {
    let service: Service
    @ObservedObject var serviceManager: ServiceManager
    @State private var showingSettings = false
    
    private var isServiceActive: Bool {
        if let managedService = serviceManager.services.first(where: { $0.id == service.id }) {
            return managedService.isActive
        }
        return service.isActive
    }
    
    private var hasSettings: Bool {
        service.metadata.settings == true
    }
    
    private func copyServiceURL(_ url: String) {
#if os(iOS)
        UIPasteboard.general.string = url
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
#endif
    }
    
    var body: some View {
        HStack {
            KFImage(URL(string: service.metadata.iconUrl))
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "app.dashed")
                                .foregroundColor(.secondary)
                        )
                }
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .padding(.trailing, 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(service.metadata.sourceName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Text(service.metadata.author.name)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text(service.metadata.language)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text("v\(service.metadata.version)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if hasSettings {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if isServiceActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .contentShape(Rectangle())
#if os(iOS) || os(macOS)
        .contextMenu {
            Button {
                copyServiceURL(service.url)
            } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
        }
#endif
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                serviceManager.setServiceState(service, isActive: !isServiceActive)
            }
        }
        .sheet(isPresented: $showingSettings) {
            ServiceSettingsView(service: service, serviceManager: serviceManager)
        }
    }
}
