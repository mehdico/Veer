import AppKit

@MainActor
final class LiveFrontmostAppProvider: FrontmostAppProviding {
    func currentBundleId() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
