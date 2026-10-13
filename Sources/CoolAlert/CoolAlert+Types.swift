import UIKit

public extension CoolAlert {

    /// The kind of alert. Picks the accent color and the icon drawn in the badge.
    enum Style: Equatable {
        case success
        case error
        case notice
        case warning
        case info
        case edit
        case wait
        case question
        /// Any accent color, with an optional icon (rendered as a template when it is a symbol).
        case custom(color: UIColor, icon: UIImage? = nil)

        /// The accent color for the style. Adapts to light and dark mode.
        public var color: UIColor {
            switch self {
            case .success: UIColor(light: 0x22B573, dark: 0x2FC97F)
            case .error: UIColor(light: 0xE5484D, dark: 0xFF6369)
            case .notice: UIColor(light: 0x6E6E73, dark: 0xA1A1A6)
            case .warning: UIColor(light: 0xF5B400, dark: 0xFFCC33)
            case .info: UIColor(light: 0x2F80ED, dark: 0x5AA9FF)
            case .edit: UIColor(light: 0x8E44EC, dark: 0xB57BFF)
            case .wait: UIColor(light: 0xD63AA0, dark: 0xF06CC0)
            case .question: UIColor(light: 0x5B6B82, dark: 0x9AA8BC)
            case .custom(let color, _): color
            }
        }

        var defaultBadgeContent: BadgeView.Content {
            switch self {
            case .success: .glyph(.checkmark)
            case .error: .glyph(.cross)
            case .warning: .glyph(.exclamation)
            case .info: .glyph(.info)
            case .question: .glyph(.question)
            case .notice: .symbol("bell.fill")
            case .edit: .symbol("pencil")
            case .wait: .spinner
            case .custom(_, let icon): icon.map { .image($0) } ?? .glyph(.info)
            }
        }

        var feedback: UINotificationFeedbackGenerator.FeedbackType? {
            switch self {
            case .success: .success
            case .error: .error
            case .warning: .warning
            default: nil
            }
        }
    }

    /// How the alert enters the screen.
    enum AnimationStyle: Sendable, CaseIterable {
        case noAnimation
        case topToBottom
        case bottomToTop
        case leftToRight
        case rightToLeft
        case fade
        case zoom
    }

    /// How buttons are arranged.
    enum ButtonLayout: Sendable {
        case vertical
        case horizontal
        /// Side by side when there are exactly two buttons whose titles fit, stacked otherwise.
        case automatic
    }

    /// The visual role of a button.
    enum ButtonRole: Sendable {
        /// Filled with the alert's accent color.
        case `default`
        /// A quiet, neutral button.
        case cancel
        /// Filled with the system red.
        case destructive
    }

    /// Shows the remaining timeout next to a button title, e.g. `"Skip (3s)"`.
    struct Countdown: Sendable, Equatable {
        public var prefix: String
        public var suffix: String

        public init(prefix: String = "", suffix: String = "") {
            self.prefix = prefix
            self.suffix = suffix
        }

        /// `"Title (3)"`
        public static let parentheses = Countdown(prefix: "(", suffix: ")")
        /// `"Title (3s)"`
        public static let seconds = Countdown(prefix: "(", suffix: "s)")

        func title(_ title: String, remaining seconds: Int) -> String {
            "\(title) \(prefix)\(seconds)\(suffix)"
        }
    }

    /// Closes the alert automatically after `seconds`, running `action` first.
    struct Timeout {
        public var seconds: TimeInterval
        public var action: Action?

        public init(_ seconds: TimeInterval, action: Action? = nil) {
            self.seconds = seconds
            self.action = action
        }
    }

    /// How an alert ended.
    enum Result: Equatable, Sendable {
        /// A button added with `button(...)` was tapped. `index` counts only those buttons, in order.
        case button(index: Int, title: String)
        /// The timeout elapsed.
        case timeout
        /// Closed without picking an action: the close button, a background tap, or `close()`.
        case dismissed
    }
}

/// Internal model for a button, kept as a class so it can drop its action when the alert closes.
@MainActor
final class ButtonItem {
    let title: String
    let role: CoolAlert.ButtonRole
    let backgroundColor: UIColor?
    let textColor: UIColor?
    let countdown: CoolAlert.Countdown?
    let isCloseButton: Bool
    var action: CoolAlert.Action?
    var asyncAction: CoolAlert.AsyncAction?
    var target: AnyObject?
    var selector: Selector?

    init(
        title: String,
        role: CoolAlert.ButtonRole,
        backgroundColor: UIColor? = nil,
        textColor: UIColor? = nil,
        countdown: CoolAlert.Countdown? = nil,
        isCloseButton: Bool = false,
        action: CoolAlert.Action? = nil,
        asyncAction: CoolAlert.AsyncAction? = nil,
        target: AnyObject? = nil,
        selector: Selector? = nil
    ) {
        self.title = title
        self.role = role
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.countdown = countdown
        self.isCloseButton = isCloseButton
        self.action = action
        self.asyncAction = asyncAction
        self.target = target
        self.selector = selector
    }

    /// Breaks retain cycles between the alert and closures that capture it.
    func release() {
        action = nil
        asyncAction = nil
        target = nil
        selector = nil
    }
}
