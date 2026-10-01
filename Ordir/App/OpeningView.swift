//
//  OpeningView.swift
//  Ordir
//
//  The launch animation: the orb rises in with its sparkles twinkling, then the name and tagline.
//  About 1.5 s, or a quick fade with Reduce Motion. A tap skips it.
//

import SwiftUI

struct OpeningView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsOrb = false
    @State private var showsTitle = false

    var body: some View {
        VStack(spacing: 8) {
            OrdirMascotView()
                .frame(height: 128)
                .scaleEffect(showsOrb || reduceMotion ? 1 : 0.8)
                .offset(y: showsOrb || reduceMotion ? 0 : 10)
                .blur(radius: showsOrb || reduceMotion ? 0 : 6)
                .opacity(showsOrb ? 1 : 0)
                .padding(.bottom, 16)
            VStack(spacing: 8) {
                Text("Ordir")
                    .font(.system(.largeTitle, weight: .bold))
                Text("Learn any turn, step by step.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .offset(y: showsTitle || reduceMotion ? 0 : 16)
            .opacity(showsTitle ? 1 : 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ordir. Learn any turn, step by step.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Skips the opening.")
        .accessibilityAction { onFinish() }
        .task {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.3)) { showsOrb = true; showsTitle = true }
                try? await Task.sleep(for: .seconds(0.9))
            } else {
                withAnimation(.spring(duration: 0.8, bounce: 0.2)) { showsOrb = true }
                try? await Task.sleep(for: .seconds(0.45))
                withAnimation(.spring(duration: 0.6, bounce: 0.1)) { showsTitle = true }
                try? await Task.sleep(for: .seconds(1.1))
            }
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }
}

#Preview {
    OpeningView {}
}
