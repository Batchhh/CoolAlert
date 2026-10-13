import SwiftUI

public extension CoolAlert {
    /// Shows a SwiftUI view below the message. Its width follows the card; its height is its ideal height.
    @discardableResult
    func customView<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        let hosting = UIHostingController(rootView: content())
        hosting.sizingOptions = .intrinsicContentSize
        hosting.view.backgroundColor = .clear
        setHostingController(hosting)
        return self
    }
}

public extension View {
    /// Shows the alert built by `alert` while `isPresented` is `true`, and resets it when the alert closes.
    ///
    /// ```swift
    /// .coolAlert(isPresented: $saved) {
    ///     CoolAlert(.success, "Saved", "Your changes are safe.")
    /// }
    /// ```
    func coolAlert(isPresented: Binding<Bool>, alert: @escaping @MainActor () -> CoolAlert) -> some View {
        modifier(CoolAlertPresenter(
            trigger: isPresented.wrappedValue,
            makeAlert: { isPresented.wrappedValue ? alert() : nil },
            reset: { isPresented.wrappedValue = false }
        ))
    }

    /// Shows an alert for `item` while it is non-nil, and sets it back to `nil` when the alert closes.
    func coolAlert<Item: Identifiable>(item: Binding<Item?>, alert: @escaping @MainActor (Item) -> CoolAlert) -> some View {
        modifier(CoolAlertPresenter(
            trigger: item.wrappedValue?.id,
            makeAlert: { item.wrappedValue.map(alert) },
            reset: { item.wrappedValue = nil }
        ))
    }
}

private struct CoolAlertPresenter<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let makeAlert: @MainActor () -> CoolAlert?
    let reset: @MainActor () -> Void
    @State private var current: CoolAlert?

    init(trigger: Trigger, makeAlert: @escaping @MainActor () -> CoolAlert?, reset: @escaping @MainActor () -> Void) {
        self.trigger = trigger
        self.makeAlert = makeAlert
        self.reset = reset
    }

    func body(content: Content) -> some View {
        content.onChange(of: trigger, initial: true) {
            // Closing the old alert first lets a new item replace it.
            if let current {
                self.current = nil
                current.close()
            }
            guard let alert = makeAlert() else { return }
            current = alert
            alert.onDismiss { [weak alert] in
                guard let alert, self.current === alert else { return }
                self.current = nil
                reset()
            }
            alert.show()
        }
    }
}
