//
//  OpeningView.swift
//  Ordir
//
//  The launch animation (~3 s), the same as the browser preview's:
//  - On black, a deep blue and violet glow rises.
//  - A glowing ribbon travels out of the orb, loops across the screen and leaves toward the top-left.
//  - The glow settles to black and the orb glides into Home's header (`target`) as the backdrop clears.
//  A tap skips it; Reduce Motion shows the orb and name with a short fade, then Home.
//

import SwiftUI

struct OpeningView: View {
    /// Where Home's header orb is, in this view's coordinates; the orb lands there.
    let target: CGRect?
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private static let orbHeight: CGFloat = 88
    private static let landingStart = 2.3
    private static let landingLength = 0.7
    private static let violet = Color(red: 0.49, green: 0.36, blue: 1)
    private static let deepBlue = Color(red: 0.15, green: 0.33, blue: 0.84)

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0.3 : timeline.date.timeIntervalSince(start)
                content(t: t, size: proxy.size)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ordir. Learn any turn, step by step.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Skips the opening.")
        .accessibilityAction { onFinish() }
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.9 : Self.landingStart + Self.landingLength + 0.05))
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }

    private func content(t: Double, size: CGSize) -> some View {
        let landing = ease((t - Self.landingStart) / Self.landingLength)
        let fadeOut = 1 - min(1, max(0, (t - Self.landingStart) / 0.18))
        let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
        let destination = target.map { CGPoint(x: $0.midX, y: $0.midY) } ?? center
        let scale = target.map { $0.height / Self.orbHeight } ?? 1

        return ZStack {
            Color.black.opacity(1 - landing)

            if !reduceMotion {
                glow(t: t, size: size).opacity(fadeOut)
                ribbon(t: t, size: size).opacity(fadeOut)
            }

            OrdirMascotView()
                .frame(height: Self.orbHeight)
                .scaleEffect(reduceMotion ? 1 : (0.8 + 0.2 * ease(t / 0.8)) * (1 + (scale - 1) * landing))
                .blur(radius: reduceMotion ? 0 : 6 * (1 - ease(t / 0.8)))
                .opacity(reduceMotion ? 1 : ease(t / 0.6))
                .position(x: center.x + (destination.x - center.x) * landing,
                          y: center.y + (destination.y - center.y) * landing)

            VStack(spacing: 6) {
                Text("Ordir")
                    .font(.ordir(.title).weight(.semibold))
                    .opacity(reduceMotion ? 1 : ease((t - 0.4) / 0.6))
                    .offset(y: reduceMotion ? 0 : 16 * (1 - ease((t - 0.4) / 0.6)))
                Text("Learn any turn, step by step.")
                    .font(.ordir(.subheadline))
                    .foregroundStyle(.secondary)
                    .opacity(reduceMotion ? 1 : ease((t - 0.55) / 0.6))
                    .offset(y: reduceMotion ? 0 : 16 * (1 - ease((t - 0.55) / 0.6)))
            }
            .multilineTextAlignment(.center)
            .opacity(fadeOut)
            .position(x: center.x, y: center.y + Self.orbHeight / 2 + 48)
        }
    }

    /// Violet and blue light that rises from below and fades as it passes.
    private func glow(t: Double, size: CGSize) -> some View {
        let opacity = t < 0.8 ? ease(t / 0.8) : 1 - ease((t - 0.8) / 1.9)
        let rise = 0.35 - 1.1 * ease(t / 2.7)
        return ZStack {
            RadialGradient(colors: [Self.violet.opacity(0.55), .clear], center: UnitPoint(x: 0.3, y: 0.62),
                           startRadius: 0, endRadius: size.width * 0.7)
            RadialGradient(colors: [Self.deepBlue.opacity(0.6), .clear], center: UnitPoint(x: 0.72, y: 0.7),
                           startRadius: 0, endRadius: size.width * 0.75)
            RadialGradient(colors: [Color.ordirSparkle.opacity(0.32), .clear], center: UnitPoint(x: 0.5, y: 0.82),
                           startRadius: 0, endRadius: size.width * 0.6)
        }
        .offset(y: size.height * rise)
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    /// A short glowing stretch of line travelling along `Self.route`.
    private func ribbon(t: Double, size: CGSize) -> some View {
        let head = -0.32 + 1.37 * ease((t - 0.55) / 1.75)
        return Self.route(in: size)
            .trim(from: min(1, max(0, head)), to: min(1, max(0, head + 0.32)))
            .stroke(Color.ordirSparkle, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .shadow(color: Color.ordirSparkle.opacity(0.9), radius: 3)
            .shadow(color: Self.violet.opacity(0.7), radius: 10)
            .allowsHitTesting(false)
    }

    /// The ribbon's route in a 100 × 200 box stretched over the screen: out of the orb, three loops,
    /// then away toward the top-left corner, where the orb lands. Matches the preview's `RIBBON`.
    private static func route(in size: CGSize) -> Path {
        let sx = size.width / 100, sy = size.height / 200
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        let curves: [(CGPoint, CGPoint, CGPoint)] = [
            (p(62, 78), p(80, 72), p(84, 58)), (p(89, 40), p(70, 26), p(52, 32)),
            (p(30, 40), p(22, 68), p(30, 98)), (p(38, 130), p(70, 138), p(78, 116)),
            (p(86, 94), p(60, 84), p(40, 102)), (p(22, 120), p(14, 150), p(30, 170)),
            (p(46, 190), p(80, 172), p(74, 140)), (p(68, 108), p(24, 72), p(18, 42)),
            (p(14, 22), p(12, 10), p(10, -6)),
        ]
        var path = Path()
        path.move(to: p(50, 84))
        for (c1, c2, end) in curves { path.addCurve(to: end, control1: c1, control2: c2) }
        return path
    }

    /// Smoothstep on 0...1, clamped.
    private func ease(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x * x * (3 - 2 * x)
    }
}

#Preview {
    OpeningView(target: nil) {}
}
