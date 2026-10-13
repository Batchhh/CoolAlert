import UIKit

/// Shared styling for the alert's text inputs: a soft fill that gains an accent border while focused.
@MainActor
protocol AlertInput: UIView {
    var accentColor: UIColor { get set }
    func apply(_ appearance: CoolAlert.Appearance, accent: UIColor)
}

extension AlertInput {
    func applyInputStyle(_ appearance: CoolAlert.Appearance, accent: UIColor) {
        accentColor = accent
        tintColor = accent
        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = appearance.fieldCornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        updateBorder(focused: false, animated: false)
    }

    func updateBorder(focused: Bool, animated: Bool) {
        let color = focused ? accentColor.resolvedColor(with: traitCollection).cgColor : UIColor.clear.cgColor
        if animated {
            let animation = CABasicAnimation(keyPath: "borderColor")
            animation.fromValue = layer.borderColor
            animation.duration = 0.2
            layer.add(animation, forKey: "borderColor")
        }
        layer.borderColor = color
    }
}

final class AlertTextField: UITextField, AlertInput {
    var accentColor: UIColor = .tintColor

    /// Shown at the leading edge. Symbols and template images take the field's tint.
    var icon: UIImage? {
        didSet { updateIcon() }
    }

    private let padding: CGFloat = 14
    private let iconSpacing: CGFloat = 10
    private var iconSide: CGFloat = 20
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clearButtonMode = .whileEditing
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .secondaryLabel
        iconView.isAccessibilityElement = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (field: AlertTextField, _: UITraitCollection) in
            field.updateBorder(focused: field.isFirstResponder, animated: false)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(_ appearance: CoolAlert.Appearance, accent: UIColor) {
        applyInputStyle(appearance, accent: accent)
        font = appearance.fieldFont
        adjustsFontForContentSizeCategory = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: appearance.textFieldHeight).isActive = true
        // Size the icon to the text so it scales with Dynamic Type.
        iconSide = (appearance.fieldFont.pointSize * 1.3).rounded()
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: appearance.fieldFont, scale: .medium)
    }

    private func updateIcon() {
        iconView.image = icon
        leftView = icon == nil ? nil : iconView
        leftViewMode = .always
        setNeedsLayout()
    }

    override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX + padding, y: bounds.midY - iconSide / 2, width: iconSide, height: iconSide)
    }

    // The placeholder is laid out with `textRect(forBounds:)`, so these two overrides cover all three.
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        inset(super.textRect(forBounds: bounds), in: bounds)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        var rect = inset(super.editingRect(forBounds: bounds), in: bounds)
        // UIKit reserved room for the clear button at its default spot; ours sits a little further in.
        let clear = clearButtonRect(forBounds: bounds)
        if rect.maxX > clear.minX - 6, rect.maxX < bounds.maxX - padding {
            rect.size.width = max(0, clear.minX - 6 - rect.minX)
        }
        return rect
    }

    /// Keeps UIKit's rect (which already leaves room for the clear button) but enforces our padding,
    /// starting the text after the icon when there is one.
    private func inset(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        let leading = bounds.minX + padding + (leftView == nil ? 0 : iconSide + iconSpacing)
        let minX = max(rect.minX, leading)
        let maxX = min(rect.maxX, bounds.maxX - padding)
        return CGRect(x: minX, y: rect.minY, width: max(0, maxX - minX), height: rect.height)
    }

    private func tintIcon(focused: Bool) {
        guard icon != nil else { return }
        UIView.transition(with: iconView, duration: 0.2, options: .transitionCrossDissolve) {
            self.iconView.tintColor = focused ? self.accentColor : .secondaryLabel
        }
    }

    override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        super.clearButtonRect(forBounds: bounds).offsetBy(dx: -6, dy: 0)
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            updateBorder(focused: true, animated: true)
            tintIcon(focused: true)
        }
        return became
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            updateBorder(focused: false, animated: true)
            tintIcon(focused: false)
        }
        return resigned
    }
}

final class AlertTextView: UITextView, AlertInput {
    var accentColor: UIColor = .tintColor

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: AlertTextView, _: UITraitCollection) in
            view.updateBorder(focused: view.isFirstResponder, animated: false)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(_ appearance: CoolAlert.Appearance, accent: UIColor) {
        applyInputStyle(appearance, accent: accent)
        font = appearance.fieldFont
        adjustsFontForContentSizeCategory = true
        heightAnchor.constraint(equalToConstant: appearance.textViewHeight).isActive = true
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { updateBorder(focused: true, animated: true) }
        return became
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { updateBorder(focused: false, animated: true) }
        return resigned
    }
}
