import SwiftUI
import UIKit

/// Extracts representative colors from a flag emoji so the match page can paint
/// an animated gradient "in the team's colors". Results are cached per emoji —
/// rendering + sampling only happens once per flag.
enum FlagPalette {
    private static var cache: [String: [Color]] = [:]

    /// Up to `count` vivid colors sampled from the rendered flag, most prominent
    /// first. Falls back to a neutral blue pair for empty/undecided flags.
    static func colors(for emoji: String, count: Int = 3) -> [Color] {
        let key = "\(emoji)#\(count)"
        if let cached = cache[key] { return cached }
        let result = extract(emoji: emoji, count: count)
        cache[key] = result
        return result
    }

    static let fallback: [Color] = [
        Color(red: 0.20, green: 0.28, blue: 0.46),
        Color(red: 0.32, green: 0.42, blue: 0.62)
    ]

    // MARK: Rendering

    private static func extract(emoji: String, count: Int) -> [Color] {
        guard !emoji.isEmpty, emoji != "🏳️" else { return fallback }

        let side: CGFloat = 40
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { _ in
            let str = emoji as NSString
            let font = UIFont.systemFont(ofSize: side)
            let textSize = str.size(withAttributes: [.font: font])
            let rect = CGRect(
                x: (side - textSize.width) / 2,
                y: (side - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            str.draw(in: rect, withAttributes: [.font: font])
        }
        guard let cg = image.cgImage else { return fallback }
        let colors = dominantColors(from: cg, count: count)
        return colors.isEmpty ? fallback : colors
    }

    // MARK: Sampling

    private struct Bucket { var count = 0; var r = 0; var g = 0; var b = 0 }

    private static func dominantColors(from cg: CGImage, count: Int) -> [Color] {
        let width = cg.width, height = cg.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Bucket colors quantized to 4 bits/channel.
        var buckets: [Int: Bucket] = [:]
        var i = 0
        while i < data.count {
            let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2]), a = Int(data[i + 3])
            i += bytesPerPixel
            if a < 160 { continue }
            let key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
            var bucket = buckets[key] ?? Bucket()
            bucket.count += 1; bucket.r += r; bucket.g += g; bucket.b += b
            buckets[key] = bucket
        }
        guard !buckets.isEmpty else { return [] }

        // Average each bucket, score by prominence weighted toward vivid colors.
        struct Candidate { let color: Color; let hue: CGFloat; let sat: CGFloat; let bri: CGFloat; let score: Double }
        var candidates: [Candidate] = buckets.values.map { bucket in
            let r = CGFloat(bucket.r) / CGFloat(bucket.count) / 255
            let g = CGFloat(bucket.g) / CGFloat(bucket.count) / 255
            let b = CGFloat(bucket.b) / CGFloat(bucket.count) / 255
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            let score = Double(bucket.count) * (0.35 + Double(s) * 0.65)
            return Candidate(color: Color(red: r, green: g, blue: b), hue: h, sat: s, bri: v, score: score)
        }
        candidates.sort { $0.score > $1.score }

        // Prefer vivid, hue-distinct colors; relax if too few remain.
        func pick(vividOnly: Bool) -> [Candidate] {
            var chosen: [Candidate] = []
            for c in candidates {
                if vividOnly {
                    let nearGray = c.sat < 0.18
                    let nearWhite = c.bri > 0.9 && c.sat < 0.25
                    let nearBlack = c.bri < 0.12
                    if nearGray || nearWhite || nearBlack { continue }
                }
                let tooClose = chosen.contains { abs($0.hue - c.hue) < 0.06 && abs($0.bri - c.bri) < 0.18 }
                if tooClose { continue }
                chosen.append(c)
                if chosen.count >= count { break }
            }
            return chosen
        }

        var chosen = pick(vividOnly: true)
        if chosen.isEmpty { chosen = pick(vividOnly: false) }
        return chosen.map(\.color)
    }
}
