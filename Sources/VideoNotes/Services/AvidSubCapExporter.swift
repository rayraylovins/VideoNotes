import Foundation

struct AvidSubCapExporter: NoteExporter {
    func export(session: Session) throws -> Data {
        var lines: [String] = []
        lines.append("<begin subtitles>")

        for note in session.sortedNotes {
            let tcIn = note.timecodeString
            // TC out = TC in + 1 second (approximation for marker duration)
            let outSeconds = note.timecodeSeconds + 1.0
            let tcOut = TimecodeInfo.from(
                seconds: outSeconds,
                frameRate: session.frameRate,
                dropFrame: session.isDropFrame
            ).description

            lines.append("")
            lines.append("\(tcIn) \(tcOut)")
            lines.append(note.text)
        }

        lines.append("")
        lines.append("<end subtitles>")
        lines.append("")

        let text = lines.joined(separator: "\r\n")

        // UTF-8 BOM + content
        var data = Data([0xEF, 0xBB, 0xBF])
        guard let textData = text.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        data.append(textData)
        return data
    }
}
