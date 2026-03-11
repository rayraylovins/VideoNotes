import SwiftUI

enum Theme {
    static let midnight = Color(red: 0.03, green: 0.05, blue: 0.10)
    static let nightBlue = Color(red: 0.05, green: 0.12, blue: 0.23)
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.20)
    static let panel = Color(red: 0.09, green: 0.11, blue: 0.18)
    static let panelElevated = Color(red: 0.13, green: 0.16, blue: 0.24)
    static let accentCyan = Color(red: 0.40, green: 0.84, blue: 1.0)
    static let accentBlue = Color(red: 0.34, green: 0.53, blue: 0.99)
    static let accentViolet = Color(red: 0.51, green: 0.36, blue: 0.98)
    static let accentMint = Color(red: 0.47, green: 0.94, blue: 0.80)

    static let backgroundGradient = LinearGradient(
        colors: [midnight, nightBlue, ink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [accentCyan, accentBlue, accentViolet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.12)
    static let divider = Color.white.opacity(0.08)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let tertiaryText = Color.white.opacity(0.46)

    static let cornerRadius: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 18
    static let cornerRadiusXLarge: CGFloat = 26
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient

            RadialGradient(
                colors: [Theme.accentCyan.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 520
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [Theme.accentViolet.opacity(0.20), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 460
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

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
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

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

struct SurfaceCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.cornerRadiusLarge
    var fillOpacity: Double = 0.88

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.panelElevated.opacity(fillOpacity),
                                Theme.panel.opacity(fillOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

extension View {
    func surfaceCard(cornerRadius: CGFloat = Theme.cornerRadiusLarge, fillOpacity: Double = 0.88) -> some View {
        modifier(SurfaceCard(cornerRadius: cornerRadius, fillOpacity: fillOpacity))
    }
}
