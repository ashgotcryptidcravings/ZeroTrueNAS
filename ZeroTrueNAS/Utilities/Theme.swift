import SwiftUI

enum Theme {
    // Core palette
    static let background = Color(red: 0.039, green: 0.039, blue: 0.059)        // #0a0a0f
    static let surfaceDark = Color(red: 0.059, green: 0.059, blue: 0.086)        // #0f0f16
    static let surface = Color(red: 0.078, green: 0.078, blue: 0.118)            // #14141e
    static let surfaceLight = Color(red: 0.110, green: 0.110, blue: 0.157)       // #1c1c28

    // Accents
    static let cyan = Color(red: 0.0, green: 0.961, blue: 1.0)                  // #00f5ff
    static let purple = Color(red: 0.616, green: 0.306, blue: 0.871)            // #9d4edd
    static let purpleLight = Color(red: 0.737, green: 0.482, blue: 0.929)       // #bc7bed

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.55)
    static let textMuted = Color(white: 0.35)

    // Status
    static let success = Color(red: 0.0, green: 0.878, blue: 0.553)             // #00e08d
    static let error = Color(red: 1.0, green: 0.29, blue: 0.38)                 // #ff4a61
    static let warning = Color(red: 1.0, green: 0.753, blue: 0.0)               // #ffc000

    // Fonts
    static func monoFont(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    static func headerFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func bodyFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    // Glow shadow
    static func glowShadow(color: Color = cyan, radius: CGFloat = 8) -> some View {
        Color.clear.shadow(color: color.opacity(0.6), radius: radius)
    }
}

// MARK: - Styled Button

struct CyanButtonStyle: ButtonStyle {
    var isCompact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.monoFont(isCompact ? 13 : 15))
            .fontWeight(.semibold)
            .foregroundColor(Theme.background)
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.vertical, isCompact ? 8 : 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.cyan)
                    .shadow(color: Theme.cyan.opacity(0.4), radius: configuration.isPressed ? 2 : 10)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.monoFont(13))
            .foregroundColor(Theme.cyan)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.cyan.opacity(0.4), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.cyan.opacity(configuration.isPressed ? 0.1 : 0.03))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.monoFont(13))
            .foregroundColor(Theme.error)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.error.opacity(0.4), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.error.opacity(configuration.isPressed ? 0.15 : 0.05))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Styled TextField

struct ThemedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(Theme.monoFont(15))
            .foregroundColor(Theme.textPrimary)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surfaceDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.cyan.opacity(0.2), lineWidth: 1)
                    )
            )
            .tint(Theme.cyan)
    }
}
