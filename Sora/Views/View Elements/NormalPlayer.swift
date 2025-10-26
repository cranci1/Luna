//
//  NormalPlayer.swift
//  Sora · Media Hub
//
//  Created by Francesco on 27/11/24.
//

import AVKit

class NormalPlayer: AVPlayerViewController, AVPlayerViewControllerDelegate {
    private var originalRate: Float = 1.0
    private var timeObserverToken: Any?
    var mediaInfo: MediaInfo?
    
#if os(iOS)
    private var holdGesture: UILongPressGestureRecognizer?
#endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
#if os(iOS)
        setupHoldGesture()
        setupPictureInPictureHandling()
#endif
        if let info = mediaInfo {
            setupProgressTracking(for: info)
        }
        setupAudioSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
    }
    
#if os(iOS)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UserDefaults.standard.bool(forKey: "alwaysLandscape") {
            return .landscape
        } else {
            return .all
        }
    }
    
    private func setupHoldGesture() {
        holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldGesture(_:)))
        holdGesture?.minimumPressDuration = 0.5
        if let holdGesture = holdGesture {
            view.addGestureRecognizer(holdGesture)
        }
    }
    
    private func setupPictureInPictureHandling() {
        delegate = self
        
        if AVPictureInPictureController.isPictureInPictureSupported() {
            self.allowsPictureInPicturePlayback = true
        }
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        let windowScene = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first
        
        let window = windowScene?.windows.first(where: { $0.isKeyWindow })
        
        if let topVC = window?.rootViewController?.topmostViewController() {
            if topVC != self {
                topVC.present(self, animated: true) {
                    completionHandler(true)
                }
            } else {
                completionHandler(true)
            }
        } else {
            completionHandler(false)
        }
    }
    
    @objc private func handleHoldGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            beginHoldSpeed()
        case .ended, .cancelled:
            endHoldSpeed()
        default:
            break
        }
    }
#endif
    
    private func beginHoldSpeed() {
        guard let player = player else { return }
        originalRate = player.rate
        let holdSpeed = UserDefaults.standard.float(forKey: "holdSpeedPlayer")
        player.rate = holdSpeed > 0 ? holdSpeed : 2.0
    }
    
    private func endHoldSpeed() {
        player?.rate = originalRate
    }
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
#if os(iOS)
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try audioSession.setActive(true)
            try audioSession.overrideOutputAudioPort(.speaker)
#elseif os(tvOS)
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
#endif
        } catch {
            Logger.shared.log("Failed to set up AVAudioSession: \(error)")
        }
    }
    
    // MARK: - Progress Tracking
    
    func setupProgressTracking(for mediaInfo: MediaInfo) {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        guard let player = player else {
            Logger.shared.log("No player available for progress tracking", type: "Warning")
            return
        }
        
        timeObserverToken = ProgressManager.shared.addPeriodicTimeObserver(to: player, for: mediaInfo)
        seekToLastPosition(for: mediaInfo)
    }
    
    private func seekToLastPosition(for mediaInfo: MediaInfo) {
        let lastPlayedTime: Double
        
        switch mediaInfo {
        case .movie(let id, let title):
            lastPlayedTime = ProgressManager.shared.getMovieCurrentTime(movieId: id, title: title)
            
        case .episode(let showId, let seasonNumber, let episodeNumber):
            lastPlayedTime = ProgressManager.shared.getEpisodeCurrentTime(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        }
        
        if lastPlayedTime != 0 {
            let progress = getProgressPercentage(for: mediaInfo)
            if progress < 0.95 {
                let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player?.seek(to: seekTime)
                Logger.shared.log("Resumed playback from \(Int(lastPlayedTime))s", type: "Progress")
            }
        }
    }
    
    private func getProgressPercentage(for mediaInfo: MediaInfo) -> Double {
        switch mediaInfo {
        case .movie(let id, let title):
            return ProgressManager.shared.getMovieProgress(movieId: id, title: title)
            
        case .episode(let showId, let seasonNumber, let episodeNumber):
            return ProgressManager.shared.getEpisodeProgress(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        }
    }
}

extension UIViewController {
    func topmostViewController() -> UIViewController {
        if let presented = self.presentedViewController {
            return presented.topmostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topmostViewController() ?? navigation
        }
        
        if let tabBar = self as? UITabBarController {
            return tabBar.selectedViewController?.topmostViewController() ?? tabBar
        }
        
        return self
    }
}
