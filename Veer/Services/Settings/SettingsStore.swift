import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let userDefaultsKey = "settings"

    var maxHistoryItems: Int { didSet { persist() } }
    var showsRichText: Bool { didSet { persist() } }
    var pastesRichText: Bool { didSet { persist() } }
    var useHorizontalLayout: Bool { didSet { persist() } }

    @ObservationIgnored let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.load(from: defaults)
        self.maxHistoryItems = loaded.maxHistoryItems
        self.showsRichText = loaded.showsRichText
        self.pastesRichText = loaded.pastesRichText
        self.useHorizontalLayout = loaded.useHorizontalLayout
    }

    var snapshot: VeerSettings {
        VeerSettings(
            maxHistoryItems: maxHistoryItems,
            showsRichText: showsRichText,
            pastesRichText: pastesRichText,
            useHorizontalLayout: useHorizontalLayout
        )
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
