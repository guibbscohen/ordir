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

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .accessibilityHidden(showsOpening)
                if showsOpening {
                    OpeningView {
                        withAnimation(.easeOut(duration: 0.35)) { showsOpening = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
