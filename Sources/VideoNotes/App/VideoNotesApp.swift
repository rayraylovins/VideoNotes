import SwiftUI

@main
struct VideoNotesApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save Session") {
                    NotificationCenter.default.post(name: .saveSession, object: nil)
                }
                .keyboardShortcut("s")

                Button("Save Session As...") {
                    NotificationCenter.default.post(name: .saveSessionAs, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Open Session...") {
                    NotificationCenter.default.post(name: .openSession, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let saveSession = Notification.Name("saveSession")
    static let saveSessionAs = Notification.Name("saveSessionAs")
    static let openSession = Notification.Name("openSession")
}
