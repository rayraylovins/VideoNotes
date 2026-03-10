import Foundation

struct PremiereCSVExporter: NoteExporter {
    func export(session: Session) throws -> Data {
        var lines: [String] = []
        lines.append("Marker Name,Description,In,Out,Duration,Marker Type")

        for (index, note) in session.sortedNotes.enumerated() {
            let name = escapeCSV("Marker \(index + 1)")
            let description = escapeCSV(note.text)
            let tcIn = note.timecodeString
            // Out = In + 1 frame
            let outSeconds = note.timecodeSeconds + (1.0 / session.frameRate)
            let tcOut = TimecodeInfo.from(
                seconds: outSeconds,
                frameRate: session.frameRate,
                dropFrame: session.isDropFrame
            ).description
            let duration = TimecodeInfo.from(
                seconds: 1.0 / session.frameRate,
                frameRate: session.frameRate,
                dropFrame: session.isDropFrame
            ).description

            lines.append("\(name),\(description),\(tcIn),\(tcOut),\(duration),Comment")
        }

        let text = lines.joined(separator: "\r\n") + "\r\n"
        guard let data = text.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
