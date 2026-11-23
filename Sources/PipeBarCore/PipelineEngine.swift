import AppKit
import CoreGraphics
import Foundation
import ImageIO

public enum PipelineEngine {
    public static func demoPayload(preset: String) -> PipePayload {
        switch preset.lowercased() {
        case "tabs":
            return .urls([
                TabItem(browser: "Safari", title: "Swift 6 Concurrency Migration", url: "https://swift.org/migration?utm_source=x&utm_medium=social"),
                TabItem(browser: "Chrome", title: "SQLite FTS5 Reference", url: "https://sqlite.org/fts5.html?ref=hn&fbclid=abc123"),
                TabItem(browser: "Chrome", title: "SQLite FTS5 Reference", url: "https://sqlite.org/fts5.html?utm_campaign=weekly"),
                TabItem(browser: "Arc", title: "Apple PDFKit Documentation", url: "https://developer.apple.com/documentation/pdfkit?gclid=xyz99"),
                TabItem(browser: "Safari", title: "Stripe Billing Webhooks", url: "https://docs.stripe.com/webhooks?si=track88")
            ])
        case "logs":
            return .lines([
                "2026-11-23 09:12:01 INFO worker boot ok",
                "2026-11-23 09:12:04 ERROR SQLITE_BUSY on checkpoint OPENAI_API_KEY=sk-proj-abc123def456ghi789jkl012mno345",
                "2026-11-23 09:12:06 WARN retrying commit with backoff 150ms",
                "2026-11-23 09:12:08 ERROR upstream timeout https://api.stripe.com/v1/invoices?utm_source=debug",
                "2026-11-23 09:12:12 INFO recovered cleanly in 42ms"
            ])
        case "invoice":
            return .text("""
            Vendor,InvoiceID,Plan,AmountUSD
            Acme Cloud,INV-2026-8841,Enterprise,4200
            Northstar AI,INV-2026-8842,Enterprise,3600
            Acme Cloud,INV-2026-8841,Enterprise,4200
            Kestrel Dev,INV-2026-8843,Pro,890
            Velox Bio,INV-2026-8844,Enterprise,5100
            """)
        default:
            return .text("""
            Company,Tier,Seats,MRR
            Acme Robotics,Enterprise,45,4200
            Northstar Labs,Enterprise,32,3100
            Kestrel Cloud,Pro,12,720
            Velox Bio,Enterprise,60,5400
            Acme Robotics,Enterprise,45,4200
            """)
        }
    }

    @MainActor
    public static func execute(
        command: String,
        initialPayload: PipePayload? = nil,
        config: PipeSafetyConfig = .default,
        allowSideEffects: Bool = true
    ) -> PipelineRunResult {
        let totalStart = CFAbsoluteTimeGetCurrent()
        let parsed = PipelineParser.parse(command)
        guard parsed.isValid else {
            return PipelineRunResult(
                command: command,
                output: .empty,
                traces: [],
                totalDurationMs: (CFAbsoluteTimeGetCurrent() - totalStart) * 1000.0,
                succeeded: false,
                errorMessage: parsed.diagnostics.joined(separator: "; ")
            )
        }

        var current: PipePayload = initialPayload ?? .empty
        var traces: [StageExecutionTrace] = []

        for stage in parsed.stages {
            let t0 = CFAbsoluteTimeGetCurrent()
            let inputCount = current.itemCount
            var note = ""

            do {
                let (nextPayload, stageNote) = try runStage(
                    stage,
                    input: current,
                    hasInjectedInput: initialPayload != nil,
                    config: config,
                    allowSideEffects: allowSideEffects
                )
                current = nextPayload
                note = stageNote
            } catch {
                let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
                traces.append(StageExecutionTrace(
                    stageName: stage.name,
                    rawCommand: stage.rawCommand,
                    category: stage.category,
                    inputCount: inputCount,
                    outputCount: current.itemCount,
                    outputType: "ERR",
                    durationMs: elapsed,
                    note: error.localizedDescription
                ))
                return PipelineRunResult(
                    command: command,
                    output: current,
                    traces: traces,
                    totalDurationMs: (CFAbsoluteTimeGetCurrent() - totalStart) * 1000.0,
                    succeeded: false,
                    errorMessage: error.localizedDescription
                )
            }

            let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
            traces.append(StageExecutionTrace(
                stageName: stage.name,
                rawCommand: stage.rawCommand,
                category: stage.category,
                inputCount: inputCount,
                outputCount: current.itemCount,
                outputType: current.typeBadge,
                durationMs: elapsed,
                note: note
            ))
        }

        return PipelineRunResult(
            command: command,
            output: current,
            traces: traces,
            totalDurationMs: (CFAbsoluteTimeGetCurrent() - totalStart) * 1000.0,
            succeeded: true
        )
    }

    @MainActor
    private static func runStage(
        _ stage: PipeStageSpec,
        input: PipePayload,
        hasInjectedInput: Bool,
        config: PipeSafetyConfig,
        allowSideEffects: Bool
    ) throws -> (PipePayload, String) {
        switch stage.name {
        // MARK: Sources
        case "clipboard":
            if hasInjectedInput && input != .empty { return (input, "injected input") }
            return (MacAdapters.readClipboard(), "NSPasteboard")

        case "selected":
            if hasInjectedInput && input != .empty { return (input, "injected selection") }
            let urls = MacAdapters.readFinderSelection(extensionFilter: stage.arguments.first)
            return (.files(urls), "\(urls.count) Finder item(s)")

        case "tabs":
            if hasInjectedInput && input != .empty { return (input, "injected tabs") }
            let tabs = MacAdapters.readBrowserTabs(browserHint: stage.arguments.first)
            return (.urls(tabs), "\(tabs.count) browser tab(s)")

        case "file":
            guard let rawPath = stage.arguments.first else {
                throw NSError(domain: "PipeBar.Stage", code: 1, userInfo: [NSLocalizedDescriptionKey: "file requires a path argument"])
            }
            let path = (rawPath as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: path)
            let ext = url.pathExtension.lowercased()
            if ["pdf", "png", "jpg", "jpeg", "heic", "tiff"].contains(ext) {
                return (.files([url]), url.lastPathComponent)
            }
            let str = try String(contentsOf: url, encoding: .utf8)
            return (.text(str), url.lastPathComponent)

        case "demo":
            let preset = stage.arguments.first ?? "csv"
            return (demoPayload(preset: preset), "demo:\(preset)")

        // MARK: Transforms
        case "pdf text":
            if case .files(let urls) = input {
                let text = DataTransformers.extractPDFText(from: urls)
                return (.text(text), "PDFKit \(urls.count) PDF(s)")
            }
            return (input, "passthrough")

        case "ocr":
            if case .files(let urls) = input {
                var blocks: [String] = []
                for url in urls {
                    if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                       let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                        let text = try DataTransformers.runVisionOCR(on: cg)
                        if !text.isEmpty { blocks.append(text) }
                    }
                }
                return (.text(blocks.joined(separator: "\n\n")), "Vision OCR \(urls.count) image(s)")
            }
            return (input, "passthrough")

        case "extract tables":
            if case .table = input { return (input, "already table") }
            let table = DataTransformers.parseTable(from: input.asText())
            return (.table(table), "\(table.rows.count) rows × \(table.headers.count) cols")

        case "extract urls":
            let found = DataTransformers.extractURLs(from: input.asText())
            return (.urls(found), "\(found.count) URL(s)")

        case "extract emails":
            let emails = DataTransformers.extractEmails(from: input.asText())
            return (.lines(emails), "\(emails.count) email(s)")

        case "clean urls":
            switch input {
            case .urls(let items):
                let cleaned = items.map { TabItem(browser: $0.browser, title: $0.title, url: DataTransformers.cleanURLString($0.url)) }
                return (.urls(cleaned), "stripped tracking params")
            default:
                let lines = input.asLines().map { DataTransformers.cleanURLString($0) }
                return (.lines(lines), "cleaned \(lines.count) line(s)")
            }

        case "dedupe":
            switch input {
            case .urls(let items):
                var seen = Set<String>()
                let unique = items.filter { seen.insert($0.url.lowercased()).inserted }
                return (.urls(unique), "removed \(items.count - unique.count) dup(s)")
            case .table(var tbl):
                var seen = Set<String>()
                let before = tbl.rows.count
                tbl.rows = tbl.rows.filter { seen.insert($0.joined(separator: "\u{1F}")).inserted }
                return (.table(tbl), "removed \(before - tbl.rows.count) dup row(s)")
            default:
                var seen = Set<String>()
                let src = input.asLines()
                let unique = src.filter { seen.insert($0).inserted }
                return (.lines(unique), "removed \(src.count - unique.count) dup(s)")
            }

        case "sort":
            let desc = stage.arguments.first?.lowercased() == "desc"
            switch input {
            case .urls(let items):
                let sorted = items.sorted { desc ? $0.title.lowercased() > $1.title.lowercased() : $0.title.lowercased() < $1.title.lowercased() }
                return (.urls(sorted), desc ? "desc" : "asc")
            case .table(var tbl):
                tbl.rows.sort { a, b in
                    let lhs = (a.first ?? "").lowercased()
                    let rhs = (b.first ?? "").lowercased()
                    return desc ? lhs > rhs : lhs < rhs
                }
                return (.table(tbl), desc ? "desc" : "asc")
            default:
                let sorted = input.asLines().sorted { desc ? $0.lowercased() > $1.lowercased() : $0.lowercased() < $1.lowercased() }
                return (.lines(sorted), desc ? "desc" : "asc")
            }

        case "filter", "exclude":
            let needle = stage.arguments.joined(separator: " ").lowercased()
            let invert = (stage.name == "exclude")
            guard !needle.isEmpty else { return (input, "empty pattern") }
            switch input {
            case .urls(let items):
                let kept = items.filter {
                    let hit = $0.title.lowercased().contains(needle) || $0.url.lowercased().contains(needle)
                    return invert ? !hit : hit
                }
                return (.urls(kept), "\(kept.count)/\(items.count) kept")
            case .table(var tbl):
                let before = tbl.rows.count
                tbl.rows = tbl.rows.filter { row in
                    let hit = row.joined(separator: " ").lowercased().contains(needle)
                    return invert ? !hit : hit
                }
                return (.table(tbl), "\(tbl.rows.count)/\(before) rows")
            default:
                let src = input.asLines()
                let kept = src.filter {
                    let hit = $0.lowercased().contains(needle)
                    return invert ? !hit : hit
                }
                return (.lines(kept), "\(kept.count)/\(src.count) lines")
            }

        case "redact":
            let (clean, count) = DataTransformers.redactSecrets(in: input.asText())
            return (.text(clean), "\(count) secret(s) scrubbed")

        case "summarize":
            return (.text(DataTransformers.summarize(payload: input)), "local extractive")

        case "merge csv":
            switch input {
            case .table(let t):
                return (.text(DataTransformers.encodeCSV(table: t)), "\(t.rows.count) CSV rows")
            default:
                let parsed = DataTransformers.parseTable(from: input.asText())
                return (.text(DataTransformers.encodeCSV(table: parsed)), "\(parsed.rows.count) CSV rows")
            }

        case "to markdown":
            return (.text(DataTransformers.encodeMarkdown(payload: input)), "GFM Markdown")

        case "to json":
            return (.json(DataTransformers.encodeJSON(payload: input)), "pretty JSON")

        case "count":
            let lines = input.asLines()
            let words = lines.reduce(0) { $0 + $1.split(separator: " ").count }
            let chars = input.asText().count
            return (.text("items: \(input.itemCount) · lines: \(lines.count) · words: \(words) · bytes: \(chars)"), "stats")

        case "head", "tail":
            let n = max(1, Int(stage.arguments.first ?? "10") ?? 10)
            let isHead = stage.name == "head"
            switch input {
            case .table(var tbl):
                tbl.rows = isHead ? Array(tbl.rows.prefix(n)) : Array(tbl.rows.suffix(n))
                return (.table(tbl), "\(tbl.rows.count) rows")
            case .urls(let items):
                let sliced = isHead ? Array(items.prefix(n)) : Array(items.suffix(n))
                return (.urls(sliced), "\(sliced.count) tabs")
            default:
                let src = input.asLines()
                let sliced = isHead ? Array(src.prefix(n)) : Array(src.suffix(n))
                return (.lines(sliced), "\(sliced.count) lines")
            }

        case "sh":
            guard config.allowLocalShellPlugins else {
                throw NSError(domain: "PipeBar.Safety", code: 2, userInfo: [NSLocalizedDescriptionKey: "Local shell plugins disabled in Safety settings"])
            }
            guard let pluginName = stage.arguments.first else {
                throw NSError(domain: "PipeBar.Plugin", code: 3, userInfo: [NSLocalizedDescriptionKey: "Specify plugin name inside ~/.config/pipebar/plugins/"])
            }
            let out = try MacAdapters.runLocalPlugin(named: pluginName, input: input.asText())
            return (.text(out), "plugin:\(pluginName)")

        // MARK: Sinks
        case "copy":
            var payloadStr = input.asText()
            if config.autoRedactBeforeCopy {
                let (clean, _) = DataTransformers.redactSecrets(in: payloadStr)
                payloadStr = clean
            }
            if allowSideEffects {
                MacAdapters.writeClipboard(payloadStr)
            }
            return (.text(payloadStr), allowSideEffects ? "copied to clipboard" : "dry-run copy")

        case "save":
            let target = stage.arguments.first ?? "pipebar-output.txt"
            if allowSideEffects {
                let savedURL = try MacAdapters.saveOutput(input.asText(), pathArg: target)
                return (.files([savedURL]), "saved \(savedURL.lastPathComponent)")
            }
            return (input, "dry-run save \(target)")

        case "note":
            if allowSideEffects {
                let md = DataTransformers.encodeMarkdown(payload: input)
                let noteURL = try MacAdapters.appendMarkdownNote(md, directoryPath: config.defaultNotesDirectory)
                return (.files([noteURL]), "appended \(noteURL.lastPathComponent)")
            }
            return (input, "dry-run note")

        case "open":
            if allowSideEffects {
                switch input {
                case .files(let urls):
                    for u in urls.prefix(3) { NSWorkspace.shared.open(u) }
                case .urls(let tabs):
                    for t in tabs.prefix(3) {
                        if let u = URL(string: t.url) { NSWorkspace.shared.open(u) }
                    }
                default:
                    break
                }
            }
            return (input, allowSideEffects ? "opened in macOS" : "dry-run open")

        default:
            throw NSError(domain: "PipeBar.Stage", code: 99, userInfo: [NSLocalizedDescriptionKey: "Unsupported stage: \(stage.name)"])
        }
    }
}
