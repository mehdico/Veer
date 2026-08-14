import Foundation

struct VeerSettings: Codable, Sendable, Equatable {
    var maxHistoryItems: Int = Constants.History.defaultMax
    var showsRichText: Bool = true
    var pastesRichText: Bool = true
    var showAsCards: Bool = true
    var textOnlyHistory: Bool = false
    var panelSizeByPosition: [Int: PanelSize] = [:]
}

extension VeerSettings {
    private enum CodingKeys: String, CodingKey {
        case maxHistoryItems
        case showsRichText
        case pastesRichText
        case showAsCards
        case textOnlyHistory
        case panelSizeByPosition
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
        self.textOnlyHistory = try container.decodeIfPresent(Bool.self, forKey: .textOnlyHistory) ?? false
        self.panelSizeByPosition = try container.decodeIfPresent([Int: PanelSize].self, forKey: .panelSizeByPosition) ?? [:]
    }
}

struct PanelSize: Codable, Sendable, Equatable {
    var width: Double
    var height: Double
    var screenWidth: Double?
    var screenHeight: Double?
}
