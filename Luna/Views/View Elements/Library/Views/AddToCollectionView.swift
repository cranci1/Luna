//
//  AddToCollectionView.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import SwiftUI

struct AddToCollectionView: View {
    let searchResult: TMDBSearchResult
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var accentColorManager = AccentColorManager.shared
    @ObservedObject private var libraryManager = LibraryManager.shared
    @State private var showingCreateSheet = false
    
    var item: LibraryItem { LibraryItem(searchResult: searchResult) }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(libraryManager.collections) { collection in
                        HStack {
                            Image(systemName: collection.name == "Bookmarks" ? "bookmark.fill" : "folder")
                                .foregroundColor(collection.name == "Bookmarks" ? .yellow : .primary)
                            VStack(alignment: .leading) {
                                Text(collection.name)
                                    .fontWeight(collection.name == "Bookmarks" ? .semibold : .regular)
                                if let desc = collection.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if libraryManager.isItemInCollection(collection.id, item: item) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(accentColorManager.currentAccentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if libraryManager.isItemInCollection(collection.id, item: item) {
                                libraryManager.removeItem(from: collection.id, item: item)
                            } else {
                                libraryManager.addItem(to: collection.id, item: item)
                            }
                        }
                    }
                }
                
                Button("Create New Collection") {
                    showingCreateSheet = true
                }
                .padding()
            }
            .navigationTitle("Add to Collection")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") { dismiss() }
            )
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateCollectionView()
        }
    }
}
