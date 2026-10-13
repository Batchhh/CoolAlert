# CoolAlert

Animated alerts for iOS with a short, chainable API. Covers everything [SCLAlertView-Swift](https://github.com/vikmeup/SCLAlertView-Swift) does, and adds async/await, SwiftUI support, dark mode and Dynamic Type.

- Nine styles (`success`, `error`, `notice`, `warning`, `info`, `edit`, `wait`, `question`, `custom`). Each has its own accent color and an icon that draws itself in.
- Seven entrance animations, or optional UIKit Dynamics (snaps in, falls out).
- Buttons with roles, custom colors, target/selector, and a countdown shown on the button.
- Text fields, text views, and custom UIKit or SwiftUI content.
- Timeouts with a draining progress bar.
- Change the title and message while the alert is showing.
- Async button actions with a spinner, inline errors and a shake.
- Validation that keeps buttons disabled until the input is valid.
- A progress ring around the icon.
- Swipe the card away to dismiss it.
- An optional queue, so alerts appear one after another.
- A Liquid Glass card on iOS 26+.
- Keyboard avoidance, landscape, VoiceOver, Dynamic Type, Reduce Motion, light and dark mode.

Requires iOS 17 and Swift 6.

## Install

Swift Package Manager: add this repository (or the local folder) and depend on the `CoolAlert` product.

## Quick start

```swift
import CoolAlert

CoolAlert.success("Payment sent", "€42.00 is on its way to Alex.")
CoolAlert.error("Upload failed", "Check your connection.", closeButton: "Got it")
CoolAlert.warning("Low storage", timeout: 3)
CoolAlert.info / .notice / .edit / .question / .wait / .custom(…)
```

For anything more, build the alert and call `show()`:

```swift
CoolAlert(.warning, "Delete 12 photos?", "They'll be removed from all your devices.")
    .button("Delete", role: .destructive) { deletePhotos() }
    .closeButton("Cancel")
    .show()
```

You don't need to keep a reference: an alert stays alive while it's on screen.

## Async / await

```swift
let result = await CoolAlert(.question, "Enable notifications?")
    .button("Enable")
    .closeButton("Not now")
    .present()

switch result {
case .button(let index, let title): …   // index counts your buttons in order
case .dismissed: …                      // close button, background tap, or close()
case .timeout: …
}
```

Cancelling the task closes the alert.

## Updating a visible alert

```swift
let alert = CoolAlert.wait("Uploading…", "0 of 12")
alert.message = "6 of 12"      // the visible alert updates
alert.title = "Almost there"
alert.close()
```

## Buttons

```swift
CoolAlert(.info, "Share")
    .button("Messages") { … }                                    // filled with the accent color
    .button("Mail", backgroundColor: .systemIndigo, textColor: .white) { … }
    .button("Report", role: .destructive) { … }
    .button("Legacy", target: self, selector: #selector(legacyTapped))
    .closeButton("Cancel")       // nil hides it; .hideCloseButton() also works
    .appearance { $0.buttonsLayout = .horizontal }   // .vertical (default) / .automatic
    .show()
```

When there are other buttons, the close button gets the neutral `.cancel` look. Set `appearance.shouldAutoDismiss = false` to keep the alert open after a button runs its action.

## Async actions and errors

Give a button an async (and throwing) action. While it runs:

- the button shows a spinner
- the other buttons and the inputs are disabled
- the timeout stops

If the action throws, the alert stays open, shows the error's `localizedDescription` in red above the buttons, and shakes. Editing a field clears the error.

```swift
let alert = CoolAlert(.edit, "Sign in")
let email = alert.addTextField("Email")
let password = alert.addTextField("Password")

alert
    .validate { email.text?.contains("@") == true && !(password.text ?? "").isEmpty }
    .button("Sign in") { try await api.signIn(email.text!, password.text!) }
    .closeButton("Cancel")
    .show()
```

`validate { }` runs as the user types and enables the action buttons only when it returns `true`. Cancel and close buttons stay enabled. Pressing return on the last field taps the first action button.

You can also show an error yourself with `alert.showError("Wrong code")`, and hide it with `alert.showError(nil)`.

## Progress

```swift
let alert = CoolAlert.wait("Downloading").progress(0)
alert.progress = 0.42        // ring fills; .wait alerts show "42%" instead of the spinner
alert.progress = nil         // hide the ring
```

Any style can show the ring, e.g. `CoolAlert(.info, "Syncing").progress(0.65)`.

## Timeouts

```swift
CoolAlert(.notice, "Ad break")
    .button("Skip", countdown: .seconds) { … }      // "Skip (5s)", "Skip (4s)", …
    .hideCloseButton()
    .timeout(5) { print("timed out") }
    .onTimeout { … }
    .onDismiss { … }
    .show()
```

`Countdown(prefix:suffix:)` lets you choose the format.

## Text input

```swift
let alert = CoolAlert(.edit, "Sign in")
let email = alert.addTextField("Email")
let password = alert.addTextField("Password")
password.isSecureTextEntry = true
let notes = alert.addTextView()

alert.button("Sign in") { login(email.text, password.text) }
    .appearance { $0.focusFirstField = true }
    .show()

// or inline:
CoolAlert(.edit, "Rename").textField("Name", text: file.name) { $0.clearButtonMode = .always }
```

### Icons in text fields

Pass an SF Symbol name with `systemImage`, or any `UIImage` with `icon`. The icon:

- sits at the leading edge, sized to the field's font so it follows Dynamic Type
- is gray, and takes the alert's accent color while its field is focused
- pushes the text and placeholder to the right to make room

Symbols and template images are tinted; other images keep their own colors.

```swift
let alert = CoolAlert(.edit, "Sign in")
let email = alert.addTextField("Email", systemImage: "envelope")
let password = alert.addTextField("Password", systemImage: "lock")

CoolAlert(.edit, "Shipping")
    .textField("Full name", systemImage: "person")
    .textField("Company", icon: UIImage(named: "building"))
```

Return moves focus to the next field. The card moves up out of the keyboard's way.

## Custom content

```swift
CoolAlert(.info, "Stay signed in?").customView(myUIView).show()

CoolAlert(.custom(color: .systemPink), "Rate your stay")
    .icon(systemName: "heart.fill")
    .customView { StarRating() }          // any SwiftUI view
    .show()
```

## Dismissing and queueing

- The user can fling the card away in any direction. This only works when the alert can already be dismissed without choosing an action, i.e. it has a close button or `hideWhenBackgroundViewIsTapped` is on. Otherwise the card resists the drag. Turn it off with `appearance.swipeToDismiss = false`.
- By default, alerts stack. Set `CoolAlert.queuesAlerts = true` and each `show()` waits until the alert on screen closes. `close()` removes a queued alert from the queue, and `CoolAlert.dismissAll()` clears the queue.

## SwiftUI

```swift
.coolAlert(isPresented: $saved) {
    CoolAlert(.success, "Saved")
}

.coolAlert(item: $failedUpload) { upload in
    CoolAlert(.error, "Couldn't upload \(upload.name)")
}
```

## Look and feel

```swift
// Every alert
CoolAlert.defaultAppearance = .init {
    $0.titleFont = UIFont(name: "AvenirNext-Bold", size: 20)!
    $0.buttonCornerRadius = 24
    $0.hideWhenBackgroundViewIsTapped = true
}

// One alert
CoolAlert(.success, "Level complete")
    .color(hex: 0x39D98A)
    .buttonTextColor(.black)
    .icon(UIImage(named: "trophy"), tint: .white)
    .animation(.bottomToTop)        // .topToBottom .leftToRight .rightToLeft .fade .zoom .noAnimation
    .appearance {
        $0.cardStyle = .glass           // Liquid Glass on iOS 26+, material blur before
        $0.dynamicAnimatorActive = true
        $0.backgroundBlur = true
    }
    .show()
```

| Group | `Appearance` properties |
|---|---|
| Backdrop | `dimOpacity`, `backgroundBlur`, `hideWhenBackgroundViewIsTapped` |
| Card | `cardStyle`, `windowWidth`, `contentViewColor`, `contentViewBorderColor`, `contentViewBorderWidth`, `contentViewCornerRadius`, `shadowOpacity`, `margin` |
| Icon | `showCircularIcon`, `circleSize`, `circleRingWidth`, `circleTopPosition`, `circleIconSize`, `circleBackgroundColor`, `animatedIcons`, `activityIndicatorStyle` |
| Text | `titleFont`, `titleColor`, `titleMinimumScaleFactor`, `messageFont`, `messageColor`, `messageAlignment`, `maxMessageHeight` |
| Inputs | `textFieldHeight`, `textViewHeight`, `fieldCornerRadius`, `fieldFont`, `focusFirstField` |
| Buttons | `buttonFont`, `buttonHeight`, `buttonCornerRadius`, `buttonsLayout`, `showCloseButton`, `shouldAutoDismiss` |
| Behavior | `dynamicAnimatorActive`, `swipeToDismiss`, `disableTapGesture`, `hapticFeedback`, `showTimeoutProgress` |

`Margin` has `top`, `titleTop`, `titleToMessage`, `textViewBottom`, `buttonSpacing`, `textFieldSpacing`, `bottom` and `horizontal`.

The default fonts follow Dynamic Type. With Reduce Motion on, every entrance becomes a fade and the shake is skipped.

## Layout

When content doesn't fit, the alert gives up space in this order:

1. The body (title, message, custom view and fields) scrolls, and the buttons stay pinned to the bottom.
2. If the body would get shorter than about 120 pt, the whole card scrolls instead. This happens in landscape with the keyboard up.

Either way, the focused field is kept above the keyboard.

## Coming from SCLAlertView

| SCLAlertView | CoolAlert |
|---|---|
| `SCLAlertView().showSuccess("T", subTitle: "S")` | `CoolAlert.success("T", "S")` |
| `showTitle(_:subTitle:style:closeButtonTitle:timeout:colorStyle:colorTextButton:circleIconImage:animationStyle:)` | `CoolAlert(style, "T", "S").closeButton(…).timeout(…).color(…).buttonTextColor(…).icon(…).animation(…).show()` |
| `showCustom(_:subTitle:color:icon:)` | `CoolAlert.custom("T", "S", color:, icon:)` |
| `SCLAlertViewResponder.setTitle` / `setSubTitle` / `close` | `alert.title = …` / `alert.message = …` / `alert.close()` |
| `setDismissBlock` / `setTimeoutBlock` | `.onDismiss { }` / `.onTimeout { }` |
| `addButton(_:backgroundColor:textColor:showTimeout:action:)` | `.button(_:backgroundColor:textColor:countdown:action:)` |
| `addButton(_:target:selector:)` | `.button(_:target:selector:)` |
| `SCLButton.ShowTimeoutConfiguration(prefix:suffix:)` | `CoolAlert.Countdown(prefix:suffix:)` |
| `SCLTimeoutConfiguration(timeoutValue:timeoutAction:)` | `.timeout(seconds) { action }` |
| `addTextField(_:)` / `addTextView()` | `addTextField(_:)` / `addTextView()` (same names) |
| `customSubview` | `.customView(view)` or `.customView { SwiftUI }` |
| `iconTintColor` | `.icon(image, tint:)` / `iconTintColor` |
| `isShowing()` | `CoolAlert.isShowing`, `alert.isVisible` |
| `hideView()` | `close()`, `CoolAlert.dismissAll()` |
| `SCLAppearance(kTitleFont:, kTextFont:, kButtonFont:, kWindowWidth:, kTextHeight:, kTextFieldHeight:, kTextViewdHeight:, kButtonHeight:, kCircleHeight:, kCircleIconHeight:, kCircleTopPosition:, kDefaultShadowOpacity:, …)` | `Appearance` with `titleFont`, `messageFont`, `buttonFont`, `windowWidth`, `maxMessageHeight`, `textFieldHeight`, `textViewHeight`, `buttonHeight`, `circleSize`, `circleIconSize`, `circleTopPosition`, `dimOpacity`, … |
| `SCLAnimationStyle` | `CoolAlert.AnimationStyle` (adds `.fade` and `.zoom`) |
| `SCLAlertButtonLayout` | `CoolAlert.ButtonLayout` (adds `.automatic`) |
| `window:` parameter | `show(in: windowScene)` |

The card sizes itself to its content, so `kWindowHeight` and `kTitleHeight` have no equivalent.

## Demo

Open `Example/CoolAlertDemo.xcodeproj` and run it. It has one row per feature. Two launch arguments help with testing:

- `-demo <id>` opens a demo at launch (`success`, `asyncsignin`, `progress`, `glass`, `form`, …; see `Demos.swift`).
  - Add `-autotap <title>` to tap a button once the alert is up.
  - Add `-landscape YES` to rotate the app first.
- `-selftest YES` runs about 50 end-to-end checks (button results, timeouts, async actions, validation, queueing, progress, overflow layout, memory release), prints PASS/FAIL, and exits.
