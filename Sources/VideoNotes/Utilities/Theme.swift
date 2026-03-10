import SwiftUI

enum Theme {
    // Core gradient colors
    static let deepPurple = Color(red: 0.12, green: 0.07, blue: 0.28)
    static let midPurple = Color(red: 0.18, green: 0.10, blue: 0.38)
    static let richBlue = Color(red: 0.14, green: 0.16, blue: 0.42)
    static let accentCyan = Color(red: 0.30, green: 0.60, blue: 1.0)
    static let accentViolet = Color(red: 0.55, green: 0.35, blue: 0.95)

    // Background gradient
    static let backgroundGradient = LinearGradient(
        colors: [deepPurple, richBlue, midPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Card surface
    static let cardFill = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.10)
    static let cardHighlight = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Text
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.35)

    // Corner radius
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 18
}

// Reusable glass card modifier
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.cornerRadius

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.cardHighlight)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                }
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
