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
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", noteNumber))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.tertiaryText)
                .frame(width: 32, alignment: .leading)
                .padding(.top, 2)

            Button(action: onSeek) {
                Text(note.timecodeString)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accentCyan)
                    .frame(width: 108, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    markerFlag

                    Text(relativeTimestamp)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.tertiaryText)
                }

                if isEditing {
                    TextField("Edit note...", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(0.24))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                }
                        )
                        .onSubmit {
                            onCommitEdit()
                        }
                } else {
                    Text(note.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.90))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.82))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.04), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private var markerFlag: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Theme.accentAmber)
                .frame(width: 12, height: 2)

            Text("NOTE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accentAmber)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isHovered
                        ? [Color.white.opacity(0.08), Color.white.opacity(0.05)]
                        : [Color.white.opacity(0.05), Color.white.opacity(0.025)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var relativeTimestamp: String {
        note.createdAt.formatted(date: .omitted, time: .shortened)
    }
}
