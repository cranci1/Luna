//
//  StorageView.swift
//  Luna
//
//  Created by Francesco on 04/11/25.
//

import SwiftUI

struct StorageView: View {
    @State private var cacheSizeBytes: Int64 = 0
    @State private var isLoading: Bool = true
    @State private var isClearing: Bool = false
    @State private var showConfirmClear: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            Section(header: Text("APP CACHE"), footer: Text("Cache includes images and other temporary files that can be removed.")) {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(formattedCacheSize)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(role: .destructive) {
                    showConfirmClear = true
                } label: {
                    if isClearing {
                        HStack {
                            ProgressView()
                            Text("Clearing Cache…")
                        }
                    } else {
                        Text("Clear Cache")
                    }
                }
                .disabled(isClearing || (isLoading && cacheSizeBytes == 0))
            }
            
            if let errorMessage {
                Section(header: Text("ERROR")) {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Storage")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshCacheSize) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading || isClearing)
                .help("Recalculate cache size")
            }
        }
        .onAppear {
            refreshCacheSize()
        }
        .alert("Clear Cache?", isPresented: $showConfirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { clearCache() }
        } message: {
            Text("This will remove cached files. You may need to re-download some content later.")
        }
    }
    
    private var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSizeBytes, countStyle: .file)
    }
    
    private func refreshCacheSize() {
        errorMessage = nil
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let size = calculateDirectorySize(at: cachesDirectory())
            DispatchQueue.main.async {
                self.cacheSizeBytes = size
                self.isLoading = false
            }
        }
    }
    
    private func clearCache() {
        errorMessage = nil
        isClearing = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let dir = cachesDirectory()
                let fileManager = FileManager.default
                let items = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
                for url in items {
                    try? fileManager.removeItem(at: url)
                }
                
                URLCache.shared.removeAllCachedResponses()
                
                let size = calculateDirectorySize(at: dir)
                DispatchQueue.main.async {
                    self.cacheSizeBytes = size
                    self.isClearing = false
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isClearing = false
                    self.isLoading = false
                }
            }
        }
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        var total: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                if resourceValues.isRegularFile == true, let fileSize = resourceValues.fileSize {
                    total += Int64(fileSize)
                }
            } catch {
                continue
            }
        }
        return total
    }
    
    private func cachesDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
}

#Preview {
    StorageView()
}
