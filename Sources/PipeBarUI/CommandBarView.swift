import PipeBarCore
import SwiftUI

public struct CommandBarView: View {
    @Bindable var state: PipeAppState

    public init(state: PipeAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            pipeInputCard
            stageFlowStrip
            outputPreviewCard
        }
    }

    private var pipeInputCard: some View {
        let parsed = state.parsedPipeline
        return PipeGlassCard(padding: 11, cornerRadius: 14, borderColor: parsed.isValid ? PipeTheme.violet.opacity(0.45) : PipeTheme.rose.opacity(0.45)) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text("|>")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(PipeTheme.violet)

                    if state.isPreviewSnapshot {
                        HStack(spacing: 2) {
                            Text(state.commandInput)
                                .font(.system(size: 12.2, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PipeTheme.textPrimary)
                                .lineLimit(2)
                            Rectangle()
                                .fill(PipeTheme.cyan)
                                .frame(width: 1.5, height: 14)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextField("selected pdfs | pdf text | extract tables | merge csv | copy", text: $state.commandInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.2, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PipeTheme.textPrimary)
                            .onSubmit {
                                state.runCurrentPipeline(allowSideEffects: true)
                            }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.36))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
                        )
                )

                HStack(spacing: 7) {
                    Button {
                        state.runCurrentPipeline(allowSideEffects: true)
                    } label: {
                        Label("Run Pipe (↩)", systemImage: "play.fill")
                            .font(.system(size: 10.8, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6.5)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PipeTheme.emerald))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.copyOutput()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(PipeTheme.cyan)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6.5)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PipeTheme.cyan.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.saveCurrentAsRecipe()
                    } label: {
                        Label("Pin", systemImage: "pin.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(PipeTheme.violet)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6.5)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PipeTheme.violet.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stageFlowStrip: some View {
        PipeGlassCard(padding: 10, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("Typed Stage Execution Trace (\(state.traces.count) stages)", systemImage: "arrow.right.arrow.left")
                        .font(.system(size: 10.8, weight: .bold))
                        .foregroundStyle(PipeTheme.textPrimary)
                    Spacer()
                    Text(String(format: "%.2f ms total", state.lastDurationMs))
                        .font(.system(size: 9.8, weight: .bold, design: .monospaced))
                        .foregroundStyle(PipeTheme.emerald)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(PipeTheme.emerald.opacity(0.15)))
                }

                VStack(spacing: 5) {
                    ForEach(state.traces.prefix(5)) { tr in
                        let tint = PipeTheme.categoryTint(tr.category)
                        HStack(spacing: 7) {
                            Text(tr.stageName.uppercased())
                                .font(.system(size: 8.8, weight: .bold, design: .monospaced))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(tint.opacity(0.16)))

                            Text(tr.note)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(PipeTheme.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            Text(tr.outputType)
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(PipeTheme.amber)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(PipeTheme.amber.opacity(0.14)))

                            Text(String(format: "%.2fms", tr.durationMs))
                                .font(.system(size: 9.2, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PipeTheme.textTertiary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var outputPreviewCard: some View {
        PipeGlassCard(padding: 10, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Live Output Preview", systemImage: "doc.plaintext.fill")
                        .font(.system(size: 10.8, weight: .bold))
                        .foregroundStyle(PipeTheme.cyan)
                    Spacer()
                    Text(state.lastOutputType)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(PipeTheme.violet)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(PipeTheme.violet.opacity(0.16)))
                }

                Text(state.lastOutputText.isEmpty ? "Run any pipeline to preview typed output here…" : state.lastOutputText)
                    .font(.system(size: 10.2, design: .monospaced))
                    .foregroundStyle(PipeTheme.textPrimary)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.32))
                    )
            }
        }
    }
}
