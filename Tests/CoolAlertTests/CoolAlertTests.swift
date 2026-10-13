import Testing
import UIKit
@testable import CoolAlert

@MainActor
struct CoolAlertTests {

    @Test func countdownFormatsTitle() {
        #expect(CoolAlert.Countdown.seconds.title("Skip", remaining: 3) == "Skip (3s)")
        #expect(CoolAlert.Countdown.parentheses.title("OK", remaining: 10) == "OK (10)")
        #expect(CoolAlert.Countdown(prefix: "– ").title("Wait", remaining: 1) == "Wait – 1")
    }

    @Test func hexColor() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hex: 0xA429FF).getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int((r * 255).rounded()) == 0xA4)
        #expect(Int((g * 255).rounded()) == 0x29)
        #expect(Int((b * 255).rounded()) == 0xFF)
        #expect(a == 1)
    }

    @Test func contrastingTextPicksReadableColor() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        #expect(UIColor.white.contrastingTextColor.resolvedColor(with: light) != .white)
        #expect(UIColor.black.contrastingTextColor.resolvedColor(with: light) == .white)
        // Warning yellow gets dark text, the other accents get white.
        #expect(CoolAlert.Style.warning.color.luminance(for: light) > 0.5)
        for style in [CoolAlert.Style.success, .error, .info, .edit, .wait, .question, .notice] {
            #expect(style.color.luminance(for: light) <= 0.5, "\(style)")
        }
    }

    @Test func builderCollectsConfiguration() {
        let alert = CoolAlert(.edit, "Title", "Message")
            .button("One")
            .button("Two", role: .destructive)
            .timeout(4)
            .animation(.bottomToTop)
            .color(hex: 0x112233)
            .appearance { $0.buttonsLayout = .horizontal }
            .textField("Name")
            .textView(text: "Notes")
        let field = alert.addTextField("Email")

        #expect(alert.style == .edit)
        #expect(alert.timeout?.seconds == 4)
        #expect(alert.animationStyle == .bottomToTop)
        #expect(alert.appearance.buttonsLayout == .horizontal)
        #expect(alert.textFields.count == 2)
        #expect(alert.textFields.last === field)
        #expect(alert.textViews.first?.text == "Notes")
        #expect(alert.inputs.count == 3)
        #expect(!alert.isVisible)
    }

    @Test func appearanceConfigureClosure() {
        let appearance = CoolAlert.Appearance {
            $0.showCloseButton = false
            $0.windowWidth = 320
        }
        #expect(!appearance.showCloseButton)
        #expect(appearance.windowWidth == 320)
        #expect(CoolAlert.Appearance().showCloseButton)
    }

    @Test func asyncButtonsValidationAndProgress() {
        var ran = false
        let alert = CoolAlert(.edit, "Async")
            .button("Sync") { ran = true }
            .button("Async") { try await Task.sleep(for: .milliseconds(1)) }
            .validate { true }
            .progress(1.5)
        #expect(alert.progress == 1)
        alert.progress = -1
        #expect(alert.progress == 0)
        alert.progress = nil
        #expect(alert.progress == nil)
        #expect(alert.validator?() == true)
        #expect(!alert.isBusy)
        #expect(!ran)
    }

    @Test func closingAQueuedOrIdleAlertIsSafe() {
        let alert = CoolAlert(.info, "Never shown")
        alert.close()
        #expect(alert.result == nil)
        #expect(!CoolAlert.isShowing)
    }

    @Test func textFieldIcons() {
        let alert = CoolAlert(.edit, "Icons")
            .textField("Email", systemImage: "envelope")
            .textField("Custom", icon: UIImage(systemName: "star"))
            .textField("Plain")
        let added = alert.addTextField("Lock", systemImage: "lock")
        #expect(alert.textFields.map { $0.leftView != nil } == [true, true, false, true])
        #expect(added.leftViewMode == .always)
    }

    @Test func customStyleUsesGivenColor() {
        let style = CoolAlert.Style.custom(color: .systemPink)
        #expect(style.color == .systemPink)
        #expect(style != .info)
    }
}
