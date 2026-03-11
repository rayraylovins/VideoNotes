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

            VStack(spacing: 14) {
                appTopStrip

                HStack(alignment: .top, spacing: 14) {
                    videoWorkspace
                    notesWorkspace
                }
            }
            .padding(16)
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
                    Label("Add Note", systemImage: "text.badge.plus")
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

    private var appTopStrip: some View {
        HStack(spacing: 10) {
            stripTitle

            Spacer()

            stripStatus(title: "SESSION", value: sessionVM.session.videoFileName.isEmpty ? "NO MEDIA" : "LOADED")
            stripStatus(title: "NOTES", value: "\(sessionVM.session.notes.count)")
            stripStatus(title: "TC", value: playerVM.currentTimecodeString)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .surfaceCard(cornerRadius: 18, fillOpacity: 0.92)
    }

    private var stripTitle: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.heroGradient)
                    .frame(width: 34, height: 34)

                Image(systemName: "timeline.selection")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("VIDEO NOTES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundColor(.white)

                Text("review logger")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.tertiaryText)
            }
        }
    }

    private var videoWorkspace: some View {
        VStack(spacing: 0) {
            playerHeader

            monitorArea

            playerFooter
        }
        .frame(minWidth: 600, minHeight: 440)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .fill(Theme.monitorGradient)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.34), radius: 34, y: 22)
    }

    private var monitorArea: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

            Group {
                if playerVM.hasVideo {
                    VideoPlayerView(player: playerVM.player)
                } else {
                    emptyStateView
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            if playerVM.hasVideo {
                bottomOverlay
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }

            if let error = playerVM.playbackError {
                errorOverlay(error: error)
            }

            if let error = speechService.errorMessage {
                speechErrorOverlay(error: error)
                    .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notesWorkspace: some View {
        NotesPanelView(sessionVM: sessionVM) { seconds in
            playerVM.seek(to: seconds)
        }
        .frame(minWidth: 340, idealWidth: 360, maxWidth: 390)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .fill(Theme.monitorGradient)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 26, y: 18)
    }

    private var playerHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("PROGRAM MONITOR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(Theme.tertiaryText)

                    monitorBadge(
                        text: playerVM.isPlaying ? "PLAY" : "STOP",
                        tint: playerVM.isPlaying ? Theme.accentMint : Theme.accentAmber
                    )
                }

                Text(sessionVM.session.videoFileName.isEmpty ? "No clip loaded" : sessionVM.session.videoFileName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                infoPill(title: "Rate", value: frameRateLabel)
                infoPill(title: "Drop", value: dropFrameLabel)
                infoPill(title: "Notes", value: "\(sessionVM.session.notes.count)")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Color.white.opacity(0.03))
    }

    private var bottomOverlay: some View {
        VStack(spacing: 12) {
            if sessionVM.isEditing {
                NoteOverlayView(
                    timecodeString: playerVM.currentTimecodeString,
                    noteText: $sessionVM.currentNoteText,
                    onCommit: { commitNote() },
                    onCancel: { cancelNote() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if voiceModeEnabled && speechService.isListening {
                voiceIndicator
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: sessionVM.isEditing)
        .animation(.easeInOut(duration: 0.22), value: speechService.isListening)
    }

    private var playerFooter: some View {
        HStack(spacing: 12) {
            footerBlock(title: "Current TC", value: playerVM.currentTimecodeString, accent: Theme.accentCyan)
            footerBlock(title: "Capture", value: footerHintText, accent: Theme.accentMint)
            footerBlock(title: "Input", value: voiceModeEnabled ? "VOICE" : "KEYBOARD", accent: voiceModeEnabled ? .red : Theme.accentAmber)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.18))
    }

    private var emptyStateView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.40),
                    Theme.panelMuted.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 18) {
                Spacer()

                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.heroGradient.opacity(0.28))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Load media to begin a review pass")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Use keyboard notes for fast frame-accurate logging or switch to voice capture for hands-free review.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                            .frame(maxWidth: 460, alignment: .leading)
                    }
                }

                HStack(spacing: 12) {
                    productionTag(systemName: "keyboard", text: "Type to mark")
                    productionTag(systemName: "waveform", text: "Voice capture")
                    productionTag(systemName: "square.and.arrow.up", text: "Editorial exports")
                }

                HStack(spacing: 12) {
                    Button(action: openVideo) {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                            Text("Load Video")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.heroGradient)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Cmd+O")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.tertiaryText)
                }

                Spacer()
            }
            .padding(30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var voiceIndicator: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 9, height: 9)
                    .shadow(color: Color.red.opacity(0.40), radius: 10)

                Text("VOICE INPUT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.white.opacity(0.12))

            Text(speechService.currentTranscript.isEmpty ? "Listening for speech…" : speechService.currentTranscript)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(2)

            Spacer()

            Text(playerVM.currentTimecodeString)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accentCyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 640)
        .surfaceCard(cornerRadius: 16, fillOpacity: 0.96)
    }

    private func errorOverlay(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30, weight: .medium))
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
        .padding(22)
        .frame(maxWidth: 360)
        .surfaceCard(cornerRadius: Theme.cornerRadiusLarge, fillOpacity: 0.96)
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
        .surfaceCard(cornerRadius: 14, fillOpacity: 0.96)
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
        return String(format: "%.2f", frameRate)
    }

    private var dropFrameLabel: String {
        (sessionVM.session.isDropFrame || playerVM.isDropFrame) ? "DF" : "NDF"
    }

    private var footerHintText: String {
        if voiceModeEnabled {
            return "Speech logging active"
        }
        if autoPauseEnabled {
            return "Type anywhere to drop a note"
        }
        return "Press N for manual note"
    }

    private func stripStatus(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(Theme.tertiaryText)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: title == "TC" ? .monospaced : .default))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.tertiaryText)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.20))
        )
    }

    private func monitorBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.22))
            )
            .overlay {
                Capsule()
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            }
    }

    private func footerBlock(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 10, height: 2)

                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(Theme.tertiaryText)
            }

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: title == "Current TC" ? .monospaced : .default))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func productionTag(systemName: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.white.opacity(0.90))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
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
        let wasAutoPaused = wasPausedByAutoPause
        let captureTime = sessionVM.pendingNoteTimecodeSeconds

        Task {
            let thumbnailJPEGData: Data?
            if let captureTime {
                thumbnailJPEGData = await playerVM.captureFrameJPEG(at: captureTime)
            } else {
                thumbnailJPEGData = nil
            }

            await MainActor.run {
                sessionVM.commitNote(thumbnailJPEGData: thumbnailJPEGData)
                if wasAutoPaused { playerVM.play() }
                wasPausedByAutoPause = false
                restartKeyMonitor()
            }
        }
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
                max(0, playerVM.currentTime.safeSeconds - 0.5)
            }

            speechService.onSegmentFinalized = { text, startSeconds in
                Task {
                    let tc = TimecodeInfo.from(
                        seconds: startSeconds,
                        frameRate: playerVM.frameRate,
                        dropFrame: playerVM.isDropFrame
                    )
                    let thumbnailJPEGData = await playerVM.captureFrameJPEG(at: startSeconds)

                    await MainActor.run {
                        sessionVM.addCapturedNote(
                            timecodeSeconds: startSeconds,
                            timecodeString: tc.description,
                            text: text,
                            thumbnailJPEGData: thumbnailJPEGData
                        )
                    }
                }
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
            let initialText = event.characters ?? ""
            sessionVM.beginNote(
                timecodeSeconds: playerVM.currentTime.safeSeconds,
                timecodeString: tc.description,
                initialText: initialText
            )

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
