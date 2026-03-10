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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Text("\(sessionVM.session.notes.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accentCyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Theme.accentCyan.opacity(0.15))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Subtle separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.0), Color.white.opacity(0.08), Color.white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Notes list
            if sessionVM.session.notes.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accentCyan.opacity(0.5), Theme.accentViolet.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("No notes yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                    Text("Start typing while a video plays\nto create timestamped notes")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
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
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
        .background(Color.white.opacity(0.03))
    }
}
