//
//  GeneralView.swift
//  Kanzen
//
//  Created by Dawud Osman on 22/05/2025.
//
import SwiftUI
struct KanzenGeneralSettingsView: View {
    @EnvironmentObject var settings : Settings
    var body: some View {
        Form {
            Section(header: Text("Interface")) {
                ColorPicker("Accent Color", selection: $settings.accentColor)
                
                HStack {
                    
                    Text("Appearance")
                    Spacer()
                    Picker("Appearance", selection: $settings.selectedAppearance) {
                        Text("System").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 300)
                    

                }
                
                
                            }
        }
        .navigationTitle(Text("Preferences"))
    }

}
