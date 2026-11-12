import Foundation

/// Callback MultitouchSupport и перезапуск устройств приходят с разных потоков.
/// Всё состояние распознавания защищено одним lock; старые события помечены поколением.
final class TrackpadFrameProcessor {
    struct Tap {
        let fingerCount: Int
        let generation: UUID
    }

    private let lock = NSLock()
    private var generation = UUID()
    private var fingerCounts: [Int] = []
    private var recognizers: [UInt: [TrackpadTapRecognizer]] = [:]

    func start(fingerCounts: Set<Int>) {
        lock.lock()
        defer { lock.unlock() }
        generation = UUID()
        self.fingerCounts = fingerCounts.filter(TrackpadGesture.supportedFingerCounts.contains).sorted()
        recognizers = [:]
    }

    func stop() {
        start(fingerCounts: [])
    }

    func isCurrent(_ tap: Tap) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return tap.generation == generation
    }

    func process(deviceID: UInt, touches: [TrackpadTapRecognizer.Touch], timestamp: Double) -> Tap? {
        lock.lock()
        defer { lock.unlock() }
        // Идентификатор из приватного callback — непрозрачный ключ. Он не обязан совпадать
        // с указателем устройства в CFArray (и может быть нулём).
        guard !fingerCounts.isEmpty else { return nil }
        var state = recognizers[deviceID] ?? fingerCounts.map { TrackpadTapRecognizer(fingerCount: $0) }
        var tapped: Int?
        for index in state.indices where state[index].process(touches: touches, timestamp: timestamp) {
            tapped = state[index].fingerCount
        }
        recognizers[deviceID] = state
        return tapped.map { Tap(fingerCount: $0, generation: generation) }
    }
}
