import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var timecodeSeconds: Double
    var timecodeString: String
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), timecodeSeconds: Double, timecodeString: String, text: String, createdAt: Date = Date()) {
        self.id = id
        self.timecodeSeconds = timecodeSeconds
        self.timecodeString = timecodeString
        self.text = text
        self.createdAt = createdAt
    }
}
