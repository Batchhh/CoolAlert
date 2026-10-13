import UIKit

/// A beautiful, animated alert with a fluent API.
///
/// ```swift
/// CoolAlert.success("Saved", "Your changes are safe.")
///
/// CoolAlert(.warning, "Delete photo?", "This can't be undone.")
///     .button("Delete", role: .destructive) { deletePhoto() }
///     .closeButton("Keep it")
///     .show()
/// ```
///
/// The alert keeps itself alive while on screen, so there is no need to store it. Keep a reference only
/// to update it later: changing `title` or `message` updates the visible alert, and `close()` dismisses it.
@MainActor
public final class CoolAlert {
    public typealias Action = @MainActor () -> Void
    public typealias AsyncAction = @MainActor () async throws -> Void

    // MARK: - Global

    /// Appearance for alerts created without one.
    public static var defaultAppearance = Appearance()

    /// `true` while any alert is on screen.
    public static var isShowing: Bool { !onScreen.isEmpty }

    /// Alerts on screen, oldest first.
    public static var visibleAlerts: [CoolAlert] { onScreen }

    /// When `true`, `show()` waits for the alert on screen to close instead of stacking on top of it.
    public static var queuesAlerts = false

    /// Closes every alert on screen and drops any waiting in the queue.
    public static func dismissAll() {
        queue.forEach { $0.close() }
        onScreen.forEach { $0.close() }
    }

    private static var onScreen: [CoolAlert] = []
    private static var queue: [CoolAlert] = []

    // MARK: - Content

    public let style: Style

    /// The title. Updates the alert live when it is on screen.
    public var title: String {
        didSet { controller?.updateText() }
    }

    /// The text under the title. Updates the alert live when it is on screen.
    public var message: String? {
        didSet { controller?.updateText() }
    }

    public var appearance: Appearance
    public var animationStyle: AnimationStyle = .topToBottom

    /// Overrides the style's accent color.
    public var color: UIColor?
    /// Overrides the text color of the default button(s).
    public var buttonTextColor: UIColor?
    /// Replaces the style's icon.
    public var iconImage: UIImage?
    /// Tints the icon. Defaults to white or black depending on the accent color.
    public var iconTintColor: UIColor?
    /// Shown below the message (or on its own when there is no message).
    public var customView: UIView?
    public var timeout: Timeout?

    /// Text fields added with `addTextField(_:)`, in order.
    public var textFields: [UITextField] { inputs.compactMap { $0 as? UITextField } }
    /// Text views added with `addTextView(_:)`, in order.
    public var textViews: [UITextView] { inputs.compactMap { $0 as? UITextView } }

    /// `true` from `show()` until the dismiss animation starts.
    public var isVisible: Bool { state == .presented }

    /// Seconds left before the timeout closes the alert, while one is running.
    public private(set) var remainingTime: TimeInterval?

    /// How the alert ended, once it has.
    public private(set) var result: Result?

    /// Fills a ring around the icon, from 0 to 1. `.wait` alerts also swap the spinner for a percentage.
    /// `nil` hides the ring. Updates the visible alert.
    public var progress: Double? {
        didSet {
            if let progress, !(0...1).contains(progress) { self.progress = min(max(progress, 0), 1) }
            controller?.updateProgress(animated: true)
        }
    }

    /// `true` while an async button action is running.
    public private(set) var isBusy = false

    var tintColor: UIColor { color ?? style.color }
    private(set) var inputs: [UIView] = []
    private(set) var hostingController: UIViewController?

    private(set) var validator: (@MainActor () -> Bool)?
    private var buttons: [ButtonItem] = []
    private var closeTitle = "Done"
    private var closeButtonOverride: Bool?
    private var dismissHandlers: [Action] = []
    private var timeoutHandlers: [Action] = []
    private var continuations: [CheckedContinuation<Result, Never>] = []

    private enum State { case idle, queued, presented, closing, closed }
    private var state = State.idle
    private var window: UIWindow?
    private weak var queuedScene: UIWindowScene?
    private weak var previousKeyWindow: UIWindow?
    private var controller: AlertViewController?
    private var timeoutTask: Task<Void, Never>?

    // MARK: - Init

    public init(_ style: Style = .info, _ title: String = "", _ message: String? = nil, appearance: Appearance? = nil) {
        self.style = style
        self.title = title
        self.message = message
        self.appearance = appearance ?? Self.defaultAppearance
    }

    // MARK: - One-liners

    /// Builds and shows an alert in one call.
    @discardableResult
    public static func show(
        _ style: Style,
        _ title: String,
        _ message: String? = nil,
        closeButton: String? = nil,
        timeout: TimeInterval? = nil,
        animation: AnimationStyle? = nil
    ) -> CoolAlert {
        let alert = CoolAlert(style, title, message)
        if let closeButton { alert.closeButton(closeButton) }
        if let timeout { alert.timeout(timeout) }
        if let animation { alert.animationStyle = animation }
        return alert.show()
    }

    @discardableResult
    public static func success(_ title: String, _ message: String? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.success, title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    @discardableResult
    public static func error(_ title: String, _ message: String? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.error, title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    @discardableResult
    public static func notice(_ title: String, _ message: String? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.notice, title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    @discardableResult
    public static func warning(_ title: String, _ message: String? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.warning, title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    @discardableResult
    public static func info(_ title: String, _ message: String? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.info, title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    @discardableResult
    public static func edit(_ title: String, _ message: String? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.edit, title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    @discardableResult
    public static func question(_ title: String, _ message: String? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.question, title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    /// A spinner alert with no close button. Keep the returned alert and call `close()` when done.
    @discardableResult
    public static func wait(_ title: String, _ message: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.wait, title, message, timeout: timeout, animation: animation)
    }

    @discardableResult
    public static func custom(_ title: String, _ message: String? = nil, color: UIColor, icon: UIImage? = nil, closeButton: String? = nil, timeout: TimeInterval? = nil, animation: AnimationStyle? = nil) -> CoolAlert {
        show(.custom(color: color, icon: icon), title, message, closeButton: closeButton, timeout: timeout, animation: animation)
    }

    // MARK: - Builder

    /// Adds a button. Buttons appear in the order they are added, before the close button.
    @discardableResult
    public func button(
        _ title: String,
        role: ButtonRole = .default,
        backgroundColor: UIColor? = nil,
        textColor: UIColor? = nil,
        countdown: Countdown? = nil,
        action: Action? = nil
    ) -> Self {
        buttons.append(ButtonItem(title: title, role: role, backgroundColor: backgroundColor, textColor: textColor, countdown: countdown, action: action))
        return self
    }

    /// Adds a button whose action is async. While it runs, the button shows a spinner and the alert
    /// can't be dismissed by the user. If it throws, the alert stays open and shows the error inline.
    ///
    /// ```swift
    /// .button("Sign in") { try await api.signIn(email.text, password.text) }
    /// ```
    @discardableResult
    public func button(
        _ title: String,
        role: ButtonRole = .default,
        backgroundColor: UIColor? = nil,
        textColor: UIColor? = nil,
        countdown: Countdown? = nil,
        action: @escaping AsyncAction
    ) -> Self {
        buttons.append(ButtonItem(title: title, role: role, backgroundColor: backgroundColor, textColor: textColor, countdown: countdown, asyncAction: action))
        return self
    }

    /// Adds a button that sends `selector` to `target` when tapped. The alert releases `target` when it closes.
    @discardableResult
    public func button(
        _ title: String,
        role: ButtonRole = .default,
        backgroundColor: UIColor? = nil,
        textColor: UIColor? = nil,
        countdown: Countdown? = nil,
        target: AnyObject,
        selector: Selector
    ) -> Self {
        buttons.append(ButtonItem(title: title, role: role, backgroundColor: backgroundColor, textColor: textColor, countdown: countdown, target: target, selector: selector))
        return self
    }

    /// Sets the close button's title and shows it, or hides it when `title` is `nil`.
    @discardableResult
    public func closeButton(_ title: String?) -> Self {
        if let title { closeTitle = title }
        closeButtonOverride = title != nil
        return self
    }

    /// Hides the close button. Make sure the alert can still go away: another button, a timeout,
    /// `hideWhenBackgroundViewIsTapped`, or a call to `close()`.
    @discardableResult
    public func hideCloseButton() -> Self {
        closeButton(nil)
    }

    @discardableResult
    public func color(_ color: UIColor) -> Self {
        self.color = color
        return self
    }

    /// Accent color from a hex value such as `0xA429FF`.
    @discardableResult
    public func color(hex: UInt32) -> Self {
        color(UIColor(hex: hex))
    }

    @discardableResult
    public func buttonTextColor(_ color: UIColor) -> Self {
        buttonTextColor = color
        return self
    }

    @discardableResult
    public func icon(_ image: UIImage?, tint: UIColor? = nil) -> Self {
        iconImage = image
        if let tint { iconTintColor = tint }
        return self
    }

    /// Uses an SF Symbol as the icon.
    @discardableResult
    public func icon(systemName: String, tint: UIColor? = nil) -> Self {
        icon(UIImage(systemName: systemName), tint: tint)
    }

    @discardableResult
    public func animation(_ style: AnimationStyle) -> Self {
        animationStyle = style
        return self
    }

    @discardableResult
    public func appearance(_ appearance: Appearance) -> Self {
        self.appearance = appearance
        return self
    }

    /// Tweaks this alert's appearance in place.
    @discardableResult
    public func appearance(_ configure: (inout Appearance) -> Void) -> Self {
        configure(&appearance)
        return self
    }

    /// Closes the alert after `seconds`, running `action` first.
    @discardableResult
    public func timeout(_ seconds: TimeInterval, action: Action? = nil) -> Self {
        timeout = Timeout(seconds, action: action)
        return self
    }

    /// Shows `view` below the message. Give it a height (constraints or intrinsic size); its width follows the card.
    @discardableResult
    public func customView(_ view: UIView) -> Self {
        customView = view
        hostingController = nil
        return self
    }

    /// Adds a text field and passes it to `configure`. Give it a leading icon with `systemImage` or `icon`.
    ///
    /// ```swift
    /// .textField("Email", systemImage: "envelope")
    /// ```
    @discardableResult
    public func textField(
        _ placeholder: String? = nil,
        text: String? = nil,
        secure: Bool = false,
        systemImage: String? = nil,
        icon: UIImage? = nil,
        configure: ((UITextField) -> Void)? = nil
    ) -> Self {
        let field = addTextField(placeholder, systemImage: systemImage, icon: icon)
        field.text = text
        field.isSecureTextEntry = secure
        configure?(field)
        return self
    }

    /// Adds a text view and passes it to `configure`.
    @discardableResult
    public func textView(text: String? = nil, configure: ((UITextView) -> Void)? = nil) -> Self {
        let view = addTextView(text)
        configure?(view)
        return self
    }

    /// Adds a text field and returns it, so you can read its text from a button action.
    /// Give it a leading icon with `systemImage` (an SF Symbol name) or `icon` (any image).
    /// The icon is gray, and takes the accent color while the field is focused.
    public func addTextField(_ placeholder: String? = nil, systemImage: String? = nil, icon: UIImage? = nil) -> UITextField {
        let field = AlertTextField()
        field.placeholder = placeholder
        field.icon = icon ?? systemImage.flatMap { UIImage(systemName: $0) }
        inputs.append(field)
        return field
    }

    /// Adds a multi-line text view and returns it.
    public func addTextView(_ text: String? = nil) -> UITextView {
        let view = AlertTextView()
        view.text = text
        inputs.append(view)
        return view
    }

    /// Enables the non-cancel buttons only while `rule` returns `true`. Re-checked as the user types.
    ///
    /// ```swift
    /// .validate { email.text?.contains("@") == true }
    /// ```
    @discardableResult
    public func validate(_ rule: @escaping @MainActor () -> Bool) -> Self {
        validator = rule
        controller?.revalidate()
        return self
    }

    /// Sets `progress`.
    @discardableResult
    public func progress(_ value: Double?) -> Self {
        progress = value
        return self
    }

    /// Shows `message` in red above the buttons and shakes the alert. `nil` hides it.
    /// Cleared automatically when the user edits a field.
    public func showError(_ message: String?) {
        controller?.showError(message)
    }

    /// Runs `handler` after the alert has been dismissed, however it was dismissed. Handlers accumulate.
    @discardableResult
    public func onDismiss(_ handler: @escaping Action) -> Self {
        dismissHandlers.append(handler)
        return self
    }

    /// Runs `handler` when the timeout fires, after the timeout's own action. Handlers accumulate.
    @discardableResult
    public func onTimeout(_ handler: @escaping Action) -> Self {
        timeoutHandlers.append(handler)
        return self
    }

    func setHostingController(_ controller: UIViewController) {
        hostingController = controller
        customView = controller.view
    }

    // MARK: - Presenting

    /// Shows the alert above everything else in `scene`, or in the foreground scene when `nil`.
    @discardableResult
    public func show(in scene: UIWindowScene? = nil) -> Self {
        guard state == .idle else { return self }
        if Self.queuesAlerts, !Self.onScreen.isEmpty {
            state = .queued
            queuedScene = scene
            Self.queue.append(self)
            return self
        }
        guard let scene = scene ?? Self.foregroundScene else {
            assertionFailure("CoolAlert: no UIWindowScene to present in")
            finishWithoutAnimation(.dismissed)
            return self
        }

        previousKeyWindow = scene.keyWindow
        let controller = AlertViewController(alert: self, buttons: allButtons)
        controller.inheritedOrientations = previousKeyWindow?.rootViewController?.supportedInterfaceOrientations

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + CGFloat(Self.onScreen.count + 1)
        window.backgroundColor = .clear
        window.rootViewController = controller
        window.makeKeyAndVisible()

        self.window = window
        self.controller = controller
        state = .presented
        Self.onScreen.append(self)

        controller.animateIn()
        startTimeout()
        if appearance.hapticFeedback, let feedback = style.feedback {
            UINotificationFeedbackGenerator().notificationOccurred(feedback)
        }
        return self
    }

    /// Shows the alert and waits until it is dismissed. Cancelling the task closes the alert.
    @discardableResult
    public func present(in scene: UIWindowScene? = nil) async -> Result {
        if let result, state == .closed { return result }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                continuations.append(continuation)
                show(in: scene)
            }
        } onCancel: {
            Task { @MainActor in self.close() }
        }
    }

    /// Dismisses the alert. Result: `.dismissed`.
    public func close() {
        if state == .queued {
            Self.queue.removeAll { $0 === self }
            finishWithoutAnimation(.dismissed)
            return
        }
        finish(.dismissed)
    }

    // MARK: - Internals

    /// User buttons followed by the close button, when there is one.
    private var allButtons: [ButtonItem] {
        let showClose = closeButtonOverride ?? (style == .wait ? false : appearance.showCloseButton)
        guard showClose else { return buttons }
        let close = ButtonItem(title: closeTitle, role: buttons.isEmpty ? .default : .cancel, isCloseButton: true)
        return buttons + [close]
    }

    func handleTap(on item: ButtonItem, sender: UIButton) {
        guard state == .presented, !isBusy else { return }
        if appearance.hapticFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if item.isCloseButton {
            finish(.dismissed)
            return
        }
        item.action?()
        if let target = item.target, let selector = item.selector {
            UIApplication.shared.sendAction(selector, to: target, from: sender, for: nil)
        }
        guard let work = item.asyncAction else {
            completeTap(on: item)
            return
        }

        // The user is engaged now: stop the timeout rather than closing mid-request.
        stopTimeout()
        isBusy = true
        controller?.setBusy(true, on: item)
        Task {
            do {
                try await work()
                isBusy = false
                controller?.setBusy(false, on: item)
                completeTap(on: item)
            } catch {
                isBusy = false
                controller?.setBusy(false, on: item)
                if !(error is CancellationError) {
                    controller?.showError(error.localizedDescription)
                }
            }
        }
    }

    private func completeTap(on item: ButtonItem) {
        if appearance.shouldAutoDismiss, let index = buttons.firstIndex(where: { $0 === item }) {
            finish(.button(index: index, title: item.title))
        }
    }

    /// Whether the user has a way to dismiss the alert without picking an action.
    var isUserDismissible: Bool {
        appearance.hideWhenBackgroundViewIsTapped || allButtons.contains(where: \.isCloseButton)
    }

    func handleBackgroundTap() -> Bool {
        guard appearance.hideWhenBackgroundViewIsTapped, !isBusy else { return false }
        close()
        return true
    }

    func handleSwipeDismiss() {
        finish(.dismissed)
    }

    private func startTimeout() {
        guard let timeout, timeout.seconds > 0 else { return }
        let deadline = ContinuousClock.now + .seconds(timeout.seconds)
        remainingTime = timeout.seconds
        controller?.timeoutStarted(duration: timeout.seconds)
        controller?.updateCountdown(Int(timeout.seconds.rounded(.up)))

        timeoutTask = Task { [weak self] in
            while true {
                let left = Self.seconds(deadline - ContinuousClock.now)
                if left <= 0 { break }
                // Wake on whole seconds so the countdown ticks evenly.
                let step = left - (left.rounded(.up) - 1)
                try? await Task.sleep(for: .seconds(step))
                guard let self, !Task.isCancelled else { return }
                let remaining = max(0, Self.seconds(deadline - ContinuousClock.now))
                self.remainingTime = remaining
                self.controller?.updateCountdown(Int(remaining.rounded(.up)))
            }
            guard let self, !Task.isCancelled, self.state == .presented else { return }
            timeout.action?()
            self.timeoutHandlers.forEach { $0() }
            self.finish(.timeout)
        }
    }

    private static func seconds(_ duration: Duration) -> TimeInterval {
        let parts = duration.components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }

    private func stopTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
        remainingTime = nil
        controller?.timeoutStopped()
    }

    private func finish(_ result: Result) {
        guard state == .presented, let controller else { return }
        state = .closing
        self.result = result
        stopTimeout()

        Task {
            await controller.animateOut()
            window?.isHidden = true
            window?.rootViewController = nil
            window = nil
            self.controller = nil
            if previousKeyWindow?.isHidden == false { previousKeyWindow?.makeKey() }
            Self.onScreen.removeAll { $0 === self }
            finishWithoutAnimation(result)
            if Self.onScreen.isEmpty, !Self.queue.isEmpty {
                let next = Self.queue.removeFirst()
                next.state = .idle
                next.show(in: next.queuedScene)
            }
        }
    }

    private func finishWithoutAnimation(_ result: Result) {
        state = .closed
        self.result = result
        buttons.forEach { $0.release() }
        let handlers = dismissHandlers
        dismissHandlers.removeAll()
        timeoutHandlers.removeAll()
        handlers.forEach { $0() }
        let waiting = continuations
        continuations.removeAll()
        waiting.forEach { $0.resume(returning: result) }
    }

    private static var foregroundScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
    }
}
