import PipeBarCore
import SwiftUI

public struct CatalogView: View {
    @Bindable var state: PipeAppState

    public init(state: PipeAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 9) {
            categoryCard(
                title: "Sources (Live macOS State Adapters)",
                category: .source,
                entries: PipelineParser.catalog.filter { $0.category == .source }
            )
            categoryCard(
                title: "Native Offline Transforms (PDFKit · Vision · Data)",
                category: .transform,
                entries: Array(PipelineParser.catalog.filter { $0.category == .transform }.prefix(8))
            )
            categoryCard(
                title: "Sinks (Clipboard · Files · Notes · Apps)",
                category: .sink,
                entries: PipelineParser.catalog.filter { $0.category == .sink }
            )
        }
    }

    private func categoryCard(title: String, category: StageCategory, entries: [StageCatalogEntry]) -> some View {
        let tint = PipeTheme.categoryTint(category)
        return PipeGlassCard(padding: 10, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                    Spacer()
                    Text("Click to append")
                        .font(.system(size: 9.2))
                        .foregroundStyle(PipeTheme.textTertiary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(entries) { entry in
                        Button {
                            state.appendStage(entry.command)
                        } label: {
                            HStack(spacing: 6) {
                                Text(entry.command)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(PipeTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Text(entry.summary)
                                    .font(.system(size: 8.8))
                                    .foregroundStyle(PipeTheme.textTertiary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5.5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(tint.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(tint.opacity(0.24), lineWidth: 0.75)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
