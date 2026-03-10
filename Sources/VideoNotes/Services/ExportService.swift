import AppKit
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case plainText = "Plain Text (.txt)"
    case pdf = "PDF (.pdf)"
    case avidSubCap = "Avid SubCap (.txt)"
    case premiereCSV = "Premiere CSV (.csv)"
    case resolveEDL = "Resolve EDL (.edl)"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .plainText, .avidSubCap: return "txt"
        case .pdf: return "pdf"
        case .premiereCSV: return "csv"
        case .resolveEDL: return "edl"
        }
    }

    var contentType: UTType {
        switch self {
        case .plainText, .avidSubCap: return .plainText
        case .pdf: return .pdf
        case .premiereCSV: return .commaSeparatedText
        case .resolveEDL: return UTType(filenameExtension: "edl") ?? .plainText
        }
    }
}

protocol NoteExporter {
    func export(session: Session) throws -> Data
}

@MainActor
struct ExportService {
    static func export(session: Session, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        let baseName = session.videoFileName.isEmpty ? "notes" : (session.videoFileName as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(baseName).\(format.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let exporter: NoteExporter
        switch format {
        case .plainText:
            exporter = PlainTextExporter()
        case .pdf:
            exporter = PDFExporter()
        case .avidSubCap:
            exporter = AvidSubCapExporter()
        case .premiereCSV:
            exporter = PremiereCSVExporter()
        case .resolveEDL:
            exporter = ResolveEDLExporter()
        }

        do {
            let data = try exporter.export(session: session)
            try data.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
