//
//  resized.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import UIKit

extension UIImage {
    func resized(to size: CGSize, contentMode: ContentMode = .scaleAspectFit) -> UIImage? {
        let aspectSize: CGSize
        
        switch contentMode {
        case .scaleAspectFill:
            let aspectRatio = self.size.width / self.size.height
            if size.width / aspectRatio > size.height {
                aspectSize = CGSize(width: size.width, height: size.width / aspectRatio)
            } else {
                aspectSize = CGSize(width: size.height * aspectRatio, height: size.height)
            }
        case .scaleAspectFit:
            let aspectRatio = self.size.width / self.size.height
            if size.width / aspectRatio < size.height {
                aspectSize = CGSize(width: size.width, height: size.width / aspectRatio)
            } else {
                aspectSize = CGSize(width: size.height * aspectRatio, height: size.height)
            }
        }
        
        let renderer = UIGraphicsImageRenderer(size: aspectSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: aspectSize))
        }
    }
    
    enum ContentMode {
        case scaleAspectFit
        case scaleAspectFill
    }
}
