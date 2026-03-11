import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var sessionVM: SessionViewModel
    var onSeek: (Double) -> Void

    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Session Notes")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)

                        Text(sessionVM.session.videoFileName.isEmpty ? "No video loaded" : sessionVM.session.videoFileName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
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
                                .fill(Theme.heroGradient.opacity(0.30))
                        )
                }

                HStack(spacing: 10) {
                    statCard(title: "Status", value: sessionVM.session.notes.isEmpty ? "Empty" : "Active", tint: Theme.accentMint)
                    statCard(title: "Format", value: frameRateLabel, tint: Theme.accentCyan)
                    statCard(title: "Mode", value: sessionVM.isEditing ? "Editing" : "Ready", tint: Theme.accentViolet)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 18)

            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)

            if sessionVM.session.notes.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer()

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accentBlue.opacity(0.35), Theme.accentViolet.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundColor(.white)
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("No notes yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Play the video and type anywhere, press N, or use voice capture to build your review log.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        hintRow(systemName: "keyboard", text: "Type during playback to capture the current frame")
                        hintRow(systemName: "pause.circle", text: "Auto-pause keeps the exact frame in place")
                        hintRow(systemName: "waveform", text: "Voice mode creates notes hands-free")
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(22)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var frameRateLabel: String {
        String(format: "%.2f", sessionVM.session.frameRate)
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.tertiaryText)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(tint.opacity(0.18), lineWidth: 1)
                }
        )
    }

    private func hintRow(systemName: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .foregroundColor(Theme.accentCyan)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.secondaryText)
        }
    }
}
