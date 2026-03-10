import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechService: ObservableObject {
    @Published var isListening: Bool = false
    @Published var currentTranscript: String = ""
    @Published var permissionGranted: Bool = false
    @Published var errorMessage: String?

    /// Called when a speech segment is finalized — (text, video seconds when speech started)
    var onSegmentFinalized: ((_ text: String, _ startSeconds: Double) -> Void)?

    /// Called on first partial result of a new segment to capture the video timecode
    var onSpeechStarted: (() -> Double)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5
    private var isRestarting: Bool = false
    private var segmentStartSeconds: Double = 0

    // MARK: - Permissions

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.permissionGranted = true
                    self.errorMessage = nil
                case .denied:
                    self.permissionGranted = false
                    self.errorMessage = "Speech recognition permission denied. Enable in System Settings > Privacy & Security > Speech Recognition."
                case .restricted:
                    self.permissionGranted = false
                    self.errorMessage = "Speech recognition is restricted on this device."
                case .notDetermined:
                    self.permissionGranted = false
                @unknown default:
                    self.permissionGranted = false
                }
            }
        }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if !granted {
                    self.permissionGranted = false
                    self.errorMessage = "Microphone access denied. Enable in System Settings > Privacy & Security > Microphone."
                }
            }
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard permissionGranted else {
            requestPermissions()
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            return
        }

        beginRecognitionSession()
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        isRestarting = false

        // Finalize any pending speech
        let text = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            onSegmentFinalized?(text, segmentStartSeconds)
            currentTranscript = ""
        }

        tearDownAudio()
        isListening = false
    }

    // MARK: - Private: Session Lifecycle

    private func beginRecognitionSession() {
        // Tear down any previous session without touching isListening
        tearDownAudio()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer!.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                // Ignore callbacks if we're in the middle of an intentional restart
                if self.isRestarting { return }

                if let result {
                    // Capture video timecode the moment speech first arrives
                    if self.currentTranscript.isEmpty && !result.bestTranscription.formattedString.isEmpty {
                        self.segmentStartSeconds = self.onSpeechStarted?() ?? 0
                    }
                    self.currentTranscript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.finalizeAndRestart()
                    }
                }

                if let error {
                    // Ignore cancellation errors (we cause these during restart)
                    let nsError = error as NSError
                    let isCancellation = nsError.code == 216 || nsError.code == 209
                    if isCancellation { return }

                    // "No speech detected" timeout or other recoverable error — restart
                    if self.isListening {
                        self.finalizeAndRestart()
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            errorMessage = nil
        } catch {
            errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
            tearDownAudio()
            isListening = false
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isListening, !self.isRestarting else { return }
                self.finalizeAndRestart()
            }
        }
    }

    /// Finalize the current transcript as a note and start a fresh recognition session
    private func finalizeAndRestart() {
        guard !isRestarting else { return }
        isRestarting = true

        silenceTimer?.invalidate()
        silenceTimer = nil

        // Commit current text
        let text = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            onSegmentFinalized?(text, segmentStartSeconds)
        }
        currentTranscript = ""
        segmentStartSeconds = 0

        // Tear down old session, then start fresh after a brief delay
        tearDownAudio()

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard self.isListening else {
                self.isRestarting = false
                return
            }
            self.isRestarting = false
            self.beginRecognitionSession()
        }
    }

    private func tearDownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
