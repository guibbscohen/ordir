//
//  OpeningView.swift
//  Ordir
//
//  The launch animation (~3 s), the same camera move as the browser preview's, inspired by Ripplix's
//  "Happier" splash:
//  - The orb and name sit on black, above a deep blue and violet glow.
//  - A glowing line draws itself from the orb down the screen.
//  - The view glides down through the glow to Home, which waits one screen below (OrdirApp slides it up
//    with `camera(at:)`), and the line ends at Home's orb (`target`).
//  A tap skips it; Reduce Motion shows the orb and name, then fades to Home.
//

import SwiftUI

struct OpeningView: View {
    /// When the opening started; OrdirApp moves Home with the same clock.
    let start: Date
    /// Home's header orb as it sits one screen down, in this view's coordinates; the line ends there.
    let target: CGRect?
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let length = 3.15
    private static let orbHeight: CGFloat = 88
    private static let violet = Color(red: 0.49, green: 0.36, blue: 1)
    private static let deepBlue = Color(red: 0.15, green: 0.33, blue: 0.84)

    /// How far the view has moved down, 0 (opening) to 1 (Home), `t` seconds in.
    static func camera(at t: Double) -> Double {
        easeInOutCubic((t - 1.3) / 1.6)
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 1 : timeline.date.timeIntervalSince(start)
                track(t: t, size: proxy.size)
                    .offset(y: reduceMotion ? 0 : -proxy.size.height * Self.camera(at: t))
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
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.9 : Self.length))
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }

    /// Two screens tall: the opening on top, Home's place below (left clear so Home shows through).
    private func track(t: Double, size: CGSize) -> some View {
        let orb = CGPoint(x: size.width / 2, y: size.height * 0.45)
        let appear = Self.smooth(t / 0.8)
        return ZStack(alignment: .topLeading) {
            Color.black.frame(width: size.width, height: size.height)

            if !reduceMotion {
                glow(size: size)
                    .opacity(Self.smooth(t / 1.2) * (1 - Self.smooth((t - 2.5) / 0.5)))
                line(from: CGPoint(x: orb.x + 40, y: orb.y + 10), size: size)
                    .trim(from: 0, to: Self.smooth((t - 0.6) / 2))
                    .stroke(Color.ordirSparkle, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .shadow(color: Color.ordirSparkle.opacity(0.9), radius: 3)
                    .shadow(color: Self.violet.opacity(0.7), radius: 10)
                    .opacity(1 - Self.smooth((t - 2.75) / 0.35))
            }

            OrdirMascotView()
                .frame(height: Self.orbHeight)
                .scaleEffect(reduceMotion ? 1 : 0.8 + 0.2 * appear)
                .blur(radius: reduceMotion ? 0 : 6 * (1 - appear))
                .opacity(reduceMotion ? 1 : Self.smooth(t / 0.6))
                .position(orb)

            VStack(spacing: 6) {
                Text("Ordir")
                    .font(.ordir(.title).weight(.semibold))
                    .opacity(reduceMotion ? 1 : Self.smooth((t - 0.4) / 0.6))
                    .offset(y: reduceMotion ? 0 : 16 * (1 - Self.smooth((t - 0.4) / 0.6)))
                Text("Learn any turn, step by step.")
                    .font(.ordir(.subheadline))
                    .foregroundStyle(.secondary)
                    .opacity(reduceMotion ? 1 : Self.smooth((t - 0.55) / 0.6))
                    .offset(y: reduceMotion ? 0 : 16 * (1 - Self.smooth((t - 0.55) / 0.6)))
            }
            .multilineTextAlignment(.center)
            .position(x: orb.x, y: orb.y + Self.orbHeight / 2 + 48)
        }
        .frame(width: size.width, height: size.height * 2, alignment: .topLeading)
    }

    /// Violet and blue light around the boundary between the opening and Home.
    private func glow(size: CGSize) -> some View {
        ZStack {
            RadialGradient(colors: [Self.violet.opacity(0.5), .clear], center: UnitPoint(x: 0.32, y: 0.48),
                           startRadius: 0, endRadius: size.width * 0.65)
            RadialGradient(colors: [Self.deepBlue.opacity(0.55), .clear], center: UnitPoint(x: 0.7, y: 0.56),
                           startRadius: 0, endRadius: size.width * 0.7)
            RadialGradient(colors: [Color.ordirSparkle.opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 0.66),
                           startRadius: 0, endRadius: size.width * 0.5)
        }
        .frame(width: size.width * 1.6, height: size.height * 0.84)
        .position(x: size.width / 2, y: size.height * 0.86)
        .allowsHitTesting(false)
    }

    /// From the orb, out to the right and down across the boundary, then into Home's orb from the right.
    private func line(from start: CGPoint, size: CGSize) -> Path {
        let w = size.width, h = size.height
        let end = target.map { CGPoint(x: $0.maxX + 2, y: $0.minY + $0.height * 0.55) } ?? CGPoint(x: w * 0.2, y: h * 1.08)
        let middle = CGPoint(x: w * 0.62, y: h * 0.9)
        let bend = CGPoint(x: w * 0.98, y: h * 0.72)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: middle, control1: CGPoint(x: w * 0.95, y: start.y + h * 0.14), control2: bend)
        // Mirror the last control point so the two curves join smoothly.
        path.addCurve(to: end, control1: CGPoint(x: 2 * middle.x - bend.x, y: 2 * middle.y - bend.y),
                      control2: CGPoint(x: end.x + w * 0.35, y: end.y + h * 0.02))
        return path
    }

    /// Smoothstep on 0...1, clamped.
    private static func smooth(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x * x * (3 - 2 * x)
    }

    private static func easeInOutCubic(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}

#Preview {
    OpeningView(start: .now, target: nil) {}
}
