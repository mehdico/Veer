import AppKit
import SwiftUI

struct AboutView: View {
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Veer"
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    /// The app icon read straight from the bundle's icns. `NSApp.applicationIconImage`
    /// can serve a stale system-cached icon (especially for LSUIElement apps),
    /// so we read the file directly to always show the current artwork.
    private static func appIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }

    var body: some View {
        VStack(spacing: 14) {
            if let icon = Self.appIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
            }
            Text(appName)
                .font(.title)
            Text("Version \(version)")
                .foregroundStyle(.secondary)
            Text("A native SwiftUI clipboard manager.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Text("Veer is a Persian word meaning memory, understanding, and mind.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 360, height: 380)
        .accessibilityIdentifier(AccessibilityIdentifiers.aboutWindow)
    }
}
