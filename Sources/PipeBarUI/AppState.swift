import AppKit
import Foundation
import Observation
import PipeBarCore

public enum PipeTab: String, CaseIterable, Identifiable, Sendable {
    case bar = "Pipe Bar"
    case recipes = "Recipes"
    case catalog = "Catalog"
    case plugins = "Plugins"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .bar: return "terminal.fill"
        case .recipes: return "bolt.horizontal.fill"
        case .catalog: return "square.grid.2x2.fill"
        case .plugins: return "puzzlepiece.extension.fill"
        }
    }

    public var shortcut: String {
        switch self {
        case .bar: return "⌘1"
        case .recipes: return "⌘2"
        case .catalog: return "⌘3"
        case .plugins: return "⌘4"
        }
    }
}

@MainActor
@Observable
public final class PipeAppState {
    public var selectedTab: PipeTab = .bar
    public var commandInput: String = "demo invoice | extract tables | filter Enterprise | dedupe | to markdown"
    public var lastOutputText: String = ""
    public var lastOutputType: String = "TEXT"
    public var traces: [StageExecutionTrace] = []
    public var lastDurationMs: Double = 0
    public var recipes: [SavedRecipe] = []
    public var safetyConfig: PipeSafetyConfig = .default
    public var installedPlugins: [String] = []
    public var databaseBytes: Int64 = 0
    public var statusToast: String? = nil
    public let isPreviewSnapshot: Bool

    private let store: RecipeStore?

    public init(store: RecipeStore? = nil, isPreviewSnapshot: Bool = false) {
        self.store = store
        self.isPreviewSnapshot = isPreviewSnapshot
        self.recipes = PipeSampleData.demoRecipes()
        if !isPreviewSnapshot {
            self.installedPlugins = MacAdapters.installedPlugins()
        }
    }

    public static func demo(tab: PipeTab = .bar) -> PipeAppState {
        let state = PipeAppState(store: nil, isPreviewSnapshot: true)
        state.selectedTab = tab
        state.commandInput = "demo invoice | extract tables | filter Enterprise | dedupe | to markdown"
        state.traces = PipeSampleData.demoTraces()
        state.lastOutputText = PipeSampleData.demoOutputMarkdown
        state.lastOutputType = "TEXT"
        state.lastDurationMs = 0.45
        state.installedPlugins = ["jq-clean.sh", "csv-currency.py", "obsidian-daily.sh"]
        state.databaseBytes = 49_152
        return state
    }

    public var parsedPipeline: ParsedPipeline {
        PipelineParser.parse(commandInput)
    }

    public var suggestions: [StageCatalogEntry] {
        PipelineParser.autocomplete(for: commandInput, limit: 5)
    }

    public func bootstrap() async {
        guard !isPreviewSnapshot else { return }
        installedPlugins = MacAdapters.installedPlugins()
        if let store {
            let saved = (try? await store.fetchAll()) ?? []
            if !saved.isEmpty {
                recipes = saved
            } else {
                for r in recipes { try? await store.upsert(r) }
            }
            databaseBytes = await store.databaseFileSizeBytes()
        }
        runCurrentPipeline(allowSideEffects: false)
    }

    public func runCurrentPipeline(allowSideEffects: Bool = true) {
        let result = PipelineEngine.execute(
            command: commandInput,
            initialPayload: nil,
            config: safetyConfig,
            allowSideEffects: allowSideEffects && !isPreviewSnapshot
        )
        traces = result.traces
        lastDurationMs = result.totalDurationMs
        lastOutputType = result.output.typeBadge
        lastOutputText = result.output.asText()
        if !result.succeeded, let err = result.errorMessage {
            showToast("Pipeline error: \(err)")
        } else if allowSideEffects {
            showToast(String(format: "Ran %d stages in %.2f ms", result.traces.count, result.totalDurationMs))
        }
    }

    public func loadRecipe(_ recipe: SavedRecipe) {
        commandInput = recipe.command
        selectedTab = .bar
        runCurrentPipeline(allowSideEffects: false)
        showToast("Loaded recipe: \(recipe.title)")
    }

    public func appendStage(_ stageCommand: String) {
        let trimmed = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            commandInput = stageCommand
        } else {
            commandInput = "\(trimmed) | \(stageCommand)"
        }
        selectedTab = .bar
        showToast("Appended | \(stageCommand)")
    }

    public func saveCurrentAsRecipe() {
        let trimmed = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let recipe = SavedRecipe(
            title: "Custom Pipe #\(recipes.count + 1)",
            summary: trimmed,
            command: trimmed,
            hotkey: "⌥\(recipes.count + 1)",
            runCount: 1,
            manualClicksReplaced: max(4, parsedPipeline.stages.count * 3),
            lastDurationMs: lastDurationMs
        )
        recipes.insert(recipe, at: 0)
        if let store {
            Task {
                try? await store.upsert(recipe)
                databaseBytes = await store.databaseFileSizeBytes()
            }
        }
        showToast("Saved recipe to local SQLite library")
    }

    public func copyOutput() {
        guard !lastOutputText.isEmpty else { return }
        if !isPreviewSnapshot {
            MacAdapters.writeClipboard(lastOutputText)
        }
        showToast("Copied pipeline output to clipboard")
    }

    public func showToast(_ msg: String) {
        statusToast = msg
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if statusToast == msg { statusToast = nil }
        }
    }
}
