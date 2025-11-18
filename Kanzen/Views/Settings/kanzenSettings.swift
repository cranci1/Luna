//
//  kanzenSettings.swift
//  Luna
//
//  Created by Dawud Osman on 17/11/2025.
//
//
//  SettingsView.swift
//  Kanzen
//
//  Created by Dawud Osman on 16/05/2025.
//
import SwiftUI
struct KanzenSettingsView : View
{
    @AppStorage("showKanzen") private var showKanzen: Bool = false
    var body: some View
    {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    NavigationLink(destination: KanzenGeneralSettingsView()){Text("Preferences")}
                   
                    
                }
                Section(header: Text("Activity")) {
                    NavigationLink(destination: LoggerView()) {
                        Text("Logs")
                        
                    }
                    
                }
                Section(header: Text("Others")){
                    Text("Switch to Sora")
                        .onTapGesture {
                            showKanzen = false
                        }
                }
                
                Section(footer: Text("Running Kanzen v0.1 - Churly" )){}
            }.navigationTitle("Settings")
            
            
        
        }
    }
}
