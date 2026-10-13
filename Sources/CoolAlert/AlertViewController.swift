import UIKit

/// Root controller of the alert's window: backdrop, card, badge and their animations.
///
/// The card has a scrolling body (title, message, custom view, inputs, error) and a pinned row of
/// buttons, so it stays usable when space runs out: landscape, a raised keyboard, or large text.
final class AlertViewController: UIViewController, UITextFieldDelegate, UIDynamicAnimatorDelegate, UIGestureRecognizerDelegate {
    private let alert: CoolAlert
    private let buttonItems: [ButtonItem]
    private let appearance: CoolAlert.Appearance
    private let reduceMotion = UIAccessibility.isReduceMotionEnabled
    var inheritedOrientations: UIInterfaceOrientationMask?

    private let backdrop = UIView()
    /// Last resort when even a shrunken card doesn't fit (landscape with the keyboard up): the whole card scrolls.
    private let container = UIScrollView()
    private var containerTop: NSLayoutConstraint?
    /// Keeps the container above the keyboard on iOS 13–14, which have no `keyboardLayoutGuide`.
    private var keyboardBottom: NSLayoutConstraint?
    private var keyboardHeight: CGFloat = 0
    /// The button running an async action, kept in its accent color while it spins.
    private weak var busyButton: AlertButton?
    private var blurView: UIVisualEffectView?
    /// Holds the card and the badge so they move as one.
    private let wrapper = UIView()
    private let card = UIView()
    private let surface = UIView()
    private let bodyScroll = UIScrollView()
    private let bodyStack = UIStackView()
    private let titleLabel = UILabel()
    private let messageScroll = UIScrollView()
    private let messageLabel = UILabel()
    private let errorLabel = UILabel()
    private var badge: BadgeView?
    private var buttonViews: [AlertButton] = []
    private let progressTrack = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let pan = UIPanGestureRecognizer()
    private var dynamics: UIDynamicAnimator?
    private var proxy: TranslationProxy?
    /// `true` once the entrance animation has finished.
    private var isSettled = false
    /// Set when a swipe flings the card away, so the exit animation continues that motion.
    private var fling: (translation: CGPoint, rotation: CGFloat, duration: TimeInterval)?
    /// Keeps the body from collapsing when space runs out. Never more than the content's own height,
    /// or it would stretch short alerts (see `viewDidLayoutSubviews`).
    private var minimumBody: NSLayoutConstraint?
    private let minimumBodyHeight: CGFloat = 120

    init(alert: CoolAlert, buttons: [ButtonItem]) {
        self.alert = alert
        self.buttonItems = buttons
        self.appearance = alert.appearance
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        inheritedOrientations ?? super.supportedInterfaceOrientations
    }

    // MARK: - Building

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildBackdrop()
        buildCard()
        buildContent()
        buildBadge()
        if let hosting = alert.hostingController {
            addChild(hosting)
            hosting.didMove(toParent: self)
        }
        refreshLayerColors()
        updateProgress(animated: false)
        revalidate()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: AlertViewController, _: UITraitCollection) in
                controller.refreshLayerColors()
            }
        }
    }

    /// iOS 13–16. Later systems use the registration in `viewDidLoad`.
    @available(iOS, deprecated: 17.0)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17.0), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshLayerColors()
        }
    }

    private func buildBackdrop() {
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backdrop)

        if appearance.backgroundBlur {
            let blur = UIVisualEffectView(effect: nil)
            blur.frame = backdrop.bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blur.isUserInteractionEnabled = false
            backdrop.addSubview(blur)
            blurView = blur
        }

        let dim = UIView(frame: backdrop.bounds)
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dim.backgroundColor = UIColor.black.withAlphaComponent(appearance.dimOpacity)
        dim.isUserInteractionEnabled = false
        backdrop.addSubview(dim)

        container.translatesAutoresizingMaskIntoConstraints = false
        container.contentInsetAdjustmentBehavior = .never
        container.alwaysBounceVertical = false
        container.showsHorizontalScrollIndicator = false
        container.delaysContentTouches = false
        view.addSubview(container)
        let bottom: NSLayoutConstraint
        if #available(iOS 15.0, *) {
            bottom = container.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        } else {
            bottom = container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            keyboardBottom = bottom
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil
            )
        }
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom,
        ])
        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backdropTapped)))
    }

    private func buildCard() {
        let margin = appearance.margin
        let radius = appearance.contentViewCornerRadius
        let isGlass = appearance.cardStyle == .glass

        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.accessibilityViewIsModal = true
        container.addSubview(wrapper)

        pan.addTarget(self, action: #selector(handlePan))
        pan.delegate = self
        wrapper.addGestureRecognizer(pan)

        card.translatesAutoresizingMaskIntoConstraints = false
        if !isGlass {
            card.layer.shadowColor = UIColor.black.cgColor
            card.layer.shadowOpacity = appearance.shadowOpacity
            card.layer.shadowRadius = 30
            card.layer.shadowOffset = CGSize(width: 0, height: 14)
        }
        wrapper.addSubview(card)

        surface.translatesAutoresizingMaskIntoConstraints = false
        surface.layer.cornerRadius = radius
        surface.layer.cornerCurve = .continuous
        surface.layer.borderWidth = appearance.contentViewBorderWidth
        if isGlass {
            // Glass draws its own rounded shape; clipping it from a parent would flatten the effect.
            let glass = Glass.makeView(cornerRadius: radius)
            glass.frame = surface.bounds
            glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            surface.addSubview(glass)
        } else {
            surface.backgroundColor = appearance.resolvedContentColor
            surface.clipsToBounds = true
        }
        card.addSubview(surface)

        if !appearance.disableTapGesture {
            let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
            tap.cancelsTouchesInView = false
            surface.addGestureRecognizer(tap)
        }

        for layer in [progressTrack, progressLayer] {
            layer.fillColor = nil
            layer.lineWidth = 3
            layer.lineCap = .round
            layer.isHidden = true
            surface.layer.addSublayer(layer)
        }

        bodyScroll.translatesAutoresizingMaskIntoConstraints = false
        bodyScroll.alwaysBounceVertical = false
        bodyScroll.showsHorizontalScrollIndicator = false
        bodyScroll.contentInsetAdjustmentBehavior = .never
        bodyScroll.delaysContentTouches = false
        surface.addSubview(bodyScroll)

        bodyStack.axis = .vertical
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyScroll.addSubview(bodyStack)

        let showBadge = appearance.showCircularIcon
        let badgeRadius = appearance.circleSize / 2 + appearance.circleRingWidth
        let badgeAboveCard = showBadge ? max(0, badgeRadius - appearance.circleTopPosition) : 0
        let badgeInsideCard = showBadge ? max(0, badgeRadius + appearance.circleTopPosition) : 0
        let showsProgress = appearance.showTimeoutProgress && (alert.timeout?.seconds ?? 0) > 0
        let bottomInset = margin.bottom + (showsProgress ? 6 : 0)
        let safe = view.safeAreaLayoutGuide

        let preferredWidth = wrapper.widthAnchor.constraint(equalToConstant: appearance.windowWidth)
        preferredWidth.priority = .defaultHigh
        let content = container.contentLayoutGuide
        let frame = container.frameLayoutGuide
        let centered = wrapper.centerYAnchor.constraint(equalTo: frame.centerYAnchor)
        centered.priority = .defaultLow
        // Squeezing order: first the body shrinks and scrolls, down to `minimumBody`;
        // only then does the whole card grow past the screen and scroll.
        let fitsScreen = content.heightAnchor.constraint(equalTo: frame.heightAnchor)
        fitsScreen.priority = .init(745)
        let minimumBody = bodyScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        minimumBody.priority = .init(750)
        self.minimumBody = minimumBody
        let top = wrapper.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 12)
        containerTop = top
        // The body takes its content's height until space runs out; then it scrolls.
        let bodyFits = bodyScroll.frameLayoutGuide.heightAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.heightAnchor)
        bodyFits.priority = .init(740)

        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
            fitsScreen,
            wrapper.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
            wrapper.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -32),
            preferredWidth,
            centered,
            top,
            wrapper.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -12),
            bodyScroll.frameLayoutGuide.heightAnchor.constraint(lessThanOrEqualTo: bodyScroll.contentLayoutGuide.heightAnchor),
            minimumBody,

            card.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: badgeAboveCard),
            card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

            surface.topAnchor.constraint(equalTo: card.topAnchor),
            surface.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            bodyScroll.topAnchor.constraint(equalTo: surface.topAnchor, constant: showBadge ? badgeInsideCard + margin.titleTop : margin.top),
            bodyScroll.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            bodyScroll.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            bodyFits,

            bodyStack.topAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.topAnchor),
            bodyStack.bottomAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.bottomAnchor),
            bodyStack.leadingAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.leadingAnchor, constant: margin.horizontal),
            bodyStack.trailingAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.trailingAnchor, constant: -margin.horizontal),
            bodyStack.widthAnchor.constraint(equalTo: bodyScroll.frameLayoutGuide.widthAnchor, constant: -margin.horizontal * 2),
        ])

        guard !buttonItems.isEmpty else {
            bodyScroll.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -bottomInset).isActive = true
            return
        }

        let buttons = UIStackView()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.spacing = margin.buttonSpacing
        buttons.distribution = .fillEqually
        buttons.axis = buttonsSideBySide ? .horizontal : .vertical
        for item in buttonItems {
            let button = makeButton(for: item)
            buttons.addArrangedSubview(button)
            buttonViews.append(button)
        }
        surface.addSubview(buttons)
        NSLayoutConstraint.activate([
            buttons.topAnchor.constraint(equalTo: bodyScroll.bottomAnchor, constant: margin.textViewBottom),
            buttons.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: margin.horizontal),
            buttons.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -margin.horizontal),
            buttons.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -bottomInset),
        ])
    }

    private func buildContent() {
        let margin = appearance.margin

        titleLabel.font = appearance.titleFont
        titleLabel.textColor = appearance.titleColor ?? .label
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        errorLabel.setContentHuggingPriority(.required, for: .vertical)
        if appearance.titleMinimumScaleFactor < 1 {
            titleLabel.numberOfLines = 1
            titleLabel.adjustsFontSizeToFitWidth = true
            titleLabel.minimumScaleFactor = appearance.titleMinimumScaleFactor
        } else {
            titleLabel.numberOfLines = 0
        }
        bodyStack.addArrangedSubview(titleLabel)

        // The message grows with its text up to `maxMessageHeight`, then scrolls on its own.
        messageLabel.numberOfLines = 0
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageScroll.addSubview(messageLabel)
        messageScroll.alwaysBounceVertical = false
        let fitsContent = messageScroll.frameLayoutGuide.heightAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.heightAnchor)
        fitsContent.priority = .init(999)
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.topAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.bottomAnchor),
            messageLabel.widthAnchor.constraint(equalTo: messageScroll.frameLayoutGuide.widthAnchor),
            messageScroll.frameLayoutGuide.heightAnchor.constraint(lessThanOrEqualToConstant: appearance.maxMessageHeight),
            fitsContent,
        ])
        bodyStack.addArrangedSubview(messageScroll)
        bodyStack.setCustomSpacing(margin.textViewBottom, after: messageScroll)

        if let custom = alert.customView {
            bodyStack.addArrangedSubview(custom)
            bodyStack.setCustomSpacing(margin.textViewBottom, after: custom)
        }

        for (index, input) in alert.inputs.enumerated() {
            (input as? AlertInput)?.apply(appearance, accent: alert.tintColor)
            if let field = input as? UITextField {
                field.delegate = self
                field.returnKeyType = index == alert.inputs.count - 1 ? .done : .next
                field.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
            } else if let textView = input as? UITextView {
                NotificationCenter.default.addObserver(self, selector: #selector(inputChanged), name: UITextView.textDidChangeNotification, object: textView)
            }
            bodyStack.addArrangedSubview(input)
            bodyStack.setCustomSpacing(margin.textFieldSpacing, after: input)
        }

        errorLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        if let last = bodyStack.arrangedSubviews.last, last !== messageScroll {
            bodyStack.setCustomSpacing(margin.textFieldSpacing, after: last)
        }
        bodyStack.addArrangedSubview(errorLabel)

        updateText()
    }

    private var buttonsSideBySide: Bool {
        switch appearance.buttonsLayout {
        case .vertical: return false
        case .horizontal: return true
        case .automatic:
            guard buttonItems.count == 2 else { return false }
            let available = (appearance.windowWidth - appearance.margin.horizontal * 2 - appearance.margin.buttonSpacing) / 2 - 28
            return buttonItems.allSatisfy {
                ($0.title as NSString).size(withAttributes: [.font: appearance.buttonFont]).width <= available
            }
        }
    }

    private func makeButton(for item: ButtonItem) -> AlertButton {
        let background: UIColor
        let foreground: UIColor
        switch item.role {
        case .default:
            background = item.backgroundColor ?? alert.tintColor
            foreground = item.textColor ?? alert.buttonTextColor ?? background.contrastingTextColor
        case .cancel:
            background = item.backgroundColor ?? .tertiarySystemFill
            foreground = item.textColor ?? .label
        case .destructive:
            background = item.backgroundColor ?? .systemRed
            foreground = item.textColor ?? .white
        }
        let button = AlertButton(item: item, appearance: appearance, background: background, foreground: foreground)
        button.addTarget(self, action: #selector(buttonTapped), for: AlertButton.tapEvent)
        return button
    }

    @objc private func buttonTapped(_ button: AlertButton) {
        alert.handleTap(on: button.item, sender: button)
    }

    private func buildBadge() {
        guard appearance.showCircularIcon else { return }
        let content = alert.iconImage.map { BadgeView.Content.image($0) } ?? alert.style.defaultBadgeContent
        let badge = BadgeView(content: content, accent: alert.tintColor, iconTint: alert.iconTintColor, appearance: appearance)
        wrapper.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: card.topAnchor, constant: appearance.circleTopPosition),
        ])
        self.badge = badge
    }

    // MARK: - Updates

    func updateText() {
        titleLabel.text = alert.title
        titleLabel.isHidden = alert.title.isEmpty
        wrapper.accessibilityLabel = alert.title

        let message = alert.message ?? ""
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = appearance.messageAlignment
        paragraph.lineSpacing = 2
        messageLabel.attributedText = NSAttributedString(string: message, attributes: [
            .font: appearance.messageFont,
            .foregroundColor: appearance.messageColor ?? UIColor.secondaryLabel,
            .paragraphStyle: paragraph,
        ])
        if messageScroll.isHidden != message.isEmpty { messageScroll.isHidden = message.isEmpty }

        // With no message, the title needs the full section gap before whatever follows.
        bodyStack.setCustomSpacing(message.isEmpty ? appearance.margin.textViewBottom : appearance.margin.titleToMessage, after: titleLabel)
        animateLayoutIfVisible()
    }

    func updateCountdown(_ seconds: Int) {
        buttonViews.forEach { $0.updateCountdown(seconds) }
    }

    func updateProgress(animated: Bool) {
        badge?.setProgress(alert.progress, animated: animated && view.window != nil)
    }

    func timeoutStarted(duration: TimeInterval) {
        guard appearance.showTimeoutProgress else { return }
        let drain = CABasicAnimation(keyPath: "strokeEnd")
        drain.fromValue = 1
        drain.toValue = 0
        drain.duration = duration
        progressLayer.strokeEnd = 0
        progressLayer.add(drain, forKey: "drain")
        progressTrack.isHidden = false
        progressLayer.isHidden = false
    }

    func timeoutStopped() {
        progressLayer.removeAnimation(forKey: "drain")
        progressTrack.isHidden = true
        progressLayer.isHidden = true
        buttonViews.forEach { $0.resetTitle() }
    }

    /// Enables the action buttons only while the alert's validation rule passes and nothing is running.
    func revalidate() {
        let valid = alert.validator?() ?? true
        for button in buttonViews {
            let gated = !button.item.isCloseButton && button.item.role != .cancel
            // Taps are ignored while busy anyway; the spinning button keeps its color.
            button.isEnabled = button === busyButton || (!alert.isBusy && (!gated || valid))
        }
    }

    func setBusy(_ busy: Bool, on item: ButtonItem) {
        if busy { view.endEditing(true) }
        let button = buttonViews.first { $0.item === item }
        busyButton = busy ? button : nil
        button?.setBusy(busy)
        alert.inputs.forEach { $0.isUserInteractionEnabled = !busy }
        revalidate()
    }

    func showError(_ message: String?) {
        let text = message?.isEmpty == false ? message : nil
        errorLabel.text = text
        if errorLabel.isHidden != (text == nil) { errorLabel.isHidden = text == nil }
        animateLayoutIfVisible()
        guard let text else { return }

        if appearance.hapticFeedback { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        if !reduceMotion {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [0, -12, 10, -7, 5, -2, 0]
            shake.duration = 0.45
            shake.isAdditive = true
            wrapper.layer.add(shake, forKey: "shake")
        }
        view.layoutIfNeeded()
        bodyScroll.scrollRectToVisible(errorLabel.convert(errorLabel.bounds, to: bodyScroll), animated: true)
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    @objc private func inputChanged() {
        revalidate()
        if !errorLabel.isHidden { showError(nil) }
    }

    private func animateLayoutIfVisible() {
        guard isViewLoaded, view.window != nil else { return }
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    private func refreshLayerColors() {
        surface.layer.borderColor = appearance.contentViewBorderColor.resolvedColor(with: traitCollection).cgColor
        let tint = alert.tintColor.resolvedColor(with: traitCollection)
        progressLayer.strokeColor = tint.cgColor
        progressTrack.strokeColor = tint.withAlphaComponent(0.15).cgColor
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        containerTop?.constant = view.safeAreaInsets.top + 12
        updateKeyboardBottom()
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let info = notification.userInfo,
              let end = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let screen = view.window?.screen else { return }
        let frame = view.convert(end, from: screen.coordinateSpace)
        keyboardHeight = max(0, view.bounds.maxY - frame.minY)
        updateKeyboardBottom()
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }

    /// Like `keyboardLayoutGuide`, which rests on the bottom safe area while the keyboard is down.
    private func updateKeyboardBottom() {
        keyboardBottom?.constant = -max(keyboardHeight, view.safeAreaInsets.bottom)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if appearance.cardStyle == .solid {
            card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds, cornerRadius: appearance.contentViewCornerRadius).cgPath
        }

        // A short bar centered in the bottom padding, clear of the rounded corners.
        let y = surface.bounds.maxY - appearance.margin.bottom / 2
        let inset = max(appearance.contentViewCornerRadius, appearance.margin.horizontal) + 8
        let line = UIBezierPath()
        line.move(to: CGPoint(x: inset, y: y))
        line.addLine(to: CGPoint(x: surface.bounds.maxX - inset, y: y))
        progressTrack.path = line.cgPath
        progressLayer.path = line.cgPath

        messageScroll.isScrollEnabled = messageScroll.contentSize.height > messageScroll.bounds.height + 0.5

        // The body's floor is the smaller of 120 pt and its natural height.
        if let minimumBody, bodyStack.bounds.width > 0 {
            let natural = bodyStack.systemLayoutSizeFitting(
                CGSize(width: bodyStack.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
            let floor = min(minimumBodyHeight, natural)
            if abs(minimumBody.constant - floor) > 0.5 {
                minimumBody.constant = floor
                view.setNeedsLayout()
            }
        }

        // Keep the focused field in view as the keyboard squeezes the card.
        if let focused = alert.inputs.first(where: \.isFirstResponder) {
            bodyScroll.scrollRectToVisible(focused.convert(focused.bounds, to: bodyScroll).insetBy(dx: 0, dy: -8), animated: false)
            container.scrollRectToVisible(focused.convert(focused.bounds, to: container).insetBy(dx: 0, dy: -12), animated: false)
        }
    }

    // MARK: - Interaction

    @objc private func backdropTapped(_ tap: UITapGestureRecognizer) {
        // The container covers the whole screen; taps on the card itself aren't background taps.
        guard !wrapper.frame.contains(tap.location(in: container)) else { return }
        if alert.handleBackgroundTap() { return }
        if view.endEditing(true) { return }
        // Not dismissible from here: a quick pulse says so.
        guard isSettled, !reduceMotion else { return }
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.wrapper.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        } completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0, options: .allowUserInteraction) {
                self.wrapper.transform = .identity
            }
        }
    }

    @objc private func cardTapped() {
        view.endEditing(true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let inputs = alert.inputs
        if let index = inputs.firstIndex(of: textField), index + 1 < inputs.count {
            inputs[index + 1].becomeFirstResponder()
            return true
        }
        // Return on the last field submits the first action button, like the system alert does.
        if let primary = buttonViews.first(where: { $0.item.role == .default && !$0.item.isCloseButton }), primary.isEnabled {
            primary.sendActions(for: AlertButton.tapEvent)
        } else {
            textField.resignFirstResponder()
        }
        return true
    }

    override func accessibilityPerformEscape() -> Bool {
        guard alert.isUserDismissible, !alert.isBusy else { return false }
        alert.close()
        return true
    }

    // MARK: - Swipe to dismiss

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === pan else { return true }
        guard appearance.swipeToDismiss else { return false }
        // Leave drags to controls and scrollable content.
        var view = touch.view
        while let current = view, current !== wrapper {
            if current is UISlider || current is UISwitch || current is UITextField || current is UITextView || current === alert.customView {
                return false
            }
            if let scroll = current as? UIScrollView, scroll.contentSize.height > scroll.bounds.height + 1 {
                return false
            }
            view = current.superview
        }
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan else { return true }
        let cardScrolls = container.contentSize.height > container.bounds.height + 1
        return isSettled && dynamics == nil && alert.isVisible && !alert.isBusy && !cardScrolls
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let dismissible = alert.isUserDismissible
        let translation = pan.translation(in: view)
        let distance = hypot(translation.x, translation.y)

        switch pan.state {
        case .changed:
            if dismissible {
                wrapper.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
                    .rotated(by: translation.x / 1000)
                backdrop.alpha = 1 - min(0.6, distance / 600)
            } else {
                // Resist: the alert needs an answer.
                wrapper.transform = CGAffineTransform(translationX: rubberBand(translation.x), y: rubberBand(translation.y))
            }
        case .ended, .cancelled, .failed:
            let velocity = pan.velocity(in: view)
            let speed = hypot(velocity.x, velocity.y)
            if dismissible, pan.state == .ended, distance > 110 || speed > 900 {
                let direction = speed > 200
                    ? CGPoint(x: velocity.x / speed, y: velocity.y / speed)
                    : CGPoint(x: translation.x / max(distance, 1), y: translation.y / max(distance, 1))
                let travel = max(view.bounds.width, view.bounds.height)
                fling = (
                    CGPoint(x: translation.x + direction.x * travel, y: translation.y + direction.y * travel),
                    (translation.x + direction.x * travel) / 1000,
                    min(0.4, max(0.18, travel / max(speed, 1)))
                )
                alert.handleSwipeDismiss()
            } else {
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: .allowUserInteraction) {
                    self.wrapper.transform = .identity
                    self.backdrop.alpha = 1
                }
            }
        default:
            break
        }
    }

    private func rubberBand(_ offset: CGFloat) -> CGFloat {
        let limit: CGFloat = 36
        let magnitude = (1 - 1 / (abs(offset) * 0.55 / limit + 1)) * limit
        return offset < 0 ? -magnitude : magnitude
    }

    // MARK: - Entrance

    func animateIn() {
        view.layoutIfNeeded()
        badge?.prepareForEntrance()
        var style = alert.animationStyle
        if reduceMotion, style != .noAnimation { style = .fade }
        let iconDelay: TimeInterval

        if style == .noAnimation {
            blurView?.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            iconDelay = 0
        } else {
            backdrop.alpha = 0
            UIView.animate(withDuration: 0.3) {
                self.backdrop.alpha = 1
                self.blurView?.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            }

            switch style {
            case .fade:
                wrapper.alpha = 0
                UIView.animate(withDuration: 0.3) { self.wrapper.alpha = 1 }
                iconDelay = 0.1
            case .zoom:
                wrapper.alpha = 0
                wrapper.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
                UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                    self.wrapper.alpha = 1
                    self.wrapper.transform = .identity
                }
                iconDelay = 0.12
            default:
                let offset = entranceOffset(for: style)
                if appearance.dynamicAnimatorActive {
                    snapIn(from: offset)
                } else {
                    wrapper.transform = CGAffineTransform(translationX: offset.x, y: offset.y)
                    UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
                        self.wrapper.transform = .identity
                    }
                }
                iconDelay = 0.28
            }
        }

        Task {
            try? await Task.sleep(seconds: iconDelay)
            badge?.playEntrance()
            UIAccessibility.post(notification: .screenChanged, argument: wrapper)
            if appearance.focusFirstField { alert.inputs.first?.becomeFirstResponder() }
            try? await Task.sleep(seconds: style == .noAnimation ? 0 : 0.35)
            if dynamics == nil { isSettled = true }
        }
    }

    private func entranceOffset(for style: CoolAlert.AnimationStyle) -> CGPoint {
        let frame = wrapper.frame
        let bounds = view.bounds
        switch style {
        case .topToBottom: return CGPoint(x: 0, y: -frame.maxY - 20)
        case .bottomToTop: return CGPoint(x: 0, y: bounds.height - frame.minY + 20)
        case .leftToRight: return CGPoint(x: -frame.maxX - 20, y: 0)
        case .rightToLeft: return CGPoint(x: bounds.width - frame.minX + 20, y: 0)
        default: return .zero
        }
    }

    private func snapIn(from offset: CGPoint) {
        let proxy = TranslationProxy(view: wrapper)
        proxy.center = CGPoint(x: proxy.rest.x + offset.x, y: proxy.rest.y + offset.y)
        let animator = UIDynamicAnimator(referenceView: view)
        animator.delegate = self
        let snap = UISnapBehavior(item: proxy, snapTo: proxy.rest)
        snap.damping = 0.35
        let noSpin = UIDynamicItemBehavior(items: [proxy])
        noSpin.allowsRotation = false
        animator.addBehavior(snap)
        animator.addBehavior(noSpin)
        self.proxy = proxy
        dynamics = animator
    }

    func dynamicAnimatorDidPause(_ animator: UIDynamicAnimator) {
        guard animator === dynamics, alert.isVisible else { return }
        animator.removeAllBehaviors()
        dynamics = nil
        proxy = nil
        UIView.animate(withDuration: 0.1) { self.wrapper.transform = .identity }
        isSettled = true
    }

    // MARK: - Exit

    func animateOut() async {
        view.endEditing(true)
        view.isUserInteractionEnabled = false
        dynamics?.removeAllBehaviors()
        dynamics = nil

        if alert.animationStyle == .noAnimation && fling == nil { return }

        if let fling {
            await animate(duration: fling.duration, options: .curveEaseOut) {
                self.wrapper.transform = CGAffineTransform(translationX: fling.translation.x, y: fling.translation.y)
                    .rotated(by: fling.rotation)
                self.backdrop.alpha = 0
                self.blurView?.effect = nil
            }
            return
        }

        if appearance.dynamicAnimatorActive && !reduceMotion {
            // Picks up from wherever the card is, even mid-snap.
            let proxy = TranslationProxy(view: wrapper)
            let animator = UIDynamicAnimator(referenceView: view)
            let gravity = UIGravityBehavior(items: [proxy])
            gravity.magnitude = 4
            let spin = UIDynamicItemBehavior(items: [proxy])
            spin.addAngularVelocity(Bool.random() ? 0.9 : -0.9, for: proxy)
            animator.addBehavior(gravity)
            animator.addBehavior(spin)
            self.proxy = proxy
            dynamics = animator
            await animate(duration: 0.45, delay: 0.1) {
                self.backdrop.alpha = 0
                self.blurView?.effect = nil
                self.wrapper.alpha = 0
            }
            animator.removeAllBehaviors()
            dynamics = nil
            return
        }

        await animate(duration: 0.22) {
            self.backdrop.alpha = 0
            self.blurView?.effect = nil
            self.wrapper.alpha = 0
            if !self.reduceMotion {
                self.wrapper.transform = self.wrapper.transform.scaledBy(x: 0.9, y: 0.9)
            }
        }
    }
}

@MainActor
private func animate(
    duration: TimeInterval,
    delay: TimeInterval = 0,
    options: UIView.AnimationOptions = .curveEaseIn,
    _ animations: @escaping () -> Void
) async {
    await withCheckedContinuation { continuation in
        UIView.animate(withDuration: duration, delay: delay, options: options, animations: animations) { _ in
            continuation.resume()
        }
    }
}

/// Lets UIKit Dynamics drive a view that is positioned with Auto Layout, by turning the
/// simulated center and rotation into the view's transform instead of moving its frame.
private final class TranslationProxy: NSObject, UIDynamicItem {
    private weak var view: UIView?
    let rest: CGPoint
    let bounds: CGRect

    var center: CGPoint { didSet { apply() } }
    var transform: CGAffineTransform = .identity { didSet { apply() } }

    init(view: UIView) {
        self.view = view
        // `center` ignores the transform, so this is the resting position even mid-animation.
        rest = view.center
        bounds = view.bounds
        center = CGPoint(x: rest.x + view.transform.tx, y: rest.y + view.transform.ty)
        super.init()
    }

    private func apply() {
        view?.transform = transform.concatenating(CGAffineTransform(translationX: center.x - rest.x, y: center.y - rest.y))
    }
}
