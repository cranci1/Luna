//
//  MPVSoftwareRenderer.swift
//  test
//
//  Created by Francesco on 28/09/25.
//

import UIKit
import Libmpv
import CoreMedia
import CoreVideo
import AVFoundation
import QuartzCore

protocol MPVSoftwareRendererDelegate: AnyObject {
    func renderer(_ renderer: MPVSoftwareRenderer, didUpdatePosition position: Double, duration: Double)
    func renderer(_ renderer: MPVSoftwareRenderer, didChangePause isPaused: Bool)
    func renderer(_ renderer: MPVSoftwareRenderer, didChangeLoading isLoading: Bool)
    func renderer(_ renderer: MPVSoftwareRenderer, didBecomeReadyToSeek: Bool)
}

struct SubtitleStyle {
    let foregroundColor: UIColor
    let strokeColor: UIColor
    let strokeWidth: CGFloat
    let fontSize: CGFloat
    let isVisible: Bool
    
    static let `default` = SubtitleStyle(
        foregroundColor: .white,
        strokeColor: .black,
        strokeWidth: 1.0,
        fontSize: 18.0,
        isVisible: false
    )
}

final class MPVSoftwareRenderer {
    enum RendererError: Error {
        case mpvCreationFailed
        case mpvInitialization(Int32)
        case renderContextCreation(Int32)
    }
    
    private weak var primaryRenderView: UIView?
    private let pipDisplayLayer: AVSampleBufferDisplayLayer
    
    private let renderQueue = DispatchQueue(label: "mpv.software.render", qos: .userInitiated)
    private let eventQueue = DispatchQueue(label: "mpv.software.events", qos: .utility)
    private let stateQueue = DispatchQueue(label: "mpv.software.state", attributes: .concurrent)
    private let eventQueueGroup = DispatchGroup()
    private let renderQueueKey = DispatchSpecificKey<Void>()
    
    private var dimensionsArray = [Int32](repeating: 0, count: 2)
    private var renderParams = [mpv_render_param](repeating: mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil), count: 5)
    
    private var mpv: OpaquePointer?
    private var pipRenderContext: OpaquePointer?
    private var videoSize: CGSize = .zero
    
    private var pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPoolAuxAttributes: CFDictionary?
    private var formatDescription: CMVideoFormatDescription?
    private var didFlushForFormatChange = false
    private var poolWidth: Int = 0
    private var poolHeight: Int = 0
    private var preAllocatedBuffers: [CVPixelBuffer] = []
    private let maxPreAllocatedBuffers = 12
    
    private var currentPreset: PlayerPreset?
    private var currentURL: URL?
    private var currentHeaders: [String: String]?
    
    private var disposeBag: [() -> Void] = []
    
    private var isRunning = false
    private var isStopping = false
    private var shouldClearPixelBuffer = false
    private let bgraFormatCString: [CChar] = Array("bgra\0".utf8CString)
    
    weak var delegate: MPVSoftwareRendererDelegate?
    
    private var isPaused: Bool = true
    private var isLoading: Bool = false
    private var cachedDuration: Double = 0
    private var cachedPosition: Double = 0
    
    private var pipDisplayLink: CADisplayLink?
    private var pipDisplayLinkProxy: PiPDisplayLinkProxy?
    private var pipDisplayLinkRequested = false
    private var pipFramePumpScheduled = false
    private var lastRenderDimensions: CGSize = .zero
    
    private final class PiPDisplayLinkProxy: NSObject {
        weak var owner: MPVSoftwareRenderer?
        
        init(owner: MPVSoftwareRenderer) {
            self.owner = owner
        }
        
        @objc func onDisplayLinkTick() {
            owner?.pumpPiPFrame()
        }
    }
    
    var isPausedState: Bool {
        return isPaused
    }
    
    init(primaryRenderView: UIView, pipDisplayLayer: AVSampleBufferDisplayLayer) {
        self.primaryRenderView = primaryRenderView
        self.pipDisplayLayer = pipDisplayLayer
        renderQueue.setSpecific(key: renderQueueKey, value: ())
    }
    
    deinit {
        stop()
    }
    
    func start() throws {
        guard !isRunning else { return }
        guard let handle = mpv_create() else {
            throw RendererError.mpvCreationFailed
        }
        
        mpv = handle
        setOption(name: "vo", value: "gpu-next")
        setOption(name: "gpu-api", value: "vulkan")
        setOption(name: "hwdec", value: "videotoolbox")
        setOption(name: "gpu-context", value: "moltenvk")
        
        setOption(name: "idle", value: "yes")
        setOption(name: "ytdl", value: "yes")
        setOption(name: "sub-ass", value: "yes")
        setOption(name: "hr-seek", value: "yes")
        setOption(name: "terminal", value: "yes")
        setOption(name: "keep-open", value: "yes")
        setOption(name: "interpolation", value: "no")
        setOption(name: "subs-fallback", value: "yes")
        setOption(name: "msg-level", value: "all=warn")
        setOption(name: "demuxer-thread", value: "yes")
        setOption(name: "sub-ass-override", value: "yes")
        setOption(name: "video-sync", value: "display-resample")
        setOption(name: "audio-normalize-downmix", value: "yes")
        configureWindowEmbedding()
        
        let initStatus = mpv_initialize(handle)
        guard initStatus >= 0 else {
            throw RendererError.mpvInitialization(initStatus)
        }
        
        mpv_request_log_messages(handle, "warn")
        observeProperties()
        installWakeupHandler()
        isRunning = true
    }
    
    func stop() {
        if isStopping { return }
        if !isRunning, mpv == nil { return }
        
        isRunning = false
        isStopping = true
        var handleForShutdown: OpaquePointer?
        
        renderQueue.sync { [weak self] in
            guard let self else { return }
            self.stopPiPRenderingLocked()
            
            handleForShutdown = self.mpv
            if let handle = handleForShutdown {
                mpv_set_wakeup_callback(handle, nil, nil)
                self.command(handle, ["quit"])
                mpv_wakeup(handle)
            }
            
            self.formatDescription = nil
            self.preAllocatedBuffers.removeAll()
            self.pixelBufferPool = nil
            self.poolWidth = 0
            self.poolHeight = 0
            self.lastRenderDimensions = .zero
        }
        
        eventQueueGroup.wait()
        
        renderQueue.sync { [weak self] in
            guard let self else { return }
            
            if let handle = handleForShutdown {
                mpv_destroy(handle)
            }
            self.mpv = nil
            
            self.preAllocatedBuffers.removeAll()
            self.pixelBufferPool = nil
            self.pixelBufferPoolAuxAttributes = nil
            self.formatDescription = nil
            self.poolWidth = 0
            self.poolHeight = 0
            self.lastRenderDimensions = .zero
            
            self.disposeBag.forEach { $0() }
            self.disposeBag.removeAll()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if #available(iOS 18.0, *) {
                self.pipDisplayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
            } else {
                self.pipDisplayLayer.flushAndRemoveImage()
            }
        }
        
        isStopping = false
    }
    
    func startPiPRendering() {
        renderQueue.async { [weak self] in
            guard let self, self.isRunning, !self.isStopping else { return }
            if self.pipRenderContext == nil {
                do {
                    try self.createPiPRenderContext()
                    self.shouldClearPixelBuffer = true
                } catch {
                    Logger.shared.log("Failed to create PiP SW render context: \(error)", type: "Error")
                    return
                }
            }
            self.startPiPDisplayLinkLocked()
        }
    }
    
    func stopPiPRendering() {
        renderQueue.async { [weak self] in
            self?.stopPiPRenderingLocked()
        }
    }
    
    func load(url: URL, with preset: PlayerPreset, headers: [String: String]? = nil) {
        currentPreset = preset
        currentURL = url
        currentHeaders = headers
        
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.isLoading = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.renderer(self, didChangeLoading: true)
            }
        }
        
        guard let handle = mpv else { return }
        
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.apply(commands: preset.commands, on: handle)
            self.command(handle, ["stop"])
            self.updateHTTPHeaders(headers)
            
            let target = url.isFileURL ? url.path : url.absoluteString
            self.command(handle, ["loadfile", target, "replace"])
        }
    }
    
    func applyPreset(_ preset: PlayerPreset) {
        currentPreset = preset
        guard let handle = mpv else { return }
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.apply(commands: preset.commands, on: handle)
        }
    }
    
    private func setOption(name: String, value: String) {
        guard let handle = mpv else { return }
        _ = value.withCString { valuePointer in
            name.withCString { namePointer in
                mpv_set_option_string(handle, namePointer, valuePointer)
            }
        }
    }
    
    private func setOption(name: String, int64Value: Int64) {
        guard let handle = mpv else { return }
        var mutableValue = int64Value
        let status = name.withCString { namePointer in
            withUnsafeMutablePointer(to: &mutableValue) { valuePointer in
                mpv_set_option(handle, namePointer, MPV_FORMAT_INT64, valuePointer)
            }
        }
        if status < 0 {
            Logger.shared.log("Failed to set option \(name)=\(int64Value) (\(status))", type: "Warn")
        }
    }
    
    private func configureWindowEmbedding() {
        guard let primaryRenderView else {
            Logger.shared.log("Primary render view is missing, mpv window embedding disabled", type: "Warn")
            return
        }
        
        let renderTarget = primaryRenderView.layer
        let pointerValue = UInt(bitPattern: Unmanaged.passUnretained(renderTarget).toOpaque())
        let wid = Int64(bitPattern: UInt64(pointerValue))
        setOption(name: "wid", int64Value: wid)
    }
    
    private func setProperty(name: String, value: String) {
        guard let handle = mpv else { return }
        let status = value.withCString { valuePointer in
            name.withCString { namePointer in
                mpv_set_property_string(handle, namePointer, valuePointer)
            }
        }
        if status < 0 {
            Logger.shared.log("Failed to set property \(name)=\(value) (\(status))", type: "Warn")
        }
    }
    
    private func clearProperty(name: String) {
        guard let handle = mpv else { return }
        let status = name.withCString { namePointer in
            mpv_set_property(handle, namePointer, MPV_FORMAT_NONE, nil)
        }
        if status < 0 {
            Logger.shared.log("Failed to clear property \(name) (\(status))", type: "Warn")
        }
    }
    
    private func updateHTTPHeaders(_ headers: [String: String]?) {
        guard let headers, !headers.isEmpty else {
            clearProperty(name: "http-header-fields")
            return
        }
        
        let headerString = headers
            .map { key, value in "\(key): \(value)" }
            .joined(separator: "\r\n")
        setProperty(name: "http-header-fields", value: headerString)
    }
    
    private func createPiPRenderContext() throws {
        guard let handle = mpv else { return }
        
        var apiType = MPV_RENDER_API_TYPE_SW
        let status = withUnsafePointer(to: &apiType) { apiTypePtr in
            var params = [
                mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(mutating: apiTypePtr)),
                mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
            ]
            
            return params.withUnsafeMutableBufferPointer { pointer -> Int32 in
                pointer.baseAddress?.withMemoryRebound(to: mpv_render_param.self, capacity: pointer.count) { parameters in
                    mpv_render_context_create(&pipRenderContext, handle, parameters)
                } ?? -1
            }
        }
        
        guard status >= 0, pipRenderContext != nil else {
            throw RendererError.renderContextCreation(status)
        }
        
        mpv_render_context_set_update_callback(pipRenderContext, { context in
            guard let context else { return }
            let instance = Unmanaged<MPVSoftwareRenderer>.fromOpaque(context).takeUnretainedValue()
            instance.requestPiPDisplayLink()
        }, Unmanaged.passUnretained(self).toOpaque())
    }
    
    private func observeProperties() {
        guard let handle = mpv else { return }
        let properties: [(String, mpv_format)] = [
            ("dwidth", MPV_FORMAT_INT64),
            ("dheight", MPV_FORMAT_INT64),
            ("duration", MPV_FORMAT_DOUBLE),
            ("time-pos", MPV_FORMAT_DOUBLE),
            ("pause", MPV_FORMAT_FLAG)
        ]
        
        for (name, format) in properties {
            _ = name.withCString { pointer in
                mpv_observe_property(handle, 0, pointer, format)
            }
        }
    }
    
    private func installWakeupHandler() {
        guard let handle = mpv else { return }
        mpv_set_wakeup_callback(handle, { userdata in
            guard let userdata else { return }
            let instance = Unmanaged<MPVSoftwareRenderer>.fromOpaque(userdata).takeUnretainedValue()
            instance.processEvents()
        }, Unmanaged.passUnretained(self).toOpaque())
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.disposeBag.append { [weak self] in
                guard let self, let handle = self.mpv else { return }
                mpv_set_wakeup_callback(handle, nil, nil)
            }
        }
    }
    
    private func requestPiPDisplayLink() {
        renderQueue.async { [weak self] in
            guard let self, self.pipRenderContext != nil else { return }
            self.pipDisplayLinkRequested = true
            self.startPiPDisplayLinkLocked()
        }
    }
    
    private func startPiPDisplayLinkLocked() {
        guard pipDisplayLink == nil else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.pipDisplayLink == nil else { return }
            
            let proxy = PiPDisplayLinkProxy(owner: self)
            let displayLink = CADisplayLink(target: proxy, selector: #selector(PiPDisplayLinkProxy.onDisplayLinkTick))
            displayLink.preferredFramesPerSecond = 30
            displayLink.add(to: .main, forMode: .common)
            
            self.pipDisplayLinkProxy = proxy
            self.pipDisplayLink = displayLink
        }
    }
    
    private func stopPiPDisplayLinkLocked() {
        DispatchQueue.main.async { [weak self] in
            self?.pipDisplayLink?.invalidate()
            self?.pipDisplayLink = nil
            self?.pipDisplayLinkProxy = nil
        }
    }
    
    private func pumpPiPFrame() {
        renderQueue.async { [weak self] in
            guard let self, self.isRunning, !self.isStopping else { return }
            guard let context = self.pipRenderContext else { return }
            guard self.pipDisplayLinkRequested || self.pipFramePumpScheduled else { return }
            
            self.pipFramePumpScheduled = true
            self.performPiPRenderUpdate(with: context)
            self.pipFramePumpScheduled = false
        }
    }
    
    private func performPiPRenderUpdate(with context: OpaquePointer) {
        let status = mpv_render_context_update(context)
        let updateFlags = UInt64(truncatingIfNeeded: status)
        if updateFlags & UInt64(MPV_RENDER_UPDATE_FRAME.rawValue) != 0 {
            pipDisplayLinkRequested = false
            renderFrame(with: context)
        }
    }
    
    private func renderFrame(with context: OpaquePointer) {
        let videoSize = currentVideoSize()
        guard videoSize.width > 0, videoSize.height > 0 else { return }
        
        let targetSize = targetRenderSize(for: videoSize)
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        guard width > 0, height > 0 else { return }
        
        if lastRenderDimensions != targetSize {
            lastRenderDimensions = targetSize
            if targetSize != videoSize {
                Logger.shared.log("Rendering PiP output at \(width)x\(height) (source \(Int(videoSize.width))x\(Int(videoSize.height)))", type: "Info")
            } else {
                Logger.shared.log("Rendering PiP output at native size \(width)x\(height)", type: "Info")
            }
        }
        
        if poolWidth != width || poolHeight != height {
            recreatePixelBufferPool(width: width, height: height)
        }
        
        var pixelBuffer: CVPixelBuffer?
        var status: CVReturn = kCVReturnError
        
        if !preAllocatedBuffers.isEmpty {
            pixelBuffer = preAllocatedBuffers.removeFirst()
            status = kCVReturnSuccess
        } else if let pool = pixelBufferPool {
            status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, pixelBufferPoolAuxAttributes, &pixelBuffer)
        }
        
        if status != kCVReturnSuccess || pixelBuffer == nil {
            let attrs: [CFString: Any] = [
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
            ]
            status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        }
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            Logger.shared.log("Failed to create pixel buffer for PiP rendering (status: \(status))", type: "Error")
            return
        }
        
        let actualFormat = CVPixelBufferGetPixelFormatType(buffer)
        if actualFormat != kCVPixelFormatType_32BGRA {
            Logger.shared.log("Pixel buffer format mismatch: expected BGRA (0x42475241), got \(actualFormat)", type: "Error")
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return
        }
        
        if shouldClearPixelBuffer {
            let bufferDataSize = CVPixelBufferGetDataSize(buffer)
            memset(baseAddress, 0, bufferDataSize)
            shouldClearPixelBuffer = false
        }
        
        dimensionsArray[0] = Int32(width)
        dimensionsArray[1] = Int32(height)
        let stride = Int32(CVPixelBufferGetBytesPerRow(buffer))
        let expectedMinStride = Int32(width * 4)
        if stride < expectedMinStride {
            Logger.shared.log("Unexpected pixel buffer stride \(stride) < expected \(expectedMinStride) - skipping render to avoid memory corruption", type: "Error")
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return
        }
        
        dimensionsArray.withUnsafeMutableBufferPointer { dimsPointer in
            bgraFormatCString.withUnsafeBufferPointer { formatPointer in
                withUnsafePointer(to: stride) { stridePointer in
                    renderParams[0] = mpv_render_param(type: MPV_RENDER_PARAM_SW_SIZE, data: UnsafeMutableRawPointer(dimsPointer.baseAddress))
                    renderParams[1] = mpv_render_param(type: MPV_RENDER_PARAM_SW_FORMAT, data: UnsafeMutableRawPointer(mutating: formatPointer.baseAddress))
                    renderParams[2] = mpv_render_param(type: MPV_RENDER_PARAM_SW_STRIDE, data: UnsafeMutableRawPointer(mutating: stridePointer))
                    renderParams[3] = mpv_render_param(type: MPV_RENDER_PARAM_SW_POINTER, data: baseAddress)
                    renderParams[4] = mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                    
                    let rc = mpv_render_context_render(context, &renderParams)
                    if rc < 0 {
                        Logger.shared.log("mpv_render_context_render returned error \(rc)", type: "Error")
                    }
                }
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        enqueue(buffer: buffer)
        
        if preAllocatedBuffers.count < 2 {
            renderQueue.async { [weak self] in
                self?.preAllocateBuffers()
            }
        }
    }
    
    private func targetRenderSize(for videoSize: CGSize) -> CGSize {
        guard videoSize.width > 0, videoSize.height > 0 else { return videoSize }
        
        guard
            let screen = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.screen })
                .first
        else {
            return videoSize
        }
        
        var scale = screen.scale
        if scale <= 0 { scale = 1 }
        let maxWidth = max(screen.bounds.width * scale, 1.0)
        let maxHeight = max(screen.bounds.height * scale, 1.0)
        if maxWidth <= 0 || maxHeight <= 0 {
            return videoSize
        }
        
        let widthRatio = videoSize.width / maxWidth
        let heightRatio = videoSize.height / maxHeight
        let ratio = max(widthRatio, heightRatio, 1)
        let targetWidth = max(1, Int(videoSize.width / ratio))
        let targetHeight = max(1, Int(videoSize.height / ratio))
        return CGSize(width: CGFloat(targetWidth), height: CGFloat(targetHeight))
    }
    
    private func createPixelBufferPool(width: Int, height: Int) {
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ]
        
        let poolAttrs: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: maxPreAllocatedBuffers,
            kCVPixelBufferPoolMaximumBufferAgeKey: 0
        ]
        
        let auxAttrs: [CFString: Any] = [
            kCVPixelBufferPoolAllocationThresholdKey: 8
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttrs as CFDictionary, attrs as CFDictionary, &pool)
        if status == kCVReturnSuccess, let pool {
            renderQueueSync {
                self.pixelBufferPool = pool
                self.pixelBufferPoolAuxAttributes = auxAttrs as CFDictionary
                self.poolWidth = width
                self.poolHeight = height
            }
            renderQueue.async { [weak self] in
                self?.preAllocateBuffers()
            }
        } else {
            Logger.shared.log("Failed to create CVPixelBufferPool (status: \(status))", type: "Error")
        }
    }
    
    private func recreatePixelBufferPool(width: Int, height: Int) {
        renderQueueSync {
            self.preAllocatedBuffers.removeAll()
            self.pixelBufferPool = nil
            self.formatDescription = nil
            self.poolWidth = 0
            self.poolHeight = 0
        }
        createPixelBufferPool(width: width, height: height)
    }
    
    private func preAllocateBuffers() {
        guard DispatchQueue.getSpecific(key: renderQueueKey) != nil else {
            renderQueue.async { [weak self] in
                self?.preAllocateBuffers()
            }
            return
        }
        
        guard let pool = pixelBufferPool else { return }
        
        let targetCount = min(maxPreAllocatedBuffers, 5)
        let currentCount = preAllocatedBuffers.count
        guard currentCount < targetCount else { return }
        
        let bufferCount = min(targetCount - currentCount, 2)
        for _ in 0..<bufferCount {
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
                kCFAllocatorDefault,
                pool,
                pixelBufferPoolAuxAttributes,
                &buffer
            )
            
            if status == kCVReturnSuccess, let buffer {
                if preAllocatedBuffers.count < maxPreAllocatedBuffers {
                    preAllocatedBuffers.append(buffer)
                }
            } else {
                if status != kCVReturnWouldExceedAllocationThreshold {
                    Logger.shared.log("Failed to pre-allocate buffer (status: \(status))", type: "Warn")
                }
                break
            }
        }
    }
    
    private func enqueue(buffer: CVPixelBuffer) {
        let needsFlush = updateFormatDescriptionIfNeeded(for: buffer)
        var capturedFormatDescription: CMVideoFormatDescription?
        renderQueueSync {
            capturedFormatDescription = self.formatDescription
        }
        
        guard let formatDescription = capturedFormatDescription else {
            Logger.shared.log("Missing formatDescription when creating sample buffer - skipping frame", type: "Error")
            return
        }
        
        let presentationTime = CMClockGetTime(CMClockGetHostTimeClock())
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        
        var sampleBuffer: CMSampleBuffer?
        let result = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard result == noErr, let sample = sampleBuffer else {
            Logger.shared.log("Failed to create sample buffer (error: \(result))", type: "Error")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            let (status, error): (AVQueuedSampleBufferRenderingStatus?, Error?) = {
                if #available(iOS 18.0, *) {
                    return (
                        self.pipDisplayLayer.sampleBufferRenderer.status,
                        self.pipDisplayLayer.sampleBufferRenderer.error
                    )
                } else {
                    return (
                        self.pipDisplayLayer.status,
                        self.pipDisplayLayer.error
                    )
                }
            }()
            
            if status == .failed {
                if let error {
                    Logger.shared.log("PiP display layer in failed state: \(error.localizedDescription)", type: "Error")
                }
                if #available(iOS 18.0, *) {
                    self.pipDisplayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
                } else {
                    self.pipDisplayLayer.flushAndRemoveImage()
                }
            }
            
            if needsFlush {
                if #available(iOS 18.0, *) {
                    self.pipDisplayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
                } else {
                    self.pipDisplayLayer.flushAndRemoveImage()
                }
                self.didFlushForFormatChange = true
            } else if self.didFlushForFormatChange {
                if #available(iOS 18.0, *) {
                    self.pipDisplayLayer.sampleBufferRenderer.flush(removingDisplayedImage: false, completionHandler: nil)
                } else {
                    self.pipDisplayLayer.flush()
                }
                self.didFlushForFormatChange = false
            }
            
            if self.pipDisplayLayer.controlTimebase == nil {
                var timebase: CMTimebase?
                if CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase) == noErr, let timebase {
                    CMTimebaseSetRate(timebase, rate: 1.0)
                    CMTimebaseSetTime(timebase, time: presentationTime)
                    self.pipDisplayLayer.controlTimebase = timebase
                }
            }
            
            if #available(iOS 18.0, *) {
                self.pipDisplayLayer.sampleBufferRenderer.enqueue(sample)
            } else {
                self.pipDisplayLayer.enqueue(sample)
            }
        }
    }
    
    private func updateFormatDescriptionIfNeeded(for buffer: CVPixelBuffer) -> Bool {
        var didChange = false
        let width = Int32(CVPixelBufferGetWidth(buffer))
        let height = Int32(CVPixelBufferGetHeight(buffer))
        let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
        
        renderQueueSync {
            var needsRecreate = false
            
            if let description = formatDescription {
                let currentDimensions = CMVideoFormatDescriptionGetDimensions(description)
                let currentPixelFormat = CMFormatDescriptionGetMediaSubType(description)
                
                if currentDimensions.width != width ||
                    currentDimensions.height != height ||
                    currentPixelFormat != pixelFormat {
                    needsRecreate = true
                }
            } else {
                needsRecreate = true
            }
            
            if needsRecreate {
                var newDescription: CMVideoFormatDescription?
                let status = CMVideoFormatDescriptionCreateForImageBuffer(
                    allocator: kCFAllocatorDefault,
                    imageBuffer: buffer,
                    formatDescriptionOut: &newDescription
                )
                
                if status == noErr, let newDescription {
                    formatDescription = newDescription
                    didChange = true
                } else {
                    Logger.shared.log("Failed to create format description (status: \(status))", type: "Error")
                }
            }
        }
        return didChange
    }
    
    private func renderQueueSync(_ block: () -> Void) {
        if DispatchQueue.getSpecific(key: renderQueueKey) != nil {
            block()
        } else {
            renderQueue.sync(execute: block)
        }
    }
    
    private func currentVideoSize() -> CGSize {
        stateQueue.sync { videoSize }
    }
    
    private func updateVideoSize(width: Int, height: Int) {
        let size = CGSize(width: max(width, 0), height: max(height, 0))
        stateQueue.async(flags: .barrier) {
            self.videoSize = size
        }
        renderQueue.async { [weak self] in
            guard let self else { return }
            if self.pipRenderContext != nil && (self.poolWidth != width || self.poolHeight != height) {
                self.recreatePixelBufferPool(width: max(width, 0), height: max(height, 0))
            }
        }
    }
    
    private func stopPiPRenderingLocked() {
        stopPiPDisplayLinkLocked()
        
        if let ctx = pipRenderContext {
            mpv_render_context_set_update_callback(ctx, nil, nil)
            mpv_render_context_free(ctx)
            pipRenderContext = nil
        }
        
        pipDisplayLinkRequested = false
        pipFramePumpScheduled = false
        preAllocatedBuffers.removeAll()
        pixelBufferPool = nil
        pixelBufferPoolAuxAttributes = nil
        formatDescription = nil
        didFlushForFormatChange = false
        poolWidth = 0
        poolHeight = 0
        lastRenderDimensions = .zero
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if #available(iOS 18.0, *) {
                self.pipDisplayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
            } else {
                self.pipDisplayLayer.flushAndRemoveImage()
            }
        }
    }
    
    private func apply(commands: [[String]], on handle: OpaquePointer) {
        for command in commands {
            guard !command.isEmpty else { continue }
            self.command(handle, command)
        }
    }
    
    private func command(_ handle: OpaquePointer, _ args: [String]) {
        guard !args.isEmpty else { return }
        _ = withCStringArray(args) { pointer in
            mpv_command_async(handle, 0, pointer)
        }
    }
    
    private func processEvents() {
        eventQueueGroup.enter()
        let group = eventQueueGroup
        eventQueue.async { [weak self] in
            defer { group.leave() }
            guard let self else { return }
            while !self.isStopping {
                guard let handle = self.mpv else { return }
                guard let eventPointer = mpv_wait_event(handle, 0) else { return }
                let event = eventPointer.pointee
                if event.event_id == MPV_EVENT_NONE { continue }
                self.handleEvent(event)
                if event.event_id == MPV_EVENT_SHUTDOWN { break }
            }
        }
    }
    
    private func handleEvent(_ event: mpv_event) {
        switch event.event_id {
        case MPV_EVENT_VIDEO_RECONFIG:
            refreshVideoState()
        case MPV_EVENT_FILE_LOADED:
            isLoading = false
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.renderer(self, didChangeLoading: false)
                self.delegate?.renderer(self, didBecomeReadyToSeek: true)
            }
        case MPV_EVENT_PROPERTY_CHANGE:
            if let property = event.data?.assumingMemoryBound(to: mpv_event_property.self).pointee.name {
                let name = String(cString: property)
                refreshProperty(named: name)
            }
        case MPV_EVENT_SHUTDOWN:
            Logger.shared.log("mpv shutdown", type: "Warn")
        case MPV_EVENT_LOG_MESSAGE:
            if let logMessagePointer = event.data?.assumingMemoryBound(to: mpv_event_log_message.self) {
                let component = String(cString: logMessagePointer.pointee.prefix)
                let text = String(cString: logMessagePointer.pointee.text)
                let lower = text.lowercased()
                if lower.contains("error") {
                    Logger.shared.log("mpv[\(component)] \(text)", type: "Error")
                } else if lower.contains("warn") || lower.contains("warning") || lower.contains("deprecated") {
                    Logger.shared.log("mpv[\(component)] \(text)", type: "Warn")
                }
            }
        default:
            break
        }
    }
    
    private func refreshVideoState() {
        guard let handle = mpv else { return }
        var width: Int64 = 0
        var height: Int64 = 0
        getProperty(handle: handle, name: "dwidth", format: MPV_FORMAT_INT64, value: &width)
        getProperty(handle: handle, name: "dheight", format: MPV_FORMAT_INT64, value: &height)
        updateVideoSize(width: Int(width), height: Int(height))
    }
    
    private func refreshProperty(named name: String) {
        guard let handle = mpv else { return }
        switch name {
        case "duration":
            var value = Double(0)
            let status = getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value)
            if status >= 0 {
                cachedDuration = value
                delegate?.renderer(self, didUpdatePosition: cachedPosition, duration: cachedDuration)
            }
        case "time-pos":
            var value = Double(0)
            let status = getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value)
            if status >= 0 {
                cachedPosition = value
                delegate?.renderer(self, didUpdatePosition: cachedPosition, duration: cachedDuration)
            }
        case "pause":
            var flag: Int32 = 0
            let status = getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag)
            if status >= 0 {
                let newPaused = flag != 0
                if newPaused != isPaused {
                    isPaused = newPaused
                    delegate?.renderer(self, didChangePause: isPaused)
                }
            }
        default:
            break
        }
    }
    
    @discardableResult
    private func getProperty<T>(handle: OpaquePointer, name: String, format: mpv_format, value: inout T) -> Int32 {
        return name.withCString { pointer in
            withUnsafeMutablePointer(to: &value) { mutablePointer in
                mpv_get_property(handle, pointer, format, mutablePointer)
            }
        }
    }
    
    @inline(__always)
    private func withCStringArray<R>(_ args: [String], body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> R) -> R {
        var cStrings = [UnsafeMutablePointer<CChar>?]()
        cStrings.reserveCapacity(args.count + 1)
        for s in args {
            cStrings.append(strdup(s))
        }
        cStrings.append(nil)
        
        defer {
            for ptr in cStrings where ptr != nil {
                free(ptr)
            }
        }
        
        return cStrings.withUnsafeMutableBufferPointer { buffer in
            return buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) { rebound in
                body(UnsafeMutablePointer(mutating: rebound))
            }
        }
    }
    
    // MARK: - Playback Controls
    
    func play() {
        setProperty(name: "pause", value: "no")
    }
    
    func pausePlayback() {
        setProperty(name: "pause", value: "yes")
    }
    
    func seek(to seconds: Double) {
        guard let handle = mpv else { return }
        let clamped = max(0, seconds)
        command(handle, ["seek", String(clamped), "absolute"])
    }
    
    func seek(by seconds: Double) {
        guard let handle = mpv else { return }
        command(handle, ["seek", String(seconds), "relative"])
    }
    
    func setSpeed(_ speed: Double) {
        setProperty(name: "speed", value: String(speed))
    }
    
    func getSpeed() -> Double {
        guard let handle = mpv else { return 1.0 }
        var speed: Double = 1.0
        getProperty(handle: handle, name: "speed", format: MPV_FORMAT_DOUBLE, value: &speed)
        return speed
    }
    
    func setSubtitleVisible(_ visible: Bool) {
        setProperty(name: "sub-visibility", value: visible ? "yes" : "no")
    }
    
    func addSubtitleTrack(urlString: String) {
        guard let handle = mpv, !urlString.isEmpty else { return }
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.command(handle, ["sub-add", urlString, "select"])
            Logger.shared.log("sub-add: \(urlString)", type: "Info")
        }
    }
    
    func clearCurrentSubtitleTrack() {
        guard let handle = mpv else { return }
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.command(handle, ["sub-remove"])
        }
    }
    
    func applySubtitleStyle(_ style: SubtitleStyle) {
        setProperty(name: "sub-font-size", value: String(format: "%.2f", style.fontSize))
        setProperty(name: "sub-color", value: style.foregroundColor.mpvColorString)
        setProperty(name: "sub-border-color", value: style.strokeColor.mpvColorString)
        setProperty(name: "sub-border-size", value: String(format: "%.2f", max(style.strokeWidth, 0)))
    }
}

private extension UIColor {
    var mpvColorString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f/%.3f/%.3f/%.3f", r, g, b, a)
    }
}
