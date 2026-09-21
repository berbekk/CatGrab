import AppKit
import SwiftUI

// MARK: - AppKit field

protocol PlainTextFieldFocusHandler: AnyObject {
    func handleBecomeFirstResponder(_ field: NSTextField)
    func handleResignFirstResponder(_ field: NSTextField)
}

final class FocusTrackingTextField: NSTextField {
    weak var focusHandler: PlainTextFieldFocusHandler?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point) {
            return hit
        }
        guard let parent = superview else { return nil }
        let local = convert(point, from: parent)
        guard bounds.contains(local) else { return nil }
        return self
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            focusHandler?.handleBecomeFirstResponder(self)
        }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok {
            focusHandler?.handleResignFirstResponder(self)
        }
        return ok
    }

    override func cursorUpdate(with event: NSEvent) {
        if currentEditor() != nil {
            NSCursor.iBeam.set()
        } else {
            NSCursor.pointingHand.set()
        }
    }
}

/// Обычный `TextField` в SwiftUI на macOS иногда помечает весь текст при фокусе.
/// Здесь после начала редактирования снимается только полное выделение (как при авто-select all);
/// повторный выбор всего текста в уже активном поле не трогаем.
struct PlainTextFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var isFocused: Bool
    var commitsOnBlur: Bool
    /// Поставить в `true`, чтобы перевести фокус в поле (например тап по обводке).
    var requestFocus: Binding<Bool>?
    var controlFont: NSFont?
    var onSubmit: (() -> Void)?
    var onResignFocus: (() -> Void)?

    init(
        text: Binding<String>,
        placeholder: String,
        isFocused: Binding<Bool>,
        commitsOnBlur: Bool = false,
        requestFocus: Binding<Bool>? = nil,
        controlFont: NSFont? = nil,
        onSubmit: (() -> Void)? = nil,
        onResignFocus: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self._isFocused = isFocused
        self.commitsOnBlur = commitsOnBlur
        self.requestFocus = requestFocus
        self.controlFont = controlFont
        self.onSubmit = onSubmit
        self.onResignFocus = onResignFocus
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: $isFocused,
            placeholder: placeholder,
            commitsOnBlur: commitsOnBlur,
            onSubmit: onSubmit,
            onResignFocus: onResignFocus
        )
    }

    func makeNSView(context: Context) -> FocusTrackingTextField {
        let tf = FocusTrackingTextField()
        tf.delegate = context.coordinator
        tf.focusHandler = context.coordinator
        context.coordinator.field = tf
        tf.isBordered = false
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.backgroundColor = .clear
        tf.focusRingType = .none
        tf.font = controlFont ?? .systemFont(ofSize: DS.Typography.bodySize, weight: .regular)
        tf.placeholderString = placeholder
        tf.stringValue = text
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.truncatesLastVisibleLine = true
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateNSView(_ nsView: FocusTrackingTextField, context: Context) {
        let coord = context.coordinator
        coord.text = $text
        coord.isFocused = $isFocused
        coord.commitsOnBlur = commitsOnBlur
        coord.placeholder = placeholder
        coord.onSubmit = onSubmit
        coord.onResignFocus = onResignFocus
        coord.field = nsView
        nsView.focusHandler = coord

        if let font = controlFont, nsView.font != font {
            nsView.font = font
        }

        if let bind = requestFocus, bind.wrappedValue {
            DispatchQueue.main.async {
                _ = nsView.window?.makeFirstResponder(nsView)
                bind.wrappedValue = false
            }
        }

        if nsView.stringValue != text {
            if nsView.currentEditor() == nil {
                nsView.stringValue = text
            } else if text.isEmpty {
                nsView.stringValue = ""
                if let editor = nsView.currentEditor() as? NSTextView {
                    editor.string = ""
                }
            }
        }

        if nsView.currentEditor() == nil, nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate, PlainTextFieldFocusHandler {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        var commitsOnBlur: Bool = false
        var placeholder: String
        var onSubmit: (() -> Void)?
        var onResignFocus: (() -> Void)?
        private var clickMonitor: Any?
        weak var field: FocusTrackingTextField?

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            placeholder: String,
            commitsOnBlur: Bool,
            onSubmit: (() -> Void)?,
            onResignFocus: (() -> Void)?
        ) {
            self.text = text
            self.isFocused = isFocused
            self.placeholder = placeholder
            self.commitsOnBlur = commitsOnBlur
            self.onSubmit = onSubmit
            self.onResignFocus = onResignFocus
        }

        deinit {
            removeClickMonitor()
        }

        func handleBecomeFirstResponder(_ field: NSTextField) {
            isFocused.wrappedValue = true
            field.placeholderString = ""
            installClickMonitorIfNeeded(field: field)
            let note = Notification(name: NSControl.textDidBeginEditingNotification, object: field)
            DispatchQueue.main.async { [weak self] in
                self?.collapseFullSelectionIfNeeded(for: note)
            }
        }

        func handleResignFirstResponder(_ field: NSTextField) {
            isFocused.wrappedValue = false
            removeClickMonitor()
            field.placeholderString = placeholder
            if commitsOnBlur {
                text.wrappedValue = field.stringValue
            }
            onResignFocus?()
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            if !commitsOnBlur {
                text.wrappedValue = field.stringValue
            }
        }

        private func collapseFullSelectionIfNeeded(for obj: Notification) {
            guard let field = obj.object as? NSTextField,
                  let editor = field.currentEditor() as? NSTextView else { return }
            let len = (field.stringValue as NSString).length
            guard len > 0 else { return }
            let r = editor.selectedRange
            if r.length == len {
                editor.selectedRange = NSRange(location: len, length: 0)
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit?()
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }

        private func installClickMonitorIfNeeded(field: NSTextField) {
            guard clickMonitor == nil else { return }
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak field] event in
                guard let self, let field, let window = field.window else { return event }

                let pointInWindow = event.locationInWindow
                let pointInField = field.convert(pointInWindow, from: nil)
                if field.bounds.contains(pointInField) {
                    return event
                }

                if self.commitsOnBlur {
                    self.text.wrappedValue = field.stringValue
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
        }
    }
}
