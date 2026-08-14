import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let userDefaultsKey = "settings"

    var maxHistoryItems: Int { didSet { persist() } }
    var showsRichText: Bool { didSet { persist() } }
    var pastesRichText: Bool { didSet { persist() } }
    var showAsCards: Bool { didSet { persist() } }
    var textOnlyHistory: Bool { didSet { persist() } }
    private(set) var ignoredAppBundleIds: [String] { didSet { persist() } }
    var ignoresPasswordManagers: Bool {
        didSet {
            applyIgnoredAppsPolicy()
            persist()
        }
    }
    private(set) var panelSizeByPosition: [Int: PanelSize] { didSet { persist() } }

    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored private let didSeedDefaultIgnoredApps: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded = Self.load(from: defaults)
        if !loaded.didSeedDefaultIgnoredApps {
            loaded.applyDefaultIgnoredAppsPolicy()
            Self.persist(loaded, to: defaults)
        }
        self.ignoresPasswordManagers = loaded.ignoresPasswordManagers
        self.didSeedDefaultIgnoredApps = loaded.didSeedDefaultIgnoredApps
        self.maxHistoryItems = loaded.maxHistoryItems
        self.showsRichText = loaded.showsRichText
        self.pastesRichText = loaded.pastesRichText
        self.showAsCards = loaded.showAsCards
        self.textOnlyHistory = loaded.textOnlyHistory
        self.ignoredAppBundleIds = loaded.ignoredAppBundleIds
        self.panelSizeByPosition = loaded.panelSizeByPosition
    }

    var snapshot: VeerSettings {
        VeerSettings(
            maxHistoryItems: maxHistoryItems,
            showsRichText: showsRichText,
            pastesRichText: pastesRichText,
            showAsCards: showAsCards,
            textOnlyHistory: textOnlyHistory,
            ignoredAppBundleIds: ignoredAppBundleIds,
            ignoresPasswordManagers: ignoresPasswordManagers,
            didSeedDefaultIgnoredApps: didSeedDefaultIgnoredApps,
            panelSizeByPosition: panelSizeByPosition
        )
    }

    func addIgnoredApp(_ bundleId: String) {
        guard !bundleId.isEmpty, !ignoredAppBundleIds.contains(bundleId) else { return }
        ignoredAppBundleIds.append(bundleId)
    }

    func removeIgnoredApp(_ bundleId: String) {
        ignoredAppBundleIds.removeAll { $0 == bundleId }
    }

    private func applyIgnoredAppsPolicy() {
        let seeded = Constants.Privacy.defaultIgnoredApps.map(\.bundleId)
        if ignoresPasswordManagers {
            var next = seeded
            for id in ignoredAppBundleIds where !next.contains(id) {
                next.append(id)
            }
            ignoredAppBundleIds = next
        } else {
            ignoredAppBundleIds.removeAll { seeded.contains($0) }
        }
    }

    func panelSize(for positionRawValue: Int, matchingScreenSize screenSize: CGSize) -> CGSize? {
        guard let stored = panelSizeByPosition[positionRawValue] else { return nil }
        guard let savedWidth = stored.screenWidth,
              let savedHeight = stored.screenHeight,
              abs(savedWidth - screenSize.width) < 0.5,
              abs(savedHeight - screenSize.height) < 0.5
        else { return nil }
        return CGSize(width: stored.width, height: stored.height)
    }

    func setPanelSize(_ size: CGSize, for positionRawValue: Int, onScreenOfSize screenSize: CGSize) {
        var next = panelSizeByPosition
        next[positionRawValue] = PanelSize(
            width: size.width,
            height: size.height,
            screenWidth: screenSize.width,
            screenHeight: screenSize.height
        )
        panelSizeByPosition = next
    }

    private static func load(from defaults: UserDefaults) -> VeerSettings {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(VeerSettings.self, from: data)
        else { return VeerSettings() }
        return decoded
    }

    private func persist() {
        Self.persist(snapshot, to: defaults)
    }

    private static func persist(_ settings: VeerSettings, to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: userDefaultsKey)
        }
    }
}
