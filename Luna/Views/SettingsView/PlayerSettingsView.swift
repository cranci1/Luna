//
//  PlayerSettingsView.swift
//  Sora
//
//  Created by Francesco on 19/09/25.
//

import SwiftUI

enum ExternalPlayer: String, CaseIterable, Identifiable {
    case none = "Default"
    case infuse = "Infuse"
    case vlc = "VLC"
    case outPlayer = "OutPlayer"
    case nPlayer = "nPlayer"
    case senPlayer = "SenPlayer"
    case tracy = "TracyPlayer"
    case vidHub = "VidHub"
    
    var id: String { rawValue }
    
    func schemeURL(for urlString: String) -> URL? {
        let url = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        switch self {
        case .infuse:
            return URL(string: "infuse://x-callback-url/play?url=\(url)")
        case .vlc:
            return URL(string: "vlc://\(url)")
        case .outPlayer:
            return URL(string: "outplayer://\(url)")
        case .nPlayer:
            return URL(string: "nplayer-\(url)")
        case .senPlayer:
            return URL(string: "senplayer://x-callback-url/play?url=\(url)")
        case .tracy:
            return URL(string: "tracy://open?url=\(url)")
        case .vidHub:
            return URL(string: "open-vidhub://x-callback-url/open?url=\(url)")
        case .none:
            return nil
        }
    }
}

enum InAppPlayer: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case mpv = "mpv"
    
    var id: String { rawValue }
}

final class PlayerSettingsStore: ObservableObject {
    @Published var holdSpeed: Double {
        didSet { UserDefaults.standard.set(holdSpeed, forKey: "holdSpeedPlayer") }
    }
    
    @Published var externalPlayer: ExternalPlayer {
        didSet { UserDefaults.standard.set(externalPlayer.rawValue, forKey: "externalPlayer") }
    }
    
    @Published var landscapeOnly: Bool {
        didSet { UserDefaults.standard.set(landscapeOnly, forKey: "alwaysLandscape") }
    }
    
    @Published var inAppPlayer: InAppPlayer {
        didSet { UserDefaults.standard.set(inAppPlayer.rawValue, forKey: "inAppPlayer") }
    }
    
    init() {
        let savedSpeed = UserDefaults.standard.double(forKey: "holdSpeedPlayer")
        self.holdSpeed = savedSpeed > 0 ? savedSpeed : 2.0
        
        let raw = UserDefaults.standard.string(forKey: "externalPlayer") ?? ExternalPlayer.none.rawValue
        self.externalPlayer = ExternalPlayer(rawValue: raw) ?? .none
        
        self.landscapeOnly = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        
        let inAppRaw = UserDefaults.standard.string(forKey: "inAppPlayer") ?? InAppPlayer.normal.rawValue
        self.inAppPlayer = InAppPlayer(rawValue: inAppRaw) ?? .normal
    }
}

struct PlayerSettingsView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared
    @StateObject private var store = PlayerSettingsStore()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section(header: Text("Default Player"), footer: Text("This settings work exclusively with the Default media player.")) {
#if !os(tvOS)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "Hold Speed: %.1fx", store.holdSpeed))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Value of long-press speed playback in the player.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Stepper(value: $store.holdSpeed, in: 0.1...3, step: 0.1) {}
                }
#endif
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force Landscape")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Force landscape orientation in the video player.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $store.landscapeOnly)
                        .tint(accentColorManager.currentAccentColor)
                }
            }
            .disabled(store.externalPlayer != .none)
            
            Section(header: Text("Media Player")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Media Player")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("The app must be installed and accept the provided scheme.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Picker("", selection: $store.externalPlayer) {
                        ForEach(ExternalPlayer.allCases) { player in
                            Text(player.rawValue).tag(player)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("In-App Player")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Select the internal player software.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Picker("", selection: $store.inAppPlayer) {
                        ForEach(InAppPlayer.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .navigationTitle("Media Player")
    }
}
