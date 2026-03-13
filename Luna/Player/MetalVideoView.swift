//
//  MetalVideoView.swift
//  test
//
//  Created by Francesco on 13/03/26.
//

import UIKit
import QuartzCore

final class MetalVideoView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    
    var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    var onDrawableSizeChanged: ((CGSize) -> Void)?
    private var lastDrawableSize: CGSize = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .black
        isOpaque = true
        contentScaleFactor = UIScreen.main.scale
        
        metalLayer.isOpaque = true
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.presentsWithTransaction = false
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        metalLayer.framebufferOnly = true
        
        updateMetalLayerLayout(notify: false)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateMetalLayerLayout(notify: true)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateMetalLayerLayout(notify: true)
    }
    
    private func updateMetalLayerLayout(notify: Bool) {
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        metalLayer.contentsScale = scale
        metalLayer.frame = bounds
        metalLayer.drawableSize = drawableSize
        CATransaction.commit()
        
        if notify, drawableSize != lastDrawableSize {
            lastDrawableSize = drawableSize
            onDrawableSizeChanged?(drawableSize)
        }
    }
}
