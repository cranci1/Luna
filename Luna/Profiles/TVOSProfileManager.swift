//
//  TVOSProfileManager.swift
//  Luna
//
//  Created by Luna on 01/02/26.
//

import Foundation

#if os(tvOS)
import UIKit
#if canImport(TVServices)
import TVServices
#endif
#endif

final class TVOSProfileManager: ObservableObject {
    static let shared = TVOSProfileManager()
    static let profileDidChangeNotification = Notification.Name("TVOSProfileDidChange")

    @Published private(set) var currentProfileID: String

    #if os(tvOS)
    private let userManager = TVUserManager()
    #endif

    private var userAccountObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    private init() {
        currentProfileID = Self.resolveCurrentProfileID()

        #if os(tvOS)
        if #available(tvOS 13.0, *) {
            userAccountObserver = NotificationCenter.default.addObserver(
                forName: TVUserManager.currentUserIdentifierDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleProfileMaybeChanged()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleProfileMaybeChanged()
        }
        #endif
    }

    private func handleProfileMaybeChanged() {
        let newID = Self.resolveCurrentProfileID()
        guard newID != currentProfileID else { return }
        currentProfileID = newID
        NotificationCenter.default.post(
            name: Self.profileDidChangeNotification,
            object: nil,
            userInfo: ["profileID": newID]
        )
    }

    static func resolveCurrentProfileID() -> String {
        #if os(tvOS)
        let manager = TVUserManager()

        if #available(tvOS 16.0, *) {
            if let identifier = manager.currentUserIdentifier {
                return sanitizedProfileIdentifier(identifier)
            }

            if manager.shouldStorePreferencesForCurrentUser {
                return "currentUser"
            }

            return "default"
        } else if let identifier = manager.currentUserIdentifier {
            return sanitizedProfileIdentifier(identifier)
        }
        #endif
        return "default"
    }

    #if os(tvOS)
    static func debugCurrentUserIdentifier() -> String? {
        TVUserManager().currentUserIdentifier
    }

    static func debugShouldStorePreferencesForCurrentUser() -> Bool? {
        if #available(tvOS 16.0, *) {
            return TVUserManager().shouldStorePreferencesForCurrentUser
        }
        return nil
    }
    #endif

    static func sanitizedProfileIdentifier(_ raw: String) -> String {
        guard raw.isEmpty == false else { return "default" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let trimmed = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let limited = trimmed.isEmpty ? "default" : String(trimmed.prefix(64))
        return limited
    }

}
