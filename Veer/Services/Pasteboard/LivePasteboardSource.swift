import AppKit

enum PasteboardSnapshotReader {
    static func snapshot(from pasteboard: NSPasteboard) -> [PasteboardItemSnapshot] {
        if let items = pasteboard.pasteboardItems, !items.isEmpty {
            let mapped = items.map { snapshotItem($0) }.filter { !$0.typed.isEmpty }
            if !mapped.isEmpty { return mapped }
        }
        return legacySnapshot(from: pasteboard)
    }

    static func snapshotItem(_ item: NSPasteboardItem) -> PasteboardItemSnapshot {
        var typed: [String: Data] = [:]
        let types = item.types
        guard !types.isEmpty else { return PasteboardItemSnapshot(typed: [:]) }
        for type in types.prefix(Constants.Pasteboard.maxTypesPerItem) {
            if let data = readData(from: item, type: type) {
                typed[type.rawValue] = data
            }
        }
        return PasteboardItemSnapshot(typed: typed)
    }

    static func legacySnapshot(from pasteboard: NSPasteboard) -> [PasteboardItemSnapshot] {
        var typed: [String: Data] = [:]
        for type in (pasteboard.types ?? []).prefix(Constants.Pasteboard.maxTypesPerItem) {
            if let data = readData(from: pasteboard, type: type) {
                typed[type.rawValue] = data
            }
        }
        return typed.isEmpty ? [] : [PasteboardItemSnapshot(typed: typed)]
    }

    private static func readData(from item: NSPasteboardItem, type: NSPasteboard.PasteboardType) -> Data? {
        if let data = item.data(forType: type), !data.isEmpty { return data }
        if let string = item.string(forType: type), !string.isEmpty {
            return Data(string.utf8)
        }
        if let plist = item.propertyList(forType: type),
           let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0),
           !data.isEmpty
        {
            return data
        }
        return nil
    }

    private static func readData(from pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Data? {
        if let data = pasteboard.data(forType: type), !data.isEmpty { return data }
        if let string = pasteboard.string(forType: type), !string.isEmpty {
            return Data(string.utf8)
        }
        return nil
    }
}

@MainActor
final class LivePasteboardSource: PasteboardSource {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() -> [PasteboardItemSnapshot] {
        PasteboardSnapshotReader.snapshot(from: pasteboard)
    }
}
