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
    /// When the opening's line reaches Home's orb and builds it (nil: no opening, or Reduce Motion).
    @State private var orbBuildStart: Date?
    /// Home's header orb while Home waits one screen down: where the opening's line ends.
    @State private var homeOrb: CGRect?

    init() {
        OrdirFont.register()
        if UserDefaults.standard.string(forKey: "OrdirOpenGame") == nil && !UIAccessibility.isReduceMotionEnabled {
            _orbBuildStart = State(initialValue: Date().addingTimeInterval(OpeningView.buildDelay))
        }
    }

    var body: some Scene {
        WindowGroup {
            GeometryReader { screen in
                // Home rises from one screen down as the opening's view glides down to it.
                let moves = showsOpening && !UIAccessibility.isReduceMotionEnabled
                TimelineView(.animation(paused: !moves)) { timeline in
                    let camera = OpeningView.camera(at: timeline.date.timeIntervalSince(openingStart))
                    HomeView(orbBuildStart: orbBuildStart) { frame in if homeOrb == nil { homeOrb = frame } }
                        .offset(y: moves ? screen.size.height * (1 - camera) : 0)
                }
            }
            .accessibilityHidden(showsOpening)
            .overlay {
                if showsOpening {
                    GeometryReader { proxy in
                        let origin = proxy.frame(in: .global).origin
                        OpeningView(start: openingStart, target: homeOrb?.offsetBy(dx: -origin.x, dy: -origin.y)) {
                            // Skipped early: build the orb now rather than when the line would have arrived.
                            if let start = orbBuildStart, start > .now { orbBuildStart = .now }
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
