import CoreMedia

extension CMTime {
    func toTimecodeInfo(frameRate: Double, dropFrame: Bool = false) -> TimecodeInfo {
        return TimecodeInfo.from(cmTime: self, frameRate: frameRate, dropFrame: dropFrame)
    }

    var safeSeconds: Double {
        let s = CMTimeGetSeconds(self)
        return s.isFinite ? s : 0
    }
}
