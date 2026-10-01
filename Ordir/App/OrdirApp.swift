//
//  OrdirApp.swift
//  Ordir
//

import SwiftUI

@main
struct OrdirApp: App {
    // The opening plays once per launch. CI and the UI tests open a game directly with
    // `-OrdirOpenGame`, so they skip it.
    @State private var showsOpening = UserDefaults.standard.string(forKey: "OrdirOpenGame") == nil
    /// Home's header orb on screen, where the opening's orb lands.
    @State private var homeOrb: CGRect?

    init() {
        OrdirFont.register()
    }

    var body: some Scene {
        WindowGroup {
            HomeView(hidesOrb: showsOpening) { homeOrb = $0 }
                .accessibilityHidden(showsOpening)
                .overlay {
                    if showsOpening {
                        GeometryReader { proxy in
                            let origin = proxy.frame(in: .global).origin
                            OpeningView(target: homeOrb?.offsetBy(dx: -origin.x, dy: -origin.y)) {
                                withAnimation(.easeOut(duration: 0.25)) { showsOpening = false }
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
