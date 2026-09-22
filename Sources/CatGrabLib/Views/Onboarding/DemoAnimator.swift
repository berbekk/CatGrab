import Foundation

/// Проигрывает показательное движение в знакомстве: сектор сам проезжает на соседнее место, кольцо
/// само поворачивается на шаг. Значение ведётся таймером, а не анимацией SwiftUI: форма сектора
/// (`PieSectorShape`) углы не интерполирует, ей нужен готовый угол на каждом кадре.
/// Каждый отрезок — пружина: разгон, лёгкий перелёт и успокоение, как рука, а не как ползунок.
@MainActor
final class DemoAnimator: ObservableObject {
    @Published private(set) var value: Double = 0
    @Published private(set) var isActive = false

    private var task: Task<Void, Never>?
    private static let frame: TimeInterval = 1.0 / 60

    struct Keyframe {
        let value: Double
        /// Сколько длится отрезок целиком, включая успокоение.
        let duration: TimeInterval
        /// Период пружины: меньше — резче.
        var response: TimeInterval = 0.5
        /// Меньше единицы — с перелётом; 0.6 даёт заметный, но короткий.
        var damping: Double = 0.6

        /// Пауза на месте.
        static func hold(_ value: Double, _ duration: TimeInterval) -> Keyframe {
            Keyframe(value: value, duration: duration, response: 0.01, damping: 1)
        }
    }

    /// Ведёт `value` по ключевым точкам от 0 и обратно.
    func play(after delay: TimeInterval, keyframes: [Keyframe]) {
        cancel()
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.isActive = true
            var current = 0.0
            for keyframe in keyframes {
                let steps = max(1, Int(keyframe.duration / Self.frame))
                let start = current
                for step in 1...steps {
                    guard !Task.isCancelled else { return }
                    let t = Double(step) * Self.frame
                    self.value = Self.spring(from: start, to: keyframe.value, at: t, response: keyframe.response, damping: keyframe.damping)
                    try? await Task.sleep(nanoseconds: UInt64(Self.frame * 1_000_000_000))
                }
                current = keyframe.value
                self.value = current
            }
            self.value = 0
            self.isActive = false
        }
    }

    /// Положение пружины, отпущенной из покоя в `from` к `to`, через `t` секунд.
    static func spring(from: Double, to: Double, at t: Double, response: TimeInterval, damping: Double) -> Double {
        let omega = 2 * Double.pi / max(0.01, response)
        let zeta = min(max(damping, 0.05), 1)
        let offset = from - to
        if zeta >= 1 {
            // Критическое затухание: без перелёта.
            return to + offset * (1 + omega * t) * exp(-omega * t)
        }
        let dampedOmega = omega * (1 - zeta * zeta).squareRoot()
        let decay = exp(-zeta * omega * t)
        let ratio = zeta / (1 - zeta * zeta).squareRoot()
        return to + offset * decay * (cos(dampedOmega * t) + ratio * sin(dampedOmega * t))
    }

    func cancel() {
        task?.cancel()
        task = nil
        value = 0
        isActive = false
    }
}
