import AVFoundation

struct TimecodeExtractor {
    struct Result {
        let startTimecodeSeconds: Double
        let frameRate: Double
        let isDropFrame: Bool
    }

    static func extract(from asset: AVAsset) async -> Result? {
        do {
            let timecodeTracks = try await asset.loadTracks(withMediaType: .timecode)
            guard let track = timecodeTracks.first else { return nil }

            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(output)

            guard reader.startReading() else { return nil }
            guard let sampleBuffer = output.copyNextSampleBuffer() else { return nil }

            // Parse timecode from sample buffer
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

            guard length >= 4, let ptr = dataPointer else { return nil }

            // 4-byte big-endian frame number
            let frameNumber = ptr.withMemoryRebound(to: UInt32.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee)
            }

            // Get format description for timecode flags
            guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
            let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDesc)

            // Detect frame rate from video track
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let nominalRate: Float
            if let videoTrack = videoTracks.first {
                nominalRate = try await videoTrack.load(.nominalFrameRate)
            } else {
                nominalRate = 24.0
            }

            let fps = Double(nominalRate)
            let roundedFPS = Int(fps.rounded())

            // Check drop frame flag from timecode type
            // mediaSubType 'tmcd' = timecode media
            let isDropFrame: Bool
            if mediaSubType == kCMMediaType_TimeCode {
                // Check if the extensions dictionary contains drop frame info
                let extensions = CMFormatDescriptionGetExtensions(formatDesc) as? [String: Any]
                if let flags = extensions?["CVTimeCodeFlags"] as? UInt32 {
                    isDropFrame = (flags & 0x01) != 0 // kCMTimeCodeFlag_DropFrame
                } else {
                    isDropFrame = (roundedFPS == 30 && abs(nominalRate - 29.97) < 0.1) ||
                                  (roundedFPS == 60 && abs(nominalRate - 59.94) < 0.1)
                }
            } else {
                isDropFrame = false
            }

            let startSeconds = Double(frameNumber) / fps

            return Result(startTimecodeSeconds: startSeconds, frameRate: fps, isDropFrame: isDropFrame)
        } catch {
            return nil
        }
    }
}
