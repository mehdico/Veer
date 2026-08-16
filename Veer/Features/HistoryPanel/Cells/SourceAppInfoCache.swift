import AppKit

/// Resolves a clip's source app (URL, icon, display name) once per bundle id.
/// These are LaunchServices and Info.plist round-trips that cells and cards
/// used to pay on every body evaluation while scrolling; the distinct-source
/// count is small enough that entries live for the process lifetime.
@MainActor
enum SourceAppInfoCache {
    private struct Info {
        let url: URL?
        let name: String
        let icon: NSImage?
    }

    private static var cache: [String: Info] = [:]

    static func appIcon(for bundleId: String) -> NSImage? {
        info(for: bundleId).icon
    }

    static func appName(for bundleId: String) -> String {
        info(for: bundleId).name
    }

    static func appURL(for bundleId: String) -> URL? {
        info(for: bundleId).url
    }

    private static func info(for bundleId: String) -> Info {
        if let cached = cache[bundleId] { return cached }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        let name = url
            .flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleName"] as? String }
            ?? bundleId
        let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
        let entry = Info(url: url, name: name, icon: icon)
        cache[bundleId] = entry
        return entry
    }
}
