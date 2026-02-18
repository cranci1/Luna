//
//  StorageErrorToast.swift
//  Luna
//
//  Created by Dominic on 01.01.26.
//

import SwiftUI

struct StorageErrorToast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Storage Error")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .foregroundColor(.blue)

                Spacer()

                Button("Restart App") {
                    fatalError("StorageErrorToast requested app termination due to an unrecoverable storage error. Please restart the app.")
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        #if !os(tvOS)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )

            .padding()
        #endif
    }
}

struct StorageErrorOverlay: ViewModifier {
    @State private var showError = false
    @State private var errorMessage = ""

    func body(content: Content) -> some View {
        ZStack {
            content

            if showError {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showError = false
                    }

                VStack {
                    StorageErrorToast(message: errorMessage) {
                        showError = false
                    }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ServiceStore.criticalErrorNotification)) { notification in
            if let error = notification.userInfo?["error"] as? String {
                errorMessage = error
                withAnimation {
                    showError = true
                }
            }
        }
    }
}

extension View {
    func storageErrorOverlay() -> some View {
        modifier(StorageErrorOverlay())
    }
}
