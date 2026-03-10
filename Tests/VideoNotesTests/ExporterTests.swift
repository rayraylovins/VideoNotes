import XCTest
@testable import VideoNotes

final class ExporterTests: XCTestCase {

    private func makeSession() -> Session {
        var session = Session(videoFileName: "test_video.mov", frameRate: 24, isDropFrame: false)
        session.addNote(Note(
            timecodeSeconds: 10.0,
            timecodeString: "00:00:10:00",
            text: "First note"
        ))
        session.addNote(Note(
            timecodeSeconds: 65.5,
            timecodeString: "00:01:05:12",
            text: "Second note"
        ))
        return session
    }

    // MARK: - Plain Text

    func testPlainTextExport() throws {
        let exporter = PlainTextExporter()
        let data = try exporter.export(session: makeSession())
        let text = String(data: data, encoding: .utf8)!

        XCTAssertTrue(text.contains("Video: test_video.mov"))
        XCTAssertTrue(text.contains("[00:00:10:00] First note"))
        XCTAssertTrue(text.contains("[00:01:05:12] Second note"))
    }

    // MARK: - Avid SubCap

    func testAvidSubCapExport() throws {
        let exporter = AvidSubCapExporter()
        let data = try exporter.export(session: makeSession())

        // Check UTF-8 BOM
        XCTAssertEqual(data[0], 0xEF)
        XCTAssertEqual(data[1], 0xBB)
        XCTAssertEqual(data[2], 0xBF)

        let text = String(data: data.dropFirst(3), encoding: .utf8)!
        XCTAssertTrue(text.contains("<begin subtitles>"))
        XCTAssertTrue(text.contains("<end subtitles>"))
        XCTAssertTrue(text.contains("00:00:10:00"))
        XCTAssertTrue(text.contains("First note"))
    }

    // MARK: - Premiere CSV

    func testPremiereCSVExport() throws {
        let exporter = PremiereCSVExporter()
        let data = try exporter.export(session: makeSession())
        let text = String(data: data, encoding: .utf8)!

        XCTAssertTrue(text.contains("Marker Name,Description,In,Out,Duration,Marker Type"))
        XCTAssertTrue(text.contains("Marker 1"))
        XCTAssertTrue(text.contains("First note"))
        XCTAssertTrue(text.contains("Comment"))
    }

    // MARK: - Resolve EDL

    func testResolveEDLExport() throws {
        let exporter = ResolveEDLExporter()
        let data = try exporter.export(session: makeSession())
        let text = String(data: data, encoding: .utf8)!

        XCTAssertTrue(text.contains("TITLE: test_video"))
        XCTAssertTrue(text.contains("FCM: NON-DROP FRAME"))
        XCTAssertTrue(text.contains("001"))
        XCTAssertTrue(text.contains("|C:ResolveColorBlue"))
        XCTAssertTrue(text.contains("|M:First note"))
    }

    func testResolveEDLDropFrame() throws {
        var session = makeSession()
        session.isDropFrame = true
        let exporter = ResolveEDLExporter()
        let data = try exporter.export(session: session)
        let text = String(data: data, encoding: .utf8)!

        XCTAssertTrue(text.contains("FCM: DROP FRAME"))
    }

    // MARK: - PDF

    func testPDFExportProducesData() throws {
        let exporter = PDFExporter()
        let data = try exporter.export(session: makeSession())
        XCTAssertTrue(data.count > 0)
        // PDF files start with %PDF
        let header = String(data: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }

    // MARK: - Empty Session

    func testExportEmptySession() throws {
        let session = Session(videoFileName: "empty.mov")
        let exporter = PlainTextExporter()
        let data = try exporter.export(session: session)
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains("Video: empty.mov"))
    }
}
