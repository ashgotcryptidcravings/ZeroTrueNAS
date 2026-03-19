import SwiftUI

struct GlowEffect: ViewModifier {
    var color: Color = Theme.cyan
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
    }
}

struct PulseGlow: ViewModifier {
    var color: Color = Theme.cyan
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isAnimating ? 0.6 : 0.2), radius: isAnimating ? 12 : 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func glow(color: Color = Theme.cyan, radius: CGFloat = 8) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }

    func pulseGlow(color: Color = Theme.cyan) -> some View {
        modifier(PulseGlow(color: color))
    }
}
