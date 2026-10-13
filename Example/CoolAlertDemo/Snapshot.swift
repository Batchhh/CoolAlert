import UIKit

/// `-demo <id> -snapshot <file.png>` saves the visible alert, without the screen behind it, as a
/// transparent PNG in the app's Documents folder. This is how the README image is made.
@MainActor
enum Snapshot {
    static func capture(named name: String) {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard
            let window = windows.last(where: { window in
                !window.isHidden && window.rootViewController.map { "\(type(of: $0))" } == "AlertViewController"
            }),
            let alert = allViews(in: window).first(where: \.accessibilityViewIsModal)
        else {
            print("SNAPSHOT no alert on screen")
            return
        }

        // Room for the card's shadow on every side.
        let margin: CGFloat = 50
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let size = CGSize(width: alert.bounds.width + margin * 2, height: alert.bounds.height + margin * 2)
        let png = UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            context.cgContext.translateBy(x: margin, y: margin)
            alert.layer.render(in: context.cgContext)
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        do {
            try png.write(to: url)
            print("SNAPSHOT \(url.path)")
        } catch {
            print("SNAPSHOT failed: \(error)")
        }
    }

    private static func allViews(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(allViews)
    }
}
