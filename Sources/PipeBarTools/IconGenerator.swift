import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PipeIconGenerator {
    static func generateIconSet(iconsetURL: URL, docsIconURL: URL) throws {
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docsIconURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        for (name, px) in sizes {
            try writePNG(renderIcon(size: px), to: iconsetURL.appendingPathComponent(name))
        }
        try writePNG(renderIcon(size: 256), to: docsIconURL)
    }

    static func renderIcon(size: Int) -> CGImage {
        let s = CGFloat(size)
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let inset = s * 0.08
        let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let radius = rect.width * 0.225
        let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()

        let bgGrad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.105, green: 0.075, blue: 0.165, alpha: 1.0),
                CGColor(red: 0.045, green: 0.038, blue: 0.085, alpha: 1.0),
                CGColor(red: 0.020, green: 0.018, blue: 0.042, alpha: 1.0)
            ] as CFArray,
            locations: [0.0, 0.5, 1.0]
        )!
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

        // Electric violet glow
        let violetGlow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.38),
                CGColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawRadialGradient(violetGlow, startCenter: CGPoint(x: s * 0.32, y: s * 0.68), startRadius: 0, endCenter: CGPoint(x: s * 0.32, y: s * 0.68), endRadius: s * 0.5, options: [])

        // Cyan bottom-right glow
        let cyanGlow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.39, green: 0.82, blue: 1.0, alpha: 0.30),
                CGColor(red: 0.39, green: 0.82, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawRadialGradient(cyanGlow, startCenter: CGPoint(x: s * 0.72, y: s * 0.30), startRadius: 0, endCenter: CGPoint(x: s * 0.72, y: s * 0.30), endRadius: s * 0.48, options: [])

        // Glass sheen
        let sheen = CGGradient(
            colorsSpace: cs,
            colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.14), CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: s * 0.5, y: rect.maxY), end: CGPoint(x: s * 0.5, y: rect.midY), options: [])

        // Iconic glowing |> Unix GUI Pipe symbol
        // Vertical pipe bar "|"
        let barW = s * 0.078
        let barH = s * 0.44
        let barRect = CGRect(x: s * 0.27, y: (s - barH) * 0.5, width: barW, height: barH)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: barW * 0.45, cornerHeight: barW * 0.45, transform: nil)
        ctx.setFillColor(CGColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.98))
        ctx.addPath(barPath)
        ctx.fillPath()

        // Luminous forward chevron ">"
        ctx.setLineWidth(max(2.0, s * 0.072))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(CGColor(red: 0.39, green: 0.82, blue: 1.0, alpha: 0.98))
        ctx.move(to: CGPoint(x: s * 0.47, y: s * 0.67))
        ctx.addLine(to: CGPoint(x: s * 0.71, y: s * 0.50))
        ctx.addLine(to: CGPoint(x: s * 0.47, y: s * 0.33))
        ctx.strokePath()

        // Emerald output pulse dot
        let dotR = s * 0.048
        ctx.setFillColor(CGColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: s * 0.75 - dotR, y: s * 0.50 - dotR, width: dotR * 2, height: dotR * 2))

        ctx.restoreGState()

        ctx.addPath(squircle)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.24))
        ctx.setLineWidth(max(1.0, s * 0.012))
        ctx.strokePath()

        return ctx.makeImage()!
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "PipeBarTools.PNG", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PNG destination"])
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "PipeBarTools.PNG", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG"])
        }
    }
}
