//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct LibraryView: View {
    @State private var showingCreateSheet = false
    
    @StateObject private var accentColorManager = AccentColorManager.shared
    @ObservedObject private var libraryManager = LibraryManager.shared
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                libraryContent
            }
        } else {
            NavigationView {
                libraryContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                bookmarksSection
                collectionsSection
            }
            .padding(.top)
        }
        .navigationTitle("Library")
        .navigationBarItems(trailing: Button(action: {
            showingCreateSheet = true
        }) {
            Image(systemName: "plus")
                .foregroundColor(accentColorManager.currentAccentColor)
        })
        .sheet(isPresented: $showingCreateSheet) {
            CreateCollectionView()
        }
    }
    
    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Bookmarks")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                if let bookmarksCollection = libraryManager.collections.first(where: { $0.name == "Bookmarks" }) {
                    Text("\(bookmarksCollection.items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if let bookmarksCollection = libraryManager.collections.first(where: { $0.name == "Bookmarks" }),
               !bookmarksCollection.items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        // Show oldest bookmarks first so order is predictable
                        ForEach(bookmarksCollection.items.sorted(by: { $0.dateAdded < $1.dateAdded })) { item in
                            NavigationLink(destination: MediaDetailView(searchResult: item.searchResult)) {
                                BookmarkItemCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No bookmarks yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("Bookmark items to see them here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    
    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Collections")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(libraryManager.collections.filter { $0.name != "Bookmarks" }.count) collections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            let nonBookmarkCollections = libraryManager.collections.filter { $0.name != "Bookmarks" }
            
            if !nonBookmarkCollections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(nonBookmarkCollections) { collection in
                            NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                CollectionCard(collection: collection)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No collections yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("Create collections to organize your media")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
}

struct BookmarkItemCard: View {
    let item: LibraryItem
    
    var body: some View {
        VStack(spacing: 8) {
            KFImage(URL(string: item.searchResult.fullPosterURL ?? ""))
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: item.searchResult.isMovie ? "tv" : "tv.and.mediabox")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
            
            Text(item.searchResult.displayTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.white)
        }
        .frame(width: 120, alignment: .leading)
    }
}

struct CollectionCard: View {
    @ObservedObject var collection: LibraryCollection
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 160, height: 160)
                .overlay(
                    collectionPreview
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(spacing: 4) {
                Text(collection.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(collection.items.count) items")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 160)
        }
        .contextMenu {
            if collection.name != "Bookmarks" {
                Button(role: .destructive) {
                    LibraryManager.shared.deleteCollection(collection)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    @MainActor
    private var collectionPreview: some View {
        let recentItems = Array(collection.items.sorted(by: { $0.dateAdded < $1.dateAdded }).suffix(4))
        
        if recentItems.isEmpty {
            VStack {
                Image(systemName: "folder")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Empty")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if recentItems.count == 1 {
            let single = recentItems[0]
            KFImage(URL(string: single.searchResult.fullPosterURL ?? ""))
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: single.searchResult.isMovie ? "tv" : "tv.and.mediabox")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 160, height: 160)
                .id(single.id)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
                ForEach(recentItems) { item in
                    KFImage(URL(string: item.searchResult.fullPosterURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: item.searchResult.isMovie ? "tv" : "tv.and.mediabox")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                )
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 78, height: 78)
                        .clipped()
                        .id(item.id)
                }
                
                ForEach(recentItems.count..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 78, height: 78)
                }
            }
        }
    }
}

#Preview {
    LibraryView()
}
