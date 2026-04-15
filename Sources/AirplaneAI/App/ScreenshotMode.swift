import Foundation

enum ScreenshotMode {
    static let isEnabled = ProcessInfo.processInfo.environment["AIRPLANE_SCREENSHOT_MODE"] == "1"
}
