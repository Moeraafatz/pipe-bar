import CoreGraphics
import Foundation
@preconcurrency import PDFKit
@preconcurrency import Vision

public enum DataTransformers {
    private static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        "fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid", "ref", "ref_src",
        "si", "igshid", "yclid", "_hsenc", "_hsmi", "trk", "spm"
    ]

    public static func cleanURLString(_ raw: String) -> String {
        guard var comps = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return raw
        }
        if let items = comps.queryItems, !items.isEmpty {
            let kept = items.filter { !trackingParams.contains($0.name.lowercased()) }
            comps.queryItems = kept.isEmpty ? nil : kept
        }
        return comps.string ?? raw
    }

    public static func extractURLs(from text: String) -> [TabItem] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var items: [TabItem] = []
        var seen = Set<String>()
        for match in detector.matches(in: text, range: range) {
            if let url = match.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                let s = url.absoluteString
                if seen.insert(s).inserted {
                    let host = url.host ?? "Link"
                    items.append(TabItem(browser: "Extracted", title: host, url: s))
                }
            }
        }
        return items
    }

    public static func extractEmails(from text: String) -> [String] {
        let pattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var out: [String] = []
        var seen = Set<String>()
        for m in regex.matches(in: text, range: range) {
            if let r = Range(m.range, in: text) {
                let email = String(text[r])
                if seen.insert(email.lowercased()).inserted {
                    out.append(email)
                }
            }
        }
        return out
    }

    public static func redactSecrets(in text: String) -> (String, Int) {
        let patterns: [(String, String)] = [
            ("OPENAI_KEY", #"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"#),
            ("ANTHROPIC_KEY", #"\bsk-ant-[A-Za-z0-9_-]{16,}\b"#),
            ("GITHUB_TOKEN", #"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b"#),
            ("AWS_KEY", #"\bAKIA[0-9A-Z]{16}\b"#),
            ("STRIPE_KEY", #"\b(?:sk|pk|rk)_(?:live|test)_[A-Za-z0-9]{16,}\b"#),
            ("JWT", #"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#),
            ("BEARER", #"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{16,}"#)
        ]
        var result = text
        var totalRedacted = 0
        for (label, pat) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pat) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let count = regex.numberOfMatches(in: result, range: range)
            if count > 0 {
                totalRedacted += count
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[REDACTED:\(label)]")
            }
        }
        return (result, totalRedacted)
    }

    public static func parseTable(from text: String) -> PipeTable {
        let nonEmpty = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = nonEmpty.first else {
            return PipeTable(headers: [], rows: [])
        }

        // Auto-detect TSV vs Pipe vs CSV
        let delimiter: Character
        if first.contains("\t") {
            delimiter = "\t"
        } else if first.contains("|") && first.filter({ $0 == "|" }).count >= 2 {
            delimiter = "|"
        } else {
            delimiter = ","
        }

        var matrix: [[String]] = []
        for line in nonEmpty {
            if delimiter == "|" && line.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            let cells = splitDelimitedLine(line, delimiter: delimiter)
            if !cells.isEmpty {
                matrix.append(cells)
            }
        }

        guard let headers = matrix.first else {
            return PipeTable(headers: [], rows: [])
        }
        let body = Array(matrix.dropFirst()).map { row -> [String] in
            if row.count == headers.count { return row }
            if row.count < headers.count { return row + [String](repeating: "", count: headers.count - row.count) }
            return Array(row.prefix(headers.count))
        }
        return PipeTable(headers: headers, rows: body)
    }

    public static func encodeCSV(table: PipeTable) -> String {
        func escape(_ field: String) -> String {
            if field.contains(",") || field.contains("\"") || field.contains("\n") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }
        var lines: [String] = []
        if !table.headers.isEmpty {
            lines.append(table.headers.map(escape).joined(separator: ","))
        }
        for row in table.rows {
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    public static func encodeMarkdown(payload: PipePayload) -> String {
        switch payload {
        case .table(let t):
            guard !t.headers.isEmpty else { return "" }
            var out = "| " + t.headers.joined(separator: " | ") + " |\n"
            out += "| " + t.headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
            for row in t.rows {
                out += "| " + row.map { $0.replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |\n"
            }
            return out.trimmingCharacters(in: .newlines)

        case .urls(let tabs):
            return tabs.map { "- [\($0.title)](\($0.url))" }.joined(separator: "\n")

        case .lines(let list):
            return list.map { "- \($0)" }.joined(separator: "\n")

        case .files(let urls):
            return urls.map { "- `\($0.lastPathComponent)` (`\($0.path)`)" }.joined(separator: "\n")

        case .text(let s), .json(let s):
            return s

        case .empty:
            return ""
        }
    }

    public static func encodeJSON(payload: PipePayload) -> String {
        switch payload {
        case .table(let t):
            let objects: [[String: String]] = t.rows.map { row in
                var obj: [String: String] = [:]
                for (i, h) in t.headers.enumerated() where i < row.count {
                    obj[h] = row[i]
                }
                return obj
            }
            if let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "[]"

        case .urls(let tabs):
            let arr = tabs.map { ["browser": $0.browser, "title": $0.title, "url": $0.url] }
            if let data = try? JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "[]"

        case .lines(let list):
            if let data = try? JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "[]"

        case .text(let s), .json(let s):
            if let raw = s.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: raw),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                return str
            }
            let escaped = s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "{\"text\": \"\(escaped)\"}"

        case .files(let urls):
            let paths = urls.map(\.path)
            if let data = try? JSONSerialization.data(withJSONObject: paths, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "[]"

        case .empty:
            return "{}"
        }
    }

    public static func summarize(payload: PipePayload) -> String {
        switch payload {
        case .table(let t):
            var summary = "Table Summary: \(t.rows.count) rows × \(t.headers.count) columns (\(t.headers.joined(separator: ", ")))."
            // Detect numeric columns and compute totals automatically
            for colIdx in 0..<t.headers.count {
                var sum = 0.0
                var numCount = 0
                for row in t.rows where colIdx < row.count {
                    let cleaned = row[colIdx].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                    if let val = Double(cleaned) {
                        sum += val
                        numCount += 1
                    }
                }
                if numCount > 0 && numCount >= max(1, t.rows.count / 2) {
                    summary += String(format: "\n• Sum(%@): %.2f across %d values", t.headers[colIdx], sum, numCount)
                }
            }
            return summary

        case .urls(let tabs):
            var domainCounts: [String: Int] = [:]
            for tab in tabs {
                let host = URL(string: tab.url)?.host ?? "other"
                domainCounts[host, default: 0] += 1
            }
            let topDomains = domainCounts.sorted { $0.value > $1.value }.prefix(4).map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
            return "Browser Tabs Summary: \(tabs.count) tabs across \(domainCounts.count) domains.\nTop domains: \(topDomains)"

        default:
            let lines = payload.asLines()
            let wordCount = lines.reduce(0) { $0 + $1.split(separator: " ").count }
            let highSignal = lines.filter { line in
                let l = line.lowercased()
                return l.contains("error") || l.contains("total") || l.contains("decision") || l.contains("http") || l.contains("invoice")
            }
            let sample = (highSignal.isEmpty ? Array(lines.prefix(4)) : Array(highSignal.prefix(4)))
            return "Summary: \(lines.count) lines · \(wordCount) words\n" + sample.map { "• \($0)" }.joined(separator: "\n")
        }
    }

    public static func extractPDFText(from urls: [URL]) -> String {
        var chunks: [String] = []
        for url in urls {
            guard let doc = PDFDocument(url: url) else { continue }
            var pageTexts: [String] = []
            for idx in 0..<doc.pageCount {
                if let pageStr = doc.page(at: idx)?.string, !pageStr.isEmpty {
                    pageTexts.append(pageStr)
                }
            }
            if !pageTexts.isEmpty {
                chunks.append(pageTexts.joined(separator: "\n"))
            }
        }
        return chunks.joined(separator: "\n\n")
    }

    public static func extractPDFText(from data: Data) -> String {
        guard let doc = PDFDocument(data: data) else { return "" }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            if let s = doc.page(at: i)?.string, !s.isEmpty {
                pages.append(s)
            }
        }
        return pages.joined(separator: "\n")
    }

    public static func runVisionOCR(on image: CGImage) throws -> String {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([req])
        let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }

    private static func splitDelimitedLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        current.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == delimiter {
                    fields.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                } else {
                    current.append(ch)
                }
            }
            i += 1
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        if delimiter == "|" {
            if fields.first == "" { fields.removeFirst() }
            if fields.last == "" { fields.removeLast() }
        }
        return fields
    }
}
