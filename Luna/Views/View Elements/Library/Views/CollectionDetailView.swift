//
//  CollectionDetailView.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import SwiftUI
import Kingfisher

struct CollectionDetailView: View {
    @ObservedObject var collection: LibraryCollection
    
    var body: some View {
        ScrollView {
            if collection.items.isEmpty {
                VStack {
                    Image(systemName: collection.name == "Bookmarks" ? "bookmark" : "folder")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No items in this collection")
                        .font(.title2)
                        .padding(.top)
                    Text(collection.name == "Bookmarks" ? "Bookmark items from detail views" : "Add media from detail views")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                    ForEach(collection.items) { item in
                        NavigationLink(destination: MediaDetailView(searchResult: item.searchResult)) {
                            VStack {
                                if let url = item.searchResult.fullPosterURL {
                                    KFImage(URL(string: url))
                                        .placeholder {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.secondary.opacity(0.3))
                                        }
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fill)
                                        .frame(width: 120, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                                }
                                
                                Text(item.searchResult.displayTitle)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                LibraryManager.shared.removeItem(from: collection.id, item: item)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(collection.name)
    }
}
