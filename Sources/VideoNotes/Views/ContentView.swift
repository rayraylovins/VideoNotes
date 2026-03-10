import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var sessionVM = SessionViewModel()
    @StateObject private var keyHandler = KeyEventHandler()

    @State private var autoPauseEnabled = true
    @State private var showExportSheet = false
    @State private var selectedExportFormat: ExportFormat = .plainText

    var body: some View {
        HSplitView {
            // Video area
            ZStack(alignment: .bottom) {
                if playerVM.hasVideo {
                    VideoPlayerView(player: playerVM.player)
                } else {
                    emptyStateView
                }

                // Timecode display
                if playerVM.hasVideo {
                    VStack {
                        Spacer()
                        if sessionVM.isEditing {
                            NoteOverlayView(
                                timecodeString: playerVM.currentTimecodeString,
                                noteText: $sessionVM.currentNoteText,
                                onCommit: { commitNote() },
                                onCancel: { cancelNote() }
                            )
                            .padding(.bottom, 60)
                        } else {
                            timecodeBar
                                .padding(.bottom, 60)
                        }
                    }
                }

                // Error overlay
                if let error = playerVM.playbackError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                        Text("Playback Error")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        if error.lowercased().contains("codec") || error.lowercased().contains("format") {
                            Text("DNxHD/DNxHR requires Avid codecs installed on the system")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                }
            }
            .frame(minWidth: 480, minHeight: 320)

            // Notes sidebar
            NotesPanelView(sessionVM: sessionVM) { seconds in
                playerVM.seek(to: seconds)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: openVideo) {
                    Label("Open Video", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("o")

                Button(action: manualNote) {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                }
                .keyboardShortcut("n")
                .disabled(!playerVM.hasVideo)

                Toggle(isOn: $autoPauseEnabled) {
                    Label("Auto-Pause", systemImage: autoPauseEnabled ? "pause.circle.fill" : "pause.circle")
                }
                .toggleStyle(.button)
                .help("Auto-pause when typing (toggle)")

                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.rawValue) {
                            ExportService.export(session: sessionVM.session, format: format)
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(sessionVM.session.notes.isEmpty)
                .keyboardShortcut("e")
            }
        }
        .onAppear {
            setupKeyHandler()
        }
        .onDisappear {
            keyHandler.stop()
            playerVM.cleanup()
        }
        .focusable()
        .onKeyPress(.space) {
            if !sessionVM.isEditing {
                playerVM.togglePlayPause()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("Open a video to get started")
                .font(.title2)
                .foregroundColor(.secondary)
            Button("Open Video...") {
                openVideo()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var timecodeBar: some View {
        Text(playerVM.currentTimecodeString)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.5))
            )
    }

    // MARK: - Actions

    private func openVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        playerVM.loadVideo(url: url)

        // Detect timecode and configure session after a short delay for asset loading
        Task {
            // Wait for player to be ready
            try? await Task.sleep(for: .milliseconds(500))
            sessionVM.configureSession(
                videoURL: url,
                frameRate: playerVM.frameRate,
                isDropFrame: playerVM.isDropFrame
            )

            // Try to extract embedded timecode
            let asset = AVAsset(url: url)
            if let tcResult = await TimecodeExtractor.extract(from: asset) {
                sessionVM.session.startTimecodeSeconds = tcResult.startTimecodeSeconds
                sessionVM.session.frameRate = tcResult.frameRate
                sessionVM.session.isDropFrame = tcResult.isDropFrame
            }
        }
    }

    private func manualNote() {
        guard playerVM.hasVideo else { return }
        let wasPlaying = playerVM.isPlaying
        if wasPlaying { playerVM.pause() }

        // Stop monitor so TextField gets clean keyboard input
        keyHandler.stop()

        let tc = playerVM.currentTime.toTimecodeInfo(
            frameRate: playerVM.frameRate,
            dropFrame: playerVM.isDropFrame
        )
        sessionVM.beginNote(
            timecodeSeconds: playerVM.currentTime.safeSeconds,
            timecodeString: tc.description
        )
    }

    private func commitNote() {
        sessionVM.commitNote()
        playerVM.play()
        restartKeyMonitor()
    }

    private func cancelNote() {
        sessionVM.cancelNote()
        playerVM.play()
        restartKeyMonitor()
    }

    // MARK: - Key Event Handling

    private func setupKeyHandler() {
        keyHandler.onPrintableKey = { event in
            // Only intercept when auto-pause is on, video is playing, and not editing
            guard autoPauseEnabled,
                  playerVM.isPlaying,
                  !sessionVM.isEditing else {
                return false
            }

            // Auto-pause and start a note
            playerVM.pause()
            let tc = playerVM.currentTime.toTimecodeInfo(
                frameRate: playerVM.frameRate,
                dropFrame: playerVM.isDropFrame
            )
            sessionVM.beginNote(
                timecodeSeconds: playerVM.currentTime.safeSeconds,
                timecodeString: tc.description
            )

            // Forward the first character to the note text
            if let chars = event.characters {
                sessionVM.currentNoteText = chars
            }

            // Stop the monitor so the TextField gets all subsequent keystrokes
            keyHandler.stop()

            return true
        }

        keyHandler.start()
    }

    /// Re-enable the key monitor after editing ends
    private func restartKeyMonitor() {
        if !keyHandler.isActive {
            keyHandler.start()
        }
    }
}
