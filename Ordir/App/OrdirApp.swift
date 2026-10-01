//
//  OrdirApp.swift
//  Ordir
//

import SwiftUI
import UIKit

@main
struct OrdirApp: App {
    // The opening plays once per launch. CI and the UI tests open a game directly with
    // `-OrdirOpenGame`, so they skip it.
    @State private var showsOpening = UserDefaults.standard.string(forKey: "OrdirOpenGame") == nil
    @State private var openingStart = Date()
    /// Home's header orb while Home waits one screen down: where the opening's line ends.
    @State private var homeOrb: CGRect?

    init() {
        OrdirFont.register()
    }

    var body: some Scene {
        WindowGroup {
            GeometryReader { screen in
                // Home rises from one screen down as the opening's view glides down to it.
                let moves = showsOpening && !UIAccessibility.isReduceMotionEnabled
                TimelineView(.animation(paused: !moves)) { timeline in
                    let camera = OpeningView.camera(at: timeline.date.timeIntervalSince(openingStart))
                    HomeView { frame in if homeOrb == nil { homeOrb = frame } }
                        .offset(y: moves ? screen.size.height * (1 - camera) : 0)
                }
            }
            .accessibilityHidden(showsOpening)
            .overlay {
                if showsOpening {
                    GeometryReader { proxy in
                        let origin = proxy.frame(in: .global).origin
                        OpeningView(start: openingStart, target: homeOrb?.offsetBy(dx: -origin.x, dy: -origin.y)) {
                            withAnimation(.easeOut(duration: 0.3)) { showsOpening = false }
                        }
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .font(.ordir(.body))
        }
    }
}
