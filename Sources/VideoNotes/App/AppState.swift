import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var session: Session = Session()
    @Published var currentVideoURL: URL?
    @Published var autoPauseEnabled: Bool = true
    @Published var isNoteOverlayVisible: Bool = false
    @Published var sessionFileURL: URL?
    @Published var hasUnsavedChanges: Bool = false
}
