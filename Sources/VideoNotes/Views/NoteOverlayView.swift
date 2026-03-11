import SwiftUI
import AppKit

struct NoteOverlayView: View {
    let timecodeString: String
    @Binding var noteText: String
    var onCommit: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CAPTURE NOTE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(Theme.tertiaryText)

                    Text(timecodeString)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 8) {
                    shortcutPill(text: "RETURN", detail: "SAVE")
                    shortcutPill(text: "ESC", detail: "CANCEL")
                }
            }

            NoteInputField(
                text: $noteText,
                placeholder: "Add review note at current frame",
                onSubmit: onCommit,
                onCancel: onCancel
            )
            .frame(height: 48)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.26))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: 640)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.panelMuted.opacity(0.96), Theme.panel.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 12)
    }

    private func shortcutPill(text: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            Text(detail)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundColor(Theme.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct NoteInputField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15, weight: .medium)
        field.textColor = .white
        field.placeholderString = placeholder
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.35)]
        )
        field.stringValue = text
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        context.coordinator.focusIfNeeded(nsView)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        private let onSubmit: () -> Void
        private let onCancel: () -> Void
        private var didRequestInitialFocus = false

        init(text: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onCancel()
                return true
            default:
                return false
            }
        }

        func focusIfNeeded(_ field: NSTextField) {
            guard !didRequestInitialFocus else { return }
            didRequestInitialFocus = true

            DispatchQueue.main.async {
                guard let window = field.window else {
                    self.didRequestInitialFocus = false
                    return
                }

                window.makeFirstResponder(field)
                if let editor = window.fieldEditor(true, for: field) as? NSTextView {
                    let length = field.stringValue.count
                    editor.selectedRange = NSRange(location: length, length: 0)
                }
            }
        }
    }
}
