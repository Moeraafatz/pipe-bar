import AppKit
import Foundation

public enum MacAdapters {
    @MainActor
    public static func readClipboard() -> PipePayload {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            return .files(urls)
        }
        if let str = pb.string(forType: .string), !str.isEmpty {
            return .text(str)
        }
        return .empty
    }

    @MainActor
    public static func writeClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    public static func readFinderSelection(extensionFilter: String? = nil) -> [URL] {
        let script = """
        tell application "Finder"
            set sel to selection
            set outPaths to ""
            repeat with f in sel
                set outPaths to outPaths & (POSIX path of (f as alias)) & linefeed
            end repeat
            return outPaths
        end tell
        """
        guard let raw = runAppleScript(script) else { return [] }
        let urls = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }

        guard let ext = extensionFilter?.lowercased(), !ext.isEmpty else { return urls }
        let mappedExts: Set<String>
        switch ext {
        case "pdf", "pdfs": mappedExts = ["pdf"]
        case "img", "image", "images", "png": mappedExts = ["png", "jpg", "jpeg", "heic", "tiff", "webp"]
        case "md", "markdown": mappedExts = ["md", "markdown", "txt"]
        case "csv": mappedExts = ["csv", "tsv"]
        default: mappedExts = [ext.trimmingCharacters(in: CharacterSet(charactersIn: "."))]
        }
        return urls.filter { mappedExts.contains($0.pathExtension.lowercased()) }
    }

    public static func readBrowserTabs(browserHint: String? = nil) -> [TabItem] {
        let targets = browserHint.map { [$0] } ?? ["Safari", "Google Chrome", "Arc"]
        var collected: [TabItem] = []

        for browser in targets {
            let script: String
            if browser.lowercased().contains("safari") {
                script = """
                if application "Safari" is running then
                    tell application "Safari"
                        set out to ""
                        repeat with w in windows
                            repeat with t in tabs of w
                                set out to out & (name of t) & "\t" & (URL of t) & linefeed
                            end repeat
                        end repeat
                        return out
                    end tell
                end if
                return ""
                """
            } else {
                script = """
                if application "\(browser)" is running then
                    tell application "\(browser)"
                        set out to ""
                        repeat with w in windows
                            repeat with t in tabs of w
                                set out to out & (title of t) & "\t" & (URL of t) & linefeed
                            end repeat
                        end repeat
                        return out
                    end tell
                end if
                return ""
                """
            }

            if let output = runAppleScript(script), !output.isEmpty {
                for line in output.components(separatedBy: .newlines) {
                    let parts = line.components(separatedBy: "\t")
                    if parts.count >= 2, !parts[1].isEmpty {
                        collected.append(TabItem(browser: browser, title: parts[0], url: parts[1]))
                    }
                }
            }
        }
        return collected
    }

    public static func appendMarkdownNote(_ markdown: String, directoryPath: String = "~/Documents/PipeBarNotes") throws -> URL {
        let expanded = (directoryPath as NSString).expandingTildeInPath
        let dirURL = URL(fileURLWithPath: expanded, isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let fileURL = dirURL.appendingPathComponent("pipebar-\(df.string(from: Date())).md")

        let stamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\n## Capture \(stamp)\n\n\(markdown)\n"
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            try (existing + entry).write(to: fileURL, atomically: true, encoding: .utf8)
        } else {
            try ("# Pipe Bar Notes\n" + entry).write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return fileURL
    }

    public static func saveOutput(_ text: String, pathArg: String) throws -> URL {
        let expanded: String
        if pathArg.hasPrefix("/") || pathArg.hasPrefix("~") {
            expanded = (pathArg as NSString).expandingTildeInPath
        } else {
            let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            expanded = desktop.appendingPathComponent(pathArg).path
        }
        let target = URL(fileURLWithPath: expanded)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: target, atomically: true, encoding: .utf8)
        return target
    }

    public static func runLocalPlugin(named pluginName: String, input: String) throws -> String {
        let sanitized = URL(fileURLWithPath: pluginName).lastPathComponent
        let pluginsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/pipebar/plugins")
        let pluginURL = pluginsDir.appendingPathComponent(sanitized)
        guard FileManager.default.isExecutableFile(atPath: pluginURL.path) else {
            throw NSError(domain: "PipeBar.Plugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Plugin not found in ~/.config/pipebar/plugins/\(sanitized)"])
        }

        let proc = Process()
        proc.executableURL = pluginURL
        let inPipe = Pipe()
        let outPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = Pipe()
        try proc.run()
        if let data = input.data(using: .utf8) {
            inPipe.fileHandleForWriting.write(data)
        }
        inPipe.fileHandleForWriting.closeFile()
        proc.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outData, encoding: .utf8) ?? ""
    }

    public static func installedPlugins() -> [String] {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/pipebar/plugins")
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return items.filter { FileManager.default.isExecutableFile(atPath: dir.appendingPathComponent($0).path) }.sorted()
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result?.stringValue
    }
}
