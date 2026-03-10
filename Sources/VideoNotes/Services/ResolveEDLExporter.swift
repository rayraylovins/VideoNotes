import Foundation

struct ResolveEDLExporter: NoteExporter {
    func export(session: Session) throws -> Data {
        var lines: [String] = []
        let title = (session.videoFileName as NSString).deletingPathExtension
        lines.append("TITLE: \(title)")
        lines.append("FCM: \(session.isDropFrame ? "DROP FRAME" : "NON-DROP FRAME")")
        lines.append("")

        for (index, note) in session.sortedNotes.enumerated() {
            let editNumber = String(format: "%03d", index + 1)
            let tcIn = note.timecodeString
            // TC out = TC in + 1 frame
            let outSeconds = note.timecodeSeconds + (1.0 / session.frameRate)
            let tcOut = TimecodeInfo.from(
                seconds: outSeconds,
                frameRate: session.frameRate,
                dropFrame: session.isDropFrame
            ).description

            let durationFrames = 1

            // CMX 3600 EDL format
            lines.append("\(editNumber)  001      V     C        \(tcIn) \(tcOut) \(tcIn) \(tcOut)")
            // Resolve marker comment
            let sanitizedText = note.text.replacingOccurrences(of: "|", with: "-")
            lines.append(" |C:ResolveColorBlue |M:\(sanitizedText) |D:\(durationFrames)")
            lines.append("")
        }

        let text = lines.joined(separator: "\n")
        guard let data = text.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }
}
