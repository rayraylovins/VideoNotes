import Foundation

struct Session: Codable {
    var videoBookmarkData: Data?
    var videoFileName: String
    var notes: [Note]
    var frameRate: Double
    var isDropFrame: Bool
    var startTimecodeSeconds: Double
    var createdAt: Date
    var modifiedAt: Date

    init(videoFileName: String = "", frameRate: Double = 24.0, isDropFrame: Bool = false) {
        self.videoBookmarkData = nil
        self.videoFileName = videoFileName
        self.notes = []
        self.frameRate = frameRate
        self.isDropFrame = isDropFrame
        self.startTimecodeSeconds = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    var sortedNotes: [Note] {
        notes.sorted { $0.timecodeSeconds < $1.timecodeSeconds }
    }

    mutating func addNote(_ note: Note) {
        notes.append(note)
        modifiedAt = Date()
    }

    mutating func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
        modifiedAt = Date()
    }

    mutating func updateNote(id: UUID, text: String) {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].text = text
            modifiedAt = Date()
        }
    }
}
