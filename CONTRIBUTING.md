# Contributing to CoolAlert

Thanks for helping make CoolAlert better. Bug reports, ideas, docs fixes and code are all welcome.

## Ways to contribute

- **Report a bug:** [open a bug report](https://github.com/Batchhh/CoolAlert/issues/new?template=bug_report.yml) with the smallest code that reproduces it.
- **Suggest a feature:** [open a feature request](https://github.com/Batchhh/CoolAlert/issues/new?template=feature_request.yml) and describe the problem it solves.
- **Pick up an issue:** look for [`good first issue`](https://github.com/Batchhh/CoolAlert/labels/good%20first%20issue) or [`help wanted`](https://github.com/Batchhh/CoolAlert/labels/help%20wanted). Comment on the issue so nobody duplicates the work.

For anything larger than a small fix, please open an issue first, so we can agree on the approach before you write the code.

## Setup

You need Xcode 26 or later. The package targets iOS 17 and builds in Swift 6 language mode with strict concurrency.

```bash
git clone https://github.com/Batchhh/CoolAlert.git
cd CoolAlert
open Package.swift                      # the library
open Example/CoolAlertDemo.xcodeproj    # the demo app, which uses the local package
```

## Project layout

| Path | What's there |
|---|---|
| `Sources/CoolAlert/CoolAlert.swift` | The public API: builder, presentation, results |
| `Sources/CoolAlert/CoolAlert+Types.swift` | `Style`, `AnimationStyle`, `ButtonRole`, `Timeout`, `Result`, … |
| `Sources/CoolAlert/Appearance.swift` | Every customization option |
| `Sources/CoolAlert/AlertViewController.swift` | Layout, animations, keyboard, swipe, accessibility |
| `Sources/CoolAlert/BadgeView.swift` | The circular icon, its drawn glyphs and the progress ring |
| `Sources/CoolAlert/AlertButton.swift`, `AlertInputs.swift` | Buttons and text inputs |
| `Sources/CoolAlert/CoolAlert+SwiftUI.swift` | `.coolAlert` modifiers and SwiftUI content |
| `Tests/CoolAlertTests` | Unit tests (Swift Testing) |
| `Example/CoolAlertDemo` | Demo app: one row per feature, plus the end-to-end self-test |

## Running the tests

```bash
scripts/test.sh
```

This runs the same checks as CI:

1. **Unit tests** for the package, on an iOS simulator.
2. **End-to-end self-test.** It launches the demo app with `-selftest YES`, which drives real alerts on screen: button taps, timeouts, async actions, validation, queueing, layout and memory release. It prints `PASS` or `FAIL` for each check.

The script picks an iPhone simulator, or creates one called "CoolAlert Tests". To choose one yourself, set `SIMULATOR_UDID`.

When you add a feature, add a unit test for its logic. If it changes on-screen behavior, also add a check to `Example/CoolAlertDemo/SelfTest.swift`. For visual changes, add a row to `Demos.swift` so reviewers can try it. You can open any demo at launch with `-demo <id>`.

## Code style

- Match the surrounding code: naming, comment density, and the chainable `@discardableResult … -> Self` builder style for public options.
- Every public API gets a `///` doc comment that says what it does, with an example when that helps.
- Keep everything `@MainActor` and free of Swift 6 concurrency warnings. The build must stay warning-free.
- Prefer Auto Layout and UIKit APIs available on iOS 17. Guard newer APIs with `if #available` and provide a fallback, the way `Glass.swift` does.
- Respect accessibility: Dynamic Type for default fonts, VoiceOver labels and announcements, and Reduce Motion.
- `.editorconfig` sets indentation: 4 spaces for Swift, 2 for YAML and Markdown.

## Pull requests

1. Fork the repo and create a branch from `main`, for example `fix/keyboard-overlap` or `feature/toast-style`.
2. Make your change, with tests.
3. Run `scripts/test.sh` and make sure it passes.
4. Update `README.md` if you changed public API or behavior, and add a line under **Unreleased** in `CHANGELOG.md`.
5. Open the pull request and fill in the template. Screenshots or a short screen recording help a lot for UI changes.

Keep each pull request to one change; small ones are reviewed faster. CI must pass before merging.

### Commit messages

Use the imperative mood and keep the summary short, for example "Fix keyboard overlap in landscape". Explain the *why* in the body when it isn't obvious from the change.

## Code of Conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.
