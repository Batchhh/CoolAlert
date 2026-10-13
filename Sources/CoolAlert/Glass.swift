import UIKit

enum Glass {
    /// Liquid Glass on iOS 26+, a thick material blur on earlier systems.
    @MainActor
    static func makeView(cornerRadius: CGFloat) -> UIVisualEffectView {
        if #available(iOS 26.0, *) {
            let view = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            view.cornerConfiguration = .corners(radius: .fixed(cornerRadius))
            return view
        }
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }
}
