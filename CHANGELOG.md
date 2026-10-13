# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

- Nine alert styles with self-drawing icons, a custom style, and seven entrance animations, plus UIKit Dynamics.
- A chainable builder, one-line shortcuts, and `async`/`await` results through `present()`.
- Buttons with roles, custom colors, target/selector and countdowns; a close button; horizontal, vertical and automatic layouts.
- Async button actions with a spinner, inline errors and a shake; `validate { }` to enable buttons; `showError(_:)`.
- Text fields with leading icons, text views, and custom UIKit or SwiftUI content.
- Timeouts with a progress bar, a progress ring with a percentage, and live title and message updates.
- Swipe to dismiss, queueing (`CoolAlert.queuesAlerts`), and `dismissAll()`.
- A Liquid Glass card style on iOS 26+.
- SwiftUI `.coolAlert(isPresented:)` and `.coolAlert(item:)` modifiers.
- Accessibility: VoiceOver, Dynamic Type, Reduce Motion, and light and dark mode.
- Keyboard avoidance, and scrolling for tall content in any orientation.

### Fixed

- Short alerts no longer get stretched gaps or clipped messages.
