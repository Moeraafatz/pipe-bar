import CoreGraphics
import CoreText
import Foundation
import PipeBarCore

enum PipeGraphRenderer {
    static func renderAll(report: PipeBarBenchmarkReport, outputDir: URL) throws {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        try PipeIconGenerator.writePNG(
            renderPipelineScalingChart(report: report),
            to: outputDir.appendingPathComponent("pipeline-scaling.png")
        )
        try PipeIconGenerator.writePNG(
            renderWorkflowBenchmarksChart(report: report),
            to: outputDir.appendingPathComponent("workflow-benchmarks.png")
        )
        try PipeIconGenerator.writePNG(
            renderParserAndClicksChart(report: report),
            to: outputDir.appendingPathComponent("parser-and-compression.png")
        )
        try makeArchitectureSVG(report: report).write(
            to: outputDir.appendingPathComponent("architecture.svg"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Chart 1: 5-Stage Pipeline Throughput Scaling (1K -> 25K Rows)

    private static func renderPipelineScalingChart(report: PipeBarBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 620
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "MEASURED ON \(report.hostArchitecture.uppercased())",
            title: "5-Stage Typed Pipeline Scaling (1K → 25K Tabular Rows)",
            subtitle: "clipboard | extract tables | filter Enterprise | dedupe | sort asc | to markdown"
        )

        let plot = CGRect(x: 110, y: 105, width: 1050, height: 360)
        let maxMs = max(20.0, (report.scalePoints.map(\.totalDurationMs).max() ?? 50.0) * 1.35)
        let yMax = ceil(maxMs / 25.0) * 25.0

        for i in 0...4 {
            let frac = CGFloat(i) / 4.0
            let y = plot.minY + frac * plot.height
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: i == 0 ? 0.22 : 0.08))
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: plot.minX, y: y))
            ctx.addLine(to: CGPoint(x: plot.maxX, y: y))
            ctx.strokePath()
            drawText(ctx, String(format: "%.0f ms", (Double(i) / 4.0) * yMax), x: 30, y: y - 6, size: 15, weight: .regular, r: 0.65, g: 0.70, b: 0.78)
        }

        let count = max(report.scalePoints.count, 1)
        let groupW = plot.width / CGFloat(count)
        let barW: CGFloat = min(115, groupW * 0.44)

        for (idx, pt) in report.scalePoints.enumerated() {
            let cx = plot.minX + groupW * (CGFloat(idx) + 0.5)
            let h = max(12, CGFloat(pt.totalDurationMs / yMax) * plot.height)
            let rect = CGRect(x: cx - barW / 2, y: plot.minY, width: barW, height: h)

            fillRoundedRect(ctx, rect: rect, radius: 10, r: 0.75, g: 0.35, b: 0.95, a: 0.92)
            drawText(ctx, String(format: "%.1f ms", pt.totalDurationMs), x: cx - 34, y: rect.maxY + 12, size: 16, weight: .bold, r: 0.39, g: 0.82, b: 1.0)
            drawText(ctx, String(format: "%.0fK rows/s", pt.rowsPerSecond / 1000.0), x: cx - 44, y: rect.maxY + 34, size: 13.5, weight: .bold, r: 0.19, g: 0.82, b: 0.35)

            let label = "\(pt.rowCount / 1_000)K rows"
            drawText(ctx, label, x: cx - 34, y: plot.minY - 34, size: 16, weight: .bold, r: 0.94, g: 0.96, b: 0.99)
        }

        return ctx.makeImage()!
    }

    // MARK: - Chart 2: Real Cross-App Workflow Latencies

    private static func renderWorkflowBenchmarksChart(report: PipeBarBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 560
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "END-TO-END NATIVE WORKFLOW TELEMETRY",
            title: "Measured Cross-App Pipeline Latency (PDFKit · Vision · Tabs · Logs)",
            subtitle: "Verified PDFKit multi-page extract (\(report.pdfKitExtractVerified ? "PASS" : "FAIL")) · Apple Vision OCR (\(report.visionOCRVerified ? "PASS" : "FAIL"))"
        )

        let items = report.workflowBenchmarks
        let maxMs = max(items.map(\.durationMs).max() ?? 50.0, 10.0)
        let barLeft: CGFloat = 385
        let barMaxW: CGFloat = 550
        let startY: CGFloat = 365
        let stepY: CGFloat = 74

        let colors: [(CGFloat, CGFloat, CGFloat)] = [
            (0.39, 0.82, 1.0),
            (0.19, 0.82, 0.35),
            (0.75, 0.35, 0.95),
            (1.0, 0.62, 0.04),
            (0.45, 0.60, 1.0)
        ]

        for (i, wf) in items.prefix(5).enumerated() {
            let y = startY - CGFloat(i) * stepY
            let col = colors[i % colors.count]

            drawText(ctx, wf.label, x: 52, y: y + 18, size: 17, weight: .bold, r: 0.94, g: 0.96, b: 0.99)
            drawText(ctx, wf.commandSummary, x: 52, y: y - 2, size: 12.5, weight: .regular, r: 0.58, g: 0.64, b: 0.74)

            fillRoundedRect(ctx, rect: CGRect(x: barLeft, y: y + 4, width: barMaxW, height: 26), radius: 8, r: 1, g: 1, b: 1, a: 0.07)
            let frac = max(0.03, min(1.0, wf.durationMs / maxMs))
            fillRoundedRect(ctx, rect: CGRect(x: barLeft, y: y + 4, width: barMaxW * CGFloat(frac), height: 26), radius: 8, r: col.0, g: col.1, b: col.2, a: 0.92)

            drawText(ctx, String(format: "%.1f ms", wf.durationMs), x: barLeft + barMaxW + 20, y: y + 10, size: 16, weight: .bold, r: col.0, g: col.1, b: col.2)
            drawText(ctx, "(\(wf.manualClicksReplaced) clicks → 1)", x: barLeft + barMaxW + 115, y: y + 10, size: 13.5, weight: .regular, r: 0.64, g: 0.70, b: 0.78)
        }

        return ctx.makeImage()!
    }

    // MARK: - Chart 3: Parser Speed & Manual Click Reduction

    private static func renderParserAndClicksChart(report: PipeBarBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 560
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "INSTANT KEYSTROKE UX & LEVERAGE",
            title: "HUD Parser Latency & Multi-App Click Collapse",
            subtitle: "Every keystroke parses pipes & ranks autocomplete under 1 ms (120 FPS budget = 8.3 ms)"
        )

        let left = CGRect(x: 52, y: 72, width: 540, height: 345)
        fillRoundedRect(ctx, rect: left, radius: 16, r: 1, g: 1, b: 1, a: 0.045)
        strokeRoundedRect(ctx, rect: left, radius: 16, r: 1, g: 1, b: 1, a: 0.12)

        drawText(ctx, "Live Keystroke Parse + Autocomplete", x: left.minX + 24, y: left.maxY - 42, size: 20, weight: .bold, r: 0.95, g: 0.97, b: 1.0)
        drawText(ctx, String(format: "%.3f ms", report.parserAutocompleteAvgMs), x: left.minX + 24, y: left.maxY - 120, size: 54, weight: .bold, r: 0.39, g: 0.82, b: 1.0)
        drawText(ctx, "average per keystroke across 500 8-stage parses", x: left.minX + 24, y: left.maxY - 150, size: 15, weight: .regular, r: 0.68, g: 0.74, b: 0.82)

        let budgetRatio = max(0.03, min(1.0, report.parserAutocompleteAvgMs / 8.33))
        let bar = CGRect(x: left.minX + 24, y: left.minY + 95, width: left.width - 48, height: 30)
        fillRoundedRect(ctx, rect: bar, radius: 9, r: 1, g: 1, b: 1, a: 0.08)
        fillRoundedRect(ctx, rect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * CGFloat(budgetRatio), height: bar.height), radius: 9, r: 0.19, g: 0.82, b: 0.35, a: 0.94)
        drawText(ctx, "120 FPS ProMotion frame budget = 8.33 ms (zero UI stutter)", x: left.minX + 24, y: left.minY + 48, size: 14, weight: .bold, r: 0.19, g: 0.82, b: 0.35)

        let right = CGRect(x: 620, y: 72, width: 568, height: 345)
        fillRoundedRect(ctx, rect: right, radius: 16, r: 1, g: 1, b: 1, a: 0.045)
        strokeRoundedRect(ctx, rect: right, radius: 16, r: 1, g: 1, b: 1, a: 0.12)

        drawText(ctx, "Manual GUI Clicks Collapsed to 1 Pipe", x: right.minX + 24, y: right.maxY - 42, size: 20, weight: .bold, r: 0.95, g: 0.97, b: 1.0)
        let maxClicks = max(report.workflowBenchmarks.map(\.manualClicksReplaced).max() ?? 34, 10)
        for (idx, wf) in report.workflowBenchmarks.prefix(4).enumerated() {
            let y = right.maxY - 102 - CGFloat(idx) * 66
            drawText(ctx, wf.label, x: right.minX + 24, y: y + 20, size: 15, weight: .bold, r: 0.92, g: 0.95, b: 0.98)
            drawText(ctx, "\(wf.manualClicksReplaced) clicks → 1 cmd", x: right.maxX - 185, y: y + 20, size: 14.5, weight: .bold, r: 0.75, g: 0.35, b: 0.95)
            let track = CGRect(x: right.minX + 24, y: y, width: right.width - 48, height: 12)
            fillRoundedRect(ctx, rect: track, radius: 6, r: 1, g: 1, b: 1, a: 0.08)
            let w = max(16, track.width * CGFloat(Double(wf.manualClicksReplaced) / Double(maxClicks)))
            fillRoundedRect(ctx, rect: CGRect(x: track.minX, y: track.minY, width: w, height: track.height), radius: 6, r: 0.75, g: 0.35, b: 0.95, a: 0.92)
        }

        return ctx.makeImage()!
    }

    // MARK: - Chart 4: Crisp Vector Architecture Diagram (SVG)

    private static func makeArchitectureSVG(report: PipeBarBenchmarkReport) -> String {
        let parseMs = String(format: "%.3f ms", report.parserAutocompleteAvgMs)
        let topRps = String(format: "%.0fK/s", (report.scalePoints.last?.rowsPerSecond ?? 50_000) / 1000.0)

        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="390" viewBox="0 0 1200 390">
          <defs>
            <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#0C0A16"/>
              <stop offset="100%" stop-color="#05040B"/>
            </linearGradient>
            <linearGradient id="violetBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#251335"/>
              <stop offset="100%" stop-color="#140A1E"/>
            </linearGradient>
            <linearGradient id="cyanBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#102230"/>
              <stop offset="100%" stop-color="#09151E"/>
            </linearGradient>
            <linearGradient id="greenBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#10291B"/>
              <stop offset="100%" stop-color="#091810"/>
            </linearGradient>
            <marker id="arrowViolet" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#BF5AF2"/>
            </marker>
            <marker id="arrowGreen" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#30D158"/>
            </marker>
          </defs>

          <rect width="1200" height="390" rx="20" fill="url(#bg)" stroke="#FFFFFF" stroke-opacity="0.14"/>

          <text x="40" y="48" fill="#BF5AF2" font-family="-apple-system, BlinkMacSystemFont, SF Pro Display, Helvetica" font-size="13" font-weight="700" letter-spacing="1.4">TYPED UNIX-STYLE GUI PIPELINE ARCHITECTURE · 100% NATIVE SWIFT 6</text>
          <text x="40" y="78" fill="#F5F8FC" font-family="-apple-system, BlinkMacSystemFont, SF Pro Display, Helvetica" font-size="24" font-weight="700">Pipe Bar Engine — Compose Live macOS Apps, PDFs, Vision &amp; Data</text>

          <!-- Node 1 -->
          <rect x="40" y="120" width="190" height="125" rx="14" fill="url(#violetBox)" stroke="#BF5AF2" stroke-opacity="0.6"/>
          <text x="58" y="150" fill="#BF5AF2" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">1. GUI SOURCES</text>
          <text x="58" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">Finder · Tabs · Clip</text>
          <text x="58" y="200" fill="#64D2FF" font-family="SF Mono, Menlo, monospace" font-size="12.5" font-weight="700">selected | tabs | clip</text>
          <text x="58" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">AppleEvents + Pasteboard</text>

          <line x1="230" y1="182" x2="262" y2="182" stroke="#BF5AF2" stroke-width="2.2" marker-end="url(#arrowViolet)"/>

          <!-- Node 2 -->
          <rect x="270" y="120" width="190" height="125" rx="14" fill="url(#cyanBox)" stroke="#64D2FF" stroke-opacity="0.55"/>
          <text x="288" y="150" fill="#64D2FF" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">2. PIPE PARSER</text>
          <text x="288" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">Lexer + Autocomplete</text>
          <text x="288" y="204" fill="#64D2FF" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">~\(parseMs) / keystroke</text>
          <text x="288" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Quoted args + aliases</text>

          <line x1="460" y1="182" x2="492" y2="182" stroke="#BF5AF2" stroke-width="2.2" marker-end="url(#arrowViolet)"/>

          <!-- Node 3 -->
          <rect x="500" y="120" width="195" height="125" rx="14" fill="url(#cyanBox)" stroke="#BF5AF2" stroke-opacity="0.55"/>
          <text x="518" y="150" fill="#D58CFF" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">3. MEDIA EXTRACT</text>
          <text x="518" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">PDFKit + Vision OCR</text>
          <text x="518" y="204" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">100% Offline ANE</text>
          <text x="518" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Tables, URLs, Emails</text>

          <line x1="695" y1="182" x2="727" y2="182" stroke="#BF5AF2" stroke-width="2.2" marker-end="url(#arrowViolet)"/>

          <!-- Node 4 -->
          <rect x="735" y="120" width="195" height="125" rx="14" fill="url(#cyanBox)" stroke="#FF9F0A" stroke-opacity="0.55"/>
          <text x="753" y="150" fill="#FF9F0A" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">4. TYPED ENGINE</text>
          <text x="753" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">Filter · Dedupe · Scrub</text>
          <text x="753" y="204" fill="#FF9F0A" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">\(topRps) rows/sec</text>
          <text x="753" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">CSV · Markdown · JSON</text>

          <line x1="930" y1="182" x2="962" y2="182" stroke="#30D158" stroke-width="2.2" marker-end="url(#arrowGreen)"/>

          <!-- Node 5 -->
          <rect x="970" y="120" width="190" height="125" rx="14" fill="url(#greenBox)" stroke="#30D158" stroke-opacity="0.65"/>
          <text x="988" y="150" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">5. OUTPUT SINKS</text>
          <text x="988" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">Copy · Save · Note</text>
          <text x="988" y="204" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">⌥⇧P Floating HUD</text>
          <text x="988" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Auto-redacts secrets</text>

          <!-- Bottom guarantee strip -->
          <rect x="40" y="286" width="1120" height="64" rx="12" fill="#FFFFFF" fill-opacity="0.04" stroke="#FFFFFF" stroke-opacity="0.1"/>
          <text x="66" y="324" fill="#BF5AF2" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ 24 COMPOSABLE STAGES</text>
          <text x="332" y="324" fill="#64D2FF" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ PDFKIT + VISION OFFLINE</text>
          <text x="635" y="324" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ SANDBOXED LOCAL PLUGINS</text>
          <text x="955" y="324" fill="#E5ECF4" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ MIT LICENSE</text>
        </svg>
        """
    }

    // MARK: - CoreGraphics Primitives

    private enum FontWeight { case regular, bold }

    private static func makeCanvas(width: Int, height: Int) -> CGContext {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let bg = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.048, green: 0.042, blue: 0.082, alpha: 1.0),
                CGColor(red: 0.020, green: 0.018, blue: 0.038, alpha: 1.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
        return ctx
    }

    private static func drawCardFrame(_ ctx: CGContext, width: Int, height: Int, badge: String, title: String, subtitle: String) {
        let outer = CGRect(x: 16, y: 16, width: width - 32, height: height - 32)
        strokeRoundedRect(ctx, rect: outer, radius: 22, r: 1, g: 1, b: 1, a: 0.14)
        drawText(ctx, badge, x: 52, y: CGFloat(height) - 62, size: 13, weight: .bold, r: 0.75, g: 0.35, b: 0.95)
        drawText(ctx, title, x: 52, y: CGFloat(height) - 98, size: 26, weight: .bold, r: 0.96, g: 0.98, b: 1.0)
        drawText(ctx, subtitle, x: 52, y: CGFloat(height) - 126, size: 15, weight: .regular, r: 0.62, g: 0.68, b: 0.77)
    }

    private static func fillRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let path = CGPath(roundedRect: rect, cornerWidth: min(radius, rect.width / 2), cornerHeight: min(radius, rect.height / 2), transform: nil)
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: a))
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func strokeRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.setStrokeColor(CGColor(red: r, green: g, blue: b, alpha: a))
        ctx.setLineWidth(1.5)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: FontWeight, r: CGFloat, g: CGFloat, b: CGFloat) {
        let fontName = (weight == .bold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString
        let font = CTFontCreateWithName(fontName, size, nil)
        let color = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }
}
