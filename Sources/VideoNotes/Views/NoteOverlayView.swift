import SwiftUI

struct NoteOverlayView: View {
    let timecodeString: String
    @Binding var noteText: String
    var onCommit: () -> Void
    var onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Timecode badge
            Text(timecodeString)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accentCyan.opacity(0.5), Theme.accentViolet.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )

            // Text input
            TextField("Type your note...", text: $noteText)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(.white)
                .focused($isFocused)
                .onSubmit {
                    onCommit()
                }
                .onExitCommand {
                    onCancel()
                }

            // Hint
            HStack(spacing: 16) {
                Label("Enter to save", systemImage: "return")
                Label("Esc to cancel", systemImage: "escape")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: 600)
        .background {
            ZStack {
                // Deep glass base
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Purple-blue tint
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.accentViolet.opacity(0.15),
                                Theme.accentCyan.opacity(0.08),
                                Theme.deepPurple.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Top highlight
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            }
        }
        .shadow(color: Theme.accentViolet.opacity(0.2), radius: 30, y: 4)
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .onAppear {
            isFocused = true
        }
    }
}
