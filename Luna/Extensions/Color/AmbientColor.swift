//
//  AmbientColor.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import UIKit
import SwiftUI
import Accelerate

// How does it work uh? On hopes and beliving on him? Why? Cuz i had to learn HSV, and how to work twith it yayy.
extension Color {
    static func ambientColor(from image: UIImage?, prioritizeBottom: Bool = true) -> Color {
        guard let image = image else { return .black }
        
        let targetSize = CGSize(width: 64, height: 64)
        guard let resizedImage = image.resized(to: targetSize, contentMode: .scaleAspectFill),
              let cgImage = resizedImage.cgImage else { return .black }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        
        guard let data = malloc(totalBytes) else { return .black }
        defer { free(data) }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return .black
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: totalBytes)
        
        var redSum: Float = 0
        var greenSum: Float = 0
        var blueSum: Float = 0
        var totalWeight: Float = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                let red = Float(buffer[pixelIndex]) / 255.0
                let green = Float(buffer[pixelIndex + 1]) / 255.0
                let blue = Float(buffer[pixelIndex + 2]) / 255.0
                let alpha = Float(buffer[pixelIndex + 3]) / 255.0
                
                guard alpha > 0.1 && (red + green + blue) > 0.15 else { continue }
                
                let brightness = red * 0.2126 + green * 0.7152 + blue * 0.0722
                let brightnessWeight = 1.0 - abs(brightness - 0.5) * 0.4
                
                let maxComponent = max(red, max(green, blue))
                let minComponent = min(red, min(green, blue))
                let saturation = maxComponent > 0 ? (maxComponent - minComponent) / maxComponent : 0
                let saturationWeight = 0.5 + saturation * 0.5
                
                let centerX = Float(width) / 2
                let centerY = Float(height) / 2
                let dx = Float(x) - centerX
                let dy = Float(y) - centerY
                let distance = sqrt(dx * dx + dy * dy)
                let maxDistance = sqrt(centerX * centerX + centerY * centerY)
                let centerWeight = 1.0 - (distance / maxDistance) * 0.3
                
                let verticalWeight: Float
                if prioritizeBottom {
                    let normalizedY = Float(y) / Float(height)
                    verticalWeight = 0.3 + 0.7 * (normalizedY * normalizedY)
                } else {
                    verticalWeight = 1.0
                }
                
                let finalWeight = centerWeight * brightnessWeight * saturationWeight * alpha * verticalWeight
                
                redSum += red * finalWeight
                greenSum += green * finalWeight
                blueSum += blue * finalWeight
                totalWeight += finalWeight
            }
        }
        
        guard totalWeight > 0 else { return .black }
        
        let avgRed = redSum / totalWeight
        let avgGreen = greenSum / totalWeight
        let avgBlue = blueSum / totalWeight
        
        let (h, s, v) = rgbToHsv(r: Double(avgRed), g: Double(avgGreen), b: Double(avgBlue))
        
        let adjustedS = min(s * 1.2, 1.0)
        let adjustedV = v * 0.7
        
        let (r, g, b) = hsvToRgb(h: h, s: adjustedS, v: adjustedV)
        
        return Color(red: r, green: g, blue: b)
    }
    
    private static func rgbToHsv(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let minVal = min(r, min(g, b))
        let maxVal = max(r, max(g, b))
        let delta = maxVal - minVal
        
        var h: Double = 0
        var s: Double = 0
        let v: Double = maxVal
        
        if delta > 0 {
            s = delta / maxVal
            
            if r == maxVal {
                h = (g - b) / delta
            } else if g == maxVal {
                h = 2 + (b - r) / delta
            } else {
                h = 4 + (r - g) / delta
            }
            
            h *= 60
            if h < 0 {
                h += 360
            }
        }
        
        return (h, s, v)
    }
    
    private static func hsvToRgb(h: Double, s: Double, v: Double) -> (r: Double, g: Double, b: Double) {
        if s == 0 {
            return (v, v, v)
        }
        
        var h = h
        if h >= 360 { h = 0 }
        h /= 60
        
        let i = Int(h)
        let f = h - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        
        switch i {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }
}
