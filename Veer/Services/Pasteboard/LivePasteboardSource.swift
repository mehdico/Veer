import AppKit

@MainActor
final class LivePasteboardSource: PasteboardSource {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() -> [PasteboardItemSnapshot] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            var typed: [String: Data] = [:]
            for type in item.types.prefix(Constants.Pasteboard.maxTypesPerItem) {
                if let data = item.data(forType: type) {
                    typed[type.rawValue] = data
                }
            }
            return PasteboardItemSnapshot(typed: typed)
        }
    }
}
