//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct EpisodeCell: View {
    let episode: TMDBEpisode
    let showId: Int
    let progress: Double
    let isSelected: Bool
    let onTap: () -> Void
    let onMarkWatched: () -> Void
    let onResetProgress: () -> Void
    
    @State private var isWatched: Bool = false
    @AppStorage("horizontalEpisodeList") private var horizontalEpisodeList: Bool = false
    
    private var episodeKey: String {
        "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
    }
    
    var body: some View {
        if horizontalEpisodeList {
            horizontalLayout
        } else {
            verticalLayout
        }
    }
    
    @MainActor private var horizontalLayout: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    KFImage(URL(string: episode.fullStillURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                )
                        }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 240, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if progress > 0 && progress < 0.95 {
                        VStack {
                            Spacer()
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                                .frame(height: 3)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 4)
                        }
                        .frame(width: 240, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Episode \(episode.episodeNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack {
                            HStack(spacing: 2) {
                                if episode.voteAverage > 0 {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", episode.voteAverage))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                    
                                    
                                    Text(" - ")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                                
                                if let runtime = episode.runtime, runtime > 0 {
                                    Text(episode.runtimeFormatted)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .applyLiquidGlassBackground(
                            cornerRadius: 16,
                            fallbackFill: Color.gray.opacity(0.2),
                            fallbackMaterial: .thinMaterial,
                            glassTint: Color.gray.opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    
                    if !episode.name.isEmpty {
                        Text(episode.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(width: 240, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            episodeContextMenu
        }
        .onAppear {
            loadEpisodeProgress()
        }
        .preferredColorScheme(.dark)
    }
    
    @MainActor private var verticalLayout: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    KFImage(URL(string: episode.fullStillURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                )
                        }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    if progress > 0 && progress < 0.95 {
                        VStack {
                            Spacer()
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                                .frame(height: 3)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 4)
                        }
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Episode \(episode.episodeNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        HStack {
                            HStack(spacing: 2) {
                                if episode.voteAverage > 0 {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", episode.voteAverage))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                    
                                    
                                    Text(" - ")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                                
                                if let runtime = episode.runtime, runtime > 0 {
                                    Text(episode.runtimeFormatted)
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .applyLiquidGlassBackground(
                            cornerRadius: 16,
                            fallbackFill: Color.gray.opacity(0.2),
                            fallbackMaterial: .thinMaterial,
                            glassTint: Color.gray.opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    
                    if !episode.name.isEmpty {
                        Text(episode.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.white)
                    }
                    
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .applyLiquidGlassBackground(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            episodeContextMenu
        }
        .onAppear {
            loadEpisodeProgress()
        }
        .preferredColorScheme(.dark)
    }
    
    private var episodeContextMenu: some View {
        Group {
            Button(action: onTap) {
                Label("Play", systemImage: "play.fill")
            }
            
            if episode.episodeNumber > 1 {
                Button(action: {
                    ProgressManager.shared.markPreviousEpisodesAsWatched(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onMarkWatched()
                }) {
                    Label("Mark Previous as Watched", systemImage: "chevron.left.slash.chevron.right")
                }
            }
            
            if progress < 0.95 {
                Button(action: {
                    ProgressManager.shared.markEpisodeAsWatched(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onMarkWatched()
                    isWatched = true
                }) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress > 0 {
                Button(action: {
                    ProgressManager.shared.resetEpisodeProgress(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onResetProgress()
                    isWatched = false
                }) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
    
    private func loadEpisodeProgress() {
        isWatched = ProgressManager.shared.isEpisodeWatched(
            showId: showId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
}
