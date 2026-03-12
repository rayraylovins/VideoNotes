import AppKit

@MainActor
final class KeyEventHandler: ObservableObject {
    private var localMonitor: Any?
    private(set) var isActive: Bool = false

    /// Called for any keyDown event. Return true to consume the event.
    var onKeyDown: ((NSEvent) -> Bool)?

    /// Called when a printable key is pressed. Return true to consume the event.
    var onPrintableKey: ((NSEvent) -> Bool)?

    func start() {
        guard localMonitor == nil else { return }
        isActive = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Always let command-modified keys pass through
            if event.modifierFlags.contains(.command) {
                return event
            }

            if self.onKeyDown?(event) == true {
                return nil
            }

            guard let chars = event.characters, !chars.isEmpty else { return event }
            let c = chars.unicodeScalars.first!

            let isPrintable = CharacterSet.alphanumerics.contains(c) ||
                              CharacterSet.punctuationCharacters.contains(c) ||
                              CharacterSet.symbols.contains(c) ||
                              c == " "

            if isPrintable, self.onPrintableKey?(event) == true {
                return nil // consumed
            }

            return event
        }
    }

    func stop() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        isActive = false
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
