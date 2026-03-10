import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var sessionVM: SessionViewModel
    var onSeek: (Double) -> Void

    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Text("\(sessionVM.session.notes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Notes list
            if sessionVM.session.notes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No notes yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Start typing while a video plays\nto create timestamped notes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(sessionVM.session.sortedNotes) { note in
                            NoteRowView(
                                note: note,
                                isEditing: sessionVM.editingNoteID == note.id,
                                editText: $editText,
                                onSeek: { onSeek(note.timecodeSeconds) },
                                onCommitEdit: {
                                    sessionVM.updateNoteText(id: note.id, text: editText)
                                    sessionVM.finishEditingNote()
                                },
                                onDelete: { sessionVM.deleteNote(id: note.id) }
                            )
                            .onTapGesture(count: 2) {
                                editText = note.text
                                sessionVM.startEditingNote(note.id)
                            }

                            Divider()
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
    }
}
