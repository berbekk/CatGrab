import AppKit
import SwiftUI

extension View {
    /// Курсор «рука» при наведении на интерактивную область.
    func pointingHandCursor() -> some View {
        onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
