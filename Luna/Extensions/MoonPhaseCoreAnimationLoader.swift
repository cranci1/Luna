//
//  MoonPhaseCoreAnimationLoader.swift
//  Luna
//
//  CoreAnimation-backed “moon phase” loader.
//  This is intentionally UIKit-based so animations are driven by CoreAnimation
//  rather than SwiftUI view update cadence.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

final class MoonPhaseSpinnerView: UIView {
    struct Configuration: Equatable {
        var iconSize: CGFloat = 22
        var spacing: CGFloat = 12
        var stepDuration: TimeInterval = 0.18
        var inactiveOpacity: Float = 0.35
        var activeOpacity: Float = 1.0
        var inactiveScale: CGFloat = 1.0
        var activeScale: CGFloat = 1.18
        /// Primary (brighter) color for palette/hierarchical SF Symbols.
        var primaryColor: UIColor = UIColor(white: 0.85, alpha: 1.0)
        /// Secondary (darker) color for palette/hierarchical SF Symbols.
        var secondaryColor: UIColor = UIColor(white: 0.45, alpha: 1.0)
    }

    private let phaseSymbolNames: [String] = [
        "moonphase.waxing.crescent",
        "moonphase.first.quarter",
        "moonphase.waxing.gibbous",
        "moonphase.full.moon",
        "moonphase.waning.gibbous",
        "moonphase.last.quarter",
        "moonphase.waning.crescent"
    ]

    private var config: Configuration = Configuration()
    private var phaseLayers: [CALayer] = []
    private var isAnimating: Bool = false

    override class var layerClass: AnyClass { CALayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        createLayersIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        createLayersIfNeeded()
    }

    func apply(configuration: Configuration) {
        guard configuration != config else { return }
        config = configuration
        updateLayerContents()
        setNeedsLayout()
        if isAnimating { restartAnimations() }
    }

    func setAnimating(_ animating: Bool) {
        guard animating != isAnimating else { return }
        isAnimating = animating
        if animating {
            restartAnimations()
        } else {
            stopAnimations()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        createLayersIfNeeded()

        let count = max(phaseLayers.count, 1)
        let totalWidth = CGFloat(count) * config.iconSize + CGFloat(max(0, count - 1)) * config.spacing
        let startX = (bounds.width - totalWidth) / 2
        let y = (bounds.height - config.iconSize) / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, layer) in phaseLayers.enumerated() {
            let x = startX + CGFloat(index) * (config.iconSize + config.spacing)
            layer.frame = CGRect(x: x, y: y, width: config.iconSize, height: config.iconSize)
        }
        CATransaction.commit()
    }

    private func createLayersIfNeeded() {
        guard phaseLayers.isEmpty else { return }

        phaseLayers = phaseSymbolNames.map { _ in
            let layer = CALayer()
            layer.contentsGravity = .resizeAspect
            layer.opacity = config.inactiveOpacity
            layer.shadowColor = UIColor.white.cgColor
            layer.shadowOpacity = 0
            layer.shadowRadius = 6
            layer.shadowOffset = .zero
            self.layer.addSublayer(layer)
            return layer
        }

        updateLayerContents()
    }

    private func updateLayerContents() {
        let pointSize = config.iconSize
        let baseConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: [config.primaryColor, config.secondaryColor])
        let symbolConfig = baseConfig.applying(paletteConfig)

        for (index, layer) in phaseLayers.enumerated() {
            let name = phaseSymbolNames[index]
            let image = UIImage(systemName: name, withConfiguration: symbolConfig)
                ?? UIImage(systemName: "circle", withConfiguration: symbolConfig)

            // Palette-configured images render with their own colors.
            // If a symbol doesn’t support palette rendering, it may still come through as a template;
            // in that case, force a mid-gray tint so it stays visible on black.
            if let img = image {
                let rendered = img.renderingMode == .alwaysTemplate
                    ? img.withTintColor(config.primaryColor, renderingMode: .alwaysOriginal)
                    : img
                layer.contents = rendered.cgImage
            } else {
                layer.contents = nil
            }
        }
    }

    private func restartAnimations() {
        stopAnimations()

        let cycleDuration = config.stepDuration * Double(max(phaseLayers.count, 1))
        let now = CACurrentMediaTime()

        for (index, layer) in phaseLayers.enumerated() {
            let beginTime = now + config.stepDuration * Double(index)

            // Opacity pulse
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [config.inactiveOpacity, config.activeOpacity, config.inactiveOpacity]
            opacity.keyTimes = [0.0, 0.5, 1.0]
            opacity.duration = cycleDuration
            opacity.beginTime = beginTime
            opacity.repeatCount = .infinity
            opacity.isRemovedOnCompletion = false

            // Scale pulse
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [config.inactiveScale, config.activeScale, config.inactiveScale]
            scale.keyTimes = [0.0, 0.5, 1.0]
            scale.duration = cycleDuration
            scale.beginTime = beginTime
            scale.repeatCount = .infinity
            scale.isRemovedOnCompletion = false

            // Shadow pulse
            let shadowOpacity = CAKeyframeAnimation(keyPath: "shadowOpacity")
            shadowOpacity.values = [0.0, 0.35, 0.0]
            shadowOpacity.keyTimes = [0.0, 0.5, 1.0]
            shadowOpacity.duration = cycleDuration
            shadowOpacity.beginTime = beginTime
            shadowOpacity.repeatCount = .infinity
            shadowOpacity.isRemovedOnCompletion = false

            // Keep all layers on the same time base.
            opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            shadowOpacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            layer.add(opacity, forKey: "moon.opacity")
            layer.add(scale, forKey: "moon.scale")
            layer.add(shadowOpacity, forKey: "moon.shadow")
        }
    }

    private func stopAnimations() {
        for layer in phaseLayers {
            layer.removeAnimation(forKey: "moon.opacity")
            layer.removeAnimation(forKey: "moon.scale")
            layer.removeAnimation(forKey: "moon.shadow")
        }
    }
}

/// SwiftUI wrapper.
struct MoonPhaseCoreAnimationLoader: UIViewRepresentable {
    var iconSize: CGFloat = 22
    var spacing: CGFloat = 12
    var stepDuration: TimeInterval = 0.18
    var isAnimating: Bool = true
    var primaryColor: UIColor = UIColor(white: 0.85, alpha: 1.0)
    var secondaryColor: UIColor = UIColor(white: 0.45, alpha: 1.0)

    func makeUIView(context: Context) -> MoonPhaseSpinnerView {
        let view = MoonPhaseSpinnerView()
        view.apply(configuration: .init(
            iconSize: iconSize,
            spacing: spacing,
            stepDuration: stepDuration,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor
        ))
        view.setAnimating(isAnimating)
        return view
    }

    func updateUIView(_ uiView: MoonPhaseSpinnerView, context: Context) {
        uiView.apply(configuration: .init(
            iconSize: iconSize,
            spacing: spacing,
            stepDuration: stepDuration,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor
        ))
        uiView.setAnimating(isAnimating)
    }
}

#else

/// Fallback for platforms without UIKit.
struct MoonPhaseCoreAnimationLoader: View {
    var iconSize: CGFloat = 22
    var spacing: CGFloat = 12
    var stepDuration: TimeInterval = 0.18
    var isAnimating: Bool = true

    var body: some View {
        if isAnimating {
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}

#endif

#Preview("MoonPhaseCoreAnimationLoader") {
    ZStack {
        Color.black.ignoresSafeArea()
        MoonPhaseCoreAnimationLoader(iconSize: 30, spacing: 14, stepDuration: 0.3)
            .frame(height: 60)
    }
}
