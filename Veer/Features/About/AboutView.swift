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

    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSApp.applicationIconImage {
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
