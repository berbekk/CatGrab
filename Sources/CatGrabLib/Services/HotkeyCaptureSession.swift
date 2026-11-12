import Combine
import Foundation

/// Пока пользователь записывает сочетание, глобальные обработчики не должны его забирать.
@MainActor
final class HotkeyCaptureSession: ObservableObject {
    static let shared = HotkeyCaptureSession()
    @Published private(set) var isRecording = false
    private var tokens: Set<UUID> = []

    func begin() -> UUID {
        let token = UUID()
        tokens.insert(token)
        if !isRecording { isRecording = true }
        return token
    }

    func end(_ token: UUID) {
        tokens.remove(token)
        if tokens.isEmpty, isRecording { isRecording = false }
    }
}
