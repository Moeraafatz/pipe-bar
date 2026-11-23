import Foundation
import PipeBarCore

public enum PipeSampleData {
    public static func demoRecipes() -> [SavedRecipe] {
        [
            SavedRecipe(
                title: "Selected PDFs → Merged CSV",
                summary: "Extracts text & line-item tables from Finder-selected PDF invoices, dedupes, merges CSV & copies.",
                command: "selected pdfs | pdf text | extract tables | dedupe | merge csv | copy",
                hotkey: "⌥1",
                runCount: 184,
                manualClicksReplaced: 22,
                lastDurationMs: 14.2
            ),
            SavedRecipe(
                title: "Clean & Dedupe Open Browser Tabs",
                summary: "Reads Safari/Chrome/Arc tabs, strips utm/fbclid/gclid trackers, dedupes & renders Markdown list.",
                command: "tabs | clean urls | dedupe | sort asc | to markdown | copy",
                hotkey: "⌥2",
                runCount: 312,
                manualClicksReplaced: 34,
                lastDurationMs: 4.8
            ),
            SavedRecipe(
                title: "Scrub API Secrets & Summarize Logs",
                summary: "Filters ERROR lines from clipboard logs, scrubs OpenAI/AWS/GitHub keys & summarizes.",
                command: "clipboard | filter ERROR | redact | summarize | copy",
                hotkey: "⌥3",
                runCount: 97,
                manualClicksReplaced: 18,
                lastDurationMs: 2.1
            ),
            SavedRecipe(
                title: "Vision OCR Screenshot → Extract Links",
                summary: "Runs offline Apple Vision OCR on selected screenshots, strips trackers & appends Markdown note.",
                command: "selected images | ocr | extract urls | clean urls | note",
                hotkey: "⌥4",
                runCount: 68,
                manualClicksReplaced: 14,
                lastDurationMs: 128.0
            )
        ]
    }

    public static func demoTraces() -> [StageExecutionTrace] {
        [
            StageExecutionTrace(stageName: "demo", rawCommand: "demo invoice", category: .source, inputCount: 0, outputCount: 6, outputType: "TEXT", durationMs: 0.04, note: "demo:invoice"),
            StageExecutionTrace(stageName: "extract tables", rawCommand: "extract tables", category: .transform, inputCount: 6, outputCount: 5, outputType: "TABLE", durationMs: 0.18, note: "5 rows × 4 cols"),
            StageExecutionTrace(stageName: "filter", rawCommand: "filter Enterprise", category: .transform, inputCount: 5, outputCount: 4, outputType: "TABLE", durationMs: 0.09, note: "4/5 rows"),
            StageExecutionTrace(stageName: "dedupe", rawCommand: "dedupe", category: .transform, inputCount: 4, outputCount: 3, outputType: "TABLE", durationMs: 0.06, note: "removed 1 dup"),
            StageExecutionTrace(stageName: "to markdown", rawCommand: "to markdown", category: .transform, inputCount: 3, outputCount: 5, outputType: "TEXT", durationMs: 0.08, note: "GFM Markdown")
        ]
    }

    public static let demoOutputMarkdown: String = """
    | Vendor | InvoiceID | Plan | AmountUSD |
    | --- | --- | --- | --- |
    | Acme Cloud | INV-2026-8841 | Enterprise | 4200 |
    | Northstar AI | INV-2026-8842 | Enterprise | 3600 |
    | Velox Bio | INV-2026-8844 | Enterprise | 5100 |
    """
}
