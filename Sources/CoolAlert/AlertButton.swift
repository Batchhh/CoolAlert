import UIKit

final class AlertButton: UIButton {
    /// The event a tap sends. `UIButton` sends `.primaryActionTriggered` from iOS 14; before that, only `.touchUpInside`.
    static var tapEvent: UIControl.Event {
        if #available(iOS 14.0, *) { return .primaryActionTriggered }
        return .touchUpInside
    }

    let item: ButtonItem
    private let font: UIFont
    private let digitFont: UIFont
    private let foreground: UIColor
    private var displayedTitle = ""
    private var showsDigits = false
    private var isBusy = false
    /// Stands in for the configuration's activity indicator on iOS 13–14.
    private var spinner: UIActivityIndicatorView?

    init(item: ButtonItem, appearance: CoolAlert.Appearance, background: UIColor, foreground: UIColor) {
        self.item = item
        self.foreground = foreground
        font = appearance.buttonFont
        digitFont = appearance.buttonFont.withMonospacedDigits
        super.init(frame: .zero)

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = background
            config.baseForegroundColor = foreground
            config.cornerStyle = .fixed
            config.background.cornerRadius = appearance.buttonCornerRadius
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            config.titleLineBreakMode = .byTruncatingTail
            configuration = config
        } else {
            backgroundColor = background
            layer.cornerRadius = appearance.buttonCornerRadius
            layer.cornerCurve = .continuous
            contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            titleLabel?.lineBreakMode = .byTruncatingTail
        }
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
        isBusy = busy
        if #available(iOS 15.0, *) {
            configuration?.showsActivityIndicator = busy
        } else if busy {
            (spinner ?? makeSpinner()).startAnimating()
        } else {
            spinner?.stopAnimating()
        }
        applyTitle()
        accessibilityValue = busy ? "Loading" : nil
    }

    private func setTitle(_ title: String, countdown: Bool) {
        displayedTitle = title
        showsDigits = countdown
        applyTitle()
    }

    private func applyTitle() {
        let font = showsDigits ? digitFont : self.font
        if #available(iOS 15.0, *) {
            var container = AttributeContainer()
            container.font = font
            configuration?.attributedTitle = isBusy ? nil : AttributedString(displayedTitle, attributes: container)
        } else {
            // Hidden rather than removed while busy, so the button keeps its size.
            setAttributedTitle(NSAttributedString(string: displayedTitle, attributes: [
                .font: font,
                .foregroundColor: isBusy ? UIColor.clear : foreground,
            ]), for: .normal)
        }
    }

    private func makeSpinner() -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = foreground
        spinner.hidesWhenStopped = true
        spinner.isUserInteractionEnabled = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        self.spinner = spinner
        return spinner
    }

    override var isEnabled: Bool {
        didSet {
            // The filled configuration dims disabled buttons itself.
            if #unavailable(iOS 15.0) { alpha = isEnabled ? 1 : 0.5 }
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
