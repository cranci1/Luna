//
//  contentCell.swift
//  Kanzen
//
//  Created by Dawud Osman on 26/05/2025.
//
import SwiftUI
import Foundation
import Kingfisher
struct contentCell: View {
    @State var title: String
    @State var urlString: String
    @State var width: CGFloat

    
    init(title: String, urlString: String, width: CGFloat) {
        self.title = title
        self.urlString = urlString
        self.width = width

    }
    var body: some View {
        ZStack(alignment: .bottomLeading){
            if let url = URL(string: urlString) {
                
                KFImage(url)
                    // Don't set processor here to ensure cached original image is used
                    .onSuccess { result in
                        switch result.cacheType {
                        case .none:
                            print("Image loaded from network.")
                        case .memory:
                            print("Image loaded from memory cache.")
                        case .disk:
                            print("Image loaded from disk cache.")
                        @unknown default:
                            print("Unknown cache type.")
                        }
                    }
                    .onFailure { error in
                        print("Image loading failed: \(error)")
                    }
                    .placeholder {
                        ProgressView()
                    }
                    .fade(duration: 0.25)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: width, height: width * 1.5)))
                    .resizable()
                    .scaleFactor(UIScreen.main.scale)
                    .interpolation(.low)
                    .aspectRatio(0.72, contentMode: .fill)
                    .onAppear{
                        print("Image appeared \(urlString)")
                    }
                    
                // SwiftUI resizes smoothly
                    .frame(width: width, height: width * 1.5)
                    .clipped()
                 
                
                
                    
            } else {
                Rectangle().fill(Color.black).clipped().frame(width: width,height: width * 1.5)
            }
            // Gradient fade at the bottom
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .clipped()
            Text(title).lineLimit(1).foregroundColor(.white)
.cornerRadius(5).padding([.leading, .bottom], 5)
            
        }
        .frame(maxWidth: 150)
        .frame(height: 150 * 1.5)
        .cornerRadius(5)
        
        
        
    }
}
