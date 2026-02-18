//
//  TVOSBackButton.swift
//  Luna
//
//  Created by Dominic on 03.01.26.
//

import SwiftUI

#if os(tvOS)
struct TVOSBackButton: ViewModifier {
    @Environment(\.presentationMode) var presentationMode

    func body(content: Content) -> some View {
        content
            .onExitCommand {
                presentationMode.wrappedValue.dismiss()
            }
    }
}
#endif

extension View {
    func tvOSBackButton() -> some View {
        #if os(tvOS)
            self.modifier(TVOSBackButton())
        #else
            self
        #endif
    }
}
