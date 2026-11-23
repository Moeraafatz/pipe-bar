import Foundation
import PipeBarCore

@main
struct PipeBarToolsMain {
    static func main() async {
        do {
            let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let docsDir = root.appendingPathComponent("docs", isDirectory: true)
            let screenshotsDir = docsDir.appendingPathComponent("screenshots", isDirectory: true)
            let graphsDir = docsDir.appendingPathComponent("graphs", isDirectory: true)
            let assetsDir = docsDir.appendingPathComponent("assets", isDirectory: true)
            let iconsetDir = root.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)

            print("[PipeBarTools] Generating macOS AppIcon set...")
            try PipeIconGenerator.generateIconSet(
                iconsetURL: iconsetDir,
                docsIconURL: assetsDir.appendingPathComponent("icon.png")
            )

            print("[PipeBarTools] Rendering SwiftUI Retina screenshots...")
            try await MainActor.run {
                try PipeScreenshotRenderer.renderAll(outputDir: screenshotsDir)
            }

            print("[PipeBarTools] Running Apple Silicon Pipeline, PDFKit & Vision benchmarks...")
            let report = try await MainActor.run {
                try PipeBarBenchmarkRunner.runFullSuite()
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(report)
            try jsonData.write(to: docsDir.appendingPathComponent("benchmarks.json"))

            print("[PipeBarTools] Rendering benchmark graphs & architecture SVG...")
            try PipeGraphRenderer.renderAll(report: report, outputDir: graphsDir)

            let summary = makeBenchmarkMarkdown(report: report)
            try summary.write(to: docsDir.appendingPathComponent("benchmark-summary.md"), atomically: true, encoding: .utf8)

            print("[PipeBarTools] Complete!")
            print(summary)
        } catch {
            fputs("[PipeBarTools] ERROR: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func makeBenchmarkMarkdown(report: PipeBarBenchmarkReport) -> String {
        var scaleRows = ""
        for pt in report.scalePoints {
            scaleRows += String(
                format: "| %d rows | **%.2f ms** | **%.0f rows/s** |\n",
                pt.rowCount, pt.totalDurationMs, pt.rowsPerSecond
            )
        }

        var wfRows = ""
        for wf in report.workflowBenchmarks {
            let escapedCmd = wf.commandSummary.replacingOccurrences(of: "|", with: "\\|")
            wfRows += String(
                format: "| %@ | `%@` | **%.2f ms** | %d → 1 |\n",
                wf.label, escapedCmd, wf.durationMs, wf.manualClicksReplaced
            )
        }

        return """
        ### Measured Benchmarks (\(report.hostArchitecture) · \(report.osVersion))

        - **Live Keystroke Parser + Autocomplete:** **`\(String(format: "%.3f ms", report.parserAutocompleteAvgMs))`** avg across 500 8-stage parses (well inside 120 FPS `8.33 ms` budget)
        - **End-to-End Media Pipelines Verified:** Apple `PDFKit` multi-page table merge (**\(report.pdfKitExtractVerified ? "PASS" : "FAIL")**) · Apple `Vision` OCR URL extractor (**\(report.visionOCRVerified ? "PASS" : "FAIL")**)

        #### 1. 5-Stage Typed Pipeline Throughput (`extract tables | filter | dedupe | sort | to markdown`)

        | Input Volume | Total Pipeline Time | Throughput |
        | ---: | ---: | ---: |
        \(scaleRows)
        #### 2. End-to-End Cross-App Workflows

        | Workflow | Pipeline Command | Measured Time | Manual Clicks |
        | :--- | :--- | ---: | ---: |
        \(wfRows)
        """
    }
}
