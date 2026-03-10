import SwiftUI

struct NoteOverlayView: View {
    let timecodeString: String
    @Binding var noteText: String
    var onCommit: () -> Void
    var onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Timecode badge
            Text(timecodeString)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.15))
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
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(maxWidth: 600)
        .background {
            ZStack {
                // Frosted glass base
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)

                // Tinted glass overlay
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Inner highlight stroke (top edge light refraction)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )

                // Outer subtle shadow border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5)
                    .padding(-0.5)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .onAppear {
            isFocused = true
        }
    }
}
