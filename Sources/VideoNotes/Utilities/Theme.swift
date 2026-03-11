import SwiftUI

enum Theme {
    static let midnight = Color(red: 0.03, green: 0.04, blue: 0.06)
    static let nightBlue = Color(red: 0.05, green: 0.08, blue: 0.12)
    static let ink = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let panel = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let panelElevated = Color(red: 0.14, green: 0.16, blue: 0.20)
    static let panelMuted = Color(red: 0.16, green: 0.18, blue: 0.22)
    static let accentCyan = Color(red: 0.40, green: 0.84, blue: 1.0)
    static let accentBlue = Color(red: 0.30, green: 0.48, blue: 0.88)
    static let accentViolet = Color(red: 0.42, green: 0.37, blue: 0.78)
    static let accentMint = Color(red: 0.50, green: 0.88, blue: 0.72)
    static let accentAmber = Color(red: 0.98, green: 0.72, blue: 0.33)

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

    static let monitorGradient = LinearGradient(
        colors: [panelElevated, panel],
        startPoint: .top,
        endPoint: .bottom
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
                colors: [Theme.accentCyan.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 520
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [Theme.accentBlue.opacity(0.10), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 460
            )
            .blendMode(.screen)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.035),
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Canvas { context, size in
                let spacing: CGFloat = 28
                var path = Path()

                stride(from: 0, through: size.height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }

                stride(from: 0, through: size.width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }

                context.stroke(path, with: .color(Color.white.opacity(0.015)), lineWidth: 0.5)
            }
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
