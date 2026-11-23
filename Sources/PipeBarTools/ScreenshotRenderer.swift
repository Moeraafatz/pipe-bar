import AppKit
import CoreGraphics
import Foundation
import PipeBarUI
import SwiftUI

@MainActor
enum PipeScreenshotRenderer {
    static func renderAll(outputDir: URL) throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let barImg = try renderCard(tab: .bar)
        let recipesImg = try renderCard(tab: .recipes)
        let catalogImg = try renderCard(tab: .catalog)
        let pluginsImg = try renderCard(tab: .plugins)

        try PipeIconGenerator.writePNG(barImg, to: outputDir.appendingPathComponent("bar.png"))
        try PipeIconGenerator.writePNG(recipesImg, to: outputDir.appendingPathComponent("recipes.png"))
        try PipeIconGenerator.writePNG(catalogImg, to: outputDir.appendingPathComponent("catalog.png"))
        try PipeIconGenerator.writePNG(pluginsImg, to: outputDir.appendingPathComponent("plugins.png"))

        let hero = try renderHeroBanner(bar: barImg, recipes: recipesImg, catalog: catalogImg)
        try PipeIconGenerator.writePNG(hero, to: outputDir.appendingPathComponent("hero.png"))
    }

    private static func renderCard(tab: PipeTab) throws -> CGImage {
        let state = PipeAppState.demo(tab: tab)
        let framed = RootPipeView(state: state, width: 510)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.032, green: 0.028, blue: 0.055),
                        Color(red: 0.015, green: 0.014, blue: 0.028)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage else {
            throw NSError(domain: "PipeBarTools.Screenshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "ImageRenderer returned nil for \(tab.rawValue)"])
        }
        return cg
    }

    private static func renderHeroBanner(bar: CGImage, recipes: CGImage, catalog: CGImage) throws -> CGImage {
        let heroView = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.028, green: 0.024, blue: 0.052),
                    Color(red: 0.012, green: 0.012, blue: 0.024)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [PipeTheme.violet.opacity(0.22), Color.clear],
                center: UnitPoint(x: 0.22, y: 0.20),
                startRadius: 20,
                endRadius: 560
            )
            RadialGradient(
                colors: [PipeTheme.cyan.opacity(0.16), Color.clear],
                center: UnitPoint(x: 0.80, y: 0.80),
                startRadius: 20,
                endRadius: 560
            )

            VStack(spacing: 26) {
                HStack(spacing: 12) {
                    Text("PIPE BAR")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(PipeTheme.violet)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(PipeTheme.violet.opacity(0.16))
                                .overlay(Capsule().strokeBorder(PipeTheme.violet.opacity(0.45), lineWidth: 1))
                        )
                    Text("Unix-Style Pipes Over Live macOS GUI State · PDFKit + Vision OCR + Browser Tabs")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PipeTheme.textSecondary)
                }

                HStack(alignment: .center, spacing: 24) {
                    panelPreview(image: bar, caption: "Live Typed Pipe Bar (⌘1)")
                    panelPreview(image: recipes, caption: "One-Click Power Recipes (⌘2)")
                    panelPreview(image: catalog, caption: "24 Composable Stages (⌘3)")
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
        }
        .frame(width: 1640, height: 880)
        .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: heroView)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage else {
            throw NSError(domain: "PipeBarTools.Screenshot", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to render hero banner"])
        }
        return cg
    }

    private static func panelPreview(image: CGImage, caption: String) -> some View {
        VStack(spacing: 10) {
            Image(decorative: image, scale: 2.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 495)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 14)

            Text(caption)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(PipeTheme.textSecondary)
        }
    }
}
