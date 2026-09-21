import AppKit
import SwiftUI

/// Многострочное текстовое поле для редактирования сниппета.
/// Использует `NSTextView` в `NSScrollView`, чтобы поддержать вставку,
/// выделение и многострочный ввод в стиле остальных полей редактора.
struct SnippetTextEditor: View {
    @Binding var text: String
    let placeholder: String

    @State private var isFocused: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            SnippetTextEditorRepresentable(text: $text, isFocused: $isFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, DS.Spacing.fieldInsetHorizontal - 4)
                .padding(.vertical, DS.Spacing.xs)

            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
                    .padding(.top, DS.Spacing.s)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: DS.Sizing.fieldHeight * 3)
        .dsFieldChrome(isHovered: isHovered, isFocused: isFocused)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .stretchInputHorizontally()
    }
}

private struct SnippetTextEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let scroll = SnippetScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.verticalScrollElasticity = .allowed
        scroll.horizontalScrollElasticity = .none

        let textView = SnippetEditingTextView(frame: .zero, textContainer: textContainer)
        let coord = context.coordinator
        coord.attachFocusHandlers(to: textView)

        textView.delegate = coord
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.font = .systemFont(ofSize: DS.Typography.bodySize, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.string = text
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        private var clickMonitor: Any?
        private weak var boundTextView: NSTextView?

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        deinit {
            removeClickMonitor()
        }

        func attachFocusHandlers(to textView: SnippetEditingTextView) {
            textView.onFocusChange = { [weak self, weak textView] focused in
                guard let self else { return }
                self.isFocused.wrappedValue = focused
                if focused, let tv = textView {
                    self.installClickMonitor(for: tv)
                } else {
                    self.removeClickMonitor()
                }
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        private func installClickMonitor(for textView: NSTextView) {
            removeClickMonitor()
            boundTextView = textView
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self, let tv = self.boundTextView, let window = tv.window else { return event }
                // Target is the scroll view containing the text view — clicks anywhere inside it keep focus.
                let container: NSView = tv.enclosingScrollView ?? tv
                let pointInWindow = event.locationInWindow
                let pointInContainer = container.convert(pointInWindow, from: nil)
                if container.bounds.contains(pointInContainer) {
                    return event
                }
                window.makeFirstResponder(nil)
                return event
            }
        }

        private func removeClickMonitor() {
            if let clickMonitor {
                NSEvent.removeMonitor(clickMonitor)
                self.clickMonitor = nil
            }
            boundTextView = nil
        }
    }
}

/// Клики по «пустому» месту клипа (ниже короткого `documentView`) иначе не попадают в `NSTextView`.
private final class SnippetScrollView: NSScrollView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit === verticalScroller || hit === horizontalScroller {
            return hit
        }
        guard let doc = documentView else { return hit }
        guard let parent = superview else { return hit }
        let localToScroll = convert(point, from: parent)
        guard bounds.contains(localToScroll) else { return hit }
        let pointInClip = contentView.convert(localToScroll, from: self)
        guard contentView.bounds.contains(pointInClip) else { return hit }
        let pInDoc = doc.convert(pointInClip, from: contentView)
        return doc.hitTest(pInDoc) ?? doc
    }
}

/// Фокус для `NSTextView` надёжнее отслеживать через респондер, чем через `textDidBeginEditing`
/// (последний при клике в пустое поле не всегда вызывается).
private final class SnippetEditingTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func cursorUpdate(with event: NSEvent) {
        if window?.firstResponder === self {
            NSCursor.iBeam.set()
        } else {
            NSCursor.pointingHand.set()
        }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }
}
