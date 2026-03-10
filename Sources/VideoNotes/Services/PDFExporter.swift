import Foundation
import AppKit
import PDFKit

struct PDFExporter: NoteExporter {
    func export(session: Session) throws -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.pdfGenerationFailed
        }

        let titleFont = NSFont.boldSystemFont(ofSize: 16)
        let headerFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let bodyFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let noteFont = NSFont.systemFont(ofSize: 10)

        var yPos: CGFloat = pageHeight - margin
        var pageStarted = false

        func startPage() {
            context.beginPDFPage(nil)
            pageStarted = true
            yPos = pageHeight - margin
        }

        func endPage() {
            if pageStarted {
                context.endPDFPage()
                pageStarted = false
            }
        }

        func checkPageBreak(needed: CGFloat) {
            if yPos - needed < margin {
                endPage()
                startPage()
            }
        }

        func drawText(_ text: String, font: NSFont, color: NSColor = .black, x: CGFloat = margin) {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let size = attrStr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
            checkPageBreak(needed: size.height + 4)
            let rect = CGRect(x: x, y: yPos - size.height, width: contentWidth, height: size.height)

            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            attrStr.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()

            yPos -= size.height + 4
        }

        // Start first page
        startPage()

        // Title
        drawText("VideoNotes — \(session.videoFileName)", font: titleFont)
        yPos -= 8

        // Metadata
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        drawText("Date: \(dateStr)", font: headerFont, color: .darkGray)
        drawText("Frame Rate: \(PlainTextExporter.formatFrameRate(session.frameRate))\(session.isDropFrame ? " DF" : "")", font: headerFont, color: .darkGray)
        drawText("Notes: \(session.notes.count)", font: headerFont, color: .darkGray)
        yPos -= 12

        // Separator line
        checkPageBreak(needed: 10)
        context.setStrokeColor(NSColor.gray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: yPos))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: yPos))
        context.strokePath()
        yPos -= 16

        // Notes
        for note in session.sortedNotes {
            checkPageBreak(needed: 30)
            drawText(note.timecodeString, font: bodyFont, color: .init(red: 0.2, green: 0.2, blue: 0.8, alpha: 1.0))
            drawText(note.text, font: noteFont)
            yPos -= 8
        }

        endPage()
        context.closePDF()

        return pdfData as Data
    }
}
