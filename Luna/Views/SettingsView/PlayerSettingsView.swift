//
//  PlayerSettingsView.swift
//  Sora
//
//  Created by Francesco on 19/09/25.
//

import AVKit
import Sybau
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
        case .infuse: return URL(string: "infuse://x-callback-url/play?url=\(url)")
        case .vlc: return URL(string: "vlc://\(url)")
        case .outPlayer: return URL(string: "outplayer://\(url)")
        case .nPlayer: return URL(string: "nplayer-\(url)")
        case .senPlayer: return URL(string: "senplayer://x-callback-url/play?url=\(url)")
        case .tracy: return URL(string: "tracy://open?url=\(url)")
        case .vidHub: return URL(string: "open-vidhub://x-callback-url/open?url=\(url)")
        case .none: return nil
        }
    }
}

enum InAppPlayer: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case mpv = "mpv"
    
    var id: String { rawValue }
}

// MARK: - PlayerSettingsStore
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
    
    @Published var skipInterval: Int {
        didSet { UserDefaults.standard.set(skipInterval, forKey: "skipIntervalSeconds") }
    }
    
    @Published var subtitleVisible: Bool {
        didSet { UserDefaults.standard.set(subtitleVisible, forKey: "subtitles_isVisible") }
    }
    
    @Published var subtitleForegroundColor: Color {
        didSet { saveColor(subtitleForegroundColor, forKey: "subtitles_foregroundColor") }
    }
    
    @Published var subtitleStrokeColor: Color {
        didSet { saveColor(subtitleStrokeColor, forKey: "subtitles_strokeColor") }
    }
    
    @Published var subtitleStrokeWidth: Double {
        didSet { UserDefaults.standard.set(subtitleStrokeWidth, forKey: "subtitles_strokeWidth") }
    }
    
    @Published var subtitleFontSize: Double {
        didSet { UserDefaults.standard.set(subtitleFontSize, forKey: "subtitles_fontSize") }
    }
    
    init() {
        let savedSpeed = UserDefaults.standard.double(forKey: "holdSpeedPlayer")
        self.holdSpeed = savedSpeed > 0 ? savedSpeed : 2.0
        
        let raw = UserDefaults.standard.string(forKey: "externalPlayer") ?? ExternalPlayer.none.rawValue
        self.externalPlayer = ExternalPlayer(rawValue: raw) ?? .none
        
        self.landscapeOnly = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        
        let inAppRaw = UserDefaults.standard.string(forKey: "inAppPlayer") ?? InAppPlayer.normal.rawValue
        self.inAppPlayer = InAppPlayer(rawValue: inAppRaw) ?? .normal
        
        let savedInterval = UserDefaults.standard.integer(forKey: "skipIntervalSeconds")
        self.skipInterval = (savedInterval >= 5 && savedInterval <= 90) ? savedInterval : 15
        
        let subtitleVisibleKey = "subtitles_isVisible"
        if UserDefaults.standard.object(forKey: subtitleVisibleKey) != nil {
            self.subtitleVisible = UserDefaults.standard.bool(forKey: subtitleVisibleKey)
        } else {
            self.subtitleVisible = false
            UserDefaults.standard.set(false, forKey: subtitleVisibleKey)
        }
        
        let strokeWidth = UserDefaults.standard.double(forKey: "subtitles_strokeWidth")
        self.subtitleStrokeWidth = strokeWidth > 0 ? strokeWidth : 1.0
        
        let fontSize = UserDefaults.standard.double(forKey: "subtitles_fontSize")
        self.subtitleFontSize = fontSize > 0 ? fontSize : 38.0
        
        self.subtitleForegroundColor = Self.loadColor(forKey: "subtitles_foregroundColor") ?? .white
        self.subtitleStrokeColor = Self.loadColor(forKey: "subtitles_strokeColor") ?? .black
    }
    
    private func saveColor(_ color: Color, forKey key: String) {
        let uiColor = UIColor(color)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private static func loadColor(forKey key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return nil
        }
        return Color(uiColor)
    }
}

// MARK: - PlayerSettingsView
struct PlayerSettingsView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared
    @StateObject private var store = PlayerSettingsStore()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section(
                header: Text("Default Player"),
                footer: Text("This settings work exclusively with the Default media player.")
            ) {
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
                    
                    Spacer()
                    Stepper(value: $store.holdSpeed, in: 0.1...3, step: 0.1) {}
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skip Interval: \(store.skipInterval)s")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Duration to skip forward/backward. (mpv exclusive)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    Stepper(value: $store.skipInterval, in: 5...90, step: 5) {}
                        .disabled(store.inAppPlayer != .mpv)
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
#if !os(tvOS)
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
#endif
                
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
                .disabled(store.externalPlayer != .none)
            }
            
            Section(header: Text("Subtitle Appearance")) {
                Toggle("Show Subtitles", isOn: $store.subtitleVisible)
                    .tint(accentColorManager.currentAccentColor)
                
                HStack {
                    Text("Foreground Color")
                    Spacer()
                    ColorPicker("", selection: $store.subtitleForegroundColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Stroke Color")
                    Spacer()
                    ColorPicker("", selection: $store.subtitleStrokeColor)
                        .labelsHidden()
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "Stroke Width: %.1f", store.subtitleStrokeWidth))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Outline thickness of subtitle text.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Stepper(value: $store.subtitleStrokeWidth, in: 0...3, step: 0.5) {}
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Font Size: \(Int(store.subtitleFontSize))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Text size of subtitles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Stepper(value: $store.subtitleFontSize, in: 20...80, step: 2) {}
                }
            }
            .disabled(store.externalPlayer != .none)
            
            Section(header: Text("Testing")) {
                Button(action: { playTestVideo() }) {
                    Text("Test Video Player")
                        .foregroundColor(accentColorManager.currentAccentColor)
                }
            }
        }
        .navigationTitle("Media Player")
    }
    
    private func playTestVideo() {
        let testUrlString = "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_5MB.mp4"
        guard let streamURL = URL(string: testUrlString) else { return }
        
#if os(tvOS)
        let player = AVPlayer(url: streamURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(playerVC, animated: true) {
                player.play()
            }
        }
#else
        let external = store.externalPlayer
        if let schemeUrl = external.schemeURL(for: testUrlString), external != .none, UIApplication.shared.canOpenURL(schemeUrl) {
            UIApplication.shared.open(schemeUrl, options: [:], completionHandler: nil)
            return
        }
        
        if store.inAppPlayer == .mpv {
            let preset = PlayerPreset.presets.first
            let pvc = PlayerViewController(
                url: streamURL,
                preset: preset ?? PlayerPreset(title: "Default", summary: "", stream: nil, commands: []),
                headers: nil as [String: String]?,
                subtitles: nil as [String]?
            )
            pvc.mediaInfo = MediaInfo.movie(id: 0, title: "Big Buck Bunny")
            pvc.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.topmostViewController().present(pvc, animated: true)
            }
        } else {
            let playerVC = NormalPlayer()
            let asset = AVURLAsset(url: streamURL)
            let item = AVPlayerItem(asset: asset)
            playerVC.player = AVPlayer(playerItem: item)
            playerVC.mediaInfo = .movie(id: 0, title: "Big Buck Bunny")
            playerVC.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.topmostViewController().present(playerVC, animated: true) {
                    playerVC.player?.play()
                }
            }
        }
#endif
    }
}
