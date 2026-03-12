import SwiftUI
import AppKit

struct NoteOverlayView: View {
    let timecodeString: String
    @Binding var noteText: String
    var onCommit: () -> Void
    var onCancel: () -> Void

    @State private var editorHeight: CGFloat = 52

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

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("Add review note at current frame")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                NoteInputField(
                    text: $noteText,
                    calculatedHeight: $editorHeight,
                    onSubmit: onCommit,
                    onCancel: onCancel
                )
                .frame(height: editorHeight)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.20))
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
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.30), radius: 18, y: 12)
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
    @Binding var calculatedHeight: CGFloat
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, calculatedHeight: $calculatedHeight, onSubmit: onSubmit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = .systemFont(ofSize: 15, weight: .medium)
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text

        context.coordinator.textView = textView
        context.coordinator.updateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        context.coordinator.updateHeight(for: textView)
        context.coordinator.focusIfNeeded(textView)
        nsView.hasVerticalScroller = calculatedHeight >= context.coordinator.maxHeight
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var calculatedHeight: CGFloat
        private let onSubmit: () -> Void
        private let onCancel: () -> Void
        private var didRequestInitialFocus = false
        weak var textView: NSTextView?

        let minHeight: CGFloat = 24
        let maxHeight: CGFloat = 180
        let padding: CGFloat = 28

        init(text: Binding<String>, calculatedHeight: Binding<CGFloat>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
            _text = text
            _calculatedHeight = calculatedHeight
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            updateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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

        func updateHeight(for textView: NSTextView) {
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
            let contentHeight = ceil(usedRect.height)
            let targetHeight = min(max(contentHeight + padding, minHeight + padding), maxHeight)

            DispatchQueue.main.async {
                self.calculatedHeight = targetHeight
            }
        }

        func focusIfNeeded(_ textView: NSTextView) {
            guard !didRequestInitialFocus else { return }
            didRequestInitialFocus = true

            DispatchQueue.main.async {
                guard let window = textView.window else {
                    self.didRequestInitialFocus = false
                    return
                }

                window.makeFirstResponder(textView)
                let length = textView.string.count
                textView.setSelectedRange(NSRange(location: length, length: 0))
            }
        }
    }
}
