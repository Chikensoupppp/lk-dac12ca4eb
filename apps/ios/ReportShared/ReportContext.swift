import DeviceActivity
import SwiftUI

/// The report contexts the app asks the LockInReport extension to draw. Data can only flow from
/// the app into the extension, never back, so the user's guess rides along in the context name.
extension DeviceActivityReport.Context {
    /// `guess` is the poster tab: 0 = 1-2 hours ... 3 = 7+, nil when skipped.
    static func reveal(guess: Int?) -> Self {
        Self("lockin.reveal.\(guess.map(String.init) ?? "none")")
    }
}
