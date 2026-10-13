import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    convenience init(light: UInt32, dark: UInt32) {
        self.init { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    /// WCAG relative luminance of the color, resolved for `traits`.
    func luminance(for traits: UITraitCollection = .current) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
        func linear(_ c: CGFloat) -> CGFloat {
            let c = min(max(c, 0), 1)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// White or near-black, whichever reads better on top of this color. Re-evaluated per trait.
    var contrastingTextColor: UIColor {
        UIColor { traits in
            self.luminance(for: traits) > 0.5 ? UIColor(hex: 0x1C1C1E) : .white
        }
    }
}
