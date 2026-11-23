import PipeBarCore
import SwiftUI

public struct RecipesView: View {
    @Bindable var state: PipeAppState

    public init(state: PipeAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            impactStrip
            recipesList
        }
    }

    private var impactStrip: some View {
        let totalRuns = state.recipes.reduce(0) { $0 + $1.runCount }
        let clicksSaved = state.recipes.reduce(0) { $0 + ($1.runCount * $1.manualClicksReplaced) }
        return HStack(spacing: 8) {
            statTile(title: "PINNED RECIPES", value: "\(state.recipes.count)", tint: PipeTheme.violet)
            statTile(title: "PIPE RUNS", value: "\(totalRuns)", tint: PipeTheme.cyan)
            statTile(title: "CLICKS SAVED", value: formatK(clicksSaved), tint: PipeTheme.emerald)
        }
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        PipeGlassCard(padding: 9, cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(PipeTheme.textTertiary)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recipesList: some View {
        VStack(spacing: 7) {
            ForEach(state.recipes.prefix(4)) { recipe in
                Button {
                    state.loadRecipe(recipe)
                } label: {
                    PipeGlassCard(padding: 10, cornerRadius: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(recipe.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(PipeTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(recipe.hotkey)
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(PipeTheme.violet)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(PipeTheme.violet.opacity(0.16)))
                            }

                            Text(recipe.command)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PipeTheme.cyan)
                                .lineLimit(1)

                            HStack(spacing: 9) {
                                Text("\(recipe.runCount) runs")
                                    .foregroundStyle(PipeTheme.emerald)
                                Text("replaces \(recipe.manualClicksReplaced) manual clicks")
                                    .foregroundStyle(PipeTheme.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f ms", recipe.lastDurationMs))
                                    .foregroundStyle(PipeTheme.textTertiary)
                            }
                            .font(.system(size: 9.2, weight: .semibold, design: .monospaced))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formatK(_ n: Int) -> String {
        n >= 1_000 ? String(format: "%.1fK", Double(n) / 1000.0) : "\(n)"
    }
}
