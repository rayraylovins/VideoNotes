import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var sessionVM = SessionViewModel()
    @StateObject private var keyHandler = KeyEventHandler()
    @StateObject private var speechService = SpeechService()

    @State private var autoPauseEnabled = true
    @State private var voiceModeEnabled = false
    @State private var showExportSheet = false
    @State private var selectedExportFormat: ExportFormat = .plainText

    var body: some View {
        HStack(spacing: 0) {
            // Video area
            ZStack(alignment: .bottom) {
                if playerVM.hasVideo {
                    VideoPlayerView(player: playerVM.player)
                } else {
                    emptyStateView
                }

                // Timecode / note overlay / voice indicator
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
                            .padding(.bottom, 68)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if voiceModeEnabled && speechService.isListening {
                            voiceIndicator
                                .padding(.bottom, 68)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            timecodeBar
                                .padding(.bottom, 68)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: sessionVM.isEditing)
                    .animation(.easeInOut(duration: 0.25), value: speechService.isListening)
                }

                // Error overlay
                if let error = playerVM.playbackError {
                    errorOverlay(error: error)
                }

                // Speech error overlay
                if let error = speechService.errorMessage {
                    speechErrorOverlay(error: error)
                }
            }
            .frame(minWidth: 480, minHeight: 320)

            // Sidebar divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)

            // Notes sidebar
            NotesPanelView(sessionVM: sessionVM) { seconds in
                playerVM.seek(to: seconds)
            }
        }
        .background(Theme.backgroundGradient)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: openVideo) {
                    Label("Open Video", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("o")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $voiceModeEnabled) {
                    Label("Voice", systemImage: voiceModeEnabled ? "mic.fill" : "mic")
                }
                .toggleStyle(.button)
                .tint(voiceModeEnabled ? .red : nil)
                .help("Voice mode — speak to create timestamped notes")
                .disabled(!playerVM.hasVideo)
                .onChange(of: voiceModeEnabled) { _, enabled in
                    handleVoiceModeToggle(enabled: enabled)
                }

                Toggle(isOn: $autoPauseEnabled) {
                    Label("Auto-Pause", systemImage: autoPauseEnabled ? "pause.circle.fill" : "pause.circle")
                }
                .toggleStyle(.button)
                .help("Auto-pause when typing")
                .disabled(voiceModeEnabled)

                Button(action: manualNote) {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                }
                .keyboardShortcut("n")
                .disabled(!playerVM.hasVideo)

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
            speechService.requestPermissions()
        }
        .onDisappear {
            keyHandler.stop()
            speechService.stopListening()
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accentCyan.opacity(0.12))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(Theme.accentCyan.opacity(0.06))
                    .frame(width: 140, height: 140)
                Image(systemName: "film")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accentCyan, Theme.accentViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Open a video to get started")
                .font(.title3.weight(.medium))
                .foregroundColor(Theme.secondaryText)

            Button(action: openVideo) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Open Video")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accentCyan, Theme.accentViolet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Theme.accentCyan.opacity(0.4), radius: 16, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timecodeBar: some View {
        Text(playerVM.currentTimecodeString)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 10)
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    private var voiceIndicator: some View {
        HStack(spacing: 12) {
            // Pulsing mic icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .scaleEffect(speechService.currentTranscript.isEmpty ? 1.0 : 1.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechService.currentTranscript.isEmpty)
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(playerVM.currentTimecodeString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accentCyan)

                if speechService.currentTranscript.isEmpty {
                    Text("Listening...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                } else {
                    Text(speechService.currentTranscript)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 500)
        .glassCard(cornerRadius: Theme.cornerRadius)
        .shadow(color: Color.red.opacity(0.15), radius: 16, y: 4)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    private func errorOverlay(error: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("Playback Error")
                .font(.headline)
                .foregroundColor(Theme.primaryText)
            Text(error)
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if error.lowercased().contains("codec") || error.lowercased().contains("format") {
                Text("DNxHD/DNxHR requires Avid codecs installed on the system")
                    .font(.caption2)
                    .foregroundColor(Theme.tertiaryText)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: Theme.cornerRadiusLarge)
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
    }

    private func speechErrorOverlay(error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.red.opacity(0.8))
            Text(error)
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .glassCard(cornerRadius: Theme.cornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .transition(.opacity)
        .onAppear {
            // Auto-dismiss after 5 seconds
            Task {
                try? await Task.sleep(for: .seconds(5))
                speechService.errorMessage = nil
            }
        }
    }

    // MARK: - Actions

    private func openVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        playerVM.loadVideo(url: url)

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            sessionVM.configureSession(
                videoURL: url,
                frameRate: playerVM.frameRate,
                isDropFrame: playerVM.isDropFrame
            )

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

    // MARK: - Voice Mode

    private func handleVoiceModeToggle(enabled: Bool) {
        if enabled {
            // Disable auto-pause while in voice mode
            autoPauseEnabled = false
            keyHandler.stop()

            // Wire up the speech callback — capture timecode when speech starts
            // Capture video time when speech first starts (offset 0.5s earlier for recognition latency)
            speechService.onSpeechStarted = {
                return max(0, playerVM.currentTime.safeSeconds - 0.5)
            }

            // Use the captured start time for the note timecode
            speechService.onSegmentFinalized = { text, startSeconds in
                let tc = TimecodeInfo.from(
                    seconds: startSeconds,
                    frameRate: playerVM.frameRate,
                    dropFrame: playerVM.isDropFrame
                )
                let note = Note(
                    timecodeSeconds: startSeconds,
                    timecodeString: tc.description,
                    text: text
                )
                sessionVM.session.addNote(note)
                sessionVM.hasUnsavedChanges = true
            }

            speechService.startListening()
        } else {
            speechService.stopListening()
            restartKeyMonitor()
        }
    }

    // MARK: - Key Event Handling

    private func setupKeyHandler() {
        keyHandler.onPrintableKey = { event in
            guard autoPauseEnabled,
                  !voiceModeEnabled,
                  playerVM.isPlaying,
                  !sessionVM.isEditing else {
                return false
            }

            playerVM.pause()
            let tc = playerVM.currentTime.toTimecodeInfo(
                frameRate: playerVM.frameRate,
                dropFrame: playerVM.isDropFrame
            )
            sessionVM.beginNote(
                timecodeSeconds: playerVM.currentTime.safeSeconds,
                timecodeString: tc.description
            )

            if let chars = event.characters {
                sessionVM.currentNoteText = chars
            }

            keyHandler.stop()
            return true
        }

        keyHandler.start()
    }

    private func restartKeyMonitor() {
        if !keyHandler.isActive && !voiceModeEnabled {
            keyHandler.start()
        }
    }
}
