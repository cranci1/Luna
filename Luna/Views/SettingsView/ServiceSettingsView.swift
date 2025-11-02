//
//  ServiceSettingsView.swift
//  Sora
//
//  Created by Francesco on 15/08/25.
//

import SwiftUI
import Kingfisher

struct ServiceSettingsView: View {
    let service: Services
    @ObservedObject var serviceManager: ServiceManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: [ServiceSetting] = []
    @State private var editedSettings: [String: String] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if settings.isEmpty {
                    emptyStateView
                } else {
                    settingsList
                }
            }
            .navigationTitle("\(service.metadata.sourceName)")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(isSaving || !hasChanges)
                }
            }
        }
        .task {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("The service settings have been updated successfully.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading settings...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Settings Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This service doesn't have configurable settings.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var settingsList: some View {
        List {
            Section {
                serviceHeaderView
            }
            .listRowBackground(Color.clear)
            
            Section {
                ForEach(Array(settings.enumerated()), id: \.element.key) { index, setting in
                    SettingRow(
                        setting: setting,
                        value: Binding(
                            get: { editedSettings[setting.key] ?? setting.value },
                            set: { editedSettings[setting.key] = $0 }
                        )
                    )
                }
            } header: {
                Text("Configuration")
            }
        }
    }
    
    @ViewBuilder
    private var serviceHeaderView: some View {
        HStack(spacing: 16) {
            KFImage(URL(string: service.metadata.iconUrl))
                .placeholder {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "app.dashed")
                                .foregroundColor(.secondary)
                        )
                }
                .resizable()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.metadata.sourceName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Text("v\(service.metadata.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(service.metadata.author.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(service.metadata.language)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var hasChanges: Bool {
        for setting in settings {
            if editedSettings[setting.key] != setting.value {
                return true
            }
        }
        return false
    }
    
    private func loadSettings() {
        settings = serviceManager.getServiceSettings(service)
        isLoading = false
        
        for setting in settings {
            editedSettings[setting.key] = setting.value
        }
    }
    
    private func saveSettings() {
        isSaving = true
        
        let updatedSettings = settings.map { setting in
            ServiceSetting(
                key: setting.key,
                value: editedSettings[setting.key] ?? setting.value,
                type: setting.type,
                comment: setting.comment,
                options: setting.options
            )
        }
        
        if serviceManager.updateServiceSettings(service, settings: updatedSettings) {
            showSuccessAlert = true
        } else {
            errorMessage = "Failed to save settings. Please try again."
            showErrorAlert = true
        }
        
        isSaving = false
    }
}

struct SettingRow: View {
    let setting: ServiceSetting
    @Binding var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(setting.key)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let comment = setting.comment {
                    Text(comment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            settingInputView
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var settingInputView: some View {
        switch setting.type {
        case .bool:
            HStack {
                Text(setting.key)
                    .font(.body)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { value.lowercased() == "true" },
                    set: { value = $0 ? "true" : "false" }
                ))
                .labelsHidden()
            }
            
        case .int:
            TextField("Enter number", text: Binding(
                get: { value },
                set: { newValue in
                    let filtered = newValue.filter { "0123456789-".contains($0) }
                    value = filtered
                }
            ))
            .textFieldStyle(modernTextFieldStyle)
            .keyboardType(.numberPad)
            
        case .float:
            TextField("Enter decimal number", text: Binding(
                get: { value },
                set: { newValue in
                    let filtered = newValue.filter { "0123456789.,-".contains($0) }
                    value = filtered
                }
            ))
            .textFieldStyle(modernTextFieldStyle)
            .keyboardType(.decimalPad)
            
        case .string:
            if let options = setting.options, !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { opt in
                        Button {
                            value = opt
                        } label: {
                            HStack {
                                Text(opt)
                                Spacer()
                                if value == opt {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(value.isEmpty ? "Select" : value)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.06))
                    )
                }
            } else {
                TextField("Enter text", text: $value)
                    .textFieldStyle(modernTextFieldStyle)
            }
        }
    }
    
    private var modernTextFieldStyle: some TextFieldStyle {
        ModernTextFieldStyle()
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .applyLiquidGlassBackground(cornerRadius: 10)
    }
}

extension ServiceSetting.SettingType {
    var displayName: String {
        switch self {
        case .string: return "Text"
        case .bool: return "Boolean"
        case .int: return "Number"
        case .float: return "Decimal"
        }
    }
}
