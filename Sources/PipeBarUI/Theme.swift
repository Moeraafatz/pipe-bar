import PipeBarCore
import SwiftUI

public enum PipeTheme {
    public static let canvasTop = Color(red: 0.048, green: 0.042, blue: 0.078)
    public static let canvasBottom = Color(red: 0.022, green: 0.020, blue: 0.040)
    public static let cardSurface = Color.white.opacity(0.055)
    public static let cardBorder = Color.white.opacity(0.11)
    public static let cardBorderStrong = Color.white.opacity(0.18)

    public static let violet = Color(red: 0.749, green: 0.353, blue: 0.949)   // #BF5AF2
    public static let cyan = Color(red: 0.392, green: 0.824, blue: 1.000)     // #64D2FF
    public static let emerald = Color(red: 0.188, green: 0.820, blue: 0.345)  // #30D158
    public static let amber = Color(red: 1.000, green: 0.624, blue: 0.039)    // #FF9F0A
    public static let rose = Color(red: 1.000, green: 0.271, blue: 0.227)     // #FF453A

    public static let textPrimary = Color.white.opacity(0.95)
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textTertiary = Color.white.opacity(0.42)

    public static func categoryTint(_ cat: StageCategory) -> Color {
        switch cat {
        case .source: return violet
        case .transform: return cyan
        case .sink: return emerald
        }
    }
}

public struct PipeGlassCard<Content: View>: View {
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let borderColor: Color
    private let content: Content

    public init(
        padding: CGFloat = 11,
        cornerRadius: CGFloat = 13,
        borderColor: Color = PipeTheme.cardBorder,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PipeTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
            )
    }
}

public struct PipeTogglePill: View {
    public let isOn: Bool
    public let accent: Color
    public let action: () -> Void

    public init(isOn: Bool, accent: Color = PipeTheme.violet, action: @escaping () -> Void) {
        self.isOn = isOn
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? accent.opacity(0.88) : Color.white.opacity(0.14))
                    .frame(width: 34, height: 19)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75))
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}
