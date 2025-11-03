import SwiftUI
import Kingfisher

struct FeaturedCard: View {
    let result: TMDBSearchResult
    let isLarge: Bool

    @State private var isHovering: Bool = false

    init(result: TMDBSearchResult, isLarge: Bool = false) {
        self.result = result
        self.isLarge = isLarge
    }

    private var cardWidth: CGFloat {
        isTvOS ?
            (isLarge ? 450 : 390) :
            (isLarge ? 250 : 190)
    }

    private var cardHeight: CGFloat {
        isTvOS ?
            (isLarge ? 250 : 190) :
            (isLarge ? 150 : 90)
    }

    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)) {
            VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        KFImage(URL(string: result.fullBackdropURL ?? result.fullPosterURL ?? ""))
                            .placeholder {
                                FallbackImageView(
                                    isMovie: result.isMovie,
                                    size: CGSize(width: cardWidth, height: cardHeight)
                                )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .clipped()

                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: isTvOS ? 18 : 8) {
                                    // Pilule mediatype
                                    Text(result.isMovie ? "Movie" : "TV Show")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, isTvOS ? 16 : 8)
                                        .padding(.vertical, isTvOS ? 6 : 4)
                                        .applyLiquidGlassBackground(cornerRadius: 12)

                                    // Pilule rating
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                        Text(String(format: "%.1f", result.voteAverage ?? 0.0))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                        .padding(.horizontal, isTvOS ? 16 : 8)
                                        .padding(.vertical, isTvOS ? 6 : 4)
                                        .applyLiquidGlassBackground(cornerRadius: 12)
                                }
                                Spacer()
                            }
                            .padding(.leading, isTvOS ? 20 : 10)
                            .padding(.bottom, isTvOS ? 20 : 10)
                        }
                    }
                    .tvos({ view in
                        view
                            .hoverEffect(.highlight)
                            .onContinuousHover { phase in
                                switch phase {
                                    case .active(_):
                                        isHovering = true
                                    case .ended:
                                        isHovering = false
                                }
                            }
                    }, else: { view in
                        view
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    })

                    Text(result.displayTitle)
                    .tvos({ view in
                        view
                            .foregroundColor(isHovering ? .white : .secondary)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.bottom, 10)
                    }, else: { view in
                        view
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .semibold))
                    })
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 8)
                    .padding(.top, isTvOS ? 20 : 8)
                    .frame(width: cardWidth, alignment: .leading)
                }
                .contentShape(Rectangle())
        }
        .tvos({ view in
            view.buttonStyle(BorderlessButtonStyle())
        }, else: { view in
            view.buttonStyle(PlainButtonStyle())
        })
    }
}
