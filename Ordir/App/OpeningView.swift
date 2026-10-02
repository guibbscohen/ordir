//
//  OpeningView.swift
//  Ordir
//
//  The launch animation (~5 s: the logo rests 1.5 s, then the move), the same camera move as the browser
//  preview's, inspired by Ripplix's "Happier" splash:
//  - The orb and name sit on black, above a deep blue and violet glow that flows on into Home's own.
//  - A glowing line draws itself from the orb down the screen.
//  - The view glides down through the glow to Home, which waits one screen below (OrdirApp slides it up
//    with `camera(at:)`). The line drops into Home's orb (`target`) from above, runs round its rim, the orb
//    is built under it (`buildDelay`), and the line fades.
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

    /// How long the logo rests before the line starts and the camera moves.
    static let hold = 1.5
    static let length = hold + 3.55
    /// When Home's orb starts being built: as the line runs round its rim.
    static let buildDelay = hold + 3.08
    private static let orbHeight: CGFloat = 88
    private static let violet = Color(red: 0.49, green: 0.36, blue: 1)
    private static let deepBlue = Color(red: 0.15, green: 0.33, blue: 0.84)

    /// How far the view has moved down, 0 (opening) to 1 (Home), `t` seconds in.
    static func camera(at t: Double) -> Double {
        easeInOutCubic((t - hold - 1.3) / 1.6)
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
        .accessibilityLabel(tr("Ordir. Learn any turn, step by step."))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(tr("Skips the opening."))
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
            backdrop(size: size)

            if !reduceMotion {
                let rimLine = rim()
                ZStack(alignment: .topLeading) {
                    approach(from: CGPoint(x: orb.x + 40, y: orb.y + 10), to: rimLine?.start, size: size)
                        .trim(from: 0, to: Self.smooth((t - Self.hold - 0.6) / 2.3))
                        .stroke(Color.ordirSparkle, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    if let rimLine {
                        rimLine.path
                            .trim(from: 0, to: Self.smooth((t - Self.hold - 2.9) / 0.3))
                            .stroke(Color.ordirSparkle, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                }
                .shadow(color: Color.ordirSparkle.opacity(0.9), radius: 3)
                .shadow(color: Self.violet.opacity(0.7), radius: 10)
                .opacity(1 - Self.smooth((t - Self.hold - 3.25) / 0.3))
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
                Text(tr("Learn any turn, step by step."))
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

    /// The opening's screen of the two-screen world: black, with Home's light centred on the boundary below
    /// (so it continues into Home's own background with no edge; same centres and radii as HomeView's
    /// ambience), and the opening's violet and blue light lower down, which fades out above the boundary.
    private func backdrop(size: CGSize) -> some View {
        let w = size.width
        return ZStack {
            Color.black
            RadialGradient(colors: [Self.violet.opacity(0.30), .clear], center: UnitPoint(x: 0.18, y: 1),
                           startRadius: 0, endRadius: w * 0.75)
            RadialGradient(colors: [Self.deepBlue.opacity(0.32), .clear], center: UnitPoint(x: 0.88, y: 1.06),
                           startRadius: 0, endRadius: w * 0.72)
            RadialGradient(colors: [Self.violet.opacity(0.42), .clear], center: UnitPoint(x: 0.3, y: 0.74),
                           startRadius: 0, endRadius: w * 0.45)
            RadialGradient(colors: [Self.deepBlue.opacity(0.48), .clear], center: UnitPoint(x: 0.72, y: 0.72),
                           startRadius: 0, endRadius: w * 0.45)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    /// From the opening's orb, out to the right and down across the boundary, then over Home's header, dropping
    /// into Home's orb from above so it arrives heading down its right side, clear of "Ordir".
    private func approach(from start: CGPoint, to end: CGPoint?, size: CGSize) -> Path {
        let w = size.width, h = size.height
        let end = end ?? CGPoint(x: w * 0.2, y: h * 1.08)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.9),
                      control1: CGPoint(x: w * 0.95, y: start.y + h * 0.15), control2: CGPoint(x: w * 0.95, y: h * 0.75))
        path.addCurve(to: end, control1: CGPoint(x: w * 0.35, y: h * 1.0), control2: CGPoint(x: end.x, y: end.y - h * 0.14))
        return path
    }

    /// Home's orb rim, which the line carries on round: clockwise from the rim's right side to the gap under
    /// the big sparkle, along the middle of the rim (OrdirMascotGeometry coordinates, as the preview's ORB_RIM).
    private func rim() -> (path: Path, start: CGPoint)? {
        guard let target else { return nil }
        let box = OrdirMascotGeometry.viewBox
        let unit = target.height / box.height
        let center = CGPoint(x: target.minX + (OrdirMascotGeometry.orbCenter.x - box.minX) * unit,
                             y: target.minY + (OrdirMascotGeometry.orbCenter.y - box.minY) * unit)
        let radius = 105 * unit
        let start = CGPoint(x: center.x + radius * cos(3 * .pi / 180), y: center.y + radius * sin(3 * .pi / 180))
        var path = Path()
        // Angles grow clockwise on screen (y points down); `clockwise: false` means growing angles.
        path.addArc(center: center, radius: radius, startAngle: .degrees(3), endAngle: .degrees(286), clockwise: false)
        return (path, start)
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
