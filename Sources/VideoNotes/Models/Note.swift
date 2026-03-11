import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var timecodeSeconds: Double
    var timecodeString: String
    var text: String
    var thumbnailJPEGData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        timecodeSeconds: Double,
        timecodeString: String,
        text: String,
        thumbnailJPEGData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timecodeSeconds = timecodeSeconds
        self.timecodeString = timecodeString
        self.text = text
        self.thumbnailJPEGData = thumbnailJPEGData
        self.createdAt = createdAt
    }
}
