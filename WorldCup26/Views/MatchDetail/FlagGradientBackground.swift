import SwiftUI

/// An animated gradient that flows between the two teams' flag colors — home on
/// the left, away on the right. Uses `MeshGradient` on iOS 18+, with an animated
/// linear gradient as the iOS 17 fallback.
struct FlagGradientBackground: View {
    let homeColors: [Color]
    let awayColors: [Color]

    var body: some View {
        if #available(iOS 18.0, *) {
            MeshFlagGradient(home: homeColors, away: awayColors)
        } else {
            LinearFlagGradient(home: homeColors, away: awayColors)
        }
    }
}

// MARK: - iOS 18+ mesh

@available(iOS 18.0, *)
private struct MeshFlagGradient: View {
    let home: [Color]
    let away: [Color]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: points(t), colors: meshColors)
        }
    }

    private var meshColors: [Color] {
        let h0 = color(home, 0), h1 = color(home, 1), h2 = color(home, 2)
        let a0 = color(away, 0), a1 = color(away, 1), a2 = color(away, 2)
        return [
            h0, blend(h0, a0), a0,
            h1, blend(h1, a1), a1,
            h2, blend(h2, a2), a2
        ]
    }

    /// Corners stay pinned; mid-edge and center points drift on sine waves for an
    /// organic, slowly flowing motion.
    private func points(_ t: TimeInterval) -> [SIMD2<Float>] {
        func osc(_ speed: Double, _ amp: Double, _ phase: Double) -> Float {
            Float(sin(t * speed + phase) * amp)
        }
        return [
            SIMD2(0, 0),
            SIMD2(0.5 + osc(0.55, 0.10, 0.0), 0),
            SIMD2(1, 0),
            SIMD2(0, 0.5 + osc(0.50, 0.10, 1.0)),
            SIMD2(0.5 + osc(0.70, 0.12, 2.0), 0.5 + osc(0.60, 0.12, 3.0)),
            SIMD2(1, 0.5 + osc(0.45, 0.10, 4.0)),
            SIMD2(0, 1),
            SIMD2(0.5 + osc(0.60, 0.10, 5.0), 1),
            SIMD2(1, 1)
        ]
    }

    private func color(_ arr: [Color], _ i: Int) -> Color {
        guard !arr.isEmpty else { return .gray }
        return arr[min(i, arr.count - 1)]
    }

    private func blend(_ a: Color, _ b: Color) -> Color { FlagGradientMath.blend(a, b) }
}

// MARK: - iOS 17 fallback

private struct LinearFlagGradient: View {
    let home: [Color]
    let away: [Color]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let shift = CGFloat(sin(t * 0.4)) * 0.18
            LinearGradient(
                colors: home + [FlagGradientMath.blend(home.first ?? .gray, away.first ?? .gray)] + away.reversed(),
                startPoint: UnitPoint(x: 0.0 + shift, y: 0.1),
                endPoint: UnitPoint(x: 1.0 + shift, y: 0.9)
            )
        }
    }
}

// MARK: - Shared math

private enum FlagGradientMath {
    static func blend(_ a: Color, _ b: Color) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double(r1 + r2) / 2, green: Double(g1 + g2) / 2, blue: Double(b1 + b2) / 2)
    }
}
