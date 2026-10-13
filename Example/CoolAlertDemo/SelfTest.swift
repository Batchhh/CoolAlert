import CoolAlert
import UIKit

/// Drives real alerts end to end. Launch with `-selftest YES`; the app prints PASS/FAIL lines and exits.
@MainActor
enum SelfTest {
    private static var failures = 0

    static func run() async {
        await buttonResult()
        await closeButtonAndDismissHandler()
        await timeoutAndCountdown()
        await stayOpenWhenAutoDismissIsOff()
        await liveUpdatesAndWaitStyle()
        await targetSelector()
        await textFieldValues()
        await cancellationClosesAlert()
        await dismissAllStacked()
        await dynamicAnimatorRoundTrip()
        await asyncActionSucceeds()
        await asyncActionFailsInline()
        await validationGatesButtons()
        await returnKeySubmits()
        await progressRing()
        await queueShowsOneAtATime()
        await glassCard()
        await tallContentFitsOnScreen()
        await alertIsReleasedAfterClose()
        await textInsetsMatch()
        await leadingIconLayout()
        print("SELFTEST DONE failures=\(failures)")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Cases

    private static func buttonResult() async {
        let alert = CoolAlert(.question, "Pick").button("Yes").button("No").closeButton("Cancel")
        let task = Task { await alert.present() }
        await settle()
        check(CoolAlert.isShowing && alert.isVisible, "alert is visible after present()")
        check(buttonTitles() == ["Yes", "No", "Cancel"], "buttons in order, close last")
        tap("No")
        let result = await task.value
        check(result == .button(index: 1, title: "No"), "present() returns tapped button")
        check(!CoolAlert.isShowing, "alert gone after tap")
    }

    private static func closeButtonAndDismissHandler() async {
        var dismissed = 0
        let alert = CoolAlert.success("Saved").onDismiss { dismissed += 1 }
        await settle()
        tap("Done")
        await settle()
        check(dismissed == 1 && alert.result == .dismissed, "close button dismisses and runs onDismiss once")
    }

    private static func timeoutAndCountdown() async {
        var action = false, handler = false
        let alert = CoolAlert(.notice, "Ad")
            .button("Skip", countdown: .seconds)
            .hideCloseButton()
            .timeout(1.5) { action = true }
            .onTimeout { handler = true }
        let task = Task { await alert.present() }
        await settle(0.2)
        check(buttonTitles() == ["Skip (2s)"], "countdown shows rounded-up seconds (got \(buttonTitles()))")
        await settle(0.6)
        check(buttonTitles() == ["Skip (1s)"], "countdown ticks (got \(buttonTitles()))")
        let result = await task.value
        check(result == .timeout && action && handler, "timeout closes with .timeout and runs both actions")
    }

    private static func stayOpenWhenAutoDismissIsOff() async {
        var taps = 0
        let alert = CoolAlert(.info, "Counter")
            .button("Tap") { taps += 1 }
            .appearance { $0.shouldAutoDismiss = false }
            .show()
        await settle()
        tap("Tap")
        tap("Tap")
        await settle(0.3)
        check(taps == 2 && alert.isVisible, "shouldAutoDismiss = false keeps alert open")
        alert.close()
        await settle()
        check(!CoolAlert.isShowing && alert.result == .dismissed, "close() dismisses")
    }

    private static func liveUpdatesAndWaitStyle() async {
        let alert = CoolAlert.wait("Loading")
        await settle()
        check(buttonTitles().isEmpty, "wait style has no close button")
        alert.title = "Updated title"
        alert.message = "Updated message"
        await settle(0.3)
        check(labelTexts().contains("Updated title") && labelTexts().contains("Updated message"), "title and message update live")
        alert.close()
        await settle()
    }

    private static func targetSelector() async {
        let target = Target()
        CoolAlert(.info, "Selector").button("Go", target: target, selector: #selector(Target.fire)).show()
        await settle()
        tap("Go")
        await settle()
        check(target.fired, "target/selector button fires")
    }

    private static func textFieldValues() async {
        let alert = CoolAlert(.edit, "Login")
        let name = alert.addTextField("Name")
        var captured: String?
        alert.button("OK") { captured = name.text }.show()
        await settle()
        name.text = "Ada"
        tap("OK")
        await settle()
        check(captured == "Ada", "button action reads text field")
    }

    private static func cancellationClosesAlert() async {
        let task = Task { await CoolAlert(.info, "Cancel me").present() }
        await settle()
        task.cancel()
        let result = await task.value
        await settle(0.1)
        check(result == .dismissed && !CoolAlert.isShowing, "cancelling present() closes the alert")
    }

    private static func dismissAllStacked() async {
        CoolAlert.info("First")
        CoolAlert.error("Second")
        await settle()
        check(CoolAlert.visibleAlerts.count == 2, "two alerts can stack")
        CoolAlert.dismissAll()
        await settle()
        check(!CoolAlert.isShowing, "dismissAll closes everything")
    }

    private static func dynamicAnimatorRoundTrip() async {
        let alert = CoolAlert(.success, "Dynamics").appearance { $0.dynamicAnimatorActive = true }.show()
        await settle(1.2)
        let card = alertWindows().first?.rootViewController?.view.subviews.dropFirst().first
        check(card?.transform == .identity, "snap behavior settles at rest")
        alert.close()
        await settle(0.9)
        check(!CoolAlert.isShowing, "gravity dismissal completes")
    }

    private static func asyncActionSucceeds() async {
        var finished = false
        let alert = CoolAlert(.info, "Save")
            .button("Save") {
                try await Task.sleep(for: .seconds(0.6))
                finished = true
            }
            .timeout(30)
        let task = Task { await alert.present() }
        await settle()
        tap("Save")
        await settle(0.2)
        let saveButton = button("Save")
        check(alert.isBusy && saveButton?.configuration?.showsActivityIndicator == true, "async action shows a spinner")
        check(button("Done")?.isEnabled == false, "other buttons are disabled while busy")
        check(saveButton?.isEnabled == true, "the spinning button keeps its color")
        check(alert.remainingTime == nil, "timeout stops once an async action starts")
        tap("Done")
        check(alert.isVisible, "busy alert ignores taps")
        let result = await task.value
        check(finished && result == .button(index: 0, title: "Save"), "async action completes, then dismisses")
    }

    private static func asyncActionFailsInline() async {
        struct Failure: LocalizedError { var errorDescription: String? { "Nope, try again" } }
        let alert = CoolAlert(.edit, "Retry")
        let field = alert.addTextField("Code")
        alert.button("Submit") { throw Failure() }.show()
        await settle()
        tap("Submit")
        await settle(0.4)
        check(alert.isVisible && !alert.isBusy, "failed async action keeps the alert open")
        check(visibleLabelTexts().contains("Nope, try again"), "error is shown inline")
        field.text = "1"
        field.sendActions(for: .editingChanged)
        await settle(0.4)
        check(!visibleLabelTexts().contains("Nope, try again"), "editing a field clears the error")
        alert.showError("Manual error")
        await settle(0.3)
        check(visibleLabelTexts().contains("Manual error"), "showError(_:) shows a message")
        alert.close()
        await settle()
    }

    private static func validationGatesButtons() async {
        let alert = CoolAlert(.edit, "Name")
        let field = alert.addTextField("Name")
        alert.validate { !(field.text ?? "").isEmpty }.button("OK").closeButton("Cancel").show()
        await settle()
        check(button("OK")?.isEnabled == false, "invalid input disables the action button")
        check(button("Cancel")?.isEnabled == true, "cancel stays enabled")
        field.text = "Ada"
        field.sendActions(for: .editingChanged)
        check(button("OK")?.isEnabled == true, "valid input enables it")
        alert.close()
        await settle()
    }

    private static func returnKeySubmits() async {
        let alert = CoolAlert(.edit, "Rename")
        let field = alert.addTextField("Name")
        let task = Task { await alert.button("Rename").closeButton("Cancel").present() }
        await settle()
        _ = field.delegate?.textFieldShouldReturn?(field)
        let result = await task.value
        check(result == .button(index: 0, title: "Rename"), "return on the last field submits the first action")
    }

    private static func progressRing() async {
        let alert = CoolAlert.wait("Downloading").progress(0.25)
        await settle()
        check(labelTexts().contains("25%"), "wait alert shows a percentage")
        alert.progress = 0.5
        check(labelTexts().contains("50%"), "progress updates live")
        alert.progress = 7
        check(alert.progress == 1, "progress is clamped to 0...1")
        alert.close()
        await settle()
    }

    private static func queueShowsOneAtATime() async {
        CoolAlert.queuesAlerts = true
        defer { CoolAlert.queuesAlerts = false }
        let first = CoolAlert.info("Q1")
        let second = CoolAlert.info("Q2")
        let third = CoolAlert.info("Q3")
        await settle()
        check(CoolAlert.visibleAlerts.count == 1 && first.isVisible && !second.isVisible, "queue shows one alert at a time")
        first.close()
        await settle()
        check(second.isVisible && CoolAlert.visibleAlerts.count == 1, "next queued alert appears after close")
        CoolAlert.dismissAll()
        await settle()
        check(!CoolAlert.isShowing && third.result == .dismissed, "dismissAll drains the queue")
    }

    private static func glassCard() async {
        let alert = CoolAlert(.info, "Glass").appearance { $0.cardStyle = .glass }.show()
        await settle()
        let hasGlass = topAlertViews.contains { $0 is UIVisualEffectView }
        check(alert.isVisible && hasGlass, "glass card renders an effect view")
        alert.close()
        await settle()
    }

    private static func tallContentFitsOnScreen() async {
        let alert = CoolAlert(.edit, "Form")
        for index in 0..<14 { alert.textField("Field \(index)") }
        alert.button("Save").show()
        await settle()
        let window = alertWindows().last
        let save = button("Save")
        let frame = save.flatMap { button in window.map { button.convert(button.bounds, to: $0) } } ?? .null
        let visible = window.map { $0.bounds.inset(by: $0.safeAreaInsets) } ?? .zero
        check(visible.contains(frame), "buttons stay on screen when the body overflows")
        alert.close()
        await settle()
    }

    private static func alertIsReleasedAfterClose() async {
        weak var released: CoolAlert?
        do {
            let alert = CoolAlert(.info, "Leak check")
            alert.button("Self") { alert.message = "captures itself" }.customView { StarRating() }.textField("Field")
            released = alert
            alert.show()
        }
        await settle()
        released?.close()
        await settle(0.8)
        check(released == nil, "alert is deallocated after closing")
    }

    private static func textInsetsMatch() async {
        let alert = CoolAlert(.edit, "Insets")
        let field = alert.addTextField("Placeholder")
        alert.show()
        await settle()
        let bounds = field.bounds
        let placeholder = field.placeholderRect(forBounds: bounds).minX
        let text = field.textRect(forBounds: bounds).minX
        let editing = field.editingRect(forBounds: bounds).minX
        print("INSETS placeholder=\(placeholder) text=\(text) editing=\(editing)")
        check(placeholder == 14 && text == 14 && editing == 14, "placeholder, text and editing share the same 14pt inset")
        alert.close()
        await settle()
    }

    private static func leadingIconLayout() async {
        let alert = CoolAlert(.edit, "Icons")
        let email = alert.addTextField("Email", systemImage: "envelope")
        let plain = alert.addTextField("Plain")
        alert.show()
        await settle()
        let bounds = email.bounds
        let icon = email.leftViewRect(forBounds: bounds)
        let text = email.textRect(forBounds: bounds)
        let placeholder = email.placeholderRect(forBounds: bounds)
        print("ICON icon=\(icon) text=\(text.minX) placeholder=\(placeholder.minX) plain=\(plain.textRect(forBounds: plain.bounds).minX)")
        check(email.leftView != nil && icon.minX == 14, "icon sits at the 14pt leading inset")
        check(abs(icon.midY - bounds.midY) < 0.5, "icon is vertically centered")
        check(text.minX == icon.maxX + 10 && placeholder.minX == text.minX, "text and placeholder start 10pt after the icon")
        check(plain.leftView == nil && plain.textRect(forBounds: plain.bounds).minX == 14, "fields without an icon keep the 14pt inset")

        email.becomeFirstResponder()
        email.text = "a@b.c"
        await settle(0.4)
        let editing = email.editingRect(forBounds: bounds)
        let clear = email.clearButtonRect(forBounds: bounds)
        print("ICON editing=\(editing) clear=\(clear)")
        check(editing.minX == text.minX && editing.maxX <= clear.minX, "editing text sits between the icon and the clear button")
        alert.close()
        await settle()
    }

    // MARK: - Helpers

    private static func button(_ title: String) -> UIButton? {
        topAlertViews.compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == title }
    }

    private static func visibleLabelTexts() -> [String] {
        topAlertViews.compactMap { $0 as? UILabel }.filter { label in
            var view: UIView? = label
            while let current = view {
                if current.isHidden { return false }
                view = current.superview
            }
            return true
        }.compactMap(\.text)
    }

    private final class Target: NSObject {
        var fired = false
        @objc func fire() { fired = true }
    }

    private static func check(_ condition: Bool, _ name: String) {
        print(condition ? "PASS \(name)" : "FAIL \(name)")
        if !condition { failures += 1 }
    }

    private static func settle(_ seconds: Double = 0.7) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func alertWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden && $0.rootViewController.map { "\(type(of: $0))" } == "AlertViewController" }
    }

    private static func views(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(views)
    }

    private static var topAlertViews: [UIView] {
        alertWindows().last.map(views) ?? []
    }

    private static func buttonTitles() -> [String] {
        topAlertViews.compactMap { $0 as? UIButton }.compactMap { button in
            button.configuration?.attributedTitle.map { String($0.characters) }
        }
    }

    private static func labelTexts() -> [String] {
        topAlertViews.compactMap { ($0 as? UILabel)?.text }
    }

    static func tap(_ title: String) {
        let button = topAlertViews.compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == title }
        check(button != nil, "found button “\(title)”")
        button?.sendActions(for: .primaryActionTriggered)
    }
}
