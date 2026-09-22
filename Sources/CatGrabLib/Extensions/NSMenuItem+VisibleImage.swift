import AppKit

extension NSMenuItem {
    /// Картинка слева от названия, которая видна всегда. С macOS 27 AppKit сам решает,
    /// показывать ли `image`, и по умолчанию обычно прячет её — нужно явно попросить
    /// `preferredImageVisibility = .visible`. Свойства нет в SDK, с которым собирается проект
    /// (macOS 26), поэтому ставим его через KVC и только там, где система его знает;
    /// до macOS 27 картинки и так видны.
    func setAlwaysVisibleImage(_ image: NSImage?) {
        self.image = image
        guard responds(to: Self.setPreferredImageVisibilitySelector) else { return }
        setValue(image == nil ? Self.imageVisibilityAutomatic : Self.imageVisibilityVisible, forKey: "preferredImageVisibility")
    }

    private static let setPreferredImageVisibilitySelector = NSSelectorFromString("setPreferredImageVisibility:")
    /// `NSMenuItemImageVisibilityAutomatic` / `…Visible` из `NSMenuItem.h` (macOS 27 SDK).
    private static let imageVisibilityAutomatic = 0
    private static let imageVisibilityVisible = 1
}
