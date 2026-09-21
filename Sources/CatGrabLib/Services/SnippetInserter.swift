import AppKit

/// Кладёт текст сниппета в буфер обмена. Вставка ⌘V — вручную (App Sandbox без эмуляции клавиш).
enum SnippetInserter {
    static func perform(text: String, targetPID: pid_t?) {
        guard !text.isEmpty else { return }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
