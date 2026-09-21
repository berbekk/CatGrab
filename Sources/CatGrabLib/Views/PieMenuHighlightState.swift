import AppKit
import SwiftUI

/// Общее состояние подсветки сектора: мышь и повторные нажатия клавиши хоткея (меню запущенных приложений, режим «по клику»).
final class PieMenuHighlightState: ObservableObject {
    @Published var highlightedIndex: Int?

    func reset() {
        highlightedIndex = nil
    }

    func advanceSelection(sectorCount: Int, hapticFeedbackEnabled: Bool) {
        guard sectorCount > 0 else { return }
        if hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .levelChange,
                performanceTime: .default
            )
        }
        if let i = highlightedIndex {
            highlightedIndex = (i + 1) % sectorCount
        } else {
            highlightedIndex = 0
        }
    }
}
