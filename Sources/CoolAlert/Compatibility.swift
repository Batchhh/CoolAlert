import CoreText
import UIKit

/// Seconds on a monotonic clock that keeps counting while the device sleeps, like `ContinuousClock` (iOS 16+).
func monotonicNow() -> TimeInterval {
    TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9
}

extension Task where Success == Never, Failure == Never {
    /// `Task.sleep(for:)` arrived in iOS 16.
    static func sleep(seconds: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(max(0, seconds) * 1e9))
    }
}

extension UIFont {
    /// The same font with fixed-width digits, so a changing number doesn't shift its neighbors.
    var withMonospacedDigits: UIFont {
        // UIKit's `FeatureKey.type` and `.selector` are iOS 15 names for these CoreText keys.
        let setting = [
            kCTFontFeatureTypeIdentifierKey as String: kNumberSpacingType,
            kCTFontFeatureSelectorIdentifierKey as String: kMonospacedNumbersSelector,
        ]
        return UIFont(descriptor: fontDescriptor.addingAttributes([.featureSettings: [setting]]), size: 0)
    }
}
