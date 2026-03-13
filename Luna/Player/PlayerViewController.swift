//
//  PlayerViewController.swift
//  test
//
//  Created by Francesco on 28/09/25.
//

import UIKit
import SwiftUI
import AVFoundation

final class PlayerViewController: UIViewController {
    private let videoContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .black
        v.clipsToBounds = true
        return v
    }()
    
    private let primaryRenderView: MetalVideoView = {
        let v = MetalVideoView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let displayLayer = AVSampleBufferDisplayLayer()
    
    private let centerPlayPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: 32, weight: .semibold)
        let image = UIImage(systemName: "play.fill", withConfiguration: configuration)
        b.setImage(image, for: .normal)
        b.tintColor = .white
        b.backgroundColor = UIColor(white: 0.2, alpha: 0.5)
        b.layer.cornerRadius = 35
        b.clipsToBounds = true
        return b
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let v: UIActivityIndicatorView
        v = UIActivityIndicatorView(style: .large)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.hidesWhenStopped = true
        v.color = .white
        v.alpha = 0.0
        return v
    }()
    
    private let controlsOverlayView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        v.alpha = 0.0
        v.isUserInteractionEnabled = false
        return v
    }()
    
    private lazy var errorBanner: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor { trait -> UIColor in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 0.95) : UIColor(red: 0.9, green: 0.17, blue: 0.17, alpha: 0.98)
        }
        container.layer.cornerRadius = 10
        container.clipsToBounds = true
        container.alpha = 0.0
        
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.numberOfLines = 2
        label.tag = 101
        
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("View Logs", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        btn.backgroundColor = UIColor(white: 1.0, alpha: 0.12)
        btn.layer.cornerRadius = 6
        
        if #unavailable(tvOS 15) {
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        }
        btn.addTarget(self, action: #selector(viewLogsTapped), for: .touchUpInside)
        
        container.addSubview(icon)
        container.addSubview(label)
        container.addSubview(btn)
        
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            
            btn.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            btn.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }()
    
    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let img = UIImage(systemName: "xmark", withConfiguration: cfg)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.alpha = 0.0
        return b
    }()
    
    private let pipButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let img = UIImage(systemName: "pip.enter", withConfiguration: cfg)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.alpha = 0.0
        return b
    }()
    
    private let skipBackwardButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        let img = UIImage(systemName: "gobackward.15", withConfiguration: cfg)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.alpha = 0.0
        return b
    }()
    
    private let skipForwardButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        let img = UIImage(systemName: "goforward.15", withConfiguration: cfg)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.alpha = 0.0
        return b
    }()
    
    private let speedIndicatorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        label.layer.cornerRadius = 20
        label.clipsToBounds = true
        label.alpha = 0.0
        return label
    }()
    
    private let subtitleButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let img = UIImage(systemName: "captions.bubble", withConfiguration: cfg)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.alpha = 0.0
        b.isHidden = true
        b.showsMenuAsPrimaryAction = true
        return b
    }()
    
    private let skipSegmentButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Skip", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.backgroundColor = UIColor(white: 0.2, alpha: 0.55)
        b.layer.cornerRadius = 18
        b.layer.cornerCurve = .continuous
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        b.alpha = 0.0
        b.isHidden = true
        return b
    }()
    
    private let progressContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()
    private var progressHostingController: UIHostingController<AnyView>?
    private var lastHostedDuration: Double = 0
    
    class ProgressModel: ObservableObject {
        @Published var position: Double = 0
        @Published var duration: Double = 1
        @Published var highlights: [ProgressHighlight] = []
    }
    private var progressModel = ProgressModel()
    
    private lazy var renderer: MPVSoftwareRenderer = {
        let r = MPVSoftwareRenderer(primaryRenderView: primaryRenderView, pipDisplayLayer: displayLayer)
        r.delegate = self
        return r
    }()
    var mediaInfo: MediaInfo?
    private var isSeeking = false
    private var cachedDuration: Double = 0
    private var cachedPosition: Double = 0
    private var pipController: PiPController?
    private var initialURL: URL?
    private var initialPreset: PlayerPreset?
    private var initialHeaders: [String: String]?
    private var initialSubtitles: [String]?
    
    private var subtitleURLs: [String] = []
    private var currentSubtitleIndex: Int = 0
    private var pendingSubtitleURLs: [String]?
    
    class SubtitleModel: ObservableObject {
        @Published var currentAttributedText: NSAttributedString = NSAttributedString()
        
        private var isLoading: Bool = true
        
        @Published var isVisible: Bool = false {
            didSet {
                if !isLoading { saveSubtitleSettings() }
            }
        }
        @Published var foregroundColor: UIColor = .white {
            didSet {
                if !isLoading { saveSubtitleSettings() }
            }
        }
        @Published var strokeColor: UIColor = .black {
            didSet {
                if !isLoading { saveSubtitleSettings() }
            }
        }
        @Published var strokeWidth: CGFloat = 1.0 {
            didSet {
                if !isLoading { saveSubtitleSettings() }
            }
        }
        @Published var fontSize: CGFloat = 38.0 {
            didSet {
                if !isLoading { saveSubtitleSettings() }
            }
        }
        
        init() {
            loadSubtitleSettings()
            isLoading = false
        }
        
        private func saveSubtitleSettings() {
            let defaults = UserDefaults.standard
            defaults.set(isVisible, forKey: "subtitles_isVisible")
            defaults.set(strokeWidth, forKey: "subtitles_strokeWidth")
            defaults.set(fontSize, forKey: "subtitles_fontSize")
            
            if let foregroundData = try? NSKeyedArchiver.archivedData(withRootObject: foregroundColor, requiringSecureCoding: false) {
                defaults.set(foregroundData, forKey: "subtitles_foregroundColor")
            }
            if let strokeData = try? NSKeyedArchiver.archivedData(withRootObject: strokeColor, requiringSecureCoding: false) {
                defaults.set(strokeData, forKey: "subtitles_strokeColor")
            }
        }
        
        private func loadSubtitleSettings() {
            let defaults = UserDefaults.standard
            
            if defaults.object(forKey: "subtitles_isVisible") != nil {
                isVisible = defaults.bool(forKey: "subtitles_isVisible")
            }
            
            if defaults.object(forKey: "subtitles_strokeWidth") != nil {
                let width = CGFloat(defaults.double(forKey: "subtitles_strokeWidth"))
                strokeWidth = width > 0 ? width : 1.0
            }
            
            if defaults.object(forKey: "subtitles_fontSize") != nil {
                let size = CGFloat(defaults.double(forKey: "subtitles_fontSize"))
                fontSize = size > 0 ? size : 38.0
            }
            
            if let foregroundData = defaults.data(forKey: "subtitles_foregroundColor"),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: foregroundData) {
                foregroundColor = color
            }
            if let strokeData = defaults.data(forKey: "subtitles_strokeColor"),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: strokeData) {
                strokeColor = color
            }
        }
    }
    private var subtitleModel = SubtitleModel()
    
    private var originalSpeed: Double = 1.0
    private var holdGesture: UILongPressGestureRecognizer?
    
    private var controlsHideWorkItem: DispatchWorkItem?
    private var controlsVisible: Bool = true
    private var pendingSeekTime: Double?
    private var introDBSegments: [IntroDBSegment] = []
    private var activeSkipSegmentID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
#if !os(tvOS)
        modalPresentationCapturesStatusBarAppearance = true
#endif
        setupLayout()
        setupActions()
        setupHoldGesture()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleLoggerNotification(_:)), name: NSNotification.Name("LoggerNotification"), object: nil)
        
        do {
            try renderer.start()
        } catch {
            Logger.shared.log("Failed to start MPV renderer: \(error)", type: "Error")
            presentErrorAlert(title: "Playback Error", message: "Failed to start renderer: \(error)")
        }
        
        pipController = PiPController(sampleBufferDisplayLayer: displayLayer)
        pipController?.delegate = self
        
        showControlsTemporarily()
        
        if let url = initialURL, let preset = initialPreset {
            load(url: url, preset: preset, headers: initialHeaders)
        }
        
        updateProgressHostingController()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.bringSubviewToFront(errorBanner)
    }
    
#if !os(tvOS)
    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UserDefaults.standard.bool(forKey: "alwaysLandscape") {
            return .landscape
        } else {
            return .all
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
#endif
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        primaryRenderView.frame = videoContainer.bounds
        primaryRenderView.layoutIfNeeded()
        
        displayLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        displayLayer.isHidden = true
        displayLayer.opacity = 0.0
        
        if let gradientLayer = controlsOverlayView.layer.sublayers?.first(where: { $0.name == "gradientLayer" }) {
            gradientLayer.frame = controlsOverlayView.bounds
        }
        
        CATransaction.commit()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.videoContainer.layoutIfNeeded()
            self?.primaryRenderView.layoutIfNeeded()
        })
    }
    
    deinit {
        pipController?.delegate = nil
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        pipController?.invalidate()
        renderer.stopPiPRendering()
        renderer.stop()
        displayLayer.removeFromSuperlayer()
        NotificationCenter.default.removeObserver(self)
    }
    
    convenience init(url: URL, preset: PlayerPreset, headers: [String: String]? = nil, subtitles: [String]? = nil) {
        self.init(nibName: nil, bundle: nil)
        self.initialURL = url
        self.initialPreset = preset
        self.initialHeaders = headers
        self.initialSubtitles = subtitles
    }
    
    func load(url: URL, preset: PlayerPreset, headers: [String: String]? = nil) {
        renderer.load(url: url, with: preset, headers: headers)
        if let info = mediaInfo {
            prepareSeekToLastPosition(for: info)
            fetchIntroDBSegments(for: info)
        }
        
        if let subs = initialSubtitles, !subs.isEmpty {
            pendingSubtitleURLs = subs
        }
    }
    
    private func prepareSeekToLastPosition(for mediaInfo: MediaInfo) {
        let lastPlayedTime: Double
        
        switch mediaInfo {
        case .movie(let id, let title):
            lastPlayedTime = ProgressManager.shared.getMovieCurrentTime(movieId: id, title: title)
            
        case .episode(let showId, _, let seasonNumber, let episodeNumber):
            lastPlayedTime = ProgressManager.shared.getEpisodeCurrentTime(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        }
        
        if lastPlayedTime != 0 {
            let progress: Double
            switch mediaInfo {
            case .movie(let id, let title):
                progress = ProgressManager.shared.getMovieProgress(movieId: id, title: title)
            case .episode(let showId, _, let seasonNumber, let episodeNumber):
                progress = ProgressManager.shared.getEpisodeProgress(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
            }
            
            if progress < 0.95 {
                pendingSeekTime = lastPlayedTime
            }
        }
    }
    
    private func setupLayout() {
        view.addSubview(videoContainer)
        videoContainer.addSubview(primaryRenderView)
        
        displayLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        displayLayer.videoGravity = .resizeAspect
#if compiler(>=6.0)
        if #available(iOS 26.0, tvOS 26.0, *) {
            displayLayer.preferredDynamicRange = .automatic
        } else {
#if !os(tvOS)
            if #available(iOS 17.0, *) {
                displayLayer.wantsExtendedDynamicRangeContent = true
            }
#endif
        }
#elseif !os(tvOS)
        if #available(iOS 17.0, *) {
            displayLayer.wantsExtendedDynamicRangeContent = true
        }
#endif
        displayLayer.backgroundColor = UIColor.black.cgColor
        displayLayer.opacity = 0.0
        displayLayer.isHidden = true
        
        videoContainer.layer.addSublayer(displayLayer)
        videoContainer.addSubview(controlsOverlayView)
        videoContainer.addSubview(loadingIndicator)
        view.addSubview(errorBanner)
        videoContainer.addSubview(centerPlayPauseButton)
        videoContainer.addSubview(progressContainer)
        videoContainer.addSubview(closeButton)
        videoContainer.addSubview(pipButton)
        videoContainer.addSubview(skipBackwardButton)
        videoContainer.addSubview(skipForwardButton)
        videoContainer.addSubview(speedIndicatorLabel)
        videoContainer.addSubview(subtitleButton)
        videoContainer.addSubview(skipSegmentButton)
        
        NSLayoutConstraint.activate([
            videoContainer.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            primaryRenderView.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            primaryRenderView.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            primaryRenderView.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            primaryRenderView.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor),
            
            progressContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            progressContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            progressContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            progressContainer.heightAnchor.constraint(equalToConstant: 44),
            
            controlsOverlayView.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            controlsOverlayView.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            controlsOverlayView.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            controlsOverlayView.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor),
        ])
        
        NSLayoutConstraint.activate([
            errorBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            errorBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorBanner.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.92),
            errorBanner.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            centerPlayPauseButton.centerXAnchor.constraint(equalTo: videoContainer.centerXAnchor),
            centerPlayPauseButton.centerYAnchor.constraint(equalTo: videoContainer.centerYAnchor),
            centerPlayPauseButton.widthAnchor.constraint(equalToConstant: 70),
            centerPlayPauseButton.heightAnchor.constraint(equalToConstant: 70),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: centerPlayPauseButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerPlayPauseButton.centerYAnchor),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: 4),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            
            pipButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            pipButton.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 16),
            pipButton.widthAnchor.constraint(equalToConstant: 36),
            pipButton.heightAnchor.constraint(equalToConstant: 36),
            
            skipBackwardButton.centerYAnchor.constraint(equalTo: centerPlayPauseButton.centerYAnchor),
            skipBackwardButton.trailingAnchor.constraint(equalTo: centerPlayPauseButton.leadingAnchor, constant: -48),
            skipBackwardButton.widthAnchor.constraint(equalToConstant: 50),
            skipBackwardButton.heightAnchor.constraint(equalToConstant: 50),
            
            skipForwardButton.centerYAnchor.constraint(equalTo: centerPlayPauseButton.centerYAnchor),
            skipForwardButton.leadingAnchor.constraint(equalTo: centerPlayPauseButton.trailingAnchor, constant: 48),
            skipForwardButton.widthAnchor.constraint(equalToConstant: 50),
            skipForwardButton.heightAnchor.constraint(equalToConstant: 50),
            
            speedIndicatorLabel.topAnchor.constraint(equalTo: videoContainer.safeAreaLayoutGuide.topAnchor, constant: 20),
            speedIndicatorLabel.centerXAnchor.constraint(equalTo: videoContainer.centerXAnchor),
            speedIndicatorLabel.widthAnchor.constraint(equalToConstant: 100),
            speedIndicatorLabel.heightAnchor.constraint(equalToConstant: 40),
            
            subtitleButton.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: 0),
            subtitleButton.bottomAnchor.constraint(equalTo: progressContainer.topAnchor, constant: -8),
            subtitleButton.widthAnchor.constraint(equalToConstant: 32),
            subtitleButton.heightAnchor.constraint(equalToConstant: 32),
            
            skipSegmentButton.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            skipSegmentButton.bottomAnchor.constraint(equalTo: progressContainer.topAnchor, constant: -14),
            skipSegmentButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
    }
    
    private func setupActions() {
        centerPlayPauseButton.addTarget(self, action: #selector(centerPlayPauseTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        pipButton.addTarget(self, action: #selector(pipTapped), for: .touchUpInside)
        skipBackwardButton.addTarget(self, action: #selector(skipBackwardTapped), for: .touchUpInside)
        skipForwardButton.addTarget(self, action: #selector(skipForwardTapped), for: .touchUpInside)
        skipSegmentButton.addTarget(self, action: #selector(skipSegmentTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(containerTapped))
        videoContainer.addGestureRecognizer(tap)
    }
    
    private func setupHoldGesture() {
        holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldGesture(_:)))
        holdGesture?.minimumPressDuration = 0.5
        if let holdGesture = holdGesture {
            videoContainer.addGestureRecognizer(holdGesture)
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
    
    private func beginHoldSpeed() {
        originalSpeed = renderer.getSpeed()
        let holdSpeed = UserDefaults.standard.float(forKey: "holdSpeedPlayer")
        let targetSpeed = holdSpeed > 0 ? Double(holdSpeed) : 2.0
        renderer.setSpeed(targetSpeed)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.speedIndicatorLabel.text = String(format: "%.1fx", targetSpeed)
            UIView.animate(withDuration: 0.2) {
                self.speedIndicatorLabel.alpha = 1.0
            }
        }
    }
    
    private func endHoldSpeed() {
        renderer.setSpeed(originalSpeed)
        
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.speedIndicatorLabel.alpha = 0.0
            }
        }
    }
    
    @objc private func playPauseTapped() {
        if renderer.isPausedState {
            renderer.play()
            updatePlayPauseButton(isPaused: false)
        } else {
            renderer.pausePlayback()
            updatePlayPauseButton(isPaused: true)
        }
    }
    
    @objc private func centerPlayPauseTapped() {
        playPauseTapped()
    }
    
    @objc private func skipBackwardTapped() {
        renderer.seek(by: -15)
        animateButtonTap(skipBackwardButton)
        showControlsTemporarily()
    }
    
    @objc private func skipForwardTapped() {
        renderer.seek(by: 15)
        animateButtonTap(skipForwardButton)
        showControlsTemporarily()
    }
    
    private func updateSubtitleMenu() {
        var trackActions: [UIAction] = []
        
        let disableAction = UIAction(
            title: "Disable Subtitles",
            image: UIImage(systemName: "xmark"),
            state: subtitleModel.isVisible ? .off : .on
        ) { [weak self] _ in
            self?.subtitleModel.isVisible = false
            self?.renderer.setSubtitleVisible(false)
            self?.updateSubtitleButtonAppearance()
            self?.updateSubtitleMenu()
        }
        trackActions.append(disableAction)
        
        for (index, _) in subtitleURLs.enumerated() {
            let isSelected = subtitleModel.isVisible && currentSubtitleIndex == index
            let action = UIAction(
                title: "Subtitle \(index + 1)",
                image: UIImage(systemName: "captions.bubble"),
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.currentSubtitleIndex = index
                self?.subtitleModel.isVisible = true
                self?.loadCurrentSubtitle()
                self?.renderer.setSubtitleVisible(true)
                self?.updateSubtitleButtonAppearance()
                self?.updateSubtitleMenu()
            }
            trackActions.append(action)
        }
        
        let trackMenu = UIMenu(title: "Select Track", image: UIImage(systemName: "list.bullet"), children: trackActions)
        
        let appearanceMenu = createAppearanceMenu()
        
        let mainMenu = UIMenu(title: "Subtitles", children: [trackMenu, appearanceMenu])
        subtitleButton.menu = mainMenu
    }
    
    private func createAppearanceMenu() -> UIMenu {
        let foregroundColors: [(String, UIColor)] = [
            ("White", .white),
            ("Yellow", .yellow),
            ("Cyan", .cyan),
            ("Green", .green),
            ("Magenta", .magenta)
        ]
        
        let foregroundColorActions = foregroundColors.map { (name, color) in
            UIAction(
                title: name,
                state: subtitleModel.foregroundColor == color ? .on : .off
            ) { [weak self] _ in
                self?.subtitleModel.foregroundColor = color
                self?.updateCurrentSubtitleAppearance()
                self?.updateSubtitleMenu()
            }
        }
        
        let foregroundColorMenu = UIMenu(title: "Text Color", image: UIImage(systemName: "paintpalette"), children: foregroundColorActions)
        
        let strokeColors: [(String, UIColor)] = [
            ("Black", .black),
            ("Dark Gray", .darkGray),
            ("White", .white),
            ("None", .clear)
        ]
        
        let strokeColorActions = strokeColors.map { (name, color) in
            UIAction(
                title: name,
                state: subtitleModel.strokeColor == color ? .on : .off
            ) { [weak self] _ in
                self?.subtitleModel.strokeColor = color
                self?.updateCurrentSubtitleAppearance()
                self?.updateSubtitleMenu()
            }
        }
        
        let strokeColorMenu = UIMenu(title: "Stroke Color", image: UIImage(systemName: "pencil.tip"), children: strokeColorActions)
        
        let strokeWidths: [(String, CGFloat)] = [
            ("None", 0.0),
            ("Thin", 0.5),
            ("Normal", 1.0),
            ("Medium", 1.5),
            ("Thick", 2.0)
        ]
        
        let strokeWidthActions = strokeWidths.map { (name, width) in
            UIAction(
                title: name,
                state: subtitleModel.strokeWidth == width ? .on : .off
            ) { [weak self] _ in
                self?.subtitleModel.strokeWidth = width
                self?.updateCurrentSubtitleAppearance()
                self?.updateSubtitleMenu()
            }
        }
        
        let strokeWidthMenu = UIMenu(title: "Stroke Width", image: UIImage(systemName: "lineweight"), children: strokeWidthActions)
        
        let fontSizes: [(String, CGFloat)] = [
            ("Small", 34.0),
            ("Medium", 38.0),
            ("Large", 42.0),
            ("Extra Large", 46.0),
            ("Huge", 56.0),
            ("Extra Huge", 66.0)
        ]
        
        let fontSizeActions = fontSizes.map { (name, size) in
            UIAction(
                title: name,
                state: subtitleModel.fontSize == size ? .on : .off
            ) { [weak self] _ in
                self?.subtitleModel.fontSize = size
                self?.updateCurrentSubtitleAppearance()
                self?.updateSubtitleMenu()
            }
        }
        
        let fontSizeMenu = UIMenu(title: "Font Size", image: UIImage(systemName: "textformat.size"), children: fontSizeActions)
        
        return UIMenu(title: "Appearance", image: UIImage(systemName: "paintbrush"), children: [
            foregroundColorMenu,
            strokeColorMenu,
            strokeWidthMenu,
            fontSizeMenu
        ])
    }
    
    private func updateCurrentSubtitleAppearance() {
        renderer.applySubtitleStyle(currentSubtitleStyle())
        renderer.setSubtitleVisible(subtitleModel.isVisible)
    }
    
    private func updateSubtitleButtonAppearance() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let imageName = subtitleModel.isVisible ? "captions.bubble.fill" : "captions.bubble"
        let img = UIImage(systemName: imageName, withConfiguration: cfg)
        subtitleButton.setImage(img, for: .normal)
    }
    
    private func loadSubtitles(_ urls: [String]) {
        subtitleURLs = urls
        
        if !urls.isEmpty {
            subtitleButton.isHidden = false
            currentSubtitleIndex = 0
            subtitleModel.isVisible = true
            renderer.applySubtitleStyle(currentSubtitleStyle())
            renderer.setSubtitleVisible(true)
            loadCurrentSubtitle()
            updateSubtitleButtonAppearance()
            updateSubtitleMenu()
        }
    }
    
    private func loadCurrentSubtitle() {
        guard currentSubtitleIndex < subtitleURLs.count else { return }
        let urlString = subtitleURLs[currentSubtitleIndex]
        guard URL(string: urlString) != nil else {
            Logger.shared.log("Invalid subtitle URL: \(urlString)", type: "Error")
            return
        }
        
        renderer.applySubtitleStyle(currentSubtitleStyle())
        renderer.clearCurrentSubtitleTrack()
        renderer.addSubtitleTrack(urlString: urlString)
        renderer.setSubtitleVisible(subtitleModel.isVisible)
        Logger.shared.log("Loading subtitle track through mpv/libass: \(urlString)", type: "Info")
    }
    
    private func currentSubtitleStyle() -> SubtitleStyle {
        SubtitleStyle(
            foregroundColor: subtitleModel.foregroundColor,
            strokeColor: subtitleModel.strokeColor,
            strokeWidth: subtitleModel.strokeWidth,
            fontSize: subtitleModel.fontSize,
            isVisible: subtitleModel.isVisible
        )
    }
    
    @objc private func subtitleButtonTapped() {
        guard !subtitleURLs.isEmpty else { return }
        
        if subtitleURLs.count == 1 {
            subtitleModel.isVisible.toggle()
            updateSubtitleButtonAppearance()
        } else {
            showSubtitleSelectionMenu()
        }
        
        showControlsTemporarily()
    }
    
    private func showSubtitleSelectionMenu() {
        let alert = UIAlertController(title: "Select Subtitle", message: nil, preferredStyle: .actionSheet)
        
        let disableAction = UIAlertAction(title: "Disable Subtitles", style: .default) { [weak self] _ in
            self?.subtitleModel.isVisible = false
            self?.renderer.setSubtitleVisible(false)
            self?.updateSubtitleButtonAppearance()
        }
        alert.addAction(disableAction)
        
        for (index, _) in subtitleURLs.enumerated() {
            let action = UIAlertAction(title: "Subtitle \(index + 1)", style: .default) { [weak self] _ in
                self?.currentSubtitleIndex = index
                self?.subtitleModel.isVisible = true
                self?.loadCurrentSubtitle()
                self?.renderer.setSubtitleVisible(true)
                self?.updateSubtitleButtonAppearance()
            }
            alert.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = subtitleButton
            popover.sourceRect = subtitleButton.bounds
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    private func animateButtonTap(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut]) {
            button.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
                button.transform = .identity
            }
        }
    }
    
    private func updateProgressHostingController() {
        struct ProgressHostView: View {
            @ObservedObject var model: ProgressModel
            var onEditingChanged: (Bool) -> Void
            var body: some View {
                MusicProgressSlider(value: Binding(get: { model.position }, set: { model.position = $0 }), inRange: 0...max(model.duration, 1.0), activeFillColor: .white, fillColor: .white, textColor: .white.opacity(0.7), emptyColor: .white.opacity(0.3), height: 33, highlights: model.highlights, onEditingChanged: onEditingChanged)
            }
        }
        
        if progressHostingController != nil {
            return
        }
        
        let host = UIHostingController(rootView: AnyView(ProgressHostView(model: progressModel, onEditingChanged: { [weak self] editing in
            guard let self = self else { return }
            self.isSeeking = editing
            if !editing {
                self.renderer.seek(to: max(0, self.progressModel.position))
            }
        })))
        
        progressHostingController = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        progressContainer.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }
    
    private func updatePlayPauseButton(isPaused: Bool) {
        DispatchQueue.main.async {
            let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .semibold)
            let name = isPaused ? "play.fill" : "pause.fill"
            let img = UIImage(systemName: name, withConfiguration: config)
            self.centerPlayPauseButton.setImage(img, for: .normal)
            self.centerPlayPauseButton.isHidden = false
            
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
                self.centerPlayPauseButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } completion: { _ in
                UIView.animate(withDuration: 0.15) {
                    self.centerPlayPauseButton.transform = .identity
                }
            }
            
            self.showControlsTemporarily()
        }
    }
    
    // MARK: - Error display helpers
    private func presentErrorAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            ac.addAction(UIAlertAction(title: "View Logs", style: .default, handler: { _ in
                self.viewLogsTapped()
            }))
            self.showErrorBanner(message)
            if self.presentedViewController == nil {
                self.present(ac, animated: true, completion: nil)
            }
        }
    }
    
    private func showTransientErrorBanner(_ message: String, duration: TimeInterval = 4.0) {
        DispatchQueue.main.async {
            self.showErrorBanner(message)
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.hideErrorBanner), object: nil)
            self.perform(#selector(self.hideErrorBanner), with: nil, afterDelay: duration)
        }
    }
    
    @objc private func hideErrorBanner() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25) {
                self.errorBanner.alpha = 0.0
            }
        }
    }
    
    @objc private func handleLoggerNotification(_ note: Notification) {
        guard let info = note.userInfo,
              let message = info["message"] as? String,
              let type = info["type"] as? String else { return }
        
        let lower = type.lowercased()
        if lower == "error" || lower == "warn" || message.lowercased().contains("error") || message.lowercased().contains("warn") {
            showTransientErrorBanner(message)
        }
    }
    
    private func showErrorBanner(_ message: String) {
        DispatchQueue.main.async {
            guard let label = self.errorBanner.viewWithTag(101) as? UILabel else { return }
            label.text = message
            self.view.bringSubviewToFront(self.errorBanner)
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.6, options: [.curveEaseOut], animations: {
                self.errorBanner.alpha = 1.0
                self.errorBanner.transform = CGAffineTransform(translationX: 0, y: 4)
            }, completion: nil)
        }
    }
    
    @objc private func viewLogsTapped() {
        Task { @MainActor in
            let logs = await Logger.shared.getLogsAsync()
            let vc = UIViewController()
            vc.view.backgroundColor = UIColor(named: "background")
            let tv = UITextView()
            tv.translatesAutoresizingMaskIntoConstraints = false
            
#if !os(tvOS)
            tv.isEditable = false
#endif
            tv.text = logs
            tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            vc.view.addSubview(tv)
            NSLayoutConstraint.activate([
                tv.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 12),
                tv.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 12),
                tv.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -12),
                tv.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor, constant: -12),
            ])
            vc.navigationItem.title = "Logs"
            let nav = UINavigationController(rootViewController: vc)
            
#if !os(tvOS)
            nav.modalPresentationStyle = .pageSheet
#endif
            
            let close: UIBarButtonItem
            
#if compiler(>=6.0)
            if #available(iOS 26.0, tvOS 26.0, *) {
                close = UIBarButtonItem(title: "Close", style: .prominent, target: self, action: #selector(dismissLogs))
            } else {
                close = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(dismissLogs))
            }
#else
            close = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(dismissLogs))
#endif
            vc.navigationItem.rightBarButtonItem = close
            self.present(nav, animated: true, completion: nil)
        }
    }
    
    @objc private func dismissLogs() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func containerTapped() {
        if controlsVisible {
            hideControls()
        } else {
            showControlsTemporarily()
        }
    }
    
    @objc private func skipSegmentTapped() {
        guard let segment = currentActiveSegment(at: cachedPosition) else { return }
        guard let target = resolvedEnd(for: segment, duration: cachedDuration) else { return }
        renderer.seek(to: max(0, target))
        showControlsTemporarily()
    }
    
    private func showControlsTemporarily() {
        controlsHideWorkItem?.cancel()
        controlsVisible = true
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
                self.centerPlayPauseButton.alpha = 1.0
                self.controlsOverlayView.alpha = 1.0
                self.progressContainer.alpha = 1.0
                self.closeButton.alpha = 1.0
                self.pipButton.alpha = 1.0
                self.skipBackwardButton.alpha = 1.0
                self.skipForwardButton.alpha = 1.0
                if !self.subtitleButton.isHidden {
                    self.subtitleButton.alpha = 1.0
                }
            }
        }
        
        let work = DispatchWorkItem { [weak self] in
            self?.hideControls()
        }
        controlsHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: work)
    }
    
    private func hideControls() {
        controlsHideWorkItem?.cancel()
        controlsVisible = false
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn]) {
                self.centerPlayPauseButton.alpha = 0.0
                self.controlsOverlayView.alpha = 0.0
                self.progressContainer.alpha = 0.0
                self.closeButton.alpha = 0.0
                self.pipButton.alpha = 0.0
                self.skipBackwardButton.alpha = 0.0
                self.skipForwardButton.alpha = 0.0
                self.subtitleButton.alpha = 0.0
            }
        }
    }
    
    @objc private func closeTapped() {
        pipController?.delegate = nil
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        
        renderer.stop()
        
        if presentingViewController != nil {
            dismiss(animated: true, completion: nil)
        } else {
            view.window?.rootViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func pipTapped() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else if pip.isPictureInPicturePossible {
            pip.startPictureInPicture()
        }
    }
    
    private func updatePosition(_ position: Double, duration: Double) {
        DispatchQueue.main.async {
            self.cachedDuration = duration
            self.cachedPosition = position
            if duration > 0 {
                self.updateProgressHostingController()
                self.updateProgressHighlights(duration: duration)
            }
            self.progressModel.position = position
            self.progressModel.duration = max(duration, 1.0)
            self.updateActiveSkipSegment(at: position, duration: duration)
            
            if self.pipController?.isPictureInPictureActive == true {
                self.pipController?.updatePlaybackState()
            }
        }
        
        guard duration.isFinite, duration > 0, position >= 0, let info = mediaInfo else { return }
        
        switch info {
        case .movie(let id, let title):
            ProgressManager.shared.updateMovieProgress(movieId: id, title: title, currentTime: position, totalDuration: duration)
        case .episode(let showId, let showTitle, let seasonNumber, let episodeNumber):
            ProgressManager.shared.updateEpisodeProgress(showId: showId, showTitle: showTitle, seasonNumber: seasonNumber, episodeNumber: episodeNumber, currentTime: position, totalDuration: duration)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds > 0 else { return "00:00" }
        let total = Int(round(seconds))
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private func fetchIntroDBSegments(for mediaInfo: MediaInfo) {
        IntroDBService.shared.fetchSegments(for: mediaInfo) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let segments):
                DispatchQueue.main.async {
                    self.introDBSegments = segments
                    self.updateProgressHighlights(duration: self.cachedDuration)
                    self.updateActiveSkipSegment(at: self.cachedPosition, duration: self.cachedDuration)
                }
                Logger.shared.log("Loaded \(segments.count) IntroDB segments", type: "Info")
            case .failure(let error):
                Logger.shared.log("IntroDB request failed: \(error.localizedDescription)", type: "Warn")
            }
        }
    }
    
    private func updateProgressHighlights(duration: Double) {
        let highlights = IntroDBService.shared.highlights(for: introDBSegments, duration: duration)
        progressModel.highlights = highlights.map {
            ProgressHighlight(start: $0.start, end: $0.end, color: Color($0.color), label: $0.label)
        }
    }
    
    private func currentActiveSegment(at position: Double, duration: Double? = nil) -> IntroDBSegment? {
        return IntroDBService.shared.activeSegment(at: position, in: introDBSegments, duration: duration ?? cachedDuration)
    }
    
    private func updateActiveSkipSegment(at position: Double, duration: Double) {
        let active = currentActiveSegment(at: position, duration: duration)
        let newID = active?.id
        guard newID != activeSkipSegmentID else { return }
        activeSkipSegmentID = newID
        
        if let active {
            showSkipButton(for: active)
        } else {
            hideSkipButton()
        }
    }
    
    private func showSkipButton(for segment: IntroDBSegment) {
        let title = "Skip \(segment.db.title)"
        skipSegmentButton.setTitle(title, for: .normal)
        skipSegmentButton.backgroundColor = segment.db.uiColor.withAlphaComponent(0.55)
        
        guard skipSegmentButton.isHidden || skipSegmentButton.alpha < 1.0 else { return }
        skipSegmentButton.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.skipSegmentButton.alpha = 1.0
        }
    }
    
    private func hideSkipButton() {
        guard !skipSegmentButton.isHidden else { return }
        UIView.animate(withDuration: 0.2, animations: {
            self.skipSegmentButton.alpha = 0.0
        }, completion: { _ in
            self.skipSegmentButton.isHidden = true
        })
    }
    
    private func resolvedEnd(for segment: IntroDBSegment, duration: Double) -> Double? {
        return segment.resolvedEnd(duration: duration)
    }
}

// MARK: - MPVSoftwareRendererDelegate
extension PlayerViewController: MPVSoftwareRendererDelegate {
    func renderer(_ renderer: MPVSoftwareRenderer, didUpdatePosition position: Double, duration: Double) {
        updatePosition(position, duration: duration)
    }
    
    func renderer(_ renderer: MPVSoftwareRenderer, didChangePause isPaused: Bool) {
        updatePlayPauseButton(isPaused: isPaused)
        pipController?.updatePlaybackState()
    }
    
    func renderer(_ renderer: MPVSoftwareRenderer, didChangeLoading isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if isLoading {
                self.centerPlayPauseButton.isHidden = true
                self.loadingIndicator.alpha = 1.0
                self.loadingIndicator.startAnimating()
            } else {
                self.loadingIndicator.stopAnimating()
                self.loadingIndicator.alpha = 0.0
                self.updatePlayPauseButton(isPaused: self.renderer.isPausedState)
            }
        }
    }
    
    func renderer(_ renderer: MPVSoftwareRenderer, didBecomeReadyToSeek: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let seekTime = self.pendingSeekTime {
                self.renderer.seek(to: seekTime)
                Logger.shared.log("Resumed MPV playback from \(Int(seekTime))s", type: "Progress")
                self.pendingSeekTime = nil
            }
            if let subs = self.pendingSubtitleURLs {
                self.pendingSubtitleURLs = nil
                self.loadSubtitles(subs)
            }
        }
    }
    
}

// MARK: - PiP Support
extension PlayerViewController: PiPControllerDelegate {
    func pipController(_ controller: PiPController, willStartPictureInPicture: Bool) {
        renderer.startPiPRendering()
        pipController?.updatePlaybackState()
    }
    func pipController(_ controller: PiPController, didStartPictureInPicture: Bool) {
        if !didStartPictureInPicture {
            renderer.stopPiPRendering()
        }
        pipController?.updatePlaybackState()
    }
    func pipController(_ controller: PiPController, willStopPictureInPicture: Bool) { }
    func pipController(_ controller: PiPController, didStopPictureInPicture: Bool) {
        renderer.stopPiPRendering()
    }
    func pipController(_ controller: PiPController, restoreUserInterfaceForPictureInPictureStop completionHandler: @escaping (Bool) -> Void) {
        if presentedViewController != nil {
            dismiss(animated: true) { completionHandler(true) }
        } else {
            completionHandler(true)
        }
    }
    func pipControllerPlay(_ controller: PiPController) { renderer.play() }
    func pipControllerPause(_ controller: PiPController) { renderer.pausePlayback() }
    func pipController(_ controller: PiPController, skipByInterval interval: CMTime) {
        let seconds = CMTimeGetSeconds(interval)
        let target = max(0, cachedPosition + seconds)
        renderer.seek(to: target)
        pipController?.updatePlaybackState()
    }
    func pipControllerIsPlaying(_ controller: PiPController) -> Bool { return !renderer.isPausedState }
    func pipControllerDuration(_ controller: PiPController) -> Double { return cachedDuration }
    func pipControllerCurrentTime(_ controller: PiPController) -> Double { return cachedPosition }
    
    @objc private func appDidEnterBackground() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let pip = self.pipController else { return }
            if pip.isPictureInPicturePossible && !pip.isPictureInPictureActive {
                pip.startPictureInPicture()
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let pip = self.pipController else { return }
            if pip.isPictureInPictureActive {
                pip.stopPictureInPicture()
            }
        }
    }
}
