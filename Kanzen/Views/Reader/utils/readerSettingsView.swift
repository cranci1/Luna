//
//  readerSettings.swift
//  Kanzen
//
//  Created by Dawud Osman on 05/10/2025.
//
import SwiftUI
struct readerManagerSettings: View {
    @ObservedObject var readerManager: readerManager
    var body: some View
    {
        Form{
            Section{
                Picker("Reading Mode",selection: readerManager.$readingModeRaw){
                    ForEach(ReadingMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            }
        }
    }

}
