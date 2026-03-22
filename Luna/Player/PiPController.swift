//
//  PiPController.swift
//  test
//
//  Created by Francesco on 30/09/25.
//

import AVKit
import AVFoundation

protocol PiPControllerDelegate: AnyObject {
    func pipController(_ controller: PiPController, willStartPictureInPicture: Bool)
    func pipController(_ controller: PiPController, didStartPictureInPicture: Bool)
    func pipController(_ controller: PiPController, willStopPictureInPicture: Bool)
    func pipController(_ controller: PiPController, didStopPictureInPicture: Bool)
    func pipController(_ controller: PiPController, restoreUserInterfaceForPictureInPictureStop completionHandler: @escaping (Bool) -> Void)
    func pipControllerPlay(_ controller: PiPController)
    func pipControllerPause(_ controller: PiPController)
    func pipController(_ controller: PiPController, skipByInterval interval: CMTime)
    func pipControllerIsPlaying(_ controller: PiPController) -> Bool
    func pipControllerDuration(_ controller: PiPController) -> Double
    func pipControllerCurrentTime(_ controller: PiPController) -> Double
}

final class PiPController: NSObject {
    private var pipController: AVPictureInPictureController?
    private weak var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var pendingStartWorkItem: DispatchWorkItem?
    private var isStartInProgress = false
    
    weak var delegate: PiPControllerDelegate?
    
    var isPictureInPictureSupported: Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }
    
    var isPictureInPictureActive: Bool {
        return pipController?.isPictureInPictureActive ?? false
    }
    
    var isPictureInPicturePossible: Bool {
        return pipController?.isPictureInPicturePossible ?? false
    }
    
    init(sampleBufferDisplayLayer: AVSampleBufferDisplayLayer) {
        self.sampleBufferDisplayLayer = sampleBufferDisplayLayer
        super.init()
        setupPictureInPicture()
    }
    
    private func setupPictureInPicture() {
        guard isPictureInPictureSupported,
              let displayLayer = sampleBufferDisplayLayer else {
            return
        }
        
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.requiresLinearPlayback = false
        #if !os(tvOS)
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        #endif
    }
    
    func startPictureInPicture() {
        guard isPictureInPictureSupported else {
            Logger.shared.log("PiP is not supported on this device", type: "mpv")
            return
        }

        if pipController == nil {
            setupPictureInPicture()
        }

        guard let pipController = pipController else { return }
        guard !isStartInProgress, !pipController.isPictureInPictureActive else { return }

        let canStart = pipController.isPictureInPicturePossible
        if !canStart {
            pendingStartWorkItem?.cancel()
            let retry = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.isStartInProgress = false
                self.startPictureInPicture()
            }
            pendingStartWorkItem = retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: retry)
            Logger.shared.log("PiP start deferred: not yet possible, retrying shortly", type: "mpv")
            return
        }

        isStartInProgress = true
        pipController.invalidatePlaybackState()
        
        pipController.startPictureInPicture()
    }
    
    func stopPictureInPicture() {
        pendingStartWorkItem?.cancel()
        pendingStartWorkItem = nil
        isStartInProgress = false
        pipController?.stopPictureInPicture()
    }
    
    func invalidate() {
        pendingStartWorkItem?.cancel()
        pendingStartWorkItem = nil
        isStartInProgress = false
        pipController?.invalidatePlaybackState()
    }
    
    func updatePlaybackState() {
        pipController?.invalidatePlaybackState()
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.pipController(self, willStartPictureInPicture: true)
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pendingStartWorkItem?.cancel()
        pendingStartWorkItem = nil
        isStartInProgress = false
        delegate?.pipController(self, didStartPictureInPicture: true)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        pendingStartWorkItem?.cancel()
        pendingStartWorkItem = nil
        isStartInProgress = false
        Logger.shared.log("Failed to start PiP: \(error)", type: "mpv")
        delegate?.pipController(self, didStartPictureInPicture: false)
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.pipController(self, willStopPictureInPicture: true)
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pendingStartWorkItem?.cancel()
        pendingStartWorkItem = nil
        isStartInProgress = false
        delegate?.pipController(self, didStopPictureInPicture: true)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        delegate?.pipController(self, restoreUserInterfaceForPictureInPictureStop: completionHandler)
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPController: AVPictureInPictureSampleBufferPlaybackDelegate {
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        if playing {
            delegate?.pipControllerPlay(self)
        } else {
            delegate?.pipControllerPause(self)
        }
        DispatchQueue.main.async { [weak self] in
            self?.pipController?.invalidatePlaybackState()
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        delegate?.pipController(self, skipByInterval: skipInterval)
        DispatchQueue.main.async { [weak self] in
            self?.pipController?.invalidatePlaybackState()
        }
        completionHandler()
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        let duration = delegate?.pipControllerDuration(self) ?? 0
        if duration > 0 {
            let cmDuration = CMTime(seconds: duration, preferredTimescale: 1000)
            return CMTimeRange(start: .zero, duration: cmDuration)
        }
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return !(delegate?.pipControllerIsPlaying(self) ?? false)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool, completion: @escaping () -> Void) {
        if playing {
            delegate?.pipControllerPlay(self)
        } else {
            delegate?.pipControllerPause(self)
        }
        DispatchQueue.main.async { [weak self] in
            self?.pipController?.invalidatePlaybackState()
        }
        completion()
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, timeRangeForPlayback sampleBufferDisplayLayer: AVSampleBufferDisplayLayer) -> CMTimeRange {
        let duration = delegate?.pipControllerDuration(self) ?? 0
        if duration > 0 {
            let cmDuration = CMTime(seconds: duration, preferredTimescale: 1000)
            return CMTimeRange(start: .zero, duration: cmDuration)
        }
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, currentTimeFor sampleBufferDisplayLayer: AVSampleBufferDisplayLayer) -> CMTime {
        let currentTime = delegate?.pipControllerCurrentTime(self) ?? 0
        return CMTime(seconds: currentTime, preferredTimescale: 1000)
    }
}
