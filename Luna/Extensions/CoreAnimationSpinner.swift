//
//  CoreAnimationSpinner.swift
//  Luna
//
//  A UIKit-backed activity indicator that continues animating via CoreAnimation
//  even if SwiftUI view updates are stalled.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// UIKit/CoreAnimation-backed spinner.
///
/// Notes:
/// - Still won’t animate if the main thread is *completely* hung.
/// - But it avoids SwiftUI-only timing mechanisms and generally stays smoother
///   during short stalls.
struct CoreAnimationSpinner: UIViewRepresentable {
    var style: UIActivityIndicatorView.Style = .large
    var color: UIColor = .white
    var isAnimating: Bool = true

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: style)
        view.hidesWhenStopped = true
        view.color = color

        if isAnimating {
            view.startAnimating()
        }

        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.style = style
        uiView.color = color

        if isAnimating {
            if uiView.isAnimating == false {
                uiView.startAnimating()
            }
        } else {
            uiView.stopAnimating()
        }
    }
}
#else

/// Fallback for platforms without UIKit (keeps the build green).
struct CoreAnimationSpinner: View {
    var isAnimating: Bool = true

    var body: some View {
        if isAnimating {
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}
#endif

#Preview("CoreAnimationSpinner") {
    ZStack {
        Color.black.ignoresSafeArea()
#if canImport(UIKit)
        CoreAnimationSpinner(style: .large, color: .white, isAnimating: true)
#else
        CoreAnimationSpinner(isAnimating: true)
#endif
    }
}
