import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var session: Session = Session()
    @Published var currentNoteText: String = ""
    @Published var isEditing: Bool = false
    @Published var editingNoteID: UUID?
    @Published var sessionFileURL: URL?
    @Published var hasUnsavedChanges: Bool = false

    private var pendingTimecodeSeconds: Double = 0
    private var pendingTimecodeString: String = "00:00:00:00"

    var pendingNoteTimecodeSeconds: Double? {
        isEditing ? pendingTimecodeSeconds : nil
    }

    // MARK: - Note Creation

    func beginNote(timecodeSeconds: Double, timecodeString: String, initialText: String = "") {
        pendingTimecodeSeconds = timecodeSeconds
        pendingTimecodeString = timecodeString
        currentNoteText = initialText
        isEditing = true
    }

    func commitNote(thumbnailJPEGData: Data? = nil) {
        guard isEditing else { return }
        let text = currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            cancelNote()
            return
        }

        let note = Note(
            timecodeSeconds: pendingTimecodeSeconds,
            timecodeString: pendingTimecodeString,
            text: text,
            thumbnailJPEGData: thumbnailJPEGData
        )
        session.addNote(note)
        currentNoteText = ""
        isEditing = false
        hasUnsavedChanges = true
    }

    func cancelNote() {
        currentNoteText = ""
        isEditing = false
    }

    // MARK: - Note Management

    func deleteNote(id: UUID) {
        session.removeNote(id: id)
        hasUnsavedChanges = true
    }

    func updateNoteText(id: UUID, text: String) {
        session.updateNote(id: id, text: text)
        hasUnsavedChanges = true
    }

    func addCapturedNote(timecodeSeconds: Double, timecodeString: String, text: String, thumbnailJPEGData: Data? = nil) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let note = Note(
            timecodeSeconds: timecodeSeconds,
            timecodeString: timecodeString,
            text: trimmedText,
            thumbnailJPEGData: thumbnailJPEGData
        )
        session.addNote(note)
        hasUnsavedChanges = true
    }

    func startEditingNote(_ id: UUID) {
        editingNoteID = id
    }

    func finishEditingNote() {
        editingNoteID = nil
    }

    // MARK: - Session Configuration

    func configureSession(videoURL: URL, frameRate: Double, isDropFrame: Bool) {
        session.videoFileName = videoURL.lastPathComponent
        session.frameRate = frameRate
        session.isDropFrame = isDropFrame

        // Create security-scoped bookmark
        do {
            session.videoBookmarkData = try videoURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            // Bookmark creation may fail; we'll still have the filename
        }
        hasUnsavedChanges = true
    }

    // MARK: - Persistence

    func save() {
        guard let url = sessionFileURL else {
            saveAs()
            return
        }
        writeSession(to: url)
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "videonotes") ?? .json]
        panel.nameFieldStringValue = session.videoFileName.isEmpty ? "Untitled.videonotes" : "\(session.videoFileName).videonotes"

        if panel.runModal() == .OK, let url = panel.url {
            sessionFileURL = url
            writeSession(to: url)
        }
    }

    func openSession() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "videonotes") ?? .json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            let data = try Data(contentsOf: url)
            session = try JSONDecoder().decode(Session.self, from: data)
            sessionFileURL = url
            hasUnsavedChanges = false

            // Resolve video bookmark
            if let bookmarkData = session.videoBookmarkData {
                var isStale = false
                if let videoURL = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) {
                    _ = videoURL.startAccessingSecurityScopedResource()
                    return videoURL
                }
            }
        } catch {
            // Failed to load session
        }
        return nil
    }

    private func writeSession(to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(session)
            try data.write(to: url)
            hasUnsavedChanges = false
        } catch {
            // Write failed silently
        }
    }
}
