import SwiftUI

struct NoteRowView: View {
    let note: Note
    let isEditing: Bool
    @Binding var editText: String
    let noteNumber: Int
    var onSeek: () -> Void
    var onCommitEdit: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("#\(noteNumber)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.tertiaryText)

                        Button(action: onSeek) {
                            Text(note.timecodeString)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.heroGradient)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(relativeTimestamp)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.tertiaryText)
                }

                Spacer()

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }

            if isEditing {
                TextField("Edit note...", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .onSubmit {
                        onCommitEdit()
                    }
            } else {
                Text(note.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isHovered
                        ? [Color.white.opacity(0.10), Color.white.opacity(0.06)]
                        : [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var relativeTimestamp: String {
        note.createdAt.formatted(.relative(presentation: .named))
    }
}
