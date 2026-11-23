import PipeBarCore
import SwiftUI

public struct PluginsView: View {
    @Bindable var state: PipeAppState

    public init(state: PipeAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            safetyCard
            pluginsFolderCard
            guaranteeCard
        }
    }

    private var safetyCard: some View {
        PipeGlassCard(padding: 11, cornerRadius: 13) {
            VStack(spacing: 9) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Redact Secrets Before Copy Sink")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PipeTheme.textPrimary)
                        Text("Scrubs OpenAI/AWS/GitHub/JWT keys whenever | copy executes")
                            .font(.system(size: 9.5))
                            .foregroundStyle(PipeTheme.textSecondary)
                    }
                    Spacer()
                    PipeTogglePill(isOn: state.safetyConfig.autoRedactBeforeCopy, accent: PipeTheme.emerald) {
                        state.safetyConfig.autoRedactBeforeCopy.toggle()
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow Local Shell Plugins (| sh <plugin>)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PipeTheme.textPrimary)
                        Text("Strictly sandboxed to executables inside ~/.config/pipebar/plugins/")
                            .font(.system(size: 9.5))
                            .foregroundStyle(PipeTheme.textSecondary)
                    }
                    Spacer()
                    PipeTogglePill(isOn: state.safetyConfig.allowLocalShellPlugins, accent: PipeTheme.violet) {
                        state.safetyConfig.allowLocalShellPlugins.toggle()
                    }
                }
            }
        }
    }

    private var pluginsFolderCard: some View {
        PipeGlassCard(padding: 11, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Local Stdin/Stdout Plugins (~/.config/pipebar/plugins/)", systemImage: "puzzlepiece.extension.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PipeTheme.textPrimary)
                    Spacer()
                    Text("\(state.installedPlugins.count) found")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(PipeTheme.cyan)
                }

                if state.installedPlugins.isEmpty {
                    Text("Drop any executable script (Swift, Python, bash) into ~/.config/pipebar/plugins/ to extend Pipe Bar with custom | sh stages.")
                        .font(.system(size: 10))
                        .foregroundStyle(PipeTheme.textSecondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(state.installedPlugins.prefix(4), id: \.self) { plugin in
                            Text("| sh \(plugin)")
                                .font(.system(size: 9.8, weight: .bold, design: .monospaced))
                                .foregroundStyle(PipeTheme.violet)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(PipeTheme.violet.opacity(0.16)))
                        }
                    }
                }
            }
        }
    }

    private var guaranteeCard: some View {
        PipeGlassCard(padding: 10, cornerRadius: 13, borderColor: PipeTheme.emerald.opacity(0.30)) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(PipeTheme.emerald)
                VStack(alignment: .leading, spacing: 2) {
                    Text("100% Offline Native Swift 6 Execution")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PipeTheme.textPrimary)
                    Text("Uses Apple PDFKit, Vision OCR, NSDataDetector & AppleEvents · Zero cloud telemetry")
                        .font(.system(size: 9.5))
                        .foregroundStyle(PipeTheme.textSecondary)
                }
                Spacer()
            }
        }
    }
}
