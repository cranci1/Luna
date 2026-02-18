import SwiftUI

struct AnimeCatalogSourceView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared
    @Binding var selectedSource: String

    var body: some View {
        List {
            Section {
                ForEach(AnimeCatalogSource.allCases) { source in
                    #if os(tvOS)
                    Button {
                        selectedSource = source.rawValue
                    } label: {
                        rowContent(for: source)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical)
                    #else
                    rowContent(for: source)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSource = source.rawValue
                        }
                    #endif
                }
            } header: {
                #if os(tvOS)
                Text("SOURCE")
                    .fontWeight(.bold)
                #endif
            } footer: {
                Text("TMDB keeps the original Luna behavior. AniList provides anime-focused catalogs with TMDB-backed posters and metadata.")
                    .foregroundColor(.secondary)
            }
        }
        #if os(tvOS)
        .listStyle(.grouped)
        .padding(.horizontal, 50)
        .scrollClipDisabled()
        #else
        .navigationTitle("Anime Source")
        #endif
    }

    @ViewBuilder
    private func rowContent(for source: AnimeCatalogSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.displayName)
                    .foregroundColor(.primary)
                Text(source.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if selectedSource == source.rawValue {
                Image(systemName: "checkmark")
                    .foregroundColor(accentColorManager.currentAccentColor)
            }
        }
    }
}
