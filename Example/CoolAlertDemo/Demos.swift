import CoolAlert
import SwiftUI
import UIKit

struct Demo: Identifiable {
    let id: String
    let title: String
    let detail: String
    let run: @MainActor () -> Void
}

struct DemoSection: Identifiable {
    let id: String
    let demos: [Demo]
}

/// Target for the target/selector button demo.
final class SelectorTarget: NSObject {
    @objc func sayHello() {
        print("Selector button tapped")
    }
}

@MainActor
enum Demos {
    private static let selectorTarget = SelectorTarget()

    static let sections: [DemoSection] = [
        DemoSection(id: "Styles", demos: [
            Demo(id: "success", title: "Success", detail: "CoolAlert.success(…)") {
                CoolAlert.success("Payment sent", "€42.00 is on its way to Alex.")
            },
            Demo(id: "error", title: "Error", detail: "CoolAlert.error(…)") {
                CoolAlert.error("Upload failed", "Check your connection and try again.", closeButton: "Got it")
            },
            Demo(id: "warning", title: "Warning", detail: "Destructive + cancel buttons") {
                CoolAlert(.warning, "Delete 12 photos?", "They'll be removed from all your devices.")
                    .button("Delete", role: .destructive) { print("Deleted") }
                    .closeButton("Cancel")
                    .show()
            },
            Demo(id: "info", title: "Info", detail: "CoolAlert.info(…)") {
                CoolAlert.info("New in 2.0", "Swipe left on any message to snooze it until later.")
            },
            Demo(id: "notice", title: "Notice", detail: "CoolAlert.notice(…)") {
                CoolAlert.notice("Scheduled maintenance", "We'll be offline Sunday 02:00–03:00 UTC.")
            },
            Demo(id: "question", title: "Question", detail: "Side-by-side buttons") {
                CoolAlert(.question, "Save changes?", "Your edits will be lost if you leave now.")
                    .button("Save") { print("Saved") }
                    .closeButton("Discard")
                    .appearance { $0.buttonsLayout = .horizontal }
                    .show()
            },
            Demo(id: "edit", title: "Edit", detail: "Text fields, return key moves focus") {
                let alert = CoolAlert(.edit, "Sign in", "Use your work account.")
                let email = alert.addTextField("Email")
                email.keyboardType = .emailAddress
                email.autocapitalizationType = .none
                let password = alert.addTextField("Password")
                password.isSecureTextEntry = true
                alert
                    .button("Sign in") { print("Signing in as \(email.text ?? "")") }
                    .closeButton("Cancel")
                    .appearance { $0.focusFirstField = true }
                    .show()
            },
            Demo(id: "wait", title: "Wait", detail: "Spinner, updated live, then closed") {
                let alert = CoolAlert.wait("Uploading…", "3 of 12 photos")
                Task {
                    for done in 4...12 {
                        try? await Task.sleep(for: .milliseconds(300))
                        alert.message = "\(done) of 12 photos"
                    }
                    alert.title = "Finishing up"
                    try? await Task.sleep(for: .seconds(0.8))
                    alert.close()
                    CoolAlert.success("All done", "12 photos uploaded.", timeout: 2)
                }
            },
            Demo(id: "custom", title: "Custom", detail: "Any color + SF Symbol") {
                CoolAlert(.custom(color: UIColor(red: 0.98, green: 0.45, blue: 0.2, alpha: 1)), "You're on fire", "7 days in a row. Keep the streak alive!")
                    .icon(systemName: "flame.fill")
                    .closeButton("Let's go")
                    .show()
            },
        ]),
        DemoSection(id: "New", demos: [
            Demo(id: "asyncsignin", title: "Async action + validation", detail: "Spinner, inline error, disabled until valid") {
                let alert = CoolAlert(.edit, "Sign in", "Hint: the password is “swift”.")
                let email = alert.addTextField("Email", systemImage: "envelope")
                email.keyboardType = .emailAddress
                email.autocapitalizationType = .none
                email.text = "ada@example.com"
                let password = alert.addTextField("Password", systemImage: "lock")
                password.isSecureTextEntry = true
                password.text = "pass"
                alert
                    .validate { email.text?.contains("@") == true && (password.text ?? "").count >= 4 }
                    .button("Sign in") {
                        try await Task.sleep(for: .seconds(1.2))
                        guard password.text == "swift" else { throw DemoError.wrongPassword }
                    }
                    .closeButton("Cancel")
                    .onDismiss { if alert.result != .dismissed { CoolAlert.success("Welcome back", timeout: 2) } }
                    .appearance { $0.focusFirstField = true }
                    .show()
            },
            Demo(id: "progress", title: "Progress", detail: "Ring + percentage, then success") {
                let alert = CoolAlert.wait("Downloading", "Fonts and assets").progress(0)
                Task {
                    for step in 1...20 {
                        try? await Task.sleep(for: .milliseconds(120))
                        alert.progress = Double(step) / 20
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                    alert.close()
                    CoolAlert.success("Download complete", timeout: 2)
                }
            },
            Demo(id: "progressicon", title: "Progress on any icon", detail: "progress(0.65)") {
                CoolAlert(.custom(color: .systemTeal), "Syncing library", "1,284 of 1,975 photos")
                    .icon(systemName: "arrow.triangle.2.circlepath")
                    .progress(0.65)
                    .closeButton("Hide")
                    .show()
            },
            Demo(id: "glass", title: "Liquid Glass", detail: "cardStyle = .glass") {
                CoolAlert(.info, "Glass card", "Uses Liquid Glass on iOS 26 and later, a material blur before that.")
                    .appearance {
                        $0.cardStyle = .glass
                        $0.dimOpacity = 0.12
                        $0.hideWhenBackgroundViewIsTapped = true
                    }
                    .animation(.zoom)
                    .closeButton("Lovely")
                    .show()
            },
            Demo(id: "swipe", title: "Swipe to dismiss", detail: "Fling the card away") {
                CoolAlert.notice("Fling me", "Drag the card in any direction and let go.")
            },
            Demo(id: "queue", title: "Queue", detail: "queuesAlerts = true") {
                CoolAlert.queuesAlerts = true
                CoolAlert.info("First", "The next one waits for this to close.")
                CoolAlert.warning("Second", "Shown after the first.")
                CoolAlert.success("Third", "The queue is empty now.").onDismiss { CoolAlert.queuesAlerts = false }
            },
            Demo(id: "form", title: "Tall form", detail: "Body scrolls, buttons stay put") {
                let alert = CoolAlert(.edit, "Shipping address", "Where should we send your order?")
                let fields = [
                    ("Full name", "person"), ("Street", "house"), ("Apartment, suite", "building.2"), ("City", "mappin.and.ellipse"),
                    ("Postal code", "number"), ("Country", "globe"), ("Phone", "phone"),
                ]
                for (placeholder, symbol) in fields {
                    alert.textField(placeholder, systemImage: symbol)
                }
                alert.button("Save address").closeButton("Cancel").show()
            },
        ]),
        DemoSection(id: "Buttons & timeouts", demos: [
            Demo(id: "buttons", title: "Many buttons", detail: "Roles, custom colors, selector") {
                CoolAlert(.info, "Share photo", "Choose where to send it.")
                    .button("Messages") { print("Messages") }
                    .button("Mail", backgroundColor: .systemIndigo) { print("Mail") }
                    .button("Selector", backgroundColor: .systemTeal, target: selectorTarget, selector: #selector(SelectorTarget.sayHello))
                    .closeButton("Cancel")
                    .show()
            },
            Demo(id: "countdown", title: "Countdown button", detail: "Timeout shown on a button") {
                CoolAlert(.notice, "Ad break", "Your video continues shortly.")
                    .button("Skip", backgroundColor: .systemBrown, textColor: .systemYellow, countdown: .seconds) { print("Skipped") }
                    .hideCloseButton()
                    .timeout(5) { print("Timed out") }
                    .show()
            },
            Demo(id: "timeout", title: "Auto close", detail: "No button, closes after 3s") {
                CoolAlert(.success, "Copied", "The link is on your clipboard.")
                    .hideCloseButton()
                    .timeout(3)
                    .appearance { $0.hideWhenBackgroundViewIsTapped = true }
                    .show()
            },
            Demo(id: "stay", title: "Don't auto dismiss", detail: "shouldAutoDismiss = false") {
                var count = 0
                let alert = CoolAlert(.question, "Counter", "Tapped 0 times")
                alert
                    .button("Tap me") {
                        count += 1
                        alert.message = "Tapped \(count) time\(count == 1 ? "" : "s")"
                    }
                    .appearance { $0.shouldAutoDismiss = false }
                    .show()
            },
            Demo(id: "async", title: "async / await", detail: "Wait for the result") {
                Task {
                    let result = await CoolAlert(.question, "Enable notifications?", "We'll only ping you about replies.")
                        .button("Enable")
                        .closeButton("Not now")
                        .present()
                    switch result {
                    case .button(_, let title): CoolAlert.success("You chose “\(title)”", timeout: 2)
                    case .dismissed: CoolAlert.notice("Maybe later", timeout: 2)
                    case .timeout: break
                    }
                }
            },
        ]),
        DemoSection(id: "Content", demos: [
            Demo(id: "textview", title: "Text view", detail: "Multi-line input") {
                let alert = CoolAlert(.edit, "Send feedback")
                let text = alert.addTextView()
                alert.button("Send") { print(text.text ?? "") }.closeButton("Cancel").show()
            },
            Demo(id: "uikitview", title: "Custom UIView", detail: "Instead of a message") {
                let toggle = UISwitch()
                toggle.isOn = true
                let label = UILabel()
                label.text = "Remember me"
                label.font = .preferredFont(forTextStyle: .body)
                let row = UIStackView(arrangedSubviews: [label, toggle])
                row.spacing = 12
                CoolAlert(.info, "Stay signed in?")
                    .customView(row)
                    .closeButton("Continue")
                    .show()
            },
            Demo(id: "swiftui", title: "SwiftUI view", detail: "customView { … }") {
                CoolAlert(.custom(color: .systemPink), "Rate your stay", "How was Hotel Lumière?")
                    .icon(systemName: "heart.fill")
                    .customView { StarRating() }
                    .button("Submit")
                    .closeButton("Later")
                    .show()
            },
            Demo(id: "long", title: "Long message", detail: "Scrolls past maxMessageHeight") {
                CoolAlert.info("Terms of service", String(repeating: "By continuing you agree to be nice to everyone, to keep your password secret, and to never feed the gremlins after midnight. ", count: 8))
            },
        ]),
        DemoSection(id: "Look & feel", demos: [
            Demo(id: "dynamic", title: "UIKit Dynamics", detail: "Snap in, fall out") {
                CoolAlert(.success, "Achievement unlocked", "Completed 100 workouts.")
                    .appearance { $0.dynamicAnimatorActive = true }
                    .closeButton("Nice")
                    .show()
            },
            Demo(id: "blur", title: "Blurred backdrop", detail: "Tap outside to close") {
                CoolAlert(.info, "Focus mode on", "Notifications are silenced until 5 PM.")
                    .appearance {
                        $0.backgroundBlur = true
                        $0.dimOpacity = 0.15
                        $0.hideWhenBackgroundViewIsTapped = true
                    }
                    .animation(.zoom)
                    .show()
            },
            Demo(id: "noicon", title: "No icon", detail: "showCircularIcon = false") {
                CoolAlert(.info, "Clean and simple", "Sometimes you don't need an icon.")
                    .appearance { $0.showCircularIcon = false }
                    .show()
            },
            Demo(id: "image", title: "Custom icon", detail: "Any UIImage, tinted") {
                CoolAlert(.custom(color: .systemIndigo), "Night mode", "We dimmed the screen for you.")
                    .icon(UIImage(systemName: "moon.stars.fill"), tint: .systemYellow)
                    .show()
            },
            Demo(id: "themed", title: "Custom appearance", detail: "Fonts, colors, corners") {
                CoolAlert(.success, "Level complete", "You collected 3 stars and 1,250 coins.")
                    .appearance {
                        $0.contentViewColor = UIColor(red: 0.1, green: 0.11, blue: 0.16, alpha: 1)
                        $0.circleBackgroundColor = UIColor(red: 0.1, green: 0.11, blue: 0.16, alpha: 1)
                        $0.titleColor = .white
                        $0.messageColor = UIColor.white.withAlphaComponent(0.7)
                        $0.titleFont = UIFont(name: "AvenirNext-Heavy", size: 22) ?? .boldSystemFont(ofSize: 22)
                        $0.contentViewCornerRadius = 12
                        $0.buttonCornerRadius = 24
                        $0.contentViewBorderColor = .systemGreen
                        $0.contentViewBorderWidth = 1
                    }
                    .color(hex: 0x39D98A)
                    .closeButton("Next level")
                    .show()
            },
        ]),
        DemoSection(id: "Animations", demos: CoolAlert.AnimationStyle.allCases.map { style in
            Demo(id: "anim-\(style)", title: "\(style)", detail: ".animation(.\(style))") {
                CoolAlert(.info, "\(style)", "Entrance animation").animation(style).show()
            }
        }),
    ]

    static func demo(id: String) -> Demo? {
        sections.flatMap(\.demos).first { $0.id == id }
    }
}

enum DemoError: LocalizedError {
    case wrongPassword

    var errorDescription: String? {
        switch self {
        case .wrongPassword: "That password didn't work. Try “swift”."
        }
    }
}

struct StarRating: View {
    @State private var rating = 4

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(star <= rating ? Color.orange : Color.secondary)
                    .onTapGesture { withAnimation(.spring) { rating = star } }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
