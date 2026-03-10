import Foundation
import CoreMedia

struct TimecodeInfo: Codable, Equatable, CustomStringConvertible {
    let hours: Int
    let minutes: Int
    let seconds: Int
    let frames: Int
    let frameRate: Double
    let isDropFrame: Bool

    var description: String {
        let separator = isDropFrame ? ";" : ":"
        return String(format: "%02d:%02d:%02d%@%02d", hours, minutes, seconds, separator, frames)
    }

    var totalFrames: Int {
        let fps = Int(frameRate.rounded())
        return hours * 3600 * fps + minutes * 60 * fps + seconds * fps + frames
    }

    var totalSeconds: Double {
        let base = Double(hours * 3600 + minutes * 60 + seconds)
        return base + Double(frames) / frameRate
    }

    static func from(seconds: Double, frameRate: Double, dropFrame: Bool = false) -> TimecodeInfo {
        let fps = frameRate.rounded()
        let totalFrameCount: Int

        if dropFrame && (fps == 30 || fps == 60) {
            totalFrameCount = Int((seconds * frameRate).rounded())
            return fromDropFrameCount(totalFrameCount, frameRate: frameRate)
        } else {
            totalFrameCount = Int((seconds * fps).rounded())
            let fpsInt = Int(fps)
            let f = totalFrameCount % fpsInt
            let totalSecs = totalFrameCount / fpsInt
            let s = totalSecs % 60
            let totalMins = totalSecs / 60
            let m = totalMins % 60
            let h = totalMins / 60
            return TimecodeInfo(hours: h, minutes: m, seconds: s, frames: f, frameRate: frameRate, isDropFrame: false)
        }
    }

    static func from(cmTime: CMTime, frameRate: Double, dropFrame: Bool = false) -> TimecodeInfo {
        let seconds = CMTimeGetSeconds(cmTime)
        guard seconds.isFinite && seconds >= 0 else {
            return TimecodeInfo(hours: 0, minutes: 0, seconds: 0, frames: 0, frameRate: frameRate, isDropFrame: dropFrame)
        }
        return from(seconds: seconds, frameRate: frameRate, dropFrame: dropFrame)
    }

    private static func fromDropFrameCount(_ frameCount: Int, frameRate: Double) -> TimecodeInfo {
        let fps = Int(frameRate.rounded())
        let dropFrames: Int
        if fps == 30 {
            dropFrames = 2
        } else if fps == 60 {
            dropFrames = 4
        } else {
            dropFrames = 0
        }

        let framesPerMin = fps * 60 - dropFrames
        let framesPer10Min = framesPerMin * 10 + dropFrames

        let d = frameCount / framesPer10Min
        let m = frameCount % framesPer10Min

        var adjustedFrames = frameCount
        if m >= dropFrames {
            adjustedFrames += dropFrames * ((m - dropFrames) / framesPerMin)
            adjustedFrames += dropFrames
        }

        let f = adjustedFrames % fps
        let totalSecs = adjustedFrames / fps
        let s = totalSecs % 60
        let totalMins = totalSecs / 60
        let min = totalMins % 60
        let h = totalMins / 60

        _ = d // suppress unused warning

        return TimecodeInfo(hours: h, minutes: min, seconds: s, frames: f, frameRate: frameRate, isDropFrame: true)
    }
}
