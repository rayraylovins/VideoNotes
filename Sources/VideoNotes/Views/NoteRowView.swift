import SwiftUI

struct NoteRowView: View {
    let note: Note
    let isEditing: Bool
    @Binding var editText: String
    var onSeek: () -> Void
    var onCommitEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: onSeek) {
                    Text(note.timecodeString)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(0.6)
            }

            if isEditing {
                TextField("Edit note...", text: $editText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        onCommitEdit()
                    }
            } else {
                Text(note.text)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
