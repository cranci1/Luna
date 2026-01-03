//
//  ServicesView.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import SwiftUI
import Kingfisher

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

                storageStatusView
            }
            #if os(tvOS)
                .listStyle(.grouped)
                .padding(.horizontal, 50)
                .scrollClipDisabled()
            #else
                .navigationTitle("Services")
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if editMode?.wrappedValue != .active {
                        Button {
                            showDownloadAlert = true
                        } label: {
                            Image(systemName: "plus.app")
                                .tint(.primary)
                        }
                    }
                }

                #if !os(tvOS)
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
                #else
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await serviceManager.updateServices()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .tint(.primary)
                        }
                        .disabled(serviceManager.isDownloading)
                    }
                #endif
            }
            .refreshable {
                await serviceManager.updateServices()
            }
            .alert("Add Service", isPresented: $showDownloadAlert) {
                TextField("JSON URL", text: $downloadURL)
                Button("Cancel", role: .cancel) {
                    downloadURL = ""
                }
                Button("Add") {
                    downloadServiceFromURL()
                }
            } message: {
                Text("Enter the direct JSON file URL")
            }
            .alert("Service Downloaded", isPresented: $showServiceDownloadAlert) {
                Button("OK") { }
            } message: {
                Text("The service has been successfully downloaded and saved to your documents folder.")
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
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var servicesList: some View {
        List {
            Section {
                ForEach(serviceManager.services, id: \.id) { service in
                    ServiceRow(service: service, serviceManager: serviceManager)
                }
                #if !os(tvOS)
                    .onDelete(perform: deleteServices)
                    .onMove { indices, newOffset in
                        serviceManager.moveServices(fromOffsets: indices, toOffset: newOffset)
                    }
                #endif
            } header: {
                #if os(tvOS)
                    Text("SERVICES")
                        .fontWeight(.bold)
                #endif
            }
        }
    }

    @ViewBuilder
    private var storageStatusView: some View {
        let status = ServiceManager.shared.getStatus()

        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: status.symbol)
                    .foregroundColor(status.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(status.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            #if os(tvOS)
                .padding(.horizontal, 20)
                .padding(.vertical)
                .applyLiquidGlassBackground(cornerRadius: 40)
            #endif

            Spacer()
        }
        .padding()
        #if !os(tvOS)
            .background(Color(.secondarySystemBackground))
        #endif
    }

    private func deleteServices(offsets: IndexSet) {
        for index in offsets {
            let service = serviceManager.services[index]
            serviceManager.removeService(service)
        }
    }
    
    private func downloadServiceFromURL() {
        guard !downloadURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            do {
                let wasHandled = await serviceManager.handlePotentialServiceURL(downloadURL)
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
    
    var body: some View {
        #if os(tvOS)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    serviceManager.setServiceState(service, isActive: !isServiceActive)
                }
            } label: {
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
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.metadata.sourceName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(service.metadata.author.name) •  \(service.metadata.language) • v\(service.metadata.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        if hasSettings {
                            Button(action: {
                                showingSettings = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if isServiceActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    ServiceSettingsView(service: service, serviceManager: serviceManager)

                }
            }
            .buttonStyle(.plain)
            .padding(.vertical)
        #else
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
                        .foregroundColor(.primary)

                    Text("\(service.metadata.author.name) •  \(service.metadata.language) • v\(service.metadata.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    /* Temporarily disabled until i have more time or someone else implements this.
                    if hasSettings {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                     */

                    if isServiceActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    serviceManager.setServiceState(service, isActive: !isServiceActive)
                }
            }
            .sheet(isPresented: $showingSettings) {
                ServiceSettingsView(service: service, serviceManager: serviceManager)
            }
        #endif
    }
}
