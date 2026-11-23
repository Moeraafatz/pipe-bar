import Foundation
import PipeBarCore
import XCTest

final class PipeBarTests: XCTestCase {
    func testParserSplitsQuotedPipesResolvesAliasesAndAutocompletes() {
        let parsed = PipelineParser.parse(#"clip | filter "error | fatal" | unique | md table | pbcopy"#)
        XCTAssertTrue(parsed.isValid, "Expected valid pipeline, got diagnostics: \(parsed.diagnostics)")
        XCTAssertEqual(parsed.stages.map(\.name), ["clipboard", "filter", "dedupe", "to markdown", "copy"])
        XCTAssertEqual(parsed.stages[1].arguments, ["error | fatal"])

        let suggestions = PipelineParser.autocomplete(for: "tabs | clean", limit: 5)
        XCTAssertEqual(suggestions.first?.command, "clean urls")
    }

    @MainActor
    func testBrowserTabsTrackerCleanerDedupeAndMarkdownPipeline() {
        let result = PipelineEngine.execute(
            command: "demo tabs | clean urls | dedupe | sort asc | to markdown",
            allowSideEffects: false
        )
        XCTAssertTrue(result.succeeded)
        let out = result.output.asText()
        XCTAssertFalse(out.contains("utm_source"))
        XCTAssertFalse(out.contains("fbclid"))
        XCTAssertFalse(out.contains("gclid"))
        // 5 demo tabs contain 1 duplicate sqlite.org URL after tracker stripping -> 4 unique markdown links
        XCTAssertEqual(out.components(separatedBy: .newlines).count, 4)
    }

    @MainActor
    func testSecretRedactionAndLogSummaryPipeline() {
        let result = PipelineEngine.execute(
            command: "demo logs | filter ERROR | redact | summarize",
            allowSideEffects: false
        )
        XCTAssertTrue(result.succeeded)
        let out = result.output.asText()
        XCTAssertFalse(out.contains("sk-proj-"))
        XCTAssertTrue(out.contains("[REDACTED:OPENAI_KEY]"))
        XCTAssertTrue(out.contains("Summary: 2 lines"))
    }

    @MainActor
    func testRealPDFKitMultiPageTableMergePipeline() throws {
        let pdfData = PipeBarBenchmarkRunner.makeSyntheticPDF(pages: [
            ["Vendor,InvoiceID,AmountUSD", "Acme Cloud,INV-2026-8841,4200"],
            ["Northstar AI,INV-2026-8842,3600"]
        ])
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pb-test-\(UUID().uuidString).pdf")
        try pdfData.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = PipelineEngine.execute(
            command: "selected pdfs | pdf text | extract tables | merge csv",
            initialPayload: .files([tmp]),
            allowSideEffects: false
        )
        XCTAssertTrue(result.succeeded)
        let csv = result.output.asText()
        XCTAssertTrue(csv.contains("Acme Cloud,INV-2026-8841,4200"), "Got CSV: \(csv)")
        XCTAssertTrue(csv.contains("Northstar AI,INV-2026-8842,3600"), "Got CSV: \(csv)")
    }

    @MainActor
    func testRealVisionOCRPipelineAndSQLiteRecipeStore() async throws {
        let img = try XCTUnwrap(PipeBarBenchmarkRunner.makeSyntheticInvoiceImage(lines: [
            "Invoice INV-2026-7701",
            "https://docs.stripe.com/webhooks?utm_source=email"
        ]))
        let text = try DataTransformers.runVisionOCR(on: img)
        XCTAssertTrue(text.lowercased().contains("invoice"), "Unexpected OCR: \(text)")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pb-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = try RecipeStore(databaseURL: dir.appendingPathComponent("recipes.sqlite"))
        let recipe = SavedRecipe(title: "Clean Tabs", summary: "Strip trackers", command: "tabs | clean urls | copy", runCount: 5)
        try await store.upsert(recipe)
        let loaded = try await store.fetchAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Clean Tabs")
    }
}
