import Foundation
import AppKit
import AVFoundation
import ImageIO

struct PDFExporter: NoteExporter {
    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func export(session: Session) throws -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - (margin * 2)
        let thumbWidth: CGFloat = 112
        let thumbHeight: CGFloat = 63
        let rowPaddingX: CGFloat = 12
        let rowPaddingY: CGFloat = 10
        let gutter: CGFloat = 12
        let textWidth = contentWidth - thumbWidth - gutter - (rowPaddingX * 2)

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.pdfGenerationFailed
        }

        let titleFont = NSFont.systemFont(ofSize: 18, weight: .bold)
        let metaFont = NSFont.systemFont(ofSize: 9, weight: .medium)
        let timecodeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        let bodyFont = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        let smallMonoFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)

        let textPrimary = NSColor(calibratedWhite: 0.10, alpha: 1)
        let textSecondary = NSColor(calibratedWhite: 0.42, alpha: 1)
        let accent = NSColor(calibratedRed: 0.18, green: 0.44, blue: 0.76, alpha: 1)
        let border = NSColor(calibratedWhite: 0.88, alpha: 1)
        let rowFill = NSColor(calibratedWhite: 0.975, alpha: 1)
        let softFill = NSColor(calibratedWhite: 0.95, alpha: 1)

        let fallbackThumbnailData = Self.generateFallbackThumbnailData(for: session, maxSize: CGSize(width: 640, height: 360))

        var yPos: CGFloat = 0
        var pageNumber = 0

        func beginPage() {
            context.beginPDFPage(nil)
            pageNumber += 1
            yPos = pageHeight - margin
            drawHeader()
        }

        func endPage() {
            drawFooter()
            context.endPDFPage()
        }

        func ensureSpace(_ needed: CGFloat) {
            if pageNumber == 0 {
                beginPage()
                return
            }

            if yPos - needed < margin + 24 {
                endPage()
                beginPage()
            }
        }

        func textAttributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
            [.font: font, .foregroundColor: color]
        }

        func measureText(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
            let attr = NSAttributedString(string: text, attributes: textAttributes(font: font, color: textPrimary))
            let rect = attr.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return ceil(rect.height)
        }

        func drawText(_ text: String, font: NSFont, color: NSColor, rect: CGRect) {
            let attr = NSAttributedString(string: text, attributes: textAttributes(font: font, color: color))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            attr.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
        }

        func drawRoundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            fill.setFill()
            path.fill()
            if let stroke {
                stroke.setStroke()
                path.lineWidth = lineWidth
                path.stroke()
            }
        }

        func drawHeader() {
            context.setFillColor(accent.cgColor)
            context.fill(CGRect(x: margin, y: yPos, width: contentWidth, height: 3))
            yPos -= 18

            drawText(
                session.videoFileName.isEmpty ? "Video Notes Review Log" : session.videoFileName,
                font: titleFont,
                color: textPrimary,
                rect: CGRect(x: margin, y: yPos - 22, width: 340, height: 24)
            )

            drawText(
                "Exported \(Self.exportDateFormatter.string(from: Date()))",
                font: metaFont,
                color: textSecondary,
                rect: CGRect(x: pageWidth - margin - 180, y: yPos - 16, width: 180, height: 12)
            )
            yPos -= 28

            let chips: [(String, String, CGFloat)] = [
                ("NOTES", "\(session.notes.count)", 74),
                ("PAGE", "\(pageNumber)", 60)
            ]

            var x = margin
            for chip in chips {
                let rect = CGRect(x: x, y: yPos - 32, width: chip.2, height: 32)
                drawRoundedRect(rect, radius: 8, fill: softFill, stroke: border)
                drawText(chip.0, font: smallMonoFont, color: textSecondary, rect: CGRect(x: rect.minX + 8, y: rect.minY + 18, width: rect.width - 16, height: 8))
                drawText(chip.1, font: metaFont, color: textPrimary, rect: CGRect(x: rect.minX + 8, y: rect.minY + 7, width: rect.width - 16, height: 10))
                x += chip.2 + 8
            }

            yPos -= 46
        }

        func drawFooter() {
            context.setStrokeColor(border.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: margin, y: margin - 6))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: margin - 6))
            context.strokePath()

            drawText("VideoNotes", font: metaFont, color: textSecondary, rect: CGRect(x: margin, y: margin - 22, width: 80, height: 10))
            drawText("Page \(pageNumber)", font: metaFont, color: textSecondary, rect: CGRect(x: pageWidth - margin - 50, y: margin - 22, width: 50, height: 10))
        }

        func cgImage(for note: Note) -> CGImage? {
            guard let data = note.thumbnailJPEGData ?? fallbackThumbnailData[note.id] else {
                return nil
            }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }

        func drawThumbnail(_ note: Note, in rect: CGRect) {
            context.saveGState()
            let clipPath = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            context.addPath(clipPath)
            context.clip()

            if let image = cgImage(for: note) {
                let sourceSize = CGSize(width: image.width, height: image.height)
                let scale = max(rect.width / sourceSize.width, rect.height / sourceSize.height)
                let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
                let drawRect = CGRect(
                    x: rect.midX - drawSize.width / 2,
                    y: rect.midY - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
                context.draw(image, in: drawRect)
            } else {
                context.setFillColor(softFill.cgColor)
                context.fill(rect)
                drawText("NO FRAME", font: smallMonoFont, color: textSecondary, rect: CGRect(x: rect.minX + 14, y: rect.midY - 5, width: rect.width - 28, height: 10))
            }

            context.restoreGState()
            context.setStrokeColor(border.cgColor)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
            context.strokePath()
        }

        func drawRow(note: Note, index: Int) {
            let noteHeight = measureText(note.text, font: bodyFont, width: textWidth)
            let rowHeight = max(thumbHeight, noteHeight + 28) + (rowPaddingY * 2)
            ensureSpace(rowHeight + 8)

            let rowRect = CGRect(x: margin, y: yPos - rowHeight, width: contentWidth, height: rowHeight)
            drawRoundedRect(rowRect, radius: 10, fill: rowFill, stroke: border)

            let leftX = rowRect.minX + rowPaddingX
            let topY = rowRect.maxY - rowPaddingY
            let thumbRect = CGRect(
                x: leftX,
                y: rowRect.minY + (rowHeight - thumbHeight) / 2,
                width: thumbWidth,
                height: thumbHeight
            )
            drawThumbnail(note, in: thumbRect)

            let textX = thumbRect.maxX + gutter

            drawText(
                String(format: "#%02d", index),
                font: smallMonoFont,
                color: textSecondary,
                rect: CGRect(x: textX, y: topY - 10, width: 34, height: 10)
            )
            drawText(
                note.timecodeString,
                font: timecodeFont,
                color: accent,
                rect: CGRect(x: textX + 40, y: topY - 12, width: 140, height: 12)
            )

            let noteRect = CGRect(
                x: textX,
                y: rowRect.minY + rowPaddingY,
                width: textWidth,
                height: rowHeight - (rowPaddingY * 2) - 18
            )
            drawText(note.text, font: bodyFont, color: textPrimary, rect: noteRect)

            yPos = rowRect.minY - 8
        }

        beginPage()

        if session.sortedNotes.isEmpty {
            ensureSpace(64)
            let rect = CGRect(x: margin, y: yPos - 56, width: contentWidth, height: 56)
            drawRoundedRect(rect, radius: 10, fill: rowFill, stroke: border)
            drawText("No notes were captured in this session.", font: bodyFont, color: textPrimary, rect: CGRect(x: rect.minX + 14, y: rect.midY - 6, width: rect.width - 28, height: 12))
            yPos = rect.minY - 8
        } else {
            for (index, note) in session.sortedNotes.enumerated() {
                drawRow(note: note, index: index + 1)
            }
        }

        endPage()
        context.closePDF()
        return pdfData as Data
    }

    private static func generateFallbackThumbnailData(for session: Session, maxSize: CGSize) -> [UUID: Data] {
        guard session.notes.contains(where: { $0.thumbnailJPEGData == nil }),
              let videoURL = resolveVideoURL(from: session.videoBookmarkData) else {
            return [:]
        }

        let didAccess = videoURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                videoURL.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var thumbnails: [UUID: Data] = [:]
        for note in session.sortedNotes where note.thumbnailJPEGData == nil {
            let time = CMTime(seconds: note.timecodeSeconds, preferredTimescale: 600)
            if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                let bitmapRep = NSBitmapImageRep(cgImage: image)
                if let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) {
                    thumbnails[note.id] = data
                }
            }
        }
        return thumbnails
    }

    private static func resolveVideoURL(from bookmarkData: Data?) -> URL? {
        guard let bookmarkData else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
