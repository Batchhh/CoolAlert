import UIKit

/// The colored circle at the top of the alert. Glyphs are drawn as strokes so they can animate in.
final class BadgeView: UIView {

    enum Content {
        case glyph(Glyph)
        case symbol(String)
        case image(UIImage)
        case spinner
    }

    enum Glyph {
        case checkmark, cross, exclamation, info, question

        func path(in rect: CGRect) -> UIBezierPath {
            let path = UIBezierPath()
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            // A zero-length segment with a round cap renders as a dot.
            func dot(_ x: CGFloat, _ y: CGFloat) {
                path.move(to: point(x, y))
                path.addLine(to: point(x, y + 0.001))
            }
            switch self {
            case .checkmark:
                path.move(to: point(0.14, 0.53))
                path.addLine(to: point(0.39, 0.77))
                path.addLine(to: point(0.86, 0.27))
            case .cross:
                path.move(to: point(0.22, 0.22))
                path.addLine(to: point(0.78, 0.78))
                path.move(to: point(0.78, 0.22))
                path.addLine(to: point(0.22, 0.78))
            case .exclamation:
                path.move(to: point(0.5, 0.12))
                path.addLine(to: point(0.5, 0.58))
                dot(0.5, 0.86)
            case .info:
                dot(0.5, 0.14)
                path.move(to: point(0.5, 0.40))
                path.addLine(to: point(0.5, 0.88))
            case .question:
                path.move(to: point(0.29, 0.32))
                path.addArc(withCenter: point(0.5, 0.32), radius: 0.21 * rect.width, startAngle: .pi, endAngle: .pi * 2.25, clockwise: true)
                path.addQuadCurve(to: point(0.5, 0.62), controlPoint: point(0.5, 0.52))
                dot(0.5, 0.88)
            }
            return path
        }
    }

    private let content: Content
    private let accent: UIColor
    private let appearance: CoolAlert.Appearance
    private let iconColor: UIColor

    private let disc = UIView()
    private let sheen = CAGradientLayer()
    private let glyphLayer = CAShapeLayer()
    private var imageView: UIImageView?
    private var spinner: UIActivityIndicatorView?
    private let progressTrack = CAShapeLayer()
    private let progressRing = CAShapeLayer()
    private var percentLabel: UILabel?

    init(content: Content, accent: UIColor, iconTint: UIColor?, appearance: CoolAlert.Appearance) {
        self.content = content
        self.accent = accent
        self.appearance = appearance
        iconColor = iconTint ?? accent.contrastingTextColor
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false

        let outer = appearance.circleSize + appearance.circleRingWidth * 2
        if let ringColor = appearance.circleBackgroundColor {
            backgroundColor = ringColor
        } else if appearance.cardStyle == .glass {
            let ring = Glass.makeView(cornerRadius: outer / 2)
            ring.isUserInteractionEnabled = false
            ring.translatesAutoresizingMaskIntoConstraints = false
            addSubview(ring)
            NSLayoutConstraint.activate([
                ring.topAnchor.constraint(equalTo: topAnchor),
                ring.leadingAnchor.constraint(equalTo: leadingAnchor),
                ring.trailingAnchor.constraint(equalTo: trailingAnchor),
                ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        } else {
            backgroundColor = appearance.resolvedContentColor
        }
        layer.cornerRadius = outer / 2
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: outer),
            heightAnchor.constraint(equalToConstant: outer),
        ])

        disc.backgroundColor = accent
        disc.layer.cornerRadius = appearance.circleSize / 2
        disc.layer.shadowOffset = CGSize(width: 0, height: 4)
        disc.layer.shadowRadius = 10
        disc.layer.shadowOpacity = 0.35
        disc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(disc)
        NSLayoutConstraint.activate([
            disc.centerXAnchor.constraint(equalTo: centerXAnchor),
            disc.centerYAnchor.constraint(equalTo: centerYAnchor),
            disc.widthAnchor.constraint(equalToConstant: appearance.circleSize),
            disc.heightAnchor.constraint(equalToConstant: appearance.circleSize),
        ])

        // A soft highlight across the top half gives the flat disc some depth.
        sheen.colors = [UIColor.white.withAlphaComponent(0.28).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        sheen.startPoint = CGPoint(x: 0.5, y: 0)
        sheen.endPoint = CGPoint(x: 0.5, y: 0.75)
        sheen.cornerRadius = appearance.circleSize / 2
        disc.layer.addSublayer(sheen)

        // The progress ring runs along the ring around the disc.
        for ring in [progressTrack, progressRing] {
            ring.fillColor = nil
            ring.lineWidth = max(2, appearance.circleRingWidth * 0.7)
            ring.lineCap = .round
            ring.isHidden = true
            layer.addSublayer(ring)
        }
        progressRing.strokeEnd = 0

        installIcon()
        refreshColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (badge: BadgeView, _: UITraitCollection) in
            badge.refreshColors()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func installIcon() {
        let size = appearance.circleIconSize
        switch content {
        case .glyph:
            glyphLayer.fillColor = nil
            glyphLayer.lineWidth = max(2.5, size * 0.13)
            glyphLayer.lineCap = .round
            glyphLayer.lineJoin = .round
            disc.layer.addSublayer(glyphLayer)
        case .symbol(let name):
            let configuration = UIImage.SymbolConfiguration(pointSize: size * 0.9, weight: .bold)
            addImageView(UIImage(systemName: name, withConfiguration: configuration), template: true)
        case .image(let image):
            addImageView(image, template: image.isSymbolImage || image.renderingMode == .alwaysTemplate)
        case .spinner:
            let spinner = UIActivityIndicatorView(style: appearance.activityIndicatorStyle)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            disc.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
            ])
            self.spinner = spinner
        }
    }

    private func addImageView(_ image: UIImage?, template: Bool) {
        let imageView = UIImageView(image: template ? image?.withRenderingMode(.alwaysTemplate) : image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        disc.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: appearance.circleIconSize),
            imageView.heightAnchor.constraint(equalToConstant: appearance.circleIconSize),
        ])
        self.imageView = imageView
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sheen.frame = disc.bounds
        glyphLayer.frame = disc.bounds
        let ringPath = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: (appearance.circleSize + appearance.circleRingWidth) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        ).cgPath
        progressTrack.path = ringPath
        progressRing.path = ringPath
        if case .glyph(let glyph) = content {
            let size = appearance.circleIconSize
            let rect = CGRect(x: (disc.bounds.width - size) / 2, y: (disc.bounds.height - size) / 2, width: size, height: size)
            glyphLayer.path = glyph.path(in: rect).cgPath
        }
    }

    private func refreshColors() {
        let traits = traitCollection
        glyphLayer.strokeColor = iconColor.resolvedColor(with: traits).cgColor
        disc.layer.shadowColor = accent.resolvedColor(with: traits).cgColor
        imageView?.tintColor = iconColor
        spinner?.color = iconColor
        percentLabel?.textColor = iconColor
        progressRing.strokeColor = accent.resolvedColor(with: traits).cgColor
        progressTrack.strokeColor = accent.resolvedColor(with: traits).withAlphaComponent(0.18).cgColor
    }

    // MARK: - Progress

    func setProgress(_ value: Double?, animated: Bool) {
        let visible = value != nil
        progressTrack.isHidden = !visible
        progressRing.isHidden = !visible
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.35)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        progressRing.strokeEnd = value ?? 0
        CATransaction.commit()

        // Spinner alerts trade the spinner for a percentage once progress is known.
        guard spinner != nil else { return }
        if let value {
            let label = percentLabel ?? makePercentLabel()
            label.text = "\(Int((value * 100).rounded()))%"
            label.accessibilityValue = label.text
            spinner?.isHidden = true
        } else {
            percentLabel?.removeFromSuperview()
            percentLabel = nil
            spinner?.isHidden = false
        }
    }

    private func makePercentLabel() -> UILabel {
        let label = UILabel()
        let size = appearance.circleSize * 0.27
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        let rounded = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        label.font = UIFont(
            descriptor: rounded.fontDescriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
                ]]
            ]),
            size: size
        )
        label.textColor = iconColor
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        disc.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: disc.widthAnchor, constant: -8),
        ])
        percentLabel = label
        return label
    }

    // MARK: - Animation

    /// Puts the icon in its pre-animation state. Call before the alert becomes visible.
    func prepareForEntrance() {
        guard appearance.animatedIcons else {
            spinner?.startAnimating()
            return
        }
        disc.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        glyphLayer.strokeEnd = 0
        imageView?.alpha = 0
        imageView?.transform = CGAffineTransform(scaleX: 0.3, y: 0.3).rotated(by: -.pi / 6)
    }

    func playEntrance() {
        spinner?.startAnimating()
        guard appearance.animatedIcons else { return }

        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
            self.disc.transform = .identity
        }

        if case .glyph = content {
            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.duration = 0.45
            draw.beginTime = CACurrentMediaTime() + 0.08
            draw.fillMode = .backwards
            draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
            glyphLayer.strokeEnd = 1
            glyphLayer.add(draw, forKey: "draw")
        }

        if let imageView {
            UIView.animate(withDuration: 0.55, delay: 0.08, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.6) {
                imageView.alpha = 1
                imageView.transform = .identity
            }
        }
    }
}
