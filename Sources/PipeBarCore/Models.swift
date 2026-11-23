import Foundation

public struct TabItem: Codable, Hashable, Sendable {
    public let browser: String
    public let title: String
    public let url: String

    public init(browser: String, title: String, url: String) {
        self.browser = browser
        self.title = title
        self.url = url
    }
}

public struct PipeTable: Codable, Hashable, Sendable {
    public var headers: [String]
    public var rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}

/// Typed intermediate value flowing cleanly across macOS GUI pipeline stages.
public enum PipePayload: Equatable, Sendable {
    case empty
    case text(String)
    case lines([String])
    case table(PipeTable)
    case urls([TabItem])
    case files([URL])
    case json(String)

    public var typeBadge: String {
        switch self {
        case .empty: return "EMPTY"
        case .text: return "TEXT"
        case .lines: return "LINES"
        case .table: return "TABLE"
        case .urls: return "TABS"
        case .files: return "FILES"
        case .json: return "JSON"
        }
    }

    public var itemCount: Int {
        switch self {
        case .empty: return 0
        case .text(let s): return s.isEmpty ? 0 : s.components(separatedBy: .newlines).count
        case .lines(let l): return l.count
        case .table(let t): return t.rows.count
        case .urls(let u): return u.count
        case .files(let f): return f.count
        case .json(let j): return j.count
        }
    }

    public func asText() -> String {
        switch self {
        case .empty:
            return ""
        case .text(let s), .json(let s):
            return s
        case .lines(let l):
            return l.joined(separator: "\n")
        case .table(let t):
            return DataTransformers.encodeCSV(table: t)
        case .urls(let items):
            return items.map { "\($0.title) — \($0.url)" }.joined(separator: "\n")
        case .files(let urls):
            return urls.map(\.path).joined(separator: "\n")
        }
    }

    public func asLines() -> [String] {
        switch self {
        case .empty:
            return []
        case .lines(let l):
            return l
        case .text(let s), .json(let s):
            return s.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .table(let t):
            return DataTransformers.encodeCSV(table: t).components(separatedBy: .newlines).filter { !$0.isEmpty }
        case .urls(let items):
            return items.map(\.url)
        case .files(let urls):
            return urls.map(\.path)
        }
    }

    public func previewSnippet(maxChars: Int = 260) -> String {
        let raw = asText().trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.count <= maxChars { return raw }
        return String(raw.prefix(maxChars)) + "…"
    }
}

public enum StageCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case source = "Source"
    case transform = "Transform"
    case sink = "Sink"

    public var id: String { rawValue }
}

public struct PipeStageSpec: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let rawCommand: String
    public let name: String
    public let arguments: [String]
    public let category: StageCategory

    public init(
        id: UUID = UUID(),
        rawCommand: String,
        name: String,
        arguments: [String] = [],
        category: StageCategory
    ) {
        self.id = id
        self.rawCommand = rawCommand
        self.name = name
        self.arguments = arguments
        self.category = category
    }
}

public struct ParsedPipeline: Equatable, Sendable {
    public let rawInput: String
    public let stages: [PipeStageSpec]
    public let diagnostics: [String]

    public var isValid: Bool { !stages.isEmpty && diagnostics.isEmpty }

    public init(rawInput: String, stages: [PipeStageSpec], diagnostics: [String] = []) {
        self.rawInput = rawInput
        self.stages = stages
        self.diagnostics = diagnostics
    }
}

public struct StageExecutionTrace: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let stageName: String
    public let rawCommand: String
    public let category: StageCategory
    public let inputCount: Int
    public let outputCount: Int
    public let outputType: String
    public let durationMs: Double
    public let note: String

    public init(
        id: UUID = UUID(),
        stageName: String,
        rawCommand: String,
        category: StageCategory,
        inputCount: Int,
        outputCount: Int,
        outputType: String,
        durationMs: Double,
        note: String = ""
    ) {
        self.id = id
        self.stageName = stageName
        self.rawCommand = rawCommand
        self.category = category
        self.inputCount = inputCount
        self.outputCount = outputCount
        self.outputType = outputType
        self.durationMs = durationMs
        self.note = note
    }
}

public struct PipelineRunResult: Sendable {
    public let command: String
    public let output: PipePayload
    public let traces: [StageExecutionTrace]
    public let totalDurationMs: Double
    public let succeeded: Bool
    public let errorMessage: String?

    public init(
        command: String,
        output: PipePayload,
        traces: [StageExecutionTrace],
        totalDurationMs: Double,
        succeeded: Bool,
        errorMessage: String? = nil
    ) {
        self.command = command
        self.output = output
        self.traces = traces
        self.totalDurationMs = totalDurationMs
        self.succeeded = succeeded
        self.errorMessage = errorMessage
    }
}

public struct SavedRecipe: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var summary: String
    public var command: String
    public var hotkey: String
    public var runCount: Int
    public var manualClicksReplaced: Int
    public var lastDurationMs: Double

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        command: String,
        hotkey: String = "⌘↩",
        runCount: Int = 0,
        manualClicksReplaced: Int = 12,
        lastDurationMs: Double = 0
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.command = command
        self.hotkey = hotkey
        self.runCount = runCount
        self.manualClicksReplaced = manualClicksReplaced
        self.lastDurationMs = lastDurationMs
    }
}

public struct StageCatalogEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let command: String
    public let aliases: [String]
    public let category: StageCategory
    public let summary: String
    public let example: String

    public init(command: String, aliases: [String] = [], category: StageCategory, summary: String, example: String) {
        self.id = command
        self.command = command
        self.aliases = aliases
        self.category = category
        self.summary = summary
        self.example = example
    }
}

public struct PipeSafetyConfig: Codable, Sendable, Equatable {
    public var allowLocalShellPlugins: Bool
    public var autoRedactBeforeCopy: Bool
    public var confirmDestructiveWrites: Bool
    public var defaultNotesDirectory: String

    public static let `default` = PipeSafetyConfig(
        allowLocalShellPlugins: false,
        autoRedactBeforeCopy: true,
        confirmDestructiveWrites: true,
        defaultNotesDirectory: "~/Documents/PipeBarNotes"
    )

    public init(
        allowLocalShellPlugins: Bool = false,
        autoRedactBeforeCopy: Bool = true,
        confirmDestructiveWrites: Bool = true,
        defaultNotesDirectory: String = "~/Documents/PipeBarNotes"
    ) {
        self.allowLocalShellPlugins = allowLocalShellPlugins
        self.autoRedactBeforeCopy = autoRedactBeforeCopy
        self.confirmDestructiveWrites = confirmDestructiveWrites
        self.defaultNotesDirectory = defaultNotesDirectory
    }
}
