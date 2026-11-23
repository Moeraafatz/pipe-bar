import CoreGraphics
import CoreText
import Foundation

public struct PipeScalePoint: Codable, Sendable {
    public let rowCount: Int
    public let totalDurationMs: Double
    public let rowsPerSecond: Double

    public init(rowCount: Int, totalDurationMs: Double, rowsPerSecond: Double) {
        self.rowCount = rowCount
        self.totalDurationMs = totalDurationMs
        self.rowsPerSecond = rowsPerSecond
    }
}

public struct WorkflowBenchmarkPoint: Codable, Sendable {
    public let label: String
    public let commandSummary: String
    public let durationMs: Double
    public let manualClicksReplaced: Int

    public init(label: String, commandSummary: String, durationMs: Double, manualClicksReplaced: Int) {
        self.label = label
        self.commandSummary = commandSummary
        self.durationMs = durationMs
        self.manualClicksReplaced = manualClicksReplaced
    }
}

public struct PipeBarBenchmarkReport: Codable, Sendable {
    public let generatedAtISO8601: String
    public let hostArchitecture: String
    public let osVersion: String
    public let parserAutocompleteAvgMs: Double
    public let pdfKitExtractVerified: Bool
    public let visionOCRVerified: Bool
    public let scalePoints: [PipeScalePoint]
    public let workflowBenchmarks: [WorkflowBenchmarkPoint]

    public init(
        generatedAtISO8601: String,
        hostArchitecture: String,
        osVersion: String,
        parserAutocompleteAvgMs: Double,
        pdfKitExtractVerified: Bool,
        visionOCRVerified: Bool,
        scalePoints: [PipeScalePoint],
        workflowBenchmarks: [WorkflowBenchmarkPoint]
    ) {
        self.generatedAtISO8601 = generatedAtISO8601
        self.hostArchitecture = hostArchitecture
        self.osVersion = osVersion
        self.parserAutocompleteAvgMs = parserAutocompleteAvgMs
        self.pdfKitExtractVerified = pdfKitExtractVerified
        self.visionOCRVerified = visionOCRVerified
        self.scalePoints = scalePoints
        self.workflowBenchmarks = workflowBenchmarks
    }
}

public enum PipeBarBenchmarkRunner {
    /// Programmatically synthesizes a genuine multi-page PDF document in memory for real PDFKit tests.
    public static func makeSyntheticPDF(pages: [[String]]) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

        for lines in pages {
            ctx.beginPDFPage(nil)
            var y: CGFloat = 720
            for line in lines {
                drawLine(ctx, text: line, x: 48, y: y, size: 13)
                y -= 24
            }
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    public static func makeSyntheticInvoiceImage(lines: [String]) -> CGImage? {
        let w = 1000
        let h = 480
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        var y: CGFloat = 410
        for line in lines {
            drawLine(ctx, text: line, x: 40, y: y, size: 24)
            y -= 52
        }
        return ctx.makeImage()
    }

    private static func drawLine(_ ctx: CGContext, text: String, x: CGFloat, y: CGFloat, size: CGFloat) {
        let font = CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
        let color = CGColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }

    @MainActor
    public static func runFullSuite() throws -> PipeBarBenchmarkReport {
        // 1. Keystroke Parser + Autocomplete responsiveness (500 cycles)
        let sampleCmd = "selected pdfs | pdf text | extract tables | filter Enterprise | dedupe | sort asc | to markdown | copy"
        let parseStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<500 {
            let p = PipelineParser.parse(sampleCmd)
            let s = PipelineParser.autocomplete(for: "tabs | clean", limit: 6)
            precondition(p.isValid && !s.isEmpty)
        }
        let parserAvgMs = ((CFAbsoluteTimeGetCurrent() - parseStart) * 1000.0) / 500.0

        // 2. 5-Stage Pipeline Throughput Scaling (1K -> 25K rows)
        var scalePoints: [PipeScalePoint] = []
        for rowCount in [1_000, 5_000, 10_000, 25_000] {
            var csv = "Company,Tier,InvoiceID,AmountUSD\n"
            csv.reserveCapacity(rowCount * 46)
            for i in 0..<rowCount {
                let tier = (i % 3 == 0) ? "Enterprise" : "Starter"
                csv += "Acme_\(i % (rowCount / 2 + 1)),\(tier),INV-\(10_000 + (i % (rowCount / 2 + 1))),\(1200 + (i % 40) * 100)\n"
            }
            let res = PipelineEngine.execute(
                command: "clipboard | extract tables | filter Enterprise | dedupe | sort asc | to markdown",
                initialPayload: .text(csv),
                allowSideEffects: false
            )
            precondition(res.succeeded)
            let rps = Double(rowCount) / max(res.totalDurationMs / 1000.0, 0.0001)
            scalePoints.append(PipeScalePoint(rowCount: rowCount, totalDurationMs: res.totalDurationMs, rowsPerSecond: rps))
        }

        // 3. Five Real Multi-Stage Cross-App Workflows
        var workflows: [WorkflowBenchmarkPoint] = []

        // 3a. 500 Browser Tabs Cleaner
        let tabs: [TabItem] = (0..<500).map { i in
            TabItem(
                browser: i % 2 == 0 ? "Chrome" : "Safari",
                title: "Engineering Doc #\(i % 250)",
                url: "https://docs.example.dev/guide/\(i % 250)?utm_source=slack&fbclid=xyz\(i)&gclid=99"
            )
        }
        let tabRes = PipelineEngine.execute(
            command: "tabs | clean urls | dedupe | sort asc | to markdown | copy",
            initialPayload: .urls(tabs),
            allowSideEffects: false
        )
        precondition(tabRes.succeeded)
        workflows.append(WorkflowBenchmarkPoint(
            label: "500 Tabs Cleaner",
            commandSummary: "tabs | clean urls | dedupe | to markdown | copy",
            durationMs: tabRes.totalDurationMs,
            manualClicksReplaced: 34
        ))

        // 3b. 10,000-Line Log Secret Scrubber & Error Summary
        let logLines: [String] = (0..<10_000).map { i in
            if i % 25 == 0 {
                return "2026-11-23 ERROR shard=\(i) OPENAI_API_KEY=sk-proj-abc123def456ghi789jkl012mno345"
            }
            return "2026-11-23 INFO heartbeat ok shard=\(i)"
        }
        let logRes = PipelineEngine.execute(
            command: "clipboard | filter ERROR | redact | summarize | copy",
            initialPayload: .lines(logLines),
            allowSideEffects: false
        )
        precondition(logRes.succeeded && !logRes.output.asText().contains("sk-proj-"))
        workflows.append(WorkflowBenchmarkPoint(
            label: "10K Log Scrubber",
            commandSummary: "clip | filter ERROR | redact | summarize",
            durationMs: logRes.totalDurationMs,
            manualClicksReplaced: 18
        ))

        // 3c. Real Multi-Page PDFKit Extraction -> Table -> Merged CSV
        let pdfData = makeSyntheticPDF(pages: [
            ["Vendor,InvoiceID,AmountUSD", "Acme Cloud,INV-2026-8841,4200", "Northstar AI,INV-2026-8842,3600"],
            ["Kestrel Dev,INV-2026-8843,890", "Velox Bio,INV-2026-8844,5100"]
        ])
        let tempPDF = FileManager.default.temporaryDirectory.appendingPathComponent("pipebar-bench-\(UUID().uuidString).pdf")
        try pdfData.write(to: tempPDF)
        defer { try? FileManager.default.removeItem(at: tempPDF) }

        let pdfRes = PipelineEngine.execute(
            command: "selected pdfs | pdf text | extract tables | merge csv | copy",
            initialPayload: .files([tempPDF]),
            allowSideEffects: false
        )
        let pdfVerified = pdfRes.succeeded && pdfRes.output.asText().contains("INV-2026-8841") && pdfRes.output.asText().contains("Velox Bio")
        workflows.append(WorkflowBenchmarkPoint(
            label: "PDFKit Table Merge",
            commandSummary: "selected pdfs | pdf text | tables | merge csv",
            durationMs: pdfRes.totalDurationMs,
            manualClicksReplaced: 22
        ))

        // 3d. 5K CSV -> JSON Pipeline
        var csv5k = "ID,Email,Plan\n"
        for i in 0..<5_000 { csv5k += "\(i),user\(i)@acme.io,Enterprise\n" }
        let jsonRes = PipelineEngine.execute(
            command: "clipboard | extract tables | to json | copy",
            initialPayload: .text(csv5k),
            allowSideEffects: false
        )
        precondition(jsonRes.succeeded)
        workflows.append(WorkflowBenchmarkPoint(
            label: "5K CSV → JSON",
            commandSummary: "clip | extract tables | to json | copy",
            durationMs: jsonRes.totalDurationMs,
            manualClicksReplaced: 15
        ))

        // 3e. Real Apple Vision OCR -> URL Extractor
        let ocrImg = makeSyntheticInvoiceImage(lines: [
            "Invoice INV-2026-9920 Paid $4200",
            "Portal https://dashboard.stripe.com/invoices/9920",
            "Contact billing@acmerobotics.io"
        ])!
        let ocrStart = CFAbsoluteTimeGetCurrent()
        let ocrText = try DataTransformers.runVisionOCR(on: ocrImg)
        let ocrPipe = PipelineEngine.execute(
            command: "clipboard | extract urls | clean urls | to markdown",
            initialPayload: .text(ocrText),
            allowSideEffects: false
        )
        let ocrTotalMs = (CFAbsoluteTimeGetCurrent() - ocrStart) * 1000.0
        let ocrVerified = ocrPipe.succeeded && ocrText.lowercased().contains("invoice")
        workflows.append(WorkflowBenchmarkPoint(
            label: "Vision OCR → Links",
            commandSummary: "selected images | ocr | extract urls | md",
            durationMs: ocrTotalMs,
            manualClicksReplaced: 14
        ))

        let iso = ISO8601DateFormatter().string(from: Date())
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        #if arch(arm64)
        let arch = "Apple Silicon (arm64)"
        #else
        let arch = "Intel (x86_64)"
        #endif

        return PipeBarBenchmarkReport(
            generatedAtISO8601: iso,
            hostArchitecture: arch,
            osVersion: osVer,
            parserAutocompleteAvgMs: parserAvgMs,
            pdfKitExtractVerified: pdfVerified,
            visionOCRVerified: ocrVerified,
            scalePoints: scalePoints,
            workflowBenchmarks: workflows
        )
    }
}
