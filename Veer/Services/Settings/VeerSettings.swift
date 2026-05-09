import Foundation

struct VeerSettings: Codable, Sendable, Equatable {
    var maxHistoryItems: Int = Constants.History.defaultMax
    var showsRichText: Bool = true
    var pastesRichText: Bool = true
    var useHorizontalLayout: Bool = true
}
