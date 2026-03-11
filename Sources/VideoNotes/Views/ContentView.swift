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
    @State private var wasPausedByAutoPause = false

    var body: some View {
        ZStack {
            AppBackdrop()

            HStack(spacing: 18) {
                videoWorkspace
                notesWorkspace
            }
            .padding(18)
        }
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: openVideo) {
                    Label("Open", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("o")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $voiceModeEnabled) {
                    Label("Voice", systemImage: voiceModeEnabled ? "waveform.badge.mic" : "mic")
                }
                .toggleStyle(.button)
                .tint(voiceModeEnabled ? .red : nil)
                .help("Voice mode creates timestamped notes from speech")
                .disabled(!playerVM.hasVideo)
                .onChange(of: voiceModeEnabled) { _, enabled in
                    handleVoiceModeToggle(enabled: enabled)
                }

                Toggle(isOn: $autoPauseEnabled) {
                    Label("Auto Pause", systemImage: autoPauseEnabled ? "pause.circle.fill" : "pause.circle")
                }
                .toggleStyle(.button)
                .help("Pause playback when note entry begins")
                .disabled(voiceModeEnabled)

                Button(action: manualNote) {
                    Label("Add Note", systemImage: "square.and.pencil")
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
        .onReceive(NotificationCenter.default.publisher(for: .saveSession)) { _ in
            sessionVM.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveSessionAs)) { _ in
            sessionVM.saveAs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSession)) { _ in
            if let videoURL = sessionVM.openSession() {
                playerVM.loadVideo(url: videoURL)
            }
        }
    }

    private var videoWorkspace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }

            ZStack(alignment: .bottom) {
                if playerVM.hasVideo {
                    VideoPlayerView(player: playerVM.player)
                } else {
                    emptyStateView
                }

                if playerVM.hasVideo {
                    VStack(spacing: 0) {
                        playerHeader
                        Spacer()
                        bottomOverlay
                    }
                    .padding(20)
                }

                if let error = playerVM.playbackError {
                    errorOverlay(error: error)
                }

                if let error = speechService.errorMessage {
                    speechErrorOverlay(error: error)
                        .padding(.bottom, 28)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous))
        }
        .frame(minWidth: 560, minHeight: 420)
        .surfaceCard(cornerRadius: Theme.cornerRadiusXLarge, fillOpacity: 0.82)
        .shadow(color: Color.black.opacity(0.30), radius: 30, y: 20)
    }

    private var notesWorkspace: some View {
        NotesPanelView(sessionVM: sessionVM) { seconds in
            playerVM.seek(to: seconds)
        }
        .frame(minWidth: 320, idealWidth: 340, maxWidth: 380)
        .surfaceCard(cornerRadius: Theme.cornerRadiusXLarge, fillOpacity: 0.90)
        .shadow(color: Color.black.opacity(0.20), radius: 24, y: 16)
    }

    private var playerHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(sessionVM.session.videoFileName.isEmpty ? "Current Session" : sessionVM.session.videoFileName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    infoPill(title: playerVM.isPlaying ? "Live" : "Paused", value: playerVM.isPlaying ? "Playing" : "Ready")
                    infoPill(title: "Format", value: frameRateLabel)
                    infoPill(title: "Notes", value: "\(sessionVM.session.notes.count)")
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                smallControlPill(systemName: autoPauseEnabled ? "pause.circle.fill" : "pause.circle", text: "Auto")
                if voiceModeEnabled {
                    smallControlPill(systemName: "mic.fill", text: "Voice")
                }
            }
        }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 0) {
            if sessionVM.isEditing {
                NoteOverlayView(
                    timecodeString: playerVM.currentTimecodeString,
                    noteText: $sessionVM.currentNoteText,
                    onCommit: { commitNote() },
                    onCancel: { cancelNote() }
                )
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if voiceModeEnabled && speechService.isListening {
                voiceIndicator
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            playerFooter
        }
        .animation(.easeInOut(duration: 0.25), value: sessionVM.isEditing)
        .animation(.easeInOut(duration: 0.25), value: speechService.isListening)
    }

    private var playerFooter: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: playerVM.isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accentMint)

                Text(playerVM.currentTimecodeString)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()

            Text(footerHintText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 18)
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    private var emptyStateView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.accentBlue.opacity(0.22),
                    Theme.accentViolet.opacity(0.14),
                    Theme.midnight.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 26) {
                Spacer()

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Theme.heroGradient)
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "video.badge.waveform")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video Notes")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Fast timestamped note-taking for review sessions")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.secondaryText)
                        }
                    }

                    Text("Open a cut, screen recording, or interview, then type or dictate notes without breaking playback flow.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .frame(maxWidth: 480, alignment: .leading)

                    HStack(spacing: 10) {
                        featureBadge(systemName: "keyboard", text: "Type to capture")
                        featureBadge(systemName: "waveform", text: "Voice notes")
                        featureBadge(systemName: "square.and.arrow.up", text: "Export formats")
                    }
                }

                HStack(spacing: 14) {
                    Button(action: openVideo) {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                            Text("Open Video")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Theme.heroGradient)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Shortcut: Cmd+O")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.tertiaryText)
                }

                Spacer()
            }
            .padding(34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var voiceIndicator: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .scaleEffect(speechService.currentTranscript.isEmpty ? 1.0 : 1.18)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: speechService.currentTranscript.isEmpty)

                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Capture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(speechService.currentTranscript.isEmpty ? "Listening for the next note…" : speechService.currentTranscript)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Text(playerVM.currentTimecodeString)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accentCyan)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 560)
        .glassCard(cornerRadius: 18)
        .shadow(color: Color.red.opacity(0.08), radius: 16, y: 8)
    }

    private func errorOverlay(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Playback Error")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(error)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)

            if error.lowercased().contains("codec") || error.lowercased().contains("format") {
                Text("DNxHD and DNxHR playback requires the Avid codecs installed on this Mac.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.tertiaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .glassCard(cornerRadius: Theme.cornerRadiusLarge)
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }

    private func speechErrorOverlay(error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .foregroundColor(.red.opacity(0.9))

            Text(error)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 14)
        .transition(.opacity)
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(5))
                speechService.errorMessage = nil
            }
        }
    }

    private var frameRateLabel: String {
        let frameRate = sessionVM.session.frameRate > 0 ? sessionVM.session.frameRate : playerVM.frameRate
        return String(format: "%.2f fps", frameRate)
    }

    private var footerHintText: String {
        if voiceModeEnabled {
            return "Voice mode active"
        }
        if autoPauseEnabled {
            return "Type anywhere to create a note"
        }
        return "Press N to add a note manually"
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.tertiaryText)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.20))
        )
    }

    private func smallControlPill(systemName: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.24))
        )
    }

    private func featureBadge(systemName: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.92))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }

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
        if wasPausedByAutoPause { playerVM.play() }
        wasPausedByAutoPause = false
        restartKeyMonitor()
    }

    private func cancelNote() {
        sessionVM.cancelNote()
        if wasPausedByAutoPause { playerVM.play() }
        wasPausedByAutoPause = false
        restartKeyMonitor()
    }

    private func handleVoiceModeToggle(enabled: Bool) {
        if enabled {
            autoPauseEnabled = false
            keyHandler.stop()

            speechService.onSpeechStarted = {
                return max(0, playerVM.currentTime.safeSeconds - 0.5)
            }

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

    private func setupKeyHandler() {
        keyHandler.onPrintableKey = { event in
            guard !voiceModeEnabled,
                  playerVM.hasVideo,
                  !sessionVM.isEditing else {
                return false
            }

            if autoPauseEnabled && playerVM.isPlaying {
                wasPausedByAutoPause = true
                playerVM.pause()
            } else {
                wasPausedByAutoPause = false
            }

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
