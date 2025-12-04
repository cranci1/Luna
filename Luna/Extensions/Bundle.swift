//
//  Bundle.swift
//  Luna
//
//  Created by Dominic on 04.11.25.
//

import Foundation

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    var iCloudContainerID: String? {
        infoDictionary?["iCloudContainerID"] as? String
    }
}

