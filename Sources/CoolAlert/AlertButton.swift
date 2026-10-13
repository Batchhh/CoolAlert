import UIKit

final class AlertButton: UIButton {
    let item: ButtonItem
    private let font: UIFont
    private let digitFont: UIFont
    private var resolvedTitle: AttributedString?

    init(item: ButtonItem, appearance: CoolAlert.Appearance, background: UIColor, foreground: UIColor) {
        self.item = item
        font = appearance.buttonFont
        digitFont = UIFont(
            descriptor: appearance.buttonFont.fontDescriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
                ]]
            ]),
            size: 0
        )
        super.init(frame: .zero)

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = background
        config.baseForegroundColor = foreground
        config.cornerStyle = .fixed
        config.background.cornerRadius = appearance.buttonCornerRadius
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.titleLineBreakMode = .byTruncatingTail
        configuration = config
        setTitle(item.title, countdown: false)

        heightAnchor.constraint(greaterThanOrEqualToConstant: appearance.buttonHeight).isActive = true
        accessibilityLabel = item.title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateCountdown(_ seconds: Int) {
        guard let countdown = item.countdown else { return }
        setTitle(countdown.title(item.title, remaining: seconds), countdown: true)
    }

    /// Drops the countdown from the title.
    func resetTitle() {
        setTitle(item.title, countdown: false)
    }

    /// Swaps the title for a spinner while an async action runs.
    func setBusy(_ busy: Bool) {
        configuration?.showsActivityIndicator = busy
        configuration?.attributedTitle = busy ? nil : resolvedTitle
        accessibilityValue = busy ? "Loading" : nil
    }

    private func setTitle(_ title: String, countdown: Bool) {
        var container = AttributeContainer()
        container.font = countdown ? digitFont : font
        resolvedTitle = AttributedString(title, attributes: container)
        if configuration?.showsActivityIndicator != true {
            configuration?.attributedTitle = resolvedTitle
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            UIView.animate(
                withDuration: isHighlighted ? 0.12 : 0.35,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}
