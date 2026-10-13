import UIKit

public extension CoolAlert {

    /// Everything about how an alert looks and behaves.
    ///
    /// Set `CoolAlert.defaultAppearance` once to theme every alert, or pass one to a single alert:
    ///
    /// ```swift
    /// CoolAlert.defaultAppearance = .init {
    ///     $0.buttonsLayout = .automatic
    ///     $0.hideWhenBackgroundViewIsTapped = true
    /// }
    /// ```
    struct Appearance {

        /// What the card is made of.
        public enum CardStyle: Sendable {
            /// An opaque card in `contentViewColor`.
            case solid
            /// Liquid Glass on iOS 26 and later, a thick material blur before that.
            case glass
        }

        /// Spacing inside the card.
        public struct Margin {
            /// Top padding when the circular icon is hidden.
            public var top: CGFloat
            /// Space between the badge and the title.
            public var titleTop: CGFloat
            /// Space between the title and the message.
            public var titleToMessage: CGFloat
            /// Space after the message, custom view and fields, before the next section.
            public var textViewBottom: CGFloat
            /// Space between buttons.
            public var buttonSpacing: CGFloat
            /// Space between text fields and text views.
            public var textFieldSpacing: CGFloat
            /// Bottom padding.
            public var bottom: CGFloat
            /// Leading and trailing padding.
            public var horizontal: CGFloat

            public init(
                top: CGFloat = 26,
                titleTop: CGFloat = 14,
                titleToMessage: CGFloat = 6,
                textViewBottom: CGFloat = 20,
                buttonSpacing: CGFloat = 10,
                textFieldSpacing: CGFloat = 10,
                bottom: CGFloat = 20,
                horizontal: CGFloat = 20
            ) {
                self.top = top
                self.titleTop = titleTop
                self.titleToMessage = titleToMessage
                self.textViewBottom = textViewBottom
                self.buttonSpacing = buttonSpacing
                self.textFieldSpacing = textFieldSpacing
                self.bottom = bottom
                self.horizontal = horizontal
            }
        }

        // MARK: Backdrop

        /// Opacity of the dimming layer behind the alert.
        public var dimOpacity: CGFloat = 0.4
        /// Blurs whatever is behind the alert.
        public var backgroundBlur = false
        /// Tapping outside the card closes the alert.
        public var hideWhenBackgroundViewIsTapped = false

        // MARK: Card

        /// Preferred card width. Shrinks on narrow screens.
        public var windowWidth: CGFloat = 300
        public var cardStyle: CardStyle = .solid
        /// Card background for `.solid` cards. `nil` uses a white card in light mode and a dark gray one in dark mode.
        public var contentViewColor: UIColor?
        public var contentViewBorderColor: UIColor = .clear
        public var contentViewBorderWidth: CGFloat = 0
        public var contentViewCornerRadius: CGFloat = 26
        public var shadowOpacity: Float = 0.18
        public var margin = Margin()

        // MARK: Circular icon

        public var showCircularIcon = true
        /// Diameter of the colored circle.
        public var circleSize: CGFloat = 66
        /// Width of the ring around the circle that cuts it out of the card.
        public var circleRingWidth: CGFloat = 6
        /// Vertical offset of the circle's center from the card's top edge.
        public var circleTopPosition: CGFloat = 0
        /// Size of the icon drawn inside the circle.
        public var circleIconSize: CGFloat = 30
        /// Ring color. `nil` matches the card (or is glass, for glass cards).
        public var circleBackgroundColor: UIColor?
        /// Draws the icon stroke by stroke as the alert appears.
        public var animatedIcons = true
        /// Spinner style for `.wait` alerts.
        public var activityIndicatorStyle: UIActivityIndicatorView.Style = .large

        // MARK: Text

        public var titleFont = Appearance.scaledFont(size: 21, weight: .bold, textStyle: .title3, rounded: true)
        /// `nil` uses the system label color.
        public var titleColor: UIColor?
        /// Below 1 the title stays on one line and shrinks to fit.
        public var titleMinimumScaleFactor: CGFloat = 1
        public var messageFont = Appearance.scaledFont(size: 15, weight: .regular, textStyle: .subheadline)
        /// `nil` uses the system secondary label color.
        public var messageColor: UIColor?
        public var messageAlignment: NSTextAlignment = .center
        /// Messages taller than this scroll.
        public var maxMessageHeight: CGFloat = 180

        // MARK: Inputs

        public var textFieldHeight: CGFloat = 46
        public var textViewHeight: CGFloat = 96
        public var fieldCornerRadius: CGFloat = 12
        public var fieldFont = Appearance.scaledFont(size: 16, weight: .regular, textStyle: .body)
        /// Focuses the first text field or text view once the alert is on screen.
        public var focusFirstField = false

        // MARK: Buttons

        public var buttonFont = Appearance.scaledFont(size: 16, weight: .semibold, textStyle: .body, rounded: true)
        public var buttonHeight: CGFloat = 48
        public var buttonCornerRadius: CGFloat = 14
        public var buttonsLayout: ButtonLayout = .vertical
        /// Adds a close button (title from `closeButton(_:)`, "Done" by default). `.wait` alerts never get one unless you ask.
        public var showCloseButton = true
        /// When `false`, tapping a button runs its action but keeps the alert open.
        public var shouldAutoDismiss = true

        // MARK: Behavior

        /// Snaps the alert in with UIKit Dynamics and drops it with gravity on dismiss.
        public var dynamicAnimatorActive = false
        /// Lets the user fling the card away. Only applies when the alert can already be dismissed without
        /// picking an action (it has a close button, or `hideWhenBackgroundViewIsTapped` is on).
        public var swipeToDismiss = true
        /// Tapping the card no longer dismisses the keyboard. Useful when a custom view has its own gestures.
        public var disableTapGesture = false
        public var hapticFeedback = true
        /// Shows a thin bar along the bottom edge that drains as the timeout runs.
        public var showTimeoutProgress = true

        public init() {}

        /// Starts from the defaults and lets you change what you need.
        public init(_ configure: (inout Appearance) -> Void) {
            configure(&self)
        }

        /// A system font that follows Dynamic Type.
        public static func scaledFont(
            size: CGFloat,
            weight: UIFont.Weight,
            textStyle: UIFont.TextStyle,
            rounded: Bool = false
        ) -> UIFont {
            var font = UIFont.systemFont(ofSize: size, weight: weight)
            if rounded, let descriptor = font.fontDescriptor.withDesign(.rounded) {
                font = UIFont(descriptor: descriptor, size: size)
            }
            return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
        }

        var resolvedContentColor: UIColor {
            contentViewColor ?? UIColor(light: 0xFFFFFF, dark: 0x1F1F22)
        }
    }
}
