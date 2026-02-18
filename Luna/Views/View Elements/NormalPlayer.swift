//
//  NormalPlayer.swift
//  Sora · Media Hub
//
//  Created by Francesco on 27/11/24.
//

import AVKit
import SwiftUI

class NormalPlayer: AVPlayerViewController, AVPlayerViewControllerDelegate {
    private final class NonFocusableVisualEffectView: UIVisualEffectView {
        #if os(tvOS)
        override var canBecomeFocused: Bool { false }
        #endif
    }

    private var originalRate: Float = 1.0
    private var timeObserverToken: Any?
    var mediaInfo: MediaInfo? {
        didSet {
            // Setup progress tracking when mediaInfo is set
            if let info = mediaInfo, player != nil {
                setupProgressTracking(for: info)
            }
        }
    }
    
    // Subtitle support via overlay
    var subtitles: [String]? {
        didSet {
            if let subs = subtitles {
                Logger.shared.log("[SUBTITLE] NormalPlayer received \(subs.count) subtitle(s): \(subs)", type: "Stream")
            } else {
                Logger.shared.log("[SUBTITLE] NormalPlayer received nil subtitles", type: "Stream")
            }
        }
    }
    var streamHeaders: [String: String]?
    
    private var subtitleController: SubtitleController?
    private var subtitleOverlayVC: UIHostingController<SubtitleOverlayView>?
    private var subtitleOffsetContainerView: UIView?
    private var subtitleOffsetLabel: UILabel?
    private var hlsInterceptor: HLSManifestInterceptor?
    private var overlaySubtitleMenuButton: UIButton?
    private var overlaySubtitleURL: String?
    
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
        
        // Setup subtitle overlay if subtitles are provided
        setupSubtitleOverlay()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure progress tracking is set up (in case mediaInfo was set after viewDidLoad)
        if let info = mediaInfo, player != nil, timeObserverToken == nil {
            setupProgressTracking(for: info)
            Logger.shared.log("Progress tracking initialized in viewDidAppear for: \(info)", type: "Progress")
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        // Cleanup subtitles
        subtitleController?.detach()
        subtitleOffsetContainerView?.removeFromSuperview()
        subtitleOffsetContainerView = nil
        subtitleOffsetLabel = nil
    }
    
    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        subtitleController?.detach()
    }

    func setHLSInterceptor(_ interceptor: HLSManifestInterceptor?) {
        hlsInterceptor = interceptor
    }
    
    // MARK: - Subtitle Overlay Setup
    
    private func setupSubtitleOverlay() {
        guard let subs = subtitles, !subs.isEmpty, let overlaySubtitle = overlaySubtitleURL(from: subs) else {
            Logger.shared.log("[SUBTITLE] No overlay subtitle URL to setup", type: "Stream")
            return
        }
        
        Logger.shared.log("[SUBTITLE] Setting up subtitle overlay with: \(overlaySubtitle)", type: "Stream")
        
        // Create subtitle controller
        let controller = SubtitleController()
        self.subtitleController = controller
        
        // Load subtitles
        controller.loadSubtitles(from: overlaySubtitle)
        
        // Attach to player when it's ready
        if let player = player {
            controller.attach(to: player)
        }
        
        // Create overlay view
        let overlayView = SubtitleOverlayView(controller: controller)
        let hostingVC = UIHostingController(rootView: overlayView)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isUserInteractionEnabled = false // Allow touches to pass through
        
        // Add as child view controller
        addChild(hostingVC)
        hostingVC.view.frame = contentOverlayView?.bounds ?? view.bounds
        hostingVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add to contentOverlayView (provided by AVPlayerViewController for overlays)
        if let overlayContainer = contentOverlayView {
            overlayContainer.addSubview(hostingVC.view)
        } else {
            view.addSubview(hostingVC.view)
        }
        
        hostingVC.didMove(toParent: self)
        self.subtitleOverlayVC = hostingVC
        
        Logger.shared.log("[SUBTITLE] Subtitle overlay added to player", type: "Stream")

        overlaySubtitleURL = overlaySubtitle
        setupOverlaySubtitleMenu()

        // Add offset controls (tvOS-friendly) so you can sync live.
        // Disabled: cannot be focused with remote
        // setupSubtitleOffsetControls()
    }

    private func setupOverlaySubtitleMenu() {
        guard overlaySubtitleMenuButton == nil else { return }
        guard overlaySubtitleURL != nil else { return }

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "captions.bubble", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        button.showsMenuAsPrimaryAction = true

        let disableAction = UIAction(title: "Disable Overlay", image: UIImage(systemName: "xmark")) { [weak self] _ in
            guard let self else { return }
            self.subtitleController?.setManualOverlaySelection(false)
            self.subtitleController?.subtitlesEnabled = false
            Logger.shared.log("[SUBTITLE] Manual overlay disabled", type: "Stream")
        }

        let overlayAction = UIAction(title: SubtitleController.overlayTrackName, image: UIImage(systemName: "captions.bubble.fill")) { [weak self] _ in
            guard let self else { return }
            self.subtitleController?.setManualOverlaySelection(true)
            self.subtitleController?.subtitlesEnabled = true
            Logger.shared.log("[SUBTITLE] Manual overlay enabled", type: "Stream")
        }

        button.menu = UIMenu(title: "Overlay Subtitles", children: [disableAction, overlayAction])

        let parent = contentOverlayView ?? view
        parent?.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: parent!.trailingAnchor, constant: -24),
            button.topAnchor.constraint(equalTo: parent!.topAnchor, constant: 24),
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36)
        ])

        overlaySubtitleMenuButton = button
    }

    private func overlaySubtitleURL(from subtitles: [String]) -> String? {
        let overlayName = SubtitleController.overlayTrackName
        for (index, entry) in subtitles.enumerated() {
            if entry.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(overlayName) == .orderedSame {
                let nextIndex = index + 1
                if nextIndex < subtitles.count, isSubtitleURL(subtitles[nextIndex]) {
                    return subtitles[nextIndex]
                }
            }
        }

        return subtitles.first(where: { isSubtitleURL($0) })
    }

    private func isSubtitleURL(_ value: String) -> Bool {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }

    private func setupSubtitleOffsetControls() {
        guard subtitleOffsetContainerView == nil else { return }
        guard subtitleController != nil else { return }

        let blur: UIVisualEffect
        #if os(tvOS)
        blur = UIBlurEffect(style: .dark)
        #else
        blur = UIBlurEffect(style: .systemThinMaterialDark)
        #endif

        let container = NonFocusableVisualEffectView(effect: blur)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        container.layer.cornerRadius = 12

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Sub offset"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 14, weight: .regular)
        valueLabel.textAlignment = .right
        subtitleOffsetLabel = valueLabel
        updateSubtitleOffsetLabel()

        let toggleButton = makeSubtitleOffsetButton(title: "Subs On/Off", action: #selector(toggleOverlaySubtitles))
        let minusButton = makeSubtitleOffsetButton(title: "-0.5s", action: #selector(decreaseSubtitleOffset))
        let resetButton = makeSubtitleOffsetButton(title: "Reset", action: #selector(resetSubtitleOffset))
        let plusButton = makeSubtitleOffsetButton(title: "+0.5s", action: #selector(increaseSubtitleOffset))

        let buttonStack = UIStackView(arrangedSubviews: [toggleButton, minusButton, resetButton, plusButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.spacing = 10
        headerStack.distribution = .fill

        let vStack = UIStackView(arrangedSubviews: [headerStack, buttonStack])
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.axis = .vertical
        vStack.spacing = 8

        container.contentView.addSubview(vStack)

        let parent = contentOverlayView ?? view
        parent?.addSubview(container)

        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 12),
            vStack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -12),
            vStack.topAnchor.constraint(equalTo: container.contentView.topAnchor, constant: 10),
            vStack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor, constant: -10),

            container.trailingAnchor.constraint(equalTo: parent!.trailingAnchor, constant: -24),
            container.topAnchor.constraint(equalTo: parent!.topAnchor, constant: 24),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        subtitleOffsetContainerView = container

        #if os(tvOS)
        // Encourage focus engine to pick the nearest player control instead of the container.
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        #endif
    }

    private func makeSubtitleOffsetButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        button.addTarget(self, action: action, for: .primaryActionTriggered)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updateSubtitleOffsetLabel() {
        guard let controller = subtitleController else { return }
        let value = controller.timeOffset
        let formatted = String(format: "%+.2fs", value)
        let enabledText = controller.subtitlesEnabled ? "ON" : "OFF"
        subtitleOffsetLabel?.text = "\(formatted) • \(enabledText)"
    }

    @objc private func decreaseSubtitleOffset() {
        adjustSubtitleOffset(by: -0.5)
    }

    @objc private func increaseSubtitleOffset() {
        adjustSubtitleOffset(by: 0.5)
    }

    @objc private func resetSubtitleOffset() {
        guard let controller = subtitleController else { return }
        controller.timeOffset = 0
        updateSubtitleOffsetLabel()
        Logger.shared.log("[SUBTITLE] Subtitle offset set to 0", type: "Stream")
    }

    @objc private func toggleOverlaySubtitles() {
        guard let controller = subtitleController else { return }
        controller.subtitlesEnabled.toggle()
        updateSubtitleOffsetLabel()
        Logger.shared.log("[SUBTITLE] Overlay subtitles \(controller.subtitlesEnabled ? "enabled" : "disabled")", type: "Stream")
    }

    private func adjustSubtitleOffset(by delta: TimeInterval) {
        guard let controller = subtitleController else { return }
        let next = max(-10, min(10, controller.timeOffset + delta))
        controller.timeOffset = next
        updateSubtitleOffsetLabel()
        Logger.shared.log("[SUBTITLE] Subtitle offset adjusted to \(next)", type: "Stream")
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
            if progress < ProgressManager.watchedProgressThreshold {
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
    
    // MARK: - Public Subtitle Control
    
    /// Toggle subtitles on/off
    func toggleSubtitles() {
        subtitleController?.subtitlesEnabled.toggle()
        let enabled = subtitleController?.subtitlesEnabled ?? false
        Logger.shared.log("[SUBTITLE] Subtitles \(enabled ? "enabled" : "disabled")", type: "Stream")
    }
    
    /// Check if subtitles are currently enabled
    var subtitlesEnabled: Bool {
        return subtitleController?.subtitlesEnabled ?? false
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
