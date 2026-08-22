import Foundation

struct VeerSettings: Codable, Sendable, Equatable {
    var maxHistoryItems: Int = Constants.History.defaultMax
    var showsRichText: Bool = true
    var pastesRichText: Bool = true
    var showAsCards: Bool = true
    var showPreviews: Bool = true
    var textOnlyHistory: Bool = false
    var alwaysSearchWeb: Bool = false
    var ignoredAppBundleIds: [String] = []
    var ignoresPasswordManagers: Bool = true
    var didSeedDefaultIgnoredApps: Bool = false
    var hasSeenActionsHint: Bool = false
    var panelSizeByPosition: [Int: PanelSize] = [:]
    /// User-recorded hotkey overrides, keyed by `HotkeyShortcut.rawValue`
    /// mapping to `[keyCode, carbonModifiers]`.
    var customHotkeys: [String: [Int]] = [:]
}

extension VeerSettings {
    private enum CodingKeys: String, CodingKey {
        case maxHistoryItems
        case showsRichText
        case pastesRichText
        case showAsCards
        case showPreviews
        case textOnlyHistory
        case alwaysSearchWeb
        case ignoredAppBundleIds
        case ignoresPasswordManagers
        case didSeedDefaultIgnoredApps
        case hasSeenActionsHint
        case panelSizeByPosition
        case customHotkeys
    }

    /// Decodes with per-key fallbacks so settings saved before a field existed
    /// keep their other values instead of failing the whole decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.maxHistoryItems = try container.decodeIfPresent(Int.self, forKey: .maxHistoryItems)
            ?? Constants.History.defaultMax
        self.showsRichText = try container.decodeIfPresent(Bool.self, forKey: .showsRichText) ?? true
        self.pastesRichText = try container.decodeIfPresent(Bool.self, forKey: .pastesRichText) ?? true
        self.showAsCards = try container.decodeIfPresent(Bool.self, forKey: .showAsCards) ?? true
        self.showPreviews = try container.decodeIfPresent(Bool.self, forKey: .showPreviews) ?? true
        self.textOnlyHistory = try container.decodeIfPresent(Bool.self, forKey: .textOnlyHistory) ?? false
        self.alwaysSearchWeb = try container.decodeIfPresent(Bool.self, forKey: .alwaysSearchWeb) ?? false
        self.ignoredAppBundleIds = try container.decodeIfPresent([String].self, forKey: .ignoredAppBundleIds) ?? []
        self.ignoresPasswordManagers = try container.decodeIfPresent(Bool.self, forKey: .ignoresPasswordManagers) ?? true
        self.didSeedDefaultIgnoredApps = try container.decodeIfPresent(Bool.self, forKey: .didSeedDefaultIgnoredApps) ?? false
        self.hasSeenActionsHint = try container.decodeIfPresent(Bool.self, forKey: .hasSeenActionsHint) ?? false
        self.panelSizeByPosition = try container.decodeIfPresent([Int: PanelSize].self, forKey: .panelSizeByPosition) ?? [:]
        self.customHotkeys = try container.decodeIfPresent([String: [Int]].self, forKey: .customHotkeys) ?? [:]
    }
}

extension VeerSettings {
    /// Applies the default ignored-apps policy once (on first launch or after an
    /// upgrade): adds the defaults when `ignoresPasswordManagers` is on, removes
    /// them when it is off. The persisted flag keeps later per-app removals from
    /// being re-added on subsequent launches.
    mutating func applyDefaultIgnoredAppsPolicy() {
        let seeded = Constants.Privacy.defaultIgnoredApps.map(\.bundleId)
        if ignoresPasswordManagers {
            ignoredAppBundleIds = seeded + ignoredAppBundleIds.filter { !seeded.contains($0) }
        } else {
            ignoredAppBundleIds.removeAll { seeded.contains($0) }
        }
        didSeedDefaultIgnoredApps = true
    }
}

struct PanelSize: Codable, Sendable, Equatable {
    var width: Double
    var height: Double
    var screenWidth: Double?
    var screenHeight: Double?
}
