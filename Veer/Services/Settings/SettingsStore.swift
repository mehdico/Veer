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
    private(set) var panelSizeByPosition: [Int: PanelSize] { didSet { persist() } }

    @ObservationIgnored let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.load(from: defaults)
        self.maxHistoryItems = loaded.maxHistoryItems
        self.showsRichText = loaded.showsRichText
        self.pastesRichText = loaded.pastesRichText
        self.showAsCards = loaded.showAsCards
        self.panelSizeByPosition = loaded.panelSizeByPosition
    }

    var snapshot: VeerSettings {
        VeerSettings(
            maxHistoryItems: maxHistoryItems,
            showsRichText: showsRichText,
            pastesRichText: pastesRichText,
            showAsCards: showAsCards,
            panelSizeByPosition: panelSizeByPosition
        )
    }

    func panelSize(for positionRawValue: Int) -> CGSize? {
        guard let stored = panelSizeByPosition[positionRawValue] else { return nil }
        return CGSize(width: stored.width, height: stored.height)
    }

    func setPanelSize(_ size: CGSize, for positionRawValue: Int) {
        var next = panelSizeByPosition
        next[positionRawValue] = PanelSize(width: size.width, height: size.height)
        panelSizeByPosition = next
    }

    private static func load(from defaults: UserDefaults) -> VeerSettings {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(VeerSettings.self, from: data)
        else { return VeerSettings() }
        return decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
