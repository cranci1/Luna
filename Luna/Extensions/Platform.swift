//
//  Platform.swift
//  Luna
//
//  Created by Dominic on 02.11.25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func tvos<Content: View, ElseContent: View>(
        _ transform: (Self) -> Content,
        else elseTransform: (Self) -> ElseContent
    ) -> some View {
        #if os(tvOS)
            transform(self)
        #else
            elseTransform(self)
        #endif
    }

    @ViewBuilder
    func tvos<Content: View>(
        _ transform: (Self) -> Content
    ) -> some View {
        #if os(tvOS)
            transform(self)
        #endif
    }

    var isTvOS: Bool {
        #if os(tvOS)
            true
        #else
            false
        #endif
    }
}
