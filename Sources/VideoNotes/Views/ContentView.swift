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
    @State private var isReviewMode = false
    @State private var isReviewChromeVisible = true
    @State private var isReviewNotesPanelVisible = false
    @State private var isWindowFullscreen = false
    @State private var reviewChromeHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppBackdrop()

            Group {
                if isReviewMode {
                    reviewModeLayout
                } else {
                    standardLayout
                }
            }
            .padding(isReviewMode ? 10 : 16)
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
                Button(action: toggleReviewMode) {
                    Label(isReviewMode ? "Exit Review" : "Review Mode", systemImage: isReviewMode ? "rectangle.inset.filled.and.person.filled" : "rectangle.inset.filled")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                if isReviewMode {
                    Button(action: toggleReviewNotesPanel) {
                        Label("Notes Panel", systemImage: isReviewNotesPanelVisible ? "sidebar.right" : "sidebar.right")
                    }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    .disabled(sessionVM.session.notes.isEmpty && !playerVM.hasVideo)
                }

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
            reviewChromeHideTask?.cancel()
            keyHandler.stop()
            speechService.stopListening()
            playerVM.cleanup()
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
                revealReviewChrome()
            }
        }
        .background(
            FullscreenWindowObserver { isFullscreen in
                isWindowFullscreen = isFullscreen

                if isFullscreen {
                    if !isReviewMode {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isReviewMode = true
                        }
                    }
                    revealReviewChrome()
                }
            }
        )
        .background(
            ReviewModeWindowConfigurator(isReviewMode: isReviewMode)
        )
        .onChange(of: isReviewMode) { _, enabled in
            reviewChromeHideTask?.cancel()
            if enabled {
                isReviewChromeVisible = true
                scheduleReviewChromeHide()
            } else {
                isReviewChromeVisible = true
                isReviewNotesPanelVisible = false
            }
        }
        .onChange(of: sessionVM.isEditing) { _, editing in
            if editing {
                revealReviewChrome(keepVisible: true)
            } else {
                scheduleReviewChromeHide()
            }
        }
        .onChange(of: speechService.isListening) { _, listening in
            if listening {
                revealReviewChrome(keepVisible: true)
            } else {
                scheduleReviewChromeHide()
            }
        }
        .onChange(of: isReviewNotesPanelVisible) { _, visible in
            if visible {
                revealReviewChrome(keepVisible: true)
            } else {
                scheduleReviewChromeHide()
            }
        }
        .onChange(of: playerVM.playbackError) { _, _ in
            revealReviewChrome(keepVisible: true)
        }
        .onChange(of: speechService.errorMessage) { _, _ in
            revealReviewChrome(keepVisible: true)
        }
    }

    private var standardLayout: some View {
        VStack(spacing: 14) {
            appTopStrip

            HStack(alignment: .top, spacing: 14) {
                standardVideoWorkspace
                standardNotesWorkspace
            }
        }
    }

    private var reviewModeLayout: some View {
        ZStack(alignment: .trailing) {
            reviewVideoWorkspace

            if isReviewNotesPanelVisible {
                reviewNotesOverlay
                    .padding(.trailing, 18)
                    .padding(.vertical, 18)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isReviewNotesPanelVisible)
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
            AppIconPreview(size: 34, cornerRadius: 9)

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

    private var standardVideoWorkspace: some View {
        VStack(spacing: 0) {
            playerHeader
            standardMonitorArea
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

    private var standardMonitorArea: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

            playerSurface(videoGravity: .resizeAspect)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

            if playerVM.hasVideo {
                bottomOverlay
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }

            errorLayers(bottomPadding: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var standardNotesWorkspace: some View {
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

    private var reviewVideoWorkspace: some View {
        ZStack {
            playerSurface(videoGravity: .resizeAspect)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            LinearGradient(
                colors: [
                    Color.black.opacity(shouldShowReviewChrome ? 0.10 : 0.02),
                    Color.clear,
                    Color.black.opacity(shouldShowReviewChrome ? 0.12 : 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                if shouldShowReviewChrome {
                    reviewTopBar
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                VStack(spacing: 12) {
                    bottomOverlay

                    if shouldShowReviewChrome {
                        reviewBottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }

            errorLayers(bottomPadding: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.34), radius: 34, y: 22)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            revealReviewChrome()
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                revealReviewChrome()
            case .ended:
                scheduleReviewChromeHide()
            }
        }
    }

    private var reviewTopBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                AppIconPreview(size: 28, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionVM.session.videoFileName.isEmpty ? "Review Mode" : sessionVM.session.videoFileName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("REVIEW MODE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(Theme.tertiaryText)
                }
            }

            Spacer()

            Button(action: toggleReviewNotesPanel) {
                HStack(spacing: 6) {
                    Image(systemName: "sidebar.right")
                    Text("Notes \(sessionVM.session.notes.count)")
                }
                .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.26)))

            monitorBadge(
                text: playerVM.isPlaying ? "PLAY" : "STOP",
                tint: playerVM.isPlaying ? Theme.accentMint : Theme.accentAmber
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlayGlassCard(cornerRadius: 18)
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
    }

    private var reviewBottomBar: some View {
        HStack(spacing: 12) {
            compactFooterPill(systemName: playerVM.isPlaying ? "play.fill" : "pause.fill", text: playerVM.currentTimecodeString, accent: Theme.accentCyan, monospaced: true)
            compactFooterPill(systemName: voiceModeEnabled ? "waveform" : "keyboard", text: footerHintText, accent: voiceModeEnabled ? .red : Theme.accentAmber, monospaced: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18)
    }

    private var reviewNotesOverlay: some View {
        NotesPanelView(sessionVM: sessionVM, onSeek: { seconds in
            playerVM.seek(to: seconds)
            revealReviewChrome(keepVisible: true)
        }, isOverlayStyle: true, onClose: {
            withAnimation(.easeInOut(duration: 0.22)) {
                isReviewNotesPanelVisible = false
            }
            scheduleReviewChromeHide()
        })
        .frame(width: 340)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
        )
        .overlayGlassCard(cornerRadius: 24)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 24, y: 12)
    }

    @ViewBuilder
    private func playerSurface(videoGravity: AVLayerVideoGravity) -> some View {
        if playerVM.hasVideo {
            VideoPlayerView(player: playerVM.player, videoGravity: videoGravity)
        } else {
            emptyStateView
        }
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
                    AppIconPreview(size: 60, cornerRadius: 14)

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
                .frame(height: 16)

            Text(speechService.currentTranscript.isEmpty ? "Listening for speech…" : speechService.currentTranscript)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text(playerVM.currentTimecodeString)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accentCyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 520)
        .surfaceCard(cornerRadius: 16, fillOpacity: 0.96)
    }

    @ViewBuilder
    private func errorLayers(bottomPadding: CGFloat) -> some View {
        if let error = playerVM.playbackError {
            errorOverlay(error: error)
        }

        if let error = speechService.errorMessage {
            speechErrorOverlay(error: error)
                .padding(.bottom, bottomPadding)
        }
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

    private var shouldKeepReviewChromeVisible: Bool {
        sessionVM.isEditing ||
        speechService.isListening ||
        isReviewNotesPanelVisible ||
        playerVM.playbackError != nil ||
        speechService.errorMessage != nil ||
        !playerVM.hasVideo
    }

    private var shouldShowReviewChrome: Bool {
        !isReviewMode || isReviewChromeVisible || shouldKeepReviewChromeVisible
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

    private func compactFooterPill(systemName: String, text: String, accent: Color, monospaced: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .foregroundColor(accent)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: monospaced ? .monospaced : .default))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.22))
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

    private func toggleReviewMode() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isReviewMode.toggle()
        }
        if !isReviewMode {
            isReviewNotesPanelVisible = false
        }
        revealReviewChrome(keepVisible: true)
    }

    private func toggleReviewNotesPanel() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isReviewNotesPanelVisible.toggle()
        }
        revealReviewChrome(keepVisible: isReviewNotesPanelVisible)
    }

    private func revealReviewChrome(keepVisible: Bool = false) {
        guard isReviewMode else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            isReviewChromeVisible = true
        }
        if keepVisible {
            reviewChromeHideTask?.cancel()
        } else {
            scheduleReviewChromeHide()
        }
    }

    private func scheduleReviewChromeHide() {
        reviewChromeHideTask?.cancel()
        guard isReviewMode, !shouldKeepReviewChromeVisible else { return }

        reviewChromeHideTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard isReviewMode, !shouldKeepReviewChromeVisible else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    isReviewChromeVisible = false
                }
            }
        }
    }

    private func openVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        playerVM.loadVideo(url: url)
        revealReviewChrome(keepVisible: true)

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
        revealReviewChrome(keepVisible: true)

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
                restoreKeyboardFocus()
                restartKeyMonitor()
                scheduleReviewChromeHide()
            }
        }
    }

    private func cancelNote() {
        sessionVM.cancelNote()
        if wasPausedByAutoPause { playerVM.play() }
        wasPausedByAutoPause = false
        restoreKeyboardFocus()
        restartKeyMonitor()
        scheduleReviewChromeHide()
    }

    private func handleVoiceModeToggle(enabled: Bool) {
        revealReviewChrome(keepVisible: enabled)

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
        keyHandler.onKeyDown = { event in
            guard !sessionVM.isEditing, playerVM.hasVideo else {
                return false
            }

            switch Int(event.keyCode) {
            case 49: // Space
                revealReviewChrome()
                playerVM.togglePlayPause()
                return true
            case 123: // Left arrow
                revealReviewChrome()
                playerVM.seekBy(seconds: -5)
                return true
            case 124: // Right arrow
                revealReviewChrome()
                playerVM.seekBy(seconds: 5)
                return true
            default:
                return false
            }
        }

        keyHandler.onPrintableKey = { event in
            guard !voiceModeEnabled,
                  playerVM.hasVideo,
                  !sessionVM.isEditing else {
                return false
            }

            let initialText = event.characters ?? ""
            guard initialText != " " else {
                return false
            }

            if autoPauseEnabled && playerVM.isPlaying {
                wasPausedByAutoPause = true
                playerVM.pause()
            } else {
                wasPausedByAutoPause = false
            }

            revealReviewChrome(keepVisible: true)

            let tc = playerVM.currentTime.toTimecodeInfo(
                frameRate: playerVM.frameRate,
                dropFrame: playerVM.isDropFrame
            )
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

    private func restoreKeyboardFocus() {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow else { return }
            window.makeFirstResponder(nil)
            if let contentView = window.contentView {
                window.makeFirstResponder(contentView)
            }
        }
    }
}

private struct AppIconPreview: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let iconImage = NSImage(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AppIcon.icns")) {
                Image(nsImage: iconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.heroGradient)
                    .frame(width: size, height: size)
            }
        }
    }
}

private struct FullscreenWindowObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    final class Coordinator {
        private let onChange: (Bool) -> Void
        private weak var window: NSWindow?
        private var willEnterObserver: NSObjectProtocol?
        private var willExitObserver: NSObjectProtocol?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
        }

        deinit {
            if let willEnterObserver {
                NotificationCenter.default.removeObserver(willEnterObserver)
            }
            if let willExitObserver {
                NotificationCenter.default.removeObserver(willExitObserver)
            }
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }

            if let willEnterObserver {
                NotificationCenter.default.removeObserver(willEnterObserver)
            }
            if let willExitObserver {
                NotificationCenter.default.removeObserver(willExitObserver)
            }

            self.window = window
            onChange(window.styleMask.contains(.fullScreen))

            willEnterObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willEnterFullScreenNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onChange(true)
            }

            willExitObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willExitFullScreenNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onChange(false)
            }
        }
    }
}

private struct ReviewModeWindowConfigurator: NSViewRepresentable {
    let isReviewMode: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
            context.coordinator.apply(isReviewMode: isReviewMode)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
            context.coordinator.apply(isReviewMode: isReviewMode)
        }
    }

    final class Coordinator {
        private weak var window: NSWindow?

        func attach(to window: NSWindow?) {
            guard let window else { return }
            self.window = window
        }

        func apply(isReviewMode: Bool) {
            guard let window else { return }

            window.titleVisibility = isReviewMode ? .hidden : .visible
            window.titlebarAppearsTransparent = isReviewMode
            window.toolbarStyle = .unified
            window.toolbar?.showsBaselineSeparator = !isReviewMode
            window.toolbar?.isVisible = !isReviewMode
        }
    }
}
