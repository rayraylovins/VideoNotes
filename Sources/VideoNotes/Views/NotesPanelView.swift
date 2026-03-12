import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var sessionVM: SessionViewModel
    var onSeek: (Double) -> Void
    var isOverlayStyle: Bool = false

    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader

            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)

            if sessionVM.session.notes.isEmpty {
                emptyPanel
            } else {
                notesTable
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("REVIEW LOG")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundColor(Theme.tertiaryText)

                    Text(sessionVM.session.videoFileName.isEmpty ? "No active clip" : sessionVM.session.videoFileName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(sessionVM.session.notes.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Theme.accentCyan.opacity(0.22))
                    )
            }

            HStack(spacing: 10) {
                statCard(title: "Status", value: sessionVM.session.notes.isEmpty ? "Idle" : "Rolling", tint: sessionVM.session.notes.isEmpty ? Theme.accentAmber : Theme.accentMint)
                statCard(title: "Rate", value: frameRateLabel, tint: Theme.accentCyan)
                statCard(title: "TC Base", value: dropFrameLabel, tint: Theme.accentViolet)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, isOverlayStyle ? 16 : 18)
        .padding(.bottom, isOverlayStyle ? 12 : 16)
    }

    private var emptyPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 70, height: 70)
                .overlay {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("No markers logged")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text("Create notes during playback to build a frame-accurate editorial review log.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 10) {
                hintRow(prefix: "TYPE", text: "Start typing while the clip plays")
                hintRow(prefix: "N", text: "Insert a manual note at the current frame")
                hintRow(prefix: "VOICE", text: "Record spoken notes with timestamps")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(22)
    }

    private var notesTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MARK")
                    .frame(width: 44, alignment: .leading)
                Text("TIMECODE")
                    .frame(width: 108, alignment: .leading)
                Text("NOTE")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundColor(Theme.tertiaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(isOverlayStyle ? 0.10 : 0.16))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sessionVM.session.sortedNotes.enumerated()), id: \.element.id) { index, note in
                        NoteRowView(
                            note: note,
                            isEditing: sessionVM.editingNoteID == note.id,
                            editText: $editText,
                            noteNumber: index + 1,
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
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var frameRateLabel: String {
        String(format: "%.2f", sessionVM.session.frameRate)
    }

    private var dropFrameLabel: String {
        sessionVM.session.isDropFrame ? "DF" : "NDF"
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.tertiaryText)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                }
        )
    }

    private func hintRow(prefix: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(prefix)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accentCyan)
                .frame(width: 44, alignment: .leading)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.secondaryText)
        }
    }
}
