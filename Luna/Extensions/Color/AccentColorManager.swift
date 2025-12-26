//
//  AccentColorManager.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import SwiftUI
import Foundation

class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    @Published var currentAccentColor: Color = .blue
    
    private init() {
        loadAccentColor()
    }
    
    func saveAccentColor(_ color: Color) {
        currentAccentColor = color
        
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: UIColor(color), requiringSecureCoding: true)
            UserDefaults.standard.set(colorData, forKey: "accentColor")
        } catch {
            Logger.shared.log("Failed to save accent color", type: "Error")
        }
    }
    
    private func loadAccentColor() {
        guard let colorData = UserDefaults.standard.data(forKey: "accentColor"), !colorData.isEmpty else {
            currentAccentColor = .blue
            return
        }
        
        do {
            if let uiColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
                currentAccentColor = Color(uiColor)
            }
        } catch {
            currentAccentColor = .blue
        }
    }
}
