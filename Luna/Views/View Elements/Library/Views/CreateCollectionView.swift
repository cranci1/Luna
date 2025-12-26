//
//  CreateCollectionView.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import SwiftUI

struct CreateCollectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var libraryManager = LibraryManager.shared
    
    @State private var name = ""
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Collection Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
            }
            .navigationTitle("New Collection")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Create") {
                    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        libraryManager.createCollection(name: name.trimmingCharacters(in: .whitespaces), description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            )
        }
    }
}
