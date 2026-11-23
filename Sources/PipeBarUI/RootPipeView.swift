import AppKit
import PipeBarCore
import SwiftUI

public struct RootPipeView: View {
    @Bindable var state: PipeAppState
    public let width: CGFloat

    public init(state: PipeAppState, width: CGFloat = 510) {
        self.state = state
        self.width = width
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            VStack(spacing: 11) {
                headerBar
                tabBar

                Group {
                    switch state.selectedTab {
                    case .bar:
                        CommandBarView(state: state)
                    case .recipes:
                        RecipesView(state: state)
                    case .catalog:
                        CatalogView(state: state)
                    case .plugins:
                        PluginsView(state: state)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                footerBar
            }
            .padding(14)

            if let toast = state.statusToast {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(PipeTheme.emerald))
                    .padding(.bottom, 16)
            }
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(PipeTheme.cardBorderStrong, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [PipeTheme.canvasTop, PipeTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [PipeTheme.violet.opacity(0.18), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [PipeTheme.cyan.opacity(0.13), Color.clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 310
            )
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PipeTheme.violet.opacity(0.35), PipeTheme.cyan.opacity(0.24)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(PipeTheme.violet.opacity(0.55), lineWidth: 1)
                    )
                    .frame(width: 30, height: 30)
                Text("|>")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(PipeTheme.violet)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Pipe Bar")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PipeTheme.textPrimary)
                    Text("v1.0.0")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PipeTheme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                Text("Universal Unix-Style GUI Pipeline Bar · 24 Composable Stages")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PipeTheme.textSecondary)
            }

            Spacer()

            Text("TYPED PIPES")
                .font(.system(size: 9.2, weight: .bold, design: .monospaced))
                .foregroundStyle(PipeTheme.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(PipeTheme.cyan.opacity(0.14))
                        .overlay(Capsule().strokeBorder(PipeTheme.cyan.opacity(0.32), lineWidth: 0.75))
                )
        }
    }

    private var tabBar: some View {
        let tabs = PipeTab.allCases
        return HStack(spacing: 5) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let active = state.selectedTab == tab
                Button {
                    state.selectedTab = tab
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10.8, weight: active ? .bold : .medium))
                        Text(tab.shortcut)
                            .font(.system(size: 8.8, weight: .medium, design: .monospaced))
                            .foregroundStyle(active ? Color.black.opacity(0.65) : PipeTheme.textTertiary)
                    }
                    .foregroundStyle(active ? Color.black : PipeTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6.5)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(active ? PipeTheme.textPrimary : Color.white.opacity(0.055))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.black.opacity(0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var footerBar: some View {
        HStack(spacing: 9) {
            Text("⌥⇧P Toggle Bar")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(PipeTheme.textTertiary)
            Text("·")
                .foregroundStyle(PipeTheme.textTertiary)
            Text("PDFKit + Vision + AppleEvents")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(PipeTheme.violet)
            Spacer()
            Text("Zero Cloud")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(PipeTheme.emerald)
            if !state.isPreviewSnapshot {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(PipeTheme.textTertiary)
            }
        }
        .padding(.top, 2)
    }
}
