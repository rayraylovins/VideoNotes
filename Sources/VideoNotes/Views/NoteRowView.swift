import SwiftUI

struct NoteRowView: View {
    let note: Note
    let isEditing: Bool
    @Binding var editText: String
    var onSeek: () -> Void
    var onCommitEdit: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onSeek) {
                    Text(note.timecodeString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accentCyan, Theme.accentViolet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.tertiaryText)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }

            if isEditing {
                TextField("Edit note...", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.primaryText)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .onSubmit {
                        onCommitEdit()
                    }
            } else {
                Text(note.text)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
