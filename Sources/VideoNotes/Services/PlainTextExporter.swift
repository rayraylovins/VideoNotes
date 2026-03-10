import Foundation

struct PlainTextExporter: NoteExporter {
    func export(session: Session) throws -> Data {
        var lines: [String] = []
        lines.append("Video: \(session.videoFileName)")
        lines.append("Date: \(Self.dateFormatter.string(from: Date()))")
        lines.append("Frame Rate: \(Self.formatFrameRate(session.frameRate))\(session.isDropFrame ? " DF" : "")")
        lines.append("")

        for note in session.sortedNotes {
            lines.append("[\(note.timecodeString)] \(note.text)")
        }

        lines.append("")
        let text = lines.joined(separator: "\n")
        guard let data = text.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    static func formatFrameRate(_ rate: Double) -> String {
        let rounded = rate.rounded()
        if abs(rate - rounded) < 0.01 {
            return String(format: "%.0f fps", rounded)
        }
        return String(format: "%.2f fps", rate)
    }
}

enum ExportError: LocalizedError {
    case encodingFailed
    case pdfGenerationFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode text data"
        case .pdfGenerationFailed: return "Failed to generate PDF"
        }
    }
}
