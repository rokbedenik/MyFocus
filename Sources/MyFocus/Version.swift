import Foundation

// Single source of truth for the app version. scripts/build-app.sh reads it from this file and writes it into
// Info.plist (CFBundleShortVersionString); the build number is the git commit count.
// Format: major.minor.patch, patch with two digits (0.4.00, 0.4.01, 0.5.00).
enum AppVersion {
    static let current = "0.4.00"

    // "v0.4.00 (build 57)"; the build number comes from Info.plist and is 0 in a dev run
    static var display: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "v\(current) (build \(build))"
    }
}
