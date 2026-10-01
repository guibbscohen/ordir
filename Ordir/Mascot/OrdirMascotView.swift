//
//  OrdirMascotView.swift
//  Ordir
//
//  The Ordir crystal-ball mascot, drawn natively with `Canvas` and animated
//  procedurally from a single `TimelineView` clock.
//
//  Geometry in `OrdirMascotGeometry` is generated from `Assets/ordir-logo.svg` by
//  `tools/svg_to_swift.py`; regenerate it there if the logo changes.
//

import SwiftUI

// MARK: - Public view

/// Ordir's animated mascot.
///
/// Drive it from a parent with plain state:
/// ```swift
/// @State private var isSpeaking = false
/// @State private var isThinking = false
///
/// OrdirMascotView(isSpeaking: isSpeaking, isThinking: isThinking)
///     .frame(width: 96, height: 96)
/// ```
/// When both flags are true, speaking wins (Ordir is already answering).
struct OrdirMascotView: View {
    var isSpeaking: Bool
    var isThinking: Bool
    var sparkleColor: Color
    /// When set, the orb is built from that moment: it fills in, the sparkles pop and the face appears
    /// (Home's orb, as the opening's line closes round its rim). Hidden until then.
    var buildStart: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transition = ModeTransition(from: .idle, start: .distantPast)

    init(isSpeaking: Bool = false, isThinking: Bool = false, sparkleColor: Color = .ordirSparkle, buildStart: Date? = nil) {
        self.isSpeaking = isSpeaking
        self.isThinking = isThinking
        self.sparkleColor = sparkleColor
        self.buildStart = buildStart
    }

    private var mode: OrdirMascotMode {
        if isSpeaking { return .speaking }
        if isThinking { return .thinking }
        return .idle
    }

    var body: some View {
        // Idle with Reduce Motion on is fully static (and never built), so stop the clock entirely.
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion && mode == .idle)) { timeline in
            let frame = MascotFrame.blended(
                transition: transition,
                to: mode,
                at: timeline.date,
                reduceMotion: reduceMotion
            )
            let build = MascotBuild(time: reduceMotion ? nil : buildStart.map { timeline.date.timeIntervalSince($0) })
            Canvas { context, size in
                OrdirMascotRenderer.draw(frame, build: build, in: &context, size: size, sparkleColor: sparkleColor)
            }
        }
        .aspectRatio(OrdirMascotGeometry.viewBox.width / OrdirMascotGeometry.viewBox.height, contentMode: .fit)
        .onChange(of: mode) { oldMode, _ in
            transition = ModeTransition(from: oldMode, start: .now)
        }
        .accessibilityElement()
        .accessibilityLabel("Ordir")
        .accessibilityValue(mode.accessibilityValue)
    }
}

extension Color {
    /// Sparkle tint from the asset catalog, with light and dark variants for contrast.
    static let ordirSparkle = Color("Sparkle")
}

// MARK: - State

enum OrdirMascotMode: Equatable {
    case idle, speaking, thinking

    var accessibilityValue: String {
        switch self {
        case .idle: "Waiting"
        case .speaking: "Speaking"
        case .thinking: "Thinking"
        }
    }
}

/// Remembers the previous mode so the clock can cross-fade between procedural states.
private struct ModeTransition {
    var from: OrdirMascotMode
    var start: Date
    static let duration: TimeInterval = 0.45
}

// MARK: - Geometry (generated from Assets/ordir-logo.svg by tools/svg_to_swift.py)

enum OrdirMascotGeometry {
    /// Region of the SVG's coordinate space the mascot draws into. Padded beyond the artwork so the
    /// outer sparkle can grow to 1.2× and glow without clipping.
    static let viewBox = CGRect(x: 20, y: 25, width: 285, height: 300)

    /// Inside of the crystal ball, used for the speaking glow.
    static let orbCenter = CGPoint(x: 154.174, y: 157.466)
    static let orbInnerRadius: CGFloat = 94.5

    struct Sparkle {
        var center: CGPoint
        var size: CGFloat  // larger side of the bounding box, sizes the halo
        var path: Path     // centred on the origin
    }

    // In animation order: main outer, medium inner, tiny inner. The medium and tiny sparkles sit
    // (+4, -46) and (-70, +20) from the logo's positions, clear of the face; the preview matches.
    static let sparkles: [Sparkle] = [
        Sparkle(center: CGPoint(x: 225.988, y: 104.436), size: 123.0, path: outerSparkle),
        Sparkle(center: CGPoint(x: 120.634, y: 105.687), size: 63.8, path: mediumSparkle),
        Sparkle(center: CGPoint(x: 101.092, y: 215.885), size: 34.4, path: tinySparkle),
    ]

    /// The face: two dot eyes and a one-line smile (a quadratic curve), drawn in the foreground colour.
    /// It's turned slightly up and to the right, so the far eye is smaller.
    static let eyes: [(center: CGPoint, radius: CGFloat)] = [
        (CGPoint(x: 148.715, y: 146.465), 10.5),
        (CGPoint(x: 189.715, y: 143.465), 8.5),
    ]
    static let mouthStart = CGPoint(x: 156.715, y: 173.465)
    static let mouthControl = CGPoint(x: 175.715, y: 186.465)
    static let mouthEnd = CGPoint(x: 192.715, y: 168.465)
    static let mouthWidth: CGFloat = 8

    // outerSparkle: centre (225.988, 104.436), size 123.0×116.0
    static let outerSparkle: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 48.955, y: -13.347))
        p.addLine(to: CGPoint(x: 29.484, y: -20.272))
        p.addCurve(to: CGPoint(x: 21.018, y: -28.468), control1: CGPoint(x: 25.528, y: -21.689), control2: CGPoint(x: 22.566, y: -24.655))
        p.addLine(to: CGPoint(x: 13.121, y: -48.952))
        p.addCurve(to: CGPoint(x: -0.001, y: -57.996), control1: CGPoint(x: 10.727, y: -55.030), control2: CGPoint(x: 5.356, y: -57.996))
        p.addCurve(to: CGPoint(x: -13.123, y: -48.952), control1: CGPoint(x: -5.358, y: -57.996), control2: CGPoint(x: -10.861, y: -55.030))
        p.addLine(to: CGPoint(x: -21.019, y: -28.468))
        p.addCurve(to: CGPoint(x: -29.484, y: -20.272), control1: CGPoint(x: -22.567, y: -24.655), control2: CGPoint(x: -25.530, y: -21.689))
        p.addLine(to: CGPoint(x: -48.956, y: -13.347))
        p.addCurve(to: CGPoint(x: -48.956, y: 13.347), control1: CGPoint(x: -61.508, y: -8.964), control2: CGPoint(x: -61.508, y: 8.832))
        p.addLine(to: CGPoint(x: -29.484, y: 20.273))
        p.addCurve(to: CGPoint(x: -21.019, y: 28.469), control1: CGPoint(x: -25.530, y: 21.689), control2: CGPoint(x: -22.567, y: 24.655))
        p.addLine(to: CGPoint(x: -13.123, y: 48.953))
        p.addCurve(to: CGPoint(x: -0.001, y: 57.996), control1: CGPoint(x: -10.728, y: 55.030), control2: CGPoint(x: -5.358, y: 57.996))
        p.addCurve(to: CGPoint(x: 13.121, y: 48.953), control1: CGPoint(x: 5.356, y: 57.996), control2: CGPoint(x: 10.859, y: 55.030))
        p.addLine(to: CGPoint(x: 21.018, y: 28.469))
        p.addCurve(to: CGPoint(x: 29.484, y: 20.273), control1: CGPoint(x: 22.566, y: 24.655), control2: CGPoint(x: 25.528, y: 21.689))
        p.addLine(to: CGPoint(x: 48.955, y: 13.347))
        p.addCurve(to: CGPoint(x: 48.955, y: -13.347), control1: CGPoint(x: 61.508, y: 8.964), control2: CGPoint(x: 61.508, y: -8.832))
        p.closeSubpath()
        p.move(to: CGPoint(x: 22.288, y: 0.212))
        p.addCurve(to: CGPoint(x: 1.123, y: 20.696), control1: CGPoint(x: 12.552, y: 3.602), control2: CGPoint(x: 4.933, y: 11.082))
        p.addLine(to: CGPoint(x: -0.292, y: 24.232))
        p.addLine(to: CGPoint(x: -1.707, y: 20.696))
        p.addCurve(to: CGPoint(x: -22.871, y: 0.212), control1: CGPoint(x: -5.371, y: 11.096), control2: CGPoint(x: -13.136, y: 3.602))
        p.addLine(to: CGPoint(x: -23.573, y: -0.066))
        p.addLine(to: CGPoint(x: -22.871, y: -0.344))
        p.addCurve(to: CGPoint(x: -1.707, y: -20.828), control1: CGPoint(x: -13.136, y: -3.734), control2: CGPoint(x: -5.517, y: -11.215))
        p.addLine(to: CGPoint(x: -0.292, y: -24.363))
        p.addLine(to: CGPoint(x: 1.123, y: -20.828))
        p.addCurve(to: CGPoint(x: 22.288, y: -0.344), control1: CGPoint(x: 4.787, y: -11.228), control2: CGPoint(x: 12.552, y: -3.734))
        p.addLine(to: CGPoint(x: 22.989, y: -0.066))
        p.closeSubpath()
        return p
    }()

    // tinySparkle: centre (171.092, 195.885), size 34.4×32.0
    static let tinySparkle: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -13.677, y: -3.674))
        p.addCurve(to: CGPoint(x: -13.677, y: 3.674), control1: CGPoint(x: -17.209, y: -2.403), control2: CGPoint(x: -17.209, y: 2.404))
        p.addLine(to: CGPoint(x: -8.320, y: 5.515))
        p.addCurve(to: CGPoint(x: -5.926, y: 7.779), control1: CGPoint(x: -7.195, y: 5.938), control2: CGPoint(x: -6.349, y: 6.786))
        p.addLine(to: CGPoint(x: -3.664, y: 13.433))
        p.addCurve(to: CGPoint(x: 0.000, y: 15.976), control1: CGPoint(x: -2.963, y: 15.128), control2: CGPoint(x: -1.547, y: 15.976))
        p.addCurve(to: CGPoint(x: 3.664, y: 13.433), control1: CGPoint(x: 1.548, y: 15.976), control2: CGPoint(x: 2.963, y: 15.128))
        p.addLine(to: CGPoint(x: 5.926, y: 7.779))
        p.addCurve(to: CGPoint(x: 8.320, y: 5.515), control1: CGPoint(x: 6.349, y: 6.654), control2: CGPoint(x: 7.196, y: 5.938))
        p.addLine(to: CGPoint(x: 13.677, y: 3.674))
        p.addCurve(to: CGPoint(x: 13.677, y: -3.674), control1: CGPoint(x: 17.209, y: 2.404), control2: CGPoint(x: 17.209, y: -2.403))
        p.addLine(to: CGPoint(x: 8.320, y: -5.515))
        p.addCurve(to: CGPoint(x: 5.926, y: -7.779), control1: CGPoint(x: 7.196, y: -5.938), control2: CGPoint(x: 6.349, y: -6.786))
        p.addLine(to: CGPoint(x: 3.664, y: -13.433))
        p.addCurve(to: CGPoint(x: 0.000, y: -15.976), control1: CGPoint(x: 2.963, y: -15.128), control2: CGPoint(x: 1.548, y: -15.976))
        p.addCurve(to: CGPoint(x: -3.664, y: -13.433), control1: CGPoint(x: -1.547, y: -15.976), control2: CGPoint(x: -2.963, y: -15.128))
        p.addLine(to: CGPoint(x: -5.926, y: -7.779))
        p.addCurve(to: CGPoint(x: -8.320, y: -5.515), control1: CGPoint(x: -6.349, y: -6.653), control2: CGPoint(x: -7.195, y: -5.938))
        p.closeSubpath()
        return p
    }()

    // mediumSparkle: centre (116.634, 151.687), size 63.8×59.9
    static let mediumSparkle: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 15.238, y: -10.454))
        p.addCurve(to: CGPoint(x: 10.860, y: -14.691), control1: CGPoint(x: 13.268, y: -11.155), control2: CGPoint(x: 11.574, y: -12.718))
        p.addLine(to: CGPoint(x: 6.773, y: -25.284))
        p.addCurve(to: CGPoint(x: 0.000, y: -29.944), control1: CGPoint(x: 5.503, y: -28.396), control2: CGPoint(x: 2.818, y: -29.944))
        p.addCurve(to: CGPoint(x: -6.772, y: -25.284), control1: CGPoint(x: -2.817, y: -29.944), control2: CGPoint(x: -5.648, y: -28.396))
        p.addLine(to: CGPoint(x: -10.860, y: -14.691))
        p.addCurve(to: CGPoint(x: -15.238, y: -10.454), control1: CGPoint(x: -11.561, y: -12.718), control2: CGPoint(x: -13.254, y: -11.155))
        p.addLine(to: CGPoint(x: -25.397, y: -6.918))
        p.addCurve(to: CGPoint(x: -25.397, y: 6.918), control1: CGPoint(x: -31.892, y: -4.654), control2: CGPoint(x: -31.892, y: 4.522))
        p.addLine(to: CGPoint(x: -15.238, y: 10.454))
        p.addCurve(to: CGPoint(x: -10.860, y: 14.691), control1: CGPoint(x: -13.267, y: 11.155), control2: CGPoint(x: -11.574, y: 12.718))
        p.addLine(to: CGPoint(x: -6.772, y: 25.284))
        p.addCurve(to: CGPoint(x: 0.000, y: 29.944), control1: CGPoint(x: -5.503, y: 28.396), control2: CGPoint(x: -2.817, y: 29.944))
        p.addCurve(to: CGPoint(x: 6.773, y: 25.284), control1: CGPoint(x: 2.818, y: 29.944), control2: CGPoint(x: 5.648, y: 28.396))
        p.addLine(to: CGPoint(x: 10.860, y: 14.691))
        p.addCurve(to: CGPoint(x: 15.238, y: 10.454), control1: CGPoint(x: 11.561, y: 12.718), control2: CGPoint(x: 13.254, y: 11.155))
        p.addLine(to: CGPoint(x: 25.397, y: 6.918))
        p.addCurve(to: CGPoint(x: 25.397, y: -6.918), control1: CGPoint(x: 31.892, y: 4.654), control2: CGPoint(x: 31.892, y: -4.522))
        p.closeSubpath()
        return p
    }()

    // frame: bounds (38.3, 41.5) – (269.9, 316.5)
    static let frame: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 269.586, y: 162.842))
        p.addCurve(to: CGPoint(x: 259.572, y: 151.826), control1: CGPoint(x: 269.863, y: 157.056), control2: CGPoint(x: 265.353, y: 152.103))
        p.addCurve(to: CGPoint(x: 248.567, y: 161.849), control1: CGPoint(x: 253.792, y: 151.547), control2: CGPoint(x: 248.845, y: 156.063))
        p.addCurve(to: CGPoint(x: 154.174, y: 252.100), control1: CGPoint(x: 246.305, y: 212.416), control2: CGPoint(x: 204.823, y: 252.100))
        p.addCurve(to: CGPoint(x: 59.636, y: 157.466), control1: CGPoint(x: 103.526, y: 252.100), control2: CGPoint(x: 59.636, y: 209.583))
        p.addCurve(to: CGPoint(x: 154.174, y: 62.832), control1: CGPoint(x: 59.636, y: 105.349), control2: CGPoint(x: 102.110, y: 62.832))
        p.addCurve(to: CGPoint(x: 175.762, y: 65.229), control1: CGPoint(x: 161.516, y: 62.832), control2: CGPoint(x: 168.712, y: 63.680))
        p.addCurve(to: CGPoint(x: 188.460, y: 57.324), control1: CGPoint(x: 181.410, y: 66.500), control2: CGPoint(x: 187.191, y: 62.965))
        p.addCurve(to: CGPoint(x: 180.564, y: 44.613), control1: CGPoint(x: 189.730, y: 51.670), control2: CGPoint(x: 186.199, y: 45.884))
        p.addCurve(to: CGPoint(x: 154.174, y: 41.647), control1: CGPoint(x: 171.952, y: 42.640), control2: CGPoint(x: 163.063, y: 41.647))
        p.addCurve(to: CGPoint(x: 38.327, y: 157.466), control1: CGPoint(x: 90.258, y: 41.514), control2: CGPoint(x: 38.327, y: 93.485))
        p.addCurve(to: CGPoint(x: 78.393, y: 244.897), control1: CGPoint(x: 38.327, y: 192.357), control2: CGPoint(x: 53.842, y: 223.711))
        p.addLine(to: CGPoint(x: 71.052, y: 267.353))
        p.addCurve(to: CGPoint(x: 84.597, y: 300.125), control1: CGPoint(x: 66.819, y: 280.342), control2: CGPoint(x: 72.599, y: 294.471))
        p.addCurve(to: CGPoint(x: 154.584, y: 316.504), control1: CGPoint(x: 107.600, y: 311.141), control2: CGPoint(x: 131.012, y: 316.504))
        p.addCurve(to: CGPoint(x: 224.003, y: 300.826), control1: CGPoint(x: 178.143, y: 316.504), control2: CGPoint(x: 200.722, y: 311.274))
        p.addCurve(to: CGPoint(x: 238.818, y: 266.082), control1: CGPoint(x: 237.402, y: 294.749), control2: CGPoint(x: 243.897, y: 279.495))
        p.addLine(to: CGPoint(x: 230.498, y: 244.327))
        p.addCurve(to: CGPoint(x: 269.718, y: 162.697), control1: CGPoint(x: 253.355, y: 224.267), control2: CGPoint(x: 268.316, y: 195.455))
        p.closeSubpath()
        p.move(to: CGPoint(x: 91.105, y: 273.987))
        p.addLine(to: CGPoint(x: 96.462, y: 257.740))
        p.addCurve(to: CGPoint(x: 126.515, y: 269.882), control1: CGPoint(x: 105.774, y: 263.103), control2: CGPoint(x: 115.933, y: 267.207))
        p.addLine(to: CGPoint(x: 123.830, y: 291.915))
        p.addCurve(to: CGPoint(x: 93.777, y: 281.044), control1: CGPoint(x: 113.817, y: 289.519), control2: CGPoint(x: 103.790, y: 285.837))
        p.addCurve(to: CGPoint(x: 91.237, y: 273.987), control1: CGPoint(x: 91.383, y: 279.919), control2: CGPoint(x: 90.245, y: 276.807))
        p.closeSubpath()
        return p
    }()
}

// MARK: - Procedural animation

/// Everything the renderer needs for one frame; all values are plain numbers so two frames can be blended.
private struct MascotFrame {
    struct SparkleState {
        var scale: Double = 1
        var opacity: Double = 1
        var rotation: Double = 0  // degrees
        var glow: Double = 0      // 0...1, drives the sparkle's halo
    }

    var sparkles: [SparkleState]
    var orbGlow: Double  // 0...1, light inside the crystal ball
    var blink: Double = 0       // 0 open ... 1 closed
    var smile: Double = 1       // depth of the smile: 1 resting, < 1 flatter, > 1 open
    var glance: Double = 0      // 0 ahead ... 1 looking up and to the right

    static func blended(transition: ModeTransition, to mode: OrdirMascotMode, at date: Date, reduceMotion: Bool) -> MascotFrame {
        let t = date.timeIntervalSinceReferenceDate
        let target = frame(for: mode, time: t, reduceMotion: reduceMotion)
        let progress = date.timeIntervalSince(transition.start) / ModeTransition.duration
        guard progress < 1, transition.from != mode else { return target }
        let source = frame(for: transition.from, time: t, reduceMotion: reduceMotion)
        return lerp(source, target, easeInOut(max(0, progress)))
    }

    static func frame(for mode: OrdirMascotMode, time t: Double, reduceMotion: Bool) -> MascotFrame {
        var frame = sparkleFrame(for: mode, time: t, reduceMotion: reduceMotion)
        guard !reduceMotion else {
            frame.smile = mode == .thinking ? 0.25 : 1
            return frame
        }
        // A quick blink every 4.6 s, in every mode.
        let phase = t.truncatingRemainder(dividingBy: 4.6)
        frame.blink = phase > 4.42 ? max(0, 1 - abs(phase - 4.5) / 0.08) : 0
        switch mode {
        case .idle: break
        case .speaking: frame.smile = 0.6 + wave(1.55 * t)
        case .thinking:
            frame.smile = 0.25
            frame.glance = easeInOut(min(1, 2 * wave(t / 2.8 - 0.25)))
        }
        return frame
    }

    private static func sparkleFrame(for mode: OrdirMascotMode, time t: Double, reduceMotion: Bool) -> MascotFrame {
        let count = OrdirMascotGeometry.sparkles.count
        switch mode {
        case .idle:
            // Slow breathing on the inner sparkles only; the outer sparkle holds still.
            let period = 1.8
            let sparkles = (0..<count).map { i -> SparkleState in
                guard i > 0, !reduceMotion else { return SparkleState() }
                let b = wave(t / period + Double(i) * 0.35)
                return SparkleState(scale: 0.97 + 0.06 * b, opacity: 0.75 + 0.25 * b)
            }
            return MascotFrame(sparkles: sparkles, orbGlow: 0)

        case .speaking:
            // Syllable-rate pulse, staggered a third of a beat per sparkle, inside a slower phrase envelope.
            let phrase = 0.65 + 0.35 * sin(2 * .pi * 0.6 * t)
            var levels: [Double] = []
            let sparkles = (0..<count).map { i -> SparkleState in
                let v = wave(3.2 * t - Double(i) / 3) * phrase
                levels.append(v)
                return SparkleState(
                    scale: reduceMotion ? 1 : 0.8 + 0.4 * v,
                    opacity: 0.5 + 0.5 * v,
                    rotation: (i == 0 && !reduceMotion) ? 5 * sin(2 * .pi * 1.1 * t) : 0,
                    glow: v
                )
            }
            let mean = levels.reduce(0, +) / Double(max(levels.count, 1))
            return MascotFrame(sparkles: sparkles, orbGlow: 0.35 + 0.45 * mean)

        case .thinking:
            // Each sparkle spins at its own pace and brightens in a rolling wave.
            // Stars have 90° symmetry, so wrapping the angle is invisible and keeps blends short.
            let speeds: [Double] = [60, -110, 160]  // degrees per second
            var pulses: [Double] = []
            let sparkles = (0..<count).map { i -> SparkleState in
                let p = wave(t / 1.1 + Double(i) / 3)
                pulses.append(p)
                let angle = reduceMotion ? 0 : (t * speeds[i % speeds.count]).truncatingRemainder(dividingBy: 90)
                return SparkleState(scale: 1, opacity: 0.55 + 0.45 * p, rotation: angle, glow: 0.8 * p)
            }
            let mean = pulses.reduce(0, +) / Double(max(pulses.count, 1))
            return MascotFrame(sparkles: sparkles, orbGlow: 0.15 + 0.15 * mean)
        }
    }

    /// 0...1 sine wave with a period of 1 in `x`.
    private static func wave(_ x: Double) -> Double { 0.5 + 0.5 * sin(2 * .pi * x) }

    private static func easeInOut(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private static func lerp(_ a: MascotFrame, _ b: MascotFrame, _ w: Double) -> MascotFrame {
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * w }
        let sparkles = zip(a.sparkles, b.sparkles).map { s, e in
            SparkleState(
                scale: mix(s.scale, e.scale),
                opacity: mix(s.opacity, e.opacity),
                rotation: mix(s.rotation, e.rotation),
                glow: mix(s.glow, e.glow)
            )
        }
        return MascotFrame(
            sparkles: sparkles,
            orbGlow: mix(a.orbGlow, b.orbGlow),
            blink: mix(a.blink, b.blink),
            smile: mix(a.smile, b.smile),
            glance: mix(a.glance, b.glance)
        )
    }
}

/// How far the orb is built, `time` seconds after it started (nil: fully built). The opening's line has just
/// drawn the rim, so the orb fills in under it, the sparkles pop and the face appears.
private struct MascotBuild {
    var fill = 1.0      // opacity of the globe and pedestal
    var face = 1.0
    var sparkles = [1.0, 1.0, 1.0]

    init(time t: Double?) {
        guard let t, t < 1.2 else { return }
        func smooth(_ x: Double) -> Double { let x = min(1, max(0, x)); return x * x * (3 - 2 * x) }
        fill = smooth(t / 0.35)
        face = smooth((t - 0.45) / 0.25)
        sparkles = (0..<3).map { smooth((t - 0.2 - 0.1 * Double($0)) / 0.4) }
    }
}

// MARK: - Rendering

private enum OrdirMascotRenderer {
    static func draw(_ frame: MascotFrame, build: MascotBuild, in context: inout GraphicsContext, size: CGSize, sparkleColor: Color) {
        typealias G = OrdirMascotGeometry
        // Aspect-fit the viewBox into the canvas, centred. All drawing below is in points.
        let box = G.viewBox
        let unit = min(size.width / box.width, size.height / box.height)
        let offset = CGPoint(
            x: (size.width - box.width * unit) / 2 - box.minX * unit,
            y: (size.height - box.height * unit) / 2 - box.minY * unit
        )
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * unit + offset.x, y: p.y * unit + offset.y) }
        let toCanvas = CGAffineTransform(translationX: offset.x, y: offset.y).scaledBy(x: unit, y: unit)

        // Glow from inside the crystal ball.
        if frame.orbGlow > 0.01 {
            let center = point(G.orbCenter)
            let radius = G.orbInnerRadius * unit
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [sparkleColor.opacity(0.55 * frame.orbGlow), sparkleColor.opacity(0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius * (0.6 + 0.4 * frame.orbGlow)
                )
            )
        }

        // Static globe frame and pedestal, in the environment's foreground colour (follows light/dark mode).
        var globe = context
        globe.opacity = build.fill
        globe.fill(G.frame.applying(toCanvas), with: .foreground)

        // Face: eyes squash to blink and drift up-right to glance; the smile's depth follows the mode.
        var face = context
        face.opacity = build.face
        let gaze = CGSize(width: 4 * frame.glance * unit, height: -5 * frame.glance * unit)
        for eye in G.eyes {
            let c = point(eye.center)
            let width = eye.radius * unit, height = width * (1 - 0.9 * frame.blink)
            face.fill(
                Path(ellipseIn: CGRect(x: c.x - width + gaze.width, y: c.y - height + gaze.height,
                                       width: width * 2, height: height * 2)),
                with: .foreground
            )
        }
        let start = point(G.mouthStart), end = point(G.mouthEnd), control = point(G.mouthControl)
        var mouth = Path()
        mouth.move(to: start)
        mouth.addQuadCurve(to: end, control: CGPoint(x: control.x, y: start.y + (control.y - start.y) * frame.smile))
        face.stroke(mouth, with: .foreground, style: StrokeStyle(lineWidth: G.mouthWidth * unit, lineCap: .round))

        // Sparkles: scale and rotate around their own centres, then place.
        for (index, (spec, state)) in zip(G.sparkles, frame.sparkles).enumerated() {
            let center = point(spec.center)
            let popped = build.sparkles[index]
            let transform = CGAffineTransform(scaleX: unit * state.scale * popped, y: unit * state.scale * popped)
                .concatenating(CGAffineTransform(rotationAngle: state.rotation * .pi / 180))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))

            var layer = context
            layer.opacity = state.opacity * popped
            if state.glow > 0.01 {
                layer.addFilter(.shadow(color: sparkleColor.opacity(0.8 * state.glow), radius: spec.size * unit * 0.25 * state.glow))
            }
            layer.fill(spec.path.applying(transform), with: .color(sparkleColor))
        }
    }
}

// MARK: - Preview

private struct OrdirMascotPreviewHarness: View {
    @State private var isSpeaking = false
    @State private var isThinking = false

    var body: some View {
        VStack(spacing: 32) {
            OrdirMascotView(isSpeaking: isSpeaking, isThinking: isThinking)
                .frame(width: 180, height: 180)

            HStack(spacing: 12) {
                Button("Idle") { set(speaking: false, thinking: false) }
                Button("Speaking") { set(speaking: true, thinking: false) }
                Button("Thinking") { set(speaking: false, thinking: true) }
            }
            .buttonStyle(.bordered)

            Divider()

            HStack(spacing: 24) {
                labelled("Idle", OrdirMascotView())
                labelled("Speaking", OrdirMascotView(isSpeaking: true))
                labelled("Thinking", OrdirMascotView(isThinking: true))
            }
        }
        .padding()
    }

    private func set(speaking: Bool, thinking: Bool) {
        isSpeaking = speaking
        isThinking = thinking
    }

    private func labelled(_ title: String, _ mascot: OrdirMascotView) -> some View {
        VStack(spacing: 8) {
            mascot.frame(width: 72, height: 72)
            Text(title).font(.ordir(.footnote)).foregroundStyle(.secondary)
        }
    }
}

#Preview("States") {
    OrdirMascotPreviewHarness()
}

#Preview("Dark") {
    OrdirMascotPreviewHarness()
        .preferredColorScheme(.dark)
}
