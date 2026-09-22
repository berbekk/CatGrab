import Foundation

/// Страницы знакомства по порядку: что это, как открыть, как переставить секторы и повернуть кольцо, что уже готово,
/// как выглядит, права — и в конце что нажать. Права намеренно последними: сначала человек видит,
/// ради чего их выдавать.
enum OnboardingPage: Int, CaseIterable, Equatable {
    case welcome
    case open
    case reorder
    case rotate
    case builtIn
    case style
    case permissions
    case done

    var next: OnboardingPage? {
        OnboardingPage(rawValue: rawValue + 1)
    }

    var previous: OnboardingPage? {
        OnboardingPage(rawValue: rawValue - 1)
    }

    var isLast: Bool { next == nil }
}
