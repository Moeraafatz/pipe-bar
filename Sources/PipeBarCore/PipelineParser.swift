import Foundation

public enum PipelineParser {
    public static let catalog: [StageCatalogEntry] = [
        // Sources
        StageCatalogEntry(command: "clipboard", aliases: ["clip", "pb"], category: .source, summary: "Read live macOS clipboard text or URLs", example: "clipboard | clean urls | copy"),
        StageCatalogEntry(command: "selected", aliases: ["finder", "files"], category: .source, summary: "Read active Finder file selection (pdfs, images, md)", example: "selected pdfs | pdf text | merge csv"),
        StageCatalogEntry(command: "tabs", aliases: ["browser", "chrome", "safari"], category: .source, summary: "Read open Safari, Chrome, or Arc browser tabs", example: "tabs | clean urls | dedupe | to markdown"),
        StageCatalogEntry(command: "file", aliases: ["read"], category: .source, summary: "Read local text, CSV, JSON, PDF, or image path", example: "file ~/Desktop/data.csv | filter paid | to json"),
        StageCatalogEntry(command: "demo", aliases: [], category: .source, summary: "Load built-in sample (tabs, csv, logs, invoice)", example: "demo tabs | clean urls | dedupe | md table"),

        // Transforms
        StageCatalogEntry(command: "pdf text", aliases: ["pdftext"], category: .transform, summary: "Extract full text from piped PDFs via PDFKit", example: "selected pdfs | pdf text | extract tables"),
        StageCatalogEntry(command: "ocr", aliases: ["vision"], category: .transform, summary: "Run offline Apple Vision OCR on piped images", example: "selected images | ocr | extract urls"),
        StageCatalogEntry(command: "extract tables", aliases: ["tables", "parse csv"], category: .transform, summary: "Parse CSV, TSV, or invoice rows into typed table", example: "clipboard | extract tables | to markdown"),
        StageCatalogEntry(command: "extract urls", aliases: ["urls"], category: .transform, summary: "Extract all HTTP/HTTPS links via NSDataDetector", example: "clipboard | extract urls | clean urls | dedupe"),
        StageCatalogEntry(command: "extract emails", aliases: ["emails"], category: .transform, summary: "Extract all unique email addresses", example: "clipboard | extract emails | sort | copy"),
        StageCatalogEntry(command: "clean urls", aliases: ["strip trackers"], category: .transform, summary: "Strip utm_*, fbclid, gclid, ref & si trackers", example: "tabs | clean urls | dedupe"),
        StageCatalogEntry(command: "dedupe", aliases: ["unique", "uniq"], category: .transform, summary: "Remove duplicate lines, URLs, or rows in order", example: "tabs | dedupe | sort"),
        StageCatalogEntry(command: "sort", aliases: [], category: .transform, summary: "Sort lines or table rows (asc / desc)", example: "clipboard | dedupe | sort asc"),
        StageCatalogEntry(command: "filter", aliases: ["grep"], category: .transform, summary: "Keep items matching substring or regex", example: "demo logs | filter error | head 20"),
        StageCatalogEntry(command: "exclude", aliases: ["grepv"], category: .transform, summary: "Drop items matching substring or regex", example: "tabs | exclude localhost | to markdown"),
        StageCatalogEntry(command: "redact", aliases: ["scrub"], category: .transform, summary: "Scrub API keys, JWTs, AWS & GitHub secrets", example: "clipboard | redact | copy"),
        StageCatalogEntry(command: "summarize", aliases: ["summary"], category: .transform, summary: "Extractive local summary + key stats (0 API)", example: "demo logs | filter error | summarize"),
        StageCatalogEntry(command: "merge csv", aliases: ["to csv", "csv"], category: .transform, summary: "Encode table or rows to RFC-4180 CSV", example: "selected pdfs | extract tables | merge csv"),
        StageCatalogEntry(command: "to markdown", aliases: ["md", "md table"], category: .transform, summary: "Render table, tabs, or list as Markdown", example: "tabs | clean urls | to markdown"),
        StageCatalogEntry(command: "to json", aliases: ["json", "pretty json"], category: .transform, summary: "Format JSON or serialize table/lines as JSON", example: "clipboard | extract tables | to json"),
        StageCatalogEntry(command: "count", aliases: ["stats"], category: .transform, summary: "Compute items, words, unique domains & sums", example: "tabs | count"),
        StageCatalogEntry(command: "head", aliases: ["take"], category: .transform, summary: "Take first N lines or rows", example: "demo csv | sort desc | head 10"),
        StageCatalogEntry(command: "tail", aliases: [], category: .transform, summary: "Take last N lines or rows", example: "demo logs | tail 15"),

        // Sinks
        StageCatalogEntry(command: "copy", aliases: ["pbcopy"], category: .sink, summary: "Write final output straight to macOS clipboard", example: "tabs | clean urls | to markdown | copy"),
        StageCatalogEntry(command: "save", aliases: ["export"], category: .sink, summary: "Write output file (.csv, .md, .json, .txt)", example: "demo csv | to json | save report.json"),
        StageCatalogEntry(command: "note", aliases: ["append note"], category: .sink, summary: "Append Markdown output to local PipeBar note", example: "tabs | summarize | note"),
        StageCatalogEntry(command: "open", aliases: [], category: .sink, summary: "Open output file or URL in default macOS app", example: "demo csv | merge csv | save out.csv | open")
    ]

    private static let twoWordCommands: Set<String> = [
        "pdf text", "extract tables", "parse csv", "extract urls", "extract emails",
        "clean urls", "strip trackers", "merge csv", "to csv", "to markdown",
        "md table", "to json", "pretty json", "append note"
    ]

    public static func parse(_ input: String) -> ParsedPipeline {
        let segments = splitUnquotedPipes(input)
        var stages: [PipeStageSpec] = []
        var diagnostics: [String] = []

        for rawSeg in segments {
            let trimmed = rawSeg.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                diagnostics.append("Empty stage between pipe operators")
                continue
            }
            let tokens = tokenize(trimmed)
            guard !tokens.isEmpty else { continue }

            let twoWord = tokens.count >= 2 ? "\(tokens[0].lowercased()) \(tokens[1].lowercased())" : ""
            let matchedName: String
            let args: [String]
            if twoWordCommands.contains(twoWord) {
                matchedName = canonicalCommand(for: twoWord)
                args = Array(tokens.dropFirst(2))
            } else {
                matchedName = canonicalCommand(for: tokens[0].lowercased())
                args = Array(tokens.dropFirst(1))
            }

            if let entry = catalog.first(where: { $0.command == matchedName }) {
                stages.append(PipeStageSpec(
                    rawCommand: trimmed,
                    name: entry.command,
                    arguments: args,
                    category: entry.category
                ))
            } else if matchedName == "sh" {
                stages.append(PipeStageSpec(
                    rawCommand: trimmed,
                    name: "sh",
                    arguments: args,
                    category: .transform
                ))
            } else {
                diagnostics.append("Unknown stage: \"\(tokens[0])\"")
            }
        }

        return ParsedPipeline(rawInput: input, stages: stages, diagnostics: diagnostics)
    }

    public static func autocomplete(for input: String, limit: Int = 6) -> [StageCatalogEntry] {
        let parts = splitUnquotedPipes(input)
        let trailing = (parts.last ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isFirstStage = parts.count <= 1

        if trailing.isEmpty {
            let preferred: StageCategory = isFirstStage ? .source : .transform
            let filtered = catalog.filter { $0.category == preferred || (!isFirstStage && $0.category == .sink) }
            return Array(filtered.prefix(limit))
        }

        let scored: [(StageCatalogEntry, Int)] = catalog.compactMap { entry in
            if entry.command.hasPrefix(trailing) { return (entry, 100) }
            if entry.aliases.contains(where: { $0.hasPrefix(trailing) }) { return (entry, 85) }
            if entry.command.contains(trailing) { return (entry, 65) }
            if entry.summary.lowercased().contains(trailing) { return (entry, 40) }
            return nil
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    private static func canonicalCommand(for raw: String) -> String {
        for entry in catalog {
            if entry.command == raw || entry.aliases.contains(raw) {
                return entry.command
            }
        }
        return raw
    }

    private static func splitUnquotedPipes(_ input: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quoteChar: Character? = nil

        for ch in input {
            if let q = quoteChar {
                if ch == q {
                    quoteChar = nil
                }
                current.append(ch)
            } else {
                if ch == "\"" || ch == "'" {
                    quoteChar = ch
                    current.append(ch)
                } else if ch == "|" {
                    result.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        result.append(current)
        return result
    }

    private static func tokenize(_ segment: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quoteChar: Character? = nil

        for ch in segment {
            if let q = quoteChar {
                if ch == q {
                    quoteChar = nil
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" || ch == "'" {
                    quoteChar = ch
                } else if ch.isWhitespace {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                } else {
                    current.append(ch)
                }
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}
