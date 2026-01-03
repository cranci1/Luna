//
//  Untitled.swift
//  Luna
//
//  Created by Dominic on 30.12.25.
//

import SwiftUI

struct AdaptiveConfirmationDialog<Actions: View, Message: View>: ViewModifier {

    let title: String
    @Binding var isPresented: Bool
    let titleVisibility: Visibility
    let actions: Actions
    let message: Message

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if !os(tvOS)
            // use alert on iPadOS to prevent anchoring to the side of a sheet
            if isPad {
                content
                    .alert(
                        titleVisibility == .hidden ? "" : title,
                        isPresented: $isPresented,
                    ) {
                        actions
                    } message: {
                        message
                    }
            } else {
                // use a normal confirmationDialog otherwise
                content
                    .confirmationDialog(
                        title,
                        isPresented: $isPresented,
                        titleVisibility: titleVisibility
                    ) {
                        actions
                    } message: {
                        message
                    }
            }
        #else
            // use confirmationDialog on tvos ? ( can be changed easily )
            content
                .confirmationDialog(
                    title,
                    isPresented: $isPresented,
                    titleVisibility: titleVisibility
                ) {
                    actions
                } message: {
                    message
                }
        #endif
    }
}

extension View {
    func adaptiveConfirmationDialog<Actions: View, Message: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder message: () -> Message
    ) -> some View {
        modifier(
            AdaptiveConfirmationDialog(
                title: title,
                isPresented: isPresented,
                titleVisibility: titleVisibility ?? .visible,
                actions: actions(),
                message: message()
            )
        )
    }
}
