import AVFoundation
import AVKit
import Combine
import SwiftUI
import AppKit

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer = AVPlayer()
    @Published var isPlaying: Bool = false
    @Published var currentTime: CMTime = .zero
    @Published var duration: CMTime = .zero
    @Published var currentTimecodeString: String = "00:00:00:00"
    @Published var frameRate: Double = 24.0
    @Published var isDropFrame: Bool = false
    @Published var hasVideo: Bool = false
    @Published var playbackError: String?

    private var timeObserver: Any?
    private var statusObserver: AnyCancellable?
    private var rateObserver: AnyCancellable?

    func loadVideo(url: URL) {
        cleanup()

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)

        // Observe player item status
        statusObserver = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.hasVideo = true
                    self.playbackError = nil
                    Task { await self.detectFrameRate(asset: asset) }
                    Task { await self.loadDuration(asset: asset) }
                case .failed:
                    self.hasVideo = false
                    self.playbackError = item.error?.localizedDescription ?? "Failed to load video"
                default:
                    break
                }
            }

        // Observe play rate
        rateObserver = player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.isPlaying = rate > 0
            }

        // Periodic time observer
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time
                let tc = TimecodeInfo.from(cmTime: time, frameRate: self.frameRate, dropFrame: self.isDropFrame)
                self.currentTimecodeString = tc.description
            }
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        let clampedSeconds = max(0, min(seconds, duration.safeSeconds > 0 ? duration.safeSeconds : seconds))
        let time = CMTime(seconds: clampedSeconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seekBy(seconds delta: Double) {
        seek(to: currentTime.safeSeconds + delta)
    }

    func captureFrameJPEG(at seconds: Double, maxSize: CGSize = CGSize(width: 640, height: 360)) async -> Data? {
        guard let asset = player.currentItem?.asset else { return nil }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)

        return await Task.detached(priority: .utility) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = maxSize
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                let bitmapRep = NSBitmapImageRep(cgImage: image)
                return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
            } catch {
                return nil
            }
        }.value
    }

    private func detectFrameRate(asset: AVAsset) async {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = tracks.first {
                let rate = try await videoTrack.load(.nominalFrameRate)
                self.frameRate = Double(rate)
                // Check for drop frame
                let roundedRate = rate.rounded()
                if roundedRate == 30 && abs(rate - 29.97) < 0.1 {
                    self.isDropFrame = true
                } else if roundedRate == 60 && abs(rate - 59.94) < 0.1 {
                    self.isDropFrame = true
                } else {
                    self.isDropFrame = false
                }
            }
        } catch {
            // Default frame rate already set
        }
    }

    private func loadDuration(asset: AVAsset) async {
        do {
            self.duration = try await asset.load(.duration)
        } catch {
            // Duration remains zero
        }
    }

    func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObserver?.cancel()
        rateObserver?.cancel()
        player.replaceCurrentItem(with: nil)
        hasVideo = false
        isPlaying = false
        currentTime = .zero
        duration = .zero
        currentTimecodeString = "00:00:00:00"
        playbackError = nil
    }
}
