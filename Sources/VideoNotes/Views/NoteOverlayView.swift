import SwiftUI

struct NoteOverlayView: View {
    let timecodeString: String
    @Binding var noteText: String
    var onCommit: () -> Void
    var onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(timecodeString)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.accentCyan)
                }

                Spacer()

                HStack(spacing: 8) {
                    shortcutPill(text: "Enter", detail: "Save")
                    shortcutPill(text: "Esc", detail: "Cancel")
                }
            }

            TextField("Type your note…", text: $noteText)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .focused($isFocused)
                .onSubmit {
                    onCommit()
                }
                .onExitCommand {
                    onCancel()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: 640)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.panelElevated.opacity(0.92),
                            Theme.panel.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: Theme.accentBlue.opacity(0.10), radius: 28, y: 14)
        .shadow(color: .black.opacity(0.32), radius: 18, y: 12)
        .onAppear {
            isFocused = true
        }
    }

    private func shortcutPill(text: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Text(detail)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(Theme.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }
}
